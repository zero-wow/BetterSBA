"""Behavioral traces and local output boundaries for the bounded sequencer model."""

from contextlib import redirect_stderr, redirect_stdout
from copy import deepcopy
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("sba_sequence_trace", ROOT / "scripts/sba_sequence_trace.py")
model = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(model)


def config(provider="GRIP2.4.20", mode="sequential", count=9):
    return {
        "schema_version": 1, "provider": provider, "input_kind": "authored", "mode": mode,
        "route": "grip-direct-down" if provider == "GRIP2.4.20" else "gse-relay-down",
        "steps": [{"id": name, "spell_id": index} for index, name in enumerate("ABC", 1)],
        "clicks": [{"time_ms": index * 100, "edge": "down"} for index in range(count)],
    }


def attempts(report):
    return [event["step_id"] for event in report["events"] if event["disposition"] == "attempt"]


class SequenceTraceTests(unittest.TestCase):
    def test_sequential_wrap_and_separate_next_index(self):
        report = model.trace(config())
        self.assertEqual(attempts(report), list("ABCABCABC"))
        self.assertEqual([e["attempted_index"] for e in report["events"]], [1, 2, 3] * 3)
        self.assertEqual([e["next_index"] for e in report["events"]], [2, 3, 1] * 3)

    def test_priority_patterns_match_actual_source_proof(self):
        for provider in model.SOURCE:
            with self.subTest(provider=provider):
                self.assertEqual(attempts(model.trace(config(provider, "priority", 12))), list("AABABC" * 2))

    def test_reverse_order_is_provider_specific(self):
        self.assertEqual(attempts(model.trace(config("GSE3.3.34", "reverse", 6))), list("ABACBA"))
        self.assertEqual(attempts(model.trace(config("GRIP2.4.20", "reverse", 6))), list("CBCABC"))

    def test_repeat_repeats_expanded_loop_not_individual_rows(self):
        for provider in model.SOURCE:
            value = config(provider, "priority", 12)
            value["repeat_count"] = 2
            report = model.trace(value)
            self.assertEqual([row["id"] for row in report["program"]], list("AABABCAABABC"))
            self.assertEqual(report["events"][5]["next_index"], 7)
            self.assertEqual(report["events"][-1]["next_index"], 1)

    def test_failed_casts_do_not_control_step_progression(self):
        for provider in model.SOURCE:
            value = config(provider, "priority", 6)
            before = model.trace(value)
            for index, click in enumerate(value["clicks"]):
                click["cast_accepted"] = index % 2 == 0
            after = model.trace(value)
            self.assertEqual(attempts(before), attempts(after))
            self.assertEqual([e["next_index"] for e in before["events"]], [e["next_index"] for e in after["events"]])
            self.assertEqual([e["cast_accepted"] for e in after["events"]], [True, False] * 3)

    def test_one_registered_edge_per_physical_press(self):
        for provider, route, edge in (("GSE3.3.34", "gse-executor-up", "up"),
                                      ("GSE3.3.34", "gse-relay-down", "down"),
                                      ("GRIP2.4.20", "grip-direct-down", "down")):
            value = config(provider)
            value["route"] = route
            value["clicks"] = [{"time_ms": index * 100, "edge": event} for index in range(3) for event in ("down", "up")]
            report = model.trace(value)
            self.assertEqual(attempts(report), list("ABC"))
            self.assertTrue(all(e["edge"] == edge for e in report["events"] if e["disposition"] == "attempt"))
            self.assertEqual(sum(e["disposition"] == "ignored_edge" for e in report["events"]), 3)

    def test_grip_channel_freeze_holds_then_resumes_same_row(self):
        value = config(count=5)
        value.update(hold_on_channel=True, freeze_enabled=True)
        value["clicks"][1]["channeling"] = True
        value["clicks"][2].update(channeling=True, frozen=True)
        report = model.trace(value)
        self.assertEqual([e["disposition"] for e in report["events"]], ["attempt", "channel_hold", "modifier_freeze", "attempt", "attempt"])
        self.assertEqual(attempts(report), list("ABC"))
        self.assertEqual(report["events"][1]["step_before"], report["events"][1]["next_index"])
        self.assertIsNone(report["events"][2]["attempted_index"])

    def test_gse_pause_is_separate_from_channeling(self):
        value = config("GSE3.3.34", count=4)
        value["pause_enabled"] = True
        value["clicks"][1]["paused"] = True
        value["clicks"][2]["channeling"] = True
        report = model.trace(value)
        self.assertEqual(attempts(report), list("ABC"))
        self.assertEqual(report["events"][1]["disposition"], "modifier_pause")
        self.assertEqual(report["events"][2]["disposition"], "attempt")

    def test_disabled_guard_does_not_hold(self):
        value = config(count=3)
        for click in value["clicks"]:
            click.update(channeling=True, frozen=True)
        self.assertEqual(attempts(model.trace(value)), list("ABC"))

    def test_pause_row_consumes_one_click(self):
        value = config(count=4)
        value["steps"][1] = {"id": "wait", "kind": "pause"}
        report = model.trace(value)
        self.assertEqual(attempts(report), list("ACA"))
        self.assertEqual(report["events"][1]["disposition"], "pause_step")
        self.assertEqual(report["events"][1]["attempted_index"], 2)
        self.assertEqual(report["events"][1]["next_index"], 3)

    def test_grip_interleaves_use_original_indices(self):
        value = config(count=8)
        value["steps"].append({"id": "D", "spell_id": 4})
        value["interleaves"] = [
            {"step": {"id": "X", "spell_id": 10}, "interval": 2},
            {"step": {"id": "Y", "spell_id": 11}, "interval": 2},
        ]
        self.assertEqual(attempts(model.trace(value)), list("ABXYCDXY"))
        value["interleaves"] = value["interleaves"][:1]
        self.assertEqual([s["id"] for s in model.trace(value)["program"]], list("ABXCDX"))
        value["interleaves"][0]["interval"] = 20
        self.assertEqual([s["id"] for s in model.trace(value)["program"]], list("ABCDX"))

    def test_grip_interleave_occurs_after_loop_repeat(self):
        value = config(mode="priority")
        value["repeat_count"] = 2
        value["interleaves"] = [{"step": {"id": "X", "spell_id": 10}, "interval": 4}]
        self.assertEqual([s["id"] for s in model.trace(value)["program"]], list("AABAXBCAAXBABCX"))

    def test_compiled_input_is_not_double_expanded(self):
        value = config()
        value["input_kind"] = "compiled"
        for name in "ABC":
            value["steps"].append({"id": name, "spell_id": 9})
        self.assertEqual(len(model.trace(value)["program"]), 6)
        for change in ({"mode": "priority"}, {"repeat_count": 2}, {"interleaves": [{"step": {"id": "X", "spell_id": 10}, "interval": 1}]}):
            with self.subTest(change=change), self.assertRaises(model.TraceError):
                model.trace({**value, **change})

    def test_unsupported_engine_features_fail_explicitly(self):
        for change in ({"provider": "GSE-latest"}, {"mode": "random"}, {"reset_timer": 5},
                       {"reset_on_target": True}, {"queue_window": 400}, {"macrotext": "/cast example"},
                       {"mode": "nested"}, {"route": "hold-to-cast"}, {"release_at_max": True}):
            with self.subTest(change=change), self.assertRaises(model.TraceError):
                model.trace({**config(), **change})
        value = config("GSE3.3.34")
        value["interleaves"] = [{"step": {"id": "X", "spell_id": 10}, "interval": 1}]
        with self.assertRaises(model.TraceError):
            model.trace(value)
        for row in ({"id": "X", "macrotext": "/cast example"}, {"id": "X", "spell_id": [1, 2]},
                    {"id": "X", "spell_id": True}, {"id": "X", "kind": "pause", "spell_id": 1}):
            with self.subTest(row=row), self.assertRaises(model.TraceError):
                model.trace({**config(), "steps": [row]})

    def test_bounds_and_malformed_events(self):
        for change in ({"steps": []}, {"steps": config()["steps"] * 100}, {"repeat_count": 0},
                       {"repeat_count": True}, {"repeat_count": 51}, {"clicks": []},
                       {"clicks": [{"time_ms": 0, "edge": "down"}] * 10001}, {"freeze_enabled": 1}):
            with self.subTest(change=list(change)), self.assertRaises(model.TraceError):
                model.trace({**config(), **change})
        for time in (-1, float("nan"), float("inf"), True, "100", 10**1000):
            with self.subTest(time_type=type(time)), self.assertRaises(model.TraceError):
                model.trace({**config(), "clicks": [{"time_ms": time, "edge": "down"}]})
        with self.assertRaises(model.TraceError):
            model.trace({**config(), "clicks": [{"time_ms": 2, "edge": "down"}, {"time_ms": 1, "edge": "up"}]})
        value = config(mode="priority")
        value["steps"] *= 8  # 24 authored -> 300 expanded; reject before allocation.
        with self.assertRaises(model.TraceError):
            model.trace(value)

    def test_outcome_cannot_claim_cast_on_nonattempt(self):
        value = config(count=1)
        value["clicks"][0].update(edge="up", cast_accepted=False)
        with self.assertRaises(model.TraceError):
            model.trace(value)
        value["clicks"][0] = {"time_ms": 0, "edge": "down", "cast_accepted": "yes"}
        with self.assertRaises(model.TraceError):
            model.trace(value)

    def test_trace_is_deterministic_and_does_not_mutate_input(self):
        value = config(mode="reverse")
        before = deepcopy(value)
        self.assertEqual(model.trace(value), model.trace(value))
        self.assertEqual(value, before)
        self.assertEqual(len(model.trace(value)["compiled_sha256"]), 64)

    def test_file_output_boundary_hashes_and_no_overwrite(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "input.json"
            output = Path(directory) / "report.json"
            source.write_text(json.dumps(config()), encoding="utf-8")
            with self.assertRaises(model.TraceError):
                model.run_file(source, ROOT / "not-written-trace.json")
            self.assertFalse((ROOT / "not-written-trace.json").exists())
            report = model.run_file(source, output)
            self.assertEqual(json.loads(output.read_text()), report)
            self.assertEqual(len(report["input_sha256"]), 64)
            self.assertNotIn(str(source), output.read_text())
            with self.assertRaises(model.TraceError):
                model.run_file(source, output)
            with self.assertRaises(model.TraceError):
                model.run_file(source, source)

    def test_invalid_file_does_not_leave_report_or_echo_input(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "input.json"
            output = Path(directory) / "report.json"
            for payload in ('{"schema_version":1,"schema_version":1}', '{"unexpected-private-marker":123}', '{bad json', 'x' * (model.MAX_BYTES + 1)):
                source.write_text(payload, encoding="utf-8")
                stdout, stderr = io.StringIO(), io.StringIO()
                with redirect_stdout(stdout), redirect_stderr(stderr):
                    result = model.main(["--input", str(source), "--output", str(output)])
                self.assertEqual(result, 2)
                self.assertNotIn("unexpected-private-marker", stderr.getvalue())
                self.assertFalse(output.exists())

    def test_rejects_network_and_savedvariable_inputs_before_open(self):
        for source in (r"\\server\share\trace.json", "//server/share/trace.json",
                       "SavedVariables/trace.json", "game_profile.lua", "profile.simc"):
            with self.subTest(source=source), self.assertRaises(model.TraceError):
                model.run_file(source, "unused-report.json")


if __name__ == "__main__":
    unittest.main()
