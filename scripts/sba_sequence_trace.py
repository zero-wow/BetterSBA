"""Trace a bounded sequencer input subset locally; no casts, simulation, or DPS.

Source-derived behavior checked 2026-10-12 against installed GSE 3.3.34
(API/Storage.lua: processAction and secure OnClick) and GRIP-EMS v2.4.20
(Engine/StepFunctions.lua and Engine/ActionCompiler.lua). SOURCE records the
exact inspected hashes; the version label alone does not establish equivalence.
Public references:
https://github.com/TimothyLuke/GSE-Advanced-Macro-Compiler
https://jesperlive.github.io/grip-ems-guide/
The guide's failure-based description of Priority conflicts with the inspected
GRIP implementation: both engines pre-expand Priority to a weighted flat list.

Input JSON requires schema_version=1, provider, input_kind (authored/compiled),
route, mode (sequential/priority/reverse), steps, and clicks. A spell step is
{"id":"A", "spell_id":123}; a pause is {"id":"wait", "kind":"pause"}.
Clicks contain time_ms, edge (down/up), optional channeling/frozen/paused flags,
and optional external cast_accepted (boolean/null). These outcomes never choose
or advance a step. No macro strings, SavedVariables, or profiles are consumed.

For authored input, repeat_count repeats ONE flat loop's expanded traversal;
it is not a global/version Repeat setting. Optional GRIP interleaves contain
{"step": <spell step>, "interval": 2}; they follow every N original compiled
loop entries, after expansion/repetition, matching the inspected loop compiler.
Compiled input is already expanded: mode must be sequential, repeat_count=1,
and interleaves empty. It must contain the effective single-spell/pause rows.

Explicit route selects the modeled input edge, not a claim about WoW dispatch:
gse-executor-up, gse-relay-down, or grip-direct-down. Only GRIP accepts
hold_on_channel/freeze_enabled; only GSE accepts pause_enabled. Reset/timers,
empower releases, random/custom algorithms, nesting, macro conditionals,
multi-action rows, /castsequence, queue/latency and cast outcomes are unsupported.
All report files must be outside the addon. Nothing is uploaded or executed.
"""

import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[1]
MAX_BYTES = 2 * 1024 * 1024
MAX_STEPS = 253  # GSE iteration chunks beyond this are explicitly unsupported.
MAX_CLICKS = 10000
SOURCE = {
    "GSE3.3.34": {
        "files": {"API/Storage.lua": "3da73f4e6f531e2229d7ef9c259970ea7a6cf454eca23e07318bda6631c39c35"},
        "reference": "https://github.com/TimothyLuke/GSE-Advanced-Macro-Compiler",
    },
    "GRIP2.4.20": {
        "files": {
            "Engine/StepFunctions.lua": "b6cd8506b7355fcc1ea81139b3a72ca4ad499ad46f7f5f3479735b5815476675",
            "Engine/ActionCompiler.lua": "cacc00d7493575f7c9c015b0b33788460174aaffb8e3e928adb1b8da07a9c353",
        },
        "reference": "https://jesperlive.github.io/grip-ems-guide/",
    },
}
LIMITATIONS = [
    "Input-to-attempt trace only; no DPS, talent ranking, or cast execution.",
    "Source-based subset; WoW hardware edge dispatch has not been validated here.",
    "One sequence and fixed resolved context; no reset, timer, random, or custom expansion.",
    "Single-spell/pause rows only; no macrotext, conditionals, nested loops, or /castsequence.",
    "No queue, latency, cooldown, resource, channel tick, or empower-release model.",
    "cast_accepted is externally supplied and is not proof of an actual in-game cast.",
]


class TraceError(ValueError):
    """Invalid or unsupported input; messages never echo supplied values."""


def object_keys(value, allowed, required=()):
    if not isinstance(value, dict):
        raise TraceError("Expected a JSON object.")
    if set(value) - set(allowed):
        raise TraceError("Unsupported field: only the documented trace subset is accepted.")
    if set(required) - set(value):
        raise TraceError("A required trace field is missing.")


def choice(value, allowed):
    if not isinstance(value, str) or value not in allowed:
        raise TraceError("Unsupported provider, route, input kind, mode, or edge.")
    return value


def integer(value, lower, upper):
    if type(value) is not int or not lower <= value <= upper:
        raise TraceError("An integer is outside the supported bounds.")
    return value


def boolean(value):
    if type(value) is not bool:
        raise TraceError("State flags must be booleans.")
    return value


def step(value, source_index):
    object_keys(value, {"id", "kind", "spell_id"}, {"id"})
    label = value["id"]
    if not isinstance(label, str) or not 1 <= len(label) <= 80 or any(ord(c) < 32 for c in label):
        raise TraceError("Step ids require 1-80 printable characters.")
    kind = choice(value.get("kind", "spell"), {"spell", "pause"})
    spell_id = None
    if kind == "spell":
        spell_id = integer(value.get("spell_id"), 1, 2147483647)
    elif "spell_id" in value:
        raise TraceError("A pause row cannot contain a spell.")
    return {"id": label, "kind": kind, "spell_id": spell_id, "source_index": source_index}


