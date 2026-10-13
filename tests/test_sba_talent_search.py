"""Candidate identity, utility preservation and uncertainty gates."""

from pathlib import Path
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import run_sba_talent_search as search


class SearchTests(unittest.TestCase):
    def test_ranking_requires_distinguishable_intervals(self):
        def row(identifier, mean, error=1):
            return dict(id=identifier, mean_dps=mean, mean_std_dev=error, model_warning_count=0)
        separated = search.rank_results([row("a", 120), row("b", 100)])
        self.assertEqual(separated["state"], "ready")
        self.assertEqual(separated["choices"], ["a"])
        overlap = search.rank_results([row("b", 100), row("a", 100)])
        self.assertEqual(overlap["state"], "tie")
        self.assertEqual(set(overlap["choices"]), {"a", "b"})
        self.assertGreater(separated["intervals"][0]["interval_error"], 1.96)

    def test_single_and_warning_results_cannot_claim_best(self):
        row = dict(id="a", mean_dps=100, mean_std_dev=1, model_warning_count=0)
        self.assertEqual(search.rank_results([row])["state"], "single-candidate")
        row["model_warning_count"] = 1
        self.assertEqual(search.rank_results([row])["state"], "unavailable")
        self.assertEqual(search.rank_results([])["state"], "unavailable")

    def test_invalid_estimates_rejected(self):
        for mean, error in [(float("nan"), 1), (100, float("inf")), (100, -1), (0, 1)]:
            with self.subTest(mean=mean, error=error), self.assertRaises(ValueError):
                search.rank_results([dict(id="a", mean_dps=mean, mean_std_dev=error, model_warning_count=0)])

    def test_decoder_engine_and_build_must_match(self):
        schema = dict(wow_build="12.1.0.69933", source_revision="abcdef0123456789abcdef0123456789abcdef01")
        summary = dict(engine_git_revision="abcdef0", game_data=dict(wow_version="12.1.0.69933"))
        search.validate_engine_identity(summary, schema, "12.1.0", "69933")
        with self.assertRaises(ValueError):
            search.validate_engine_identity(None, schema, "12.1.5", "70077")
        for revision in (None, "abc", "deadbee", "ABCDEF0"):
            summary["engine_git_revision"] = revision
            with self.subTest(revision=revision), self.assertRaises(ValueError):
                search.validate_engine_identity(summary, schema, "12.1.0", "69933")
        summary["engine_git_revision"] = "abcdef0"
        summary["game_data"]["wow_version"] = "12.1.0.69934"
        with self.assertRaises(ValueError):
            search.validate_engine_identity(summary, schema, "12.1.0", "69933")

    @patch.object(search, "decode_talents")
    def test_preserves_anchor_class_and_hero(self, decode):
        decoded = {
            "A": dict(spec_id=269, class_signature="same", hero_subtree_id=65),
            "B": dict(spec_id=269, class_signature="same", hero_subtree_id=65),
            "C": dict(spec_id=269, class_signature="changed", hero_subtree_id=65),
            "D": dict(spec_id=269, class_signature="same", hero_subtree_id=66),
            "E": dict(spec_id=270, class_signature="same", hero_subtree_id=65),
        }
        for value in decoded.values(): value["hero_signature"] = "same"
        decode.side_effect = lambda code, _: decoded[code]
        manifest = {"schema_version": 1, "anchor_id": "a", "candidates": [
            dict(id=key.lower(), name=key, import_string=key) for key in decoded]}
        anchor, accepted, rejected = search.load_candidates(manifest, {})
        self.assertEqual(anchor["id"], "a")
        self.assertEqual([row["id"] for row in accepted], ["a", "b"])
        self.assertEqual([row["id"] for row in rejected], ["c", "d", "e"])

    @patch.object(search, "decode_talents", return_value=dict(spec_id=269, class_signature="same", hero_subtree_id=65, hero_signature="same"))
    def test_manifest_identity_and_path_injection_rejected(self, _):
        good = dict(id="a", name="A", import_string="A")
        for second in [dict(id="a", name="B", import_string="B"),
                       dict(id="b", name="B", import_string="A"),
                       dict(id="../outside", name="B", import_string="B"),
                       dict(id="b", name="B\ninput=other", import_string="B")]:
            with self.subTest(second=second), self.assertRaises(ValueError):
                search.load_candidates(dict(schema_version=1, anchor_id="a", candidates=[good, second]), {})


if __name__ == "__main__":
    unittest.main()
