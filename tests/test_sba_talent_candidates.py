"""Structural decoding tests. Optional SBA_TRAIT_DATA verifies public real exports."""
import copy
import os
from pathlib import Path
import re
import sys
import tempfile
import unittest

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
import sba_talent_candidates as candidates


def row(tree, entry, node, maximum=1, kind=0, subtree=0, starter=0):
    return (f'  {{ {tree}, 10, {entry}, {node}, {maximum}, 0, 1, 1, 0, 0, 1, 1, 100, "Fixture", '
            f'{{ 269, 0, 0, 0 }}, {{ {starter}, 0, 0, 0 }}, {subtree}, {kind} }},')


ROWS = [row(1, 101, 10, maximum=2), row(1, 102, 11, kind=2), row(1, 103, 11, kind=2),
        row(1, 104, 12, starter=269), row(2, 201, 20, kind=1), row(2, 202, 20, kind=1),
        row(3, 301, 30, subtree=65), row(3, 302, 31, subtree=64),
        row(4, 401, 40, kind=3, subtree=65), row(4, 402, 40, kind=3, subtree=64)]


def table_text(rows):
    return (f"// Player trait definitions, wow build {candidates.WOW_BUILD}\n"
            f"static constexpr std::array<trait_data_t, {len(rows)}> __trait_data_data {{ {{\n"
            + "\n".join(rows) + "\n} };\n")


def encode(schema, selected, *, spec=269, version=2, tree_hash=0, overrides=None):
    """Independent inverse bit writer for fixtures and decoded real allocations."""
    bits = []
    def put(width, value):
        bits.extend((value >> n) & 1 for n in range(width))
    put(8, version); put(16, spec); put(128, tree_hash)
    for node_id, entries in sorted(schema["classes"][10].items()):
        allocated = [(i, selected[e["entry_id"]]) for i, e in enumerate(entries) if e["entry_id"] in selected]
        put(1, bool(allocated))
        if not allocated:
            continue
        index, (_, purchased) = allocated[0]
        rank = sum(value[0] for _, value in allocated)
        first = entries[0]
        maximum = sum(e["max_ranks"] for e in entries) if first["node_type"] == 1 else entries[index]["max_ranks"]
        override = (overrides or {}).get(node_id, {})
        rank = override.get("rank", rank)
        put(1, purchased)
        if not purchased:
            continue
        put(1, rank != maximum)
        if rank != maximum:
            put(6, rank)
        choice = first["node_type"] in (2, 3)
        put(1, choice)
        if choice:
            put(2, override.get("index", index))
    bits.extend([0] * ((-len(bits)) % 6))
    return "".join(candidates.BASE64[sum(bits[i + n] << n for n in range(6))] for i in range(0, len(bits), 6))