def compile_steps(config):
    values = config["steps"]
    if not isinstance(values, list) or not 1 <= len(values) <= MAX_STEPS:
        raise TraceError("Supply 1-253 single-spell/pause steps.")
    base = [step(value, index) for index, value in enumerate(values, 1)]
    repeats = integer(config.get("repeat_count", 1), 1, 50)
    interleaves = config.get("interleaves", [])
    if not isinstance(interleaves, list) or len(interleaves) > 16:
        raise TraceError("Supply at most 16 GRIP interleaves.")
    if config["input_kind"] == "compiled":
        if config["mode"] != "sequential" or repeats != 1 or interleaves:
            raise TraceError("Compiled input must not be expanded or repeated again.")
        return base
    count = len(base)
    expanded_count = count if config["mode"] == "sequential" else count * (count + 1) // 2
    if expanded_count * repeats > MAX_STEPS:
        raise TraceError("Expanded sequence exceeds the 253-step subset.")
    if config["mode"] == "sequential":
        expanded = base
    elif config["mode"] == "priority":
        expanded = [base[j] for i in range(count) for j in range(i + 1)]
    elif config["provider"] == "GSE3.3.34":
        expanded = [base[j] for i in range(count) for j in range(i, -1, -1)]
    else:
        expanded = [base[j] for i in range(count - 1, -1, -1) for j in range(i, count)]
    expanded = expanded * repeats
    if interleaves:
        if config["provider"] != "GRIP2.4.20":
            raise TraceError("GSE interval Repeat nodes are not GRIP interleaves.")
        insert_after = {}
        inserted = 0
        for index, value in enumerate(interleaves, 1):
            object_keys(value, {"step", "interval"}, {"step", "interval"})
            item = step(value["step"], "interleave:" + str(index))
            if item["kind"] != "spell":
                raise TraceError("Interleaves require single-spell actions.")
            interval = min(integer(value["interval"], 1, 50), len(expanded))
            for position in range(interval, len(expanded) + 1, interval):
                if inserted >= 200:  # Installed GRIP compiler scope limit.
                    break
                insert_after.setdefault(position, []).append(item)
                inserted += 1
        if len(expanded) + inserted > MAX_STEPS:
            raise TraceError("Interleaved sequence exceeds the 253-step subset.")
        result = []
        for position, item in enumerate(expanded, 1):
            result.append(item)
            result.extend(insert_after.get(position, ()))
        expanded = result
    return expanded


def validate_config(config):
    object_keys(config, {"schema_version", "provider", "input_kind", "mode", "route", "steps",
                        "repeat_count", "interleaves", "clicks", "hold_on_channel", "freeze_enabled",
                        "pause_enabled"},
                {"schema_version", "provider", "input_kind", "mode", "route", "steps", "clicks"})
    integer(config["schema_version"], 1, 1)
    choice(config["provider"], SOURCE)
    choice(config["input_kind"], {"authored", "compiled"})
    choice(config["mode"], {"sequential", "priority", "reverse"})
    routes = {"gse-executor-up", "gse-relay-down"} if config["provider"] == "GSE3.3.34" else {"grip-direct-down"}
    choice(config["route"], routes)
    for flag in ("hold_on_channel", "freeze_enabled", "pause_enabled"):
        boolean(config.get(flag, False))
    if config["provider"] == "GSE3.3.34" and (config.get("hold_on_channel") or config.get("freeze_enabled")):
        raise TraceError("GSE has no supported engine channel-hold/freeze guard in this subset.")
    if config["provider"] == "GRIP2.4.20" and config.get("pause_enabled"):
        raise TraceError("GRIP uses freeze_enabled, not the GSE pause guard.")
    clicks = config["clicks"]
    if not isinstance(clicks, list) or not 1 <= len(clicks) <= MAX_CLICKS:
        raise TraceError("Supply 1-10000 timestamped input events.")
    previous = -1
    for click in clicks:
        object_keys(click, {"time_ms", "edge", "channeling", "frozen", "paused", "cast_accepted"}, {"time_ms", "edge"})
        time_ms = click["time_ms"]
        if type(time_ms) not in (int, float) or not 0 <= time_ms <= 86400000 or not math.isfinite(time_ms) or time_ms < previous:
            raise TraceError("Input times must be finite, ordered, and within a 24-hour trace.")
        previous = time_ms
        choice(click["edge"], {"down", "up"})
        for flag in ("channeling", "frozen", "paused"):
            boolean(click.get(flag, False))
        if click.get("cast_accepted") is not None:
            boolean(click["cast_accepted"])
        if config["provider"] == "GSE3.3.34" and click.get("frozen"):
            raise TraceError("GSE input uses paused, not frozen.")
        if config["provider"] == "GRIP2.4.20" and click.get("paused"):
            raise TraceError("GRIP input uses frozen, not paused.")


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False).encode()).hexdigest()


def trace(config):
    validate_config(config)
    program = compile_steps(config)
    pointer = 0
    events = []
    expected_edge = "up" if config["route"] == "gse-executor-up" else "down"
    for index, click in enumerate(config["clicks"], 1):
        before = pointer + 1
        attempted = None
        if click["edge"] != expected_edge:
            reason = "ignored_edge"
        elif config.get("pause_enabled") and click.get("paused"):
            reason = "modifier_pause"
        elif config.get("freeze_enabled") and click.get("frozen"):
            reason = "modifier_freeze"
        elif config.get("hold_on_channel") and click.get("channeling"):
            reason = "channel_hold"
        else:
            attempted = program[pointer]
            reason = "attempt" if attempted["kind"] == "spell" else "pause_step"
            pointer = (pointer + 1) % len(program)
        if reason != "attempt" and click.get("cast_accepted") is not None:
            raise TraceError("Cast outcomes require an attempted spell; omit them on ignored, held, or pause events.")
        events.append({
            "event_index": index, "time_ms": click["time_ms"], "edge": click["edge"],
            "state": {flag: click.get(flag, False) for flag in ("channeling", "frozen", "paused")},
            "disposition": reason, "step_before": before,
            "attempted_index": before if attempted else None, "next_index": pointer + 1,
            "step_id": attempted["id"] if attempted else None,
            "spell_id": attempted["spell_id"] if attempted else None,
            "cast_accepted": click.get("cast_accepted"),
        })
    return {
        "schema_version": 1, "analysis": "input_trace_only", "provider": config["provider"],
        "source": SOURCE[config["provider"]], "source_checked_date": "2026-10-12",
        "config_sha256": digest(config), "compiled_sha256": digest(program),
        "route": config["route"], "input_kind": config["input_kind"], "mode": config["mode"],
        "guards": {flag: config.get(flag, False) for flag in ("hold_on_channel", "freeze_enabled", "pause_enabled")},
        "program": [{"index": i, **item} for i, item in enumerate(program, 1)],
        "events": events, "limitations": LIMITATIONS,
    }


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise TraceError("Duplicate JSON fields are not supported.")
        result[key] = value
    return result


def run_file(input_path, output_path):
    for path in (input_path, output_path):
        # Explicit trace files only; do not follow a UNC/device path into a
        # network share or consume a game's account persistence directory.
        if str(path).replace("/", "\\").startswith("\\\\"):
            raise TraceError("Use ordinary local JSON paths, not network or device paths.")
        if Path(path).suffix.lower() != ".json" or any(part.casefold() == "savedvariables" for part in Path(path).parts):
            raise TraceError("Use explicit JSON trace files outside SavedVariables.")
    source = Path(input_path).resolve(strict=True)
    destination = Path(output_path).resolve()
    for path in (source, destination):
        if str(path).replace("/", "\\").startswith("\\\\"):
            raise TraceError("Resolved trace paths must remain local.")
        if os.name == "nt":
            import ctypes
            get_drive_type = ctypes.windll.kernel32.GetDriveTypeW
            get_drive_type.argtypes = [ctypes.c_wchar_p]
            get_drive_type.restype = ctypes.c_uint
            if get_drive_type(path.anchor) == 4:  # DRIVE_REMOTE, including mapped shares.
                raise TraceError("Mapped network drives are not supported for trace files.")
    if any(part.casefold() == "savedvariables" for path in (source, destination) for part in path.parts):
        raise TraceError("Resolved trace paths must stay outside SavedVariables.")
    if destination == ROOT or ROOT in destination.parents:
        raise TraceError("Trace output must stay outside the addon repository.")
    if destination == source or destination.exists():
        raise TraceError("Choose a new output file; trace inputs and existing reports are never overwritten.")
    with source.open("rb") as handle:
        raw = handle.read(MAX_BYTES + 1)
    if len(raw) > MAX_BYTES:
        raise TraceError("Input exceeds the 2 MiB trace limit.")
    try:
        config = json.loads(raw, object_pairs_hook=unique_object)
    except (json.JSONDecodeError, UnicodeDecodeError, RecursionError):
        raise TraceError("Input must be a valid, bounded JSON object.") from None
    report = trace(config)
    report["input_sha256"] = hashlib.sha256(raw).hexdigest()
    destination.parent.mkdir(parents=True, exist_ok=True)
    with destination.open("x", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2, ensure_ascii=True, allow_nan=False)
        handle.write("\n")
    return report


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--input", required=True, type=Path, help="Explicit JSON step/input trace file")
    parser.add_argument("--output", required=True, type=Path, help="New report file outside the addon")
    args = parser.parse_args(argv)
    try:
        report = run_file(args.input, args.output)
    except TraceError as exc:
        print("Trace rejected: " + str(exc), file=sys.stderr)
        return 2
    except (OSError, ValueError, OverflowError):
        print("Trace failed: check local input/output access and supported input values.", file=sys.stderr)
        return 2
    print(f"Wrote local input trace: {len(report['program'])} steps, {len(report['events'])} events. No DPS model.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