class CandidateTests(unittest.TestCase):
    def setUp(self):
        self.schema = candidates._parse_trait_text(table_text(ROWS))
        self.selected = {101: (1, True), 103: (1, True), 104: (1, False),
                         201: (1, True), 202: (1, True), 301: (1, True),
                         302: (1, False), 401: (1, True)}
        self.code = encode(self.schema, self.selected)

    def test_rank_choice_grant_inactive_hero_and_roundtrip(self):
        decoded = candidates.decode_talents(self.code, self.schema)
        self.assertEqual(decoded["ranks"], {entry: value[0] for entry, value in self.selected.items()})
        self.assertEqual(decoded["hero_subtree_id"], 65)
        self.assertEqual(len(decoded["class_signature"]), 3)
        self.assertEqual(decoded["validation_status"], "structurally_decoded_needs_live_validation")
        allocation = {e["entry_id"]: (e["rank"], e["purchased"]) for e in decoded["entries"]}
        self.assertEqual(encode(self.schema, allocation), self.code)
        self.assertEqual(candidates.encode_talents(decoded, self.schema), self.code)

    def test_constraints_compare_allocations_not_string_or_counts(self):
        anchor = candidates.decode_talents(self.code, self.schema)
        self.assertTrue(candidates.preserves_anchor(anchor, copy.deepcopy(anchor)))
        for key, value in [("spec_id", 268), ("class_signature", ()), ("hero_subtree_id", 64), ("hero_signature", ())]:
            altered = dict(anchor, **{key: value})
            self.assertFalse(candidates.preserves_anchor(anchor, altered), key)

    def test_bad_alphabet_length_version_and_spec(self):
        for code in ["", self.code + "=", " " + self.code, self.code + "\n",
                     encode(self.schema, self.selected, version=3), encode(self.schema, self.selected, spec=268)]:
            with self.subTest(code_length=len(code)), self.assertRaises(ValueError):
                candidates.decode_talents(code, self.schema)

    def test_truncated_and_trailing_bits(self):
        for code in [self.code[:-1], self.code[:-4], self.code + "A", self.code + "B"]:
            with self.subTest(code_length=len(code)), self.assertRaises(ValueError):
                candidates.decode_talents(code, self.schema)

    def test_rank_overflow_zero_and_choice_index(self):
        for overrides in [{10: {"rank": 3}}, {10: {"rank": 0}}, {11: {"index": 3}}]:
            with self.subTest(overrides=overrides), self.assertRaises(ValueError):
                candidates.decode_talents(encode(self.schema, self.selected, overrides=overrides), self.schema)

    def test_duplicate_entry_and_conflicting_node_rejected(self):
        for rows in [ROWS[:1] + ROWS, ROWS[:4] + [row(2, 250, 10)] + ROWS[4:]]:
            with self.assertRaises(ValueError):
                candidates._parse_trait_text(table_text(rows))

    def test_bad_source_fields_count_and_digest(self):
        for text in [table_text(ROWS).replace("269, 0, 0, 0", "269, 0, 0", 1),
                     table_text(ROWS).replace("trait_data_t, 10", "trait_data_t, 11"),
                     table_text(ROWS).replace(candidates.WOW_BUILD, "12.0.0.1")]:
            with self.assertRaises(ValueError):
                candidates._parse_trait_text(text)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "trait_data.inc"
            path.write_text(table_text(ROWS))
            with self.assertRaises(ValueError):
                candidates.parse_trait_data(path)

    def test_nonzero_hash_is_preserved_not_validated(self):
        code = encode(self.schema, self.selected, tree_hash=123456)
        result = candidates.decode_talents(code, self.schema)
        self.assertTrue(result["tree_hash_present"])
        self.assertEqual(int(result["tree_hash"], 16), 123456)
        self.assertIn("needs_live_validation", result["validation_status"])

    def test_encoder_rejects_allocation_bits_disagreement(self):
        decoded = candidates.decode_talents(self.code, self.schema)
        decoded["entries"][0]["rank"] = 2
        with self.assertRaises(ValueError):
            candidates.encode_talents(decoded, self.schema)

    def test_graft_rejects_changed_paid_rank_total(self):
        selected = dict(self.selected)
        del selected[202]
        with self.assertRaisesRegex(ValueError, "paid-rank"):
            candidates.graft_spec_talents(self.code, encode(self.schema, selected), self.schema)

    def test_graft_keeps_header_and_non_spec_node_bits(self):
        # A donor may differ outside its spec tree. Those differences must not
        # leak into the hybrid, including inactive hero grant bits and tree hash.
        selected = dict(self.selected)
        selected[101] = (2, True)
        selected[302] = (1, True)
        donor_code = encode(self.schema, selected, tree_hash=9876)
        anchor_code = encode(self.schema, self.selected, tree_hash=1234)
        hybrid_code = candidates.graft_spec_talents(anchor_code, donor_code, self.schema)
        self.assertEqual(hybrid_code, anchor_code)

    @unittest.skipUnless(os.environ.get("SBA_TRAIT_DATA"), "external pinned trait table not provided")
    def test_three_real_exports_roundtrip_and_constraints(self):
        schema = candidates.parse_trait_data(os.environ["SBA_TRAIT_DATA"])
        supplied = re.search(r'importString = "([^"]+)"', (ROOT / "Core/TalentAnalysisData.lua").read_text())[1]
        lazy = re.search(r'id = "LAZYGRIP-121-269-mqd2avol".*?importString = "([^"]+)"',
                         (ROOT / "Core/LazyGripTalentBuildData.lua").read_text(), re.S)[1]
        # Public MID2 profile at SIMC_REVISION; this fixture is not a user profile.
        mid2 = "C0QAAAAAAAAAAAAAAAAAAAAAAMzYw2MmhlZGbzAAAAAAAAAAAAsMMaGzAGwMGmZmZY2GmhZZmAAWMz2MDzMzMAA2AQzys0MzMLAYgZGAGLDgB8B"
        results = []
        for code, expected_count in [(supplied, 81), (lazy, 80), (mid2, 80)]:
            decoded = candidates.decode_talents(code, schema)
            self.assertEqual(decoded["spec_id"], 269)
            self.assertEqual(decoded["hero_subtree_id"], 65)
            self.assertEqual(len(decoded["entries"]), expected_count)
            allocation = {e["entry_id"]: (e["rank"], e["purchased"]) for e in decoded["entries"]}
            self.assertEqual(encode(schema, allocation, tree_hash=int(decoded["tree_hash"], 16)), code)
            self.assertEqual(candidates.encode_talents(decoded, schema), code)
            results.append(decoded)
        self.assertFalse(candidates.preserves_anchor(results[0], results[1]))
        self.assertFalse(candidates.preserves_anchor(results[0], results[2]))
        anchor = results[0]
        for donor_code, donor in zip((lazy, mid2), results[1:]):
            hybrid_code = candidates.graft_spec_talents(supplied, donor_code, schema)
            hybrid = candidates.decode_talents(hybrid_code, schema)
            self.assertTrue(candidates.preserves_anchor(anchor, hybrid))
            self.assertEqual(hybrid["tree_hash"], anchor["tree_hash"])
            self.assertEqual([e for e in hybrid["entries"] if e["tree"] == 2],
                             [e for e in donor["entries"] if e["tree"] == 2])
            for node, entries in schema["classes"][10].items():
                if entries[0]["tree"] != 2:
                    self.assertEqual(hybrid["node_bits"][node], anchor["node_bits"][node])
            # The supplied and LazyGrip builds already have the same full spec
            # tree. Its hybrid must deduplicate to the anchor, not become a new
            # supposedly distinct candidate.
            self.assertEqual(hybrid_code == supplied, donor_code == lazy)
            self.assertEqual(candidates.encode_talents(hybrid, schema), hybrid_code)


if __name__ == "__main__":
    unittest.main()
