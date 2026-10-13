"""Decode source-qualified Windwalker candidates; this is NOT a legality solver.

Public API: parse_trait_data(path), decode_talents(code, schema),
encode_talents(decoded, schema), graft_spec_talents(anchor, donor, schema), and
preserves_anchor(anchor, candidate). The external trait_data.inc must match the
pinned SimC revision. No source tables are bundled and no client state is changed.
Serialization follows player.cpp generate_tree_nodes/parse_traits_hash, retaining
file order within each node, including nodes for the other Monk specializations.
Prerequisite edges, currency budgets, and live conditions are not in this schema.
"""

import hashlib
from pathlib import Path
import re


SIMC_REVISION = "af05b9e2e1e50ad5b50f255d7189161dcc058554"
TRAIT_DATA_SHA256 = "3f58211f59d4304f019f12c1e359a7862410c97461caa91b12398f4d00c46e2a"
WOW_BUILD = "12.1.0.69933"
SOURCE_URL = f"https://github.com/simulationcraft/simc/blob/{SIMC_REVISION}/engine/dbc/generated/trait_data.inc"
SERIALIZATION_URL = f"https://github.com/simulationcraft/simc/blob/{SIMC_REVISION}/engine/player/player.cpp"
BASE64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
SPEC_CLASSES = {269: 10}  # Deliberately bounded to the verified Windwalker proof.


def _parse_trait_text(text):
    """Parse the generated initializer without evaluating C++ or arbitrary input."""
    header = re.match(r"// Player trait definitions, wow build ([0-9.]+)\r?\n", text)
    block = re.search(r"std::array<trait_data_t, (\d+)> __trait_data_data \{ \{\s*\n(.*?)\n\} \};", text, re.S)
    if not header or not block or header[1] != WOW_BUILD:
        raise ValueError("Unsupported trait data format or client build.")
    traits, entry_ids, previous = [], set(), (0, 0)
    row_pattern = re.compile(r'\s*\{\s*([\d,\s-]+)"([^"\\]*)",\s*\{([\d,\s]+)\},\s*\{([\d,\s]+)\},\s*(\d+),\s*(\d+)\s*\},\s*')
    for row in block[2].splitlines():
        match = row_pattern.fullmatch(row)
        if not match:
            raise ValueError("Malformed generated trait row.")
        values = [int(v.strip()) for v in match[1].rstrip().rstrip(",").split(",")]
        specs = tuple(int(v.strip()) for v in match[3].split(","))
        starters = tuple(int(v.strip()) for v in match[4].split(","))
        if len(values) != 13 or len(specs) != 4 or len(starters) != 4:
            raise ValueError("Unexpected generated trait fields.")
        tree, class_id, entry_id, node_id, max_ranks = values[:5]
        subtree, node_type = int(match[5]), int(match[6])
        if (not 0 < tree <= 6 or not 0 <= class_id <= 13 or min(entry_id, node_id) <= 0
                or not 0 <= max_ranks <= 63 or node_type not in (0, 1, 2, 3)
                or (tree, class_id) < previous or entry_id in entry_ids):
            raise ValueError("Invalid, duplicate, or unordered generated trait data.")
        previous = (tree, class_id)
        entry_ids.add(entry_id)
        traits.append(dict(tree=tree, class_id=class_id, entry_id=entry_id,
                           node_id=node_id, max_ranks=max_ranks, specs=specs,
                           starters=starters, subtree=subtree, node_type=node_type))
    if len(traits) != int(block[1]):
        raise ValueError("Generated trait row count mismatch.")
    classes = {}
    for trait in traits:
        classes.setdefault(trait["class_id"], {}).setdefault(trait["node_id"], []).append(trait)
    for nodes in classes.values():
        for entries in nodes.values():
            first = entries[0]
            if any((e["tree"], e["node_type"]) != (first["tree"], first["node_type"]) for e in entries):
                raise ValueError("A node has conflicting tree or type data.")
            # The pinned table contains placeholder entries on some ordinary
            # nodes. Preserve them: SimC uses the first entry for a full rank.
            if first["node_type"] in (2, 3) and len(entries) > 4:
                raise ValueError("Choice node exceeds the serialization index width.")
    return {"wow_build": header[1], "classes": classes, "source_revision": SIMC_REVISION}


def parse_trait_data(path):
    """Load the exact pinned external public table; reject other revisions."""
    data = Path(path).read_bytes()
    digest = hashlib.sha256(data).hexdigest()
    if digest != TRAIT_DATA_SHA256:
        raise ValueError("Trait data does not match the reviewed SimC revision.")
    schema = _parse_trait_text(data.decode("utf-8"))
    schema["sha256"] = digest
    return schema


class _Bits:
    def __init__(self, code):
        if not isinstance(code, str) or not 26 <= len(code) <= 4096 or any(c not in BASE64 for c in code):
            raise ValueError("Invalid talent export alphabet or length.")
        self.values = [BASE64.index(c) for c in code]
        self.position = 0

    def read(self, count):
        if self.position + count > len(self.values) * 6:
            raise ValueError("Truncated talent export.")
        result = 0
        for offset in range(count):
            at = self.position + offset
            result |= ((self.values[at // 6] >> (at % 6)) & 1) << offset
        self.position += count
        return result

    def finish(self):
        remaining = len(self.values) * 6 - self.position
        if remaining > 5 or self.read(remaining):
            raise ValueError("Unexpected trailing talent data.")

    def segment(self, start, end):
        return "".join(str((self.values[i // 6] >> (i % 6)) & 1) for i in range(start, end))


def decode_talents(code, schema):
    """Return a structural allocation and signatures, never a legality verdict.

    class_signature preserves every class-tree entry/rank, including granted
    nodes. It protects class-tree utility but cannot classify utility elsewhere.
    hero_subtree_id identifies the hero choice; hero_signature retains all hero
    allocations, including inactive ones, so callers can preserve them exactly.
    """
    if schema.get("wow_build") != WOW_BUILD:
        raise ValueError("Unsupported trait schema build.")
    bits = _Bits(code)
    if bits.read(8) != 2:
        raise ValueError("Unsupported talent serialization version.")
    spec_id = bits.read(16)
    if spec_id not in SPEC_CLASSES:
        raise ValueError("Unsupported specialization; this decoder is scoped to Windwalker.")
    tree_hash = bits.read(128)
    nodes = schema["classes"].get(SPEC_CLASSES[spec_id])
    if not nodes:
        raise ValueError("Class tree is missing.")
    selected, hero_trees, node_bits = [], set(), {}
    for node_id, entries in sorted(nodes.items()):
        start = bits.position
        if not bits.read(1):
            node_bits[node_id] = "0"
            continue
        first = entries[0]
        max_rank = sum(e["max_ranks"] for e in entries) if first["node_type"] == 1 else first["max_ranks"]
        rank, entry = max_rank, first
        purchased = bool(bits.read(1))
        if not purchased:
            rank = 1
        else:
            if bits.read(1):
                rank = bits.read(6)
                if not 0 < rank < max_rank or (first["node_type"] != 1 and len(entries) > 1):
                    raise ValueError("Invalid partial talent rank.")
            choice = bool(bits.read(1))
            if choice:
                if first["node_type"] not in (2, 3):
                    raise ValueError("Choice index on an ordinary node.")
                index = bits.read(2)
                if index >= len(entries):
                    raise ValueError("Talent choice index is out of bounds.")
                entry = entries[index]
            elif first["node_type"] in (2, 3):
                raise ValueError("Choice node is missing its selection index.")
        if max_rank <= 0 or rank > max_rank:
            raise ValueError("Selected rank exceeds the node maximum.")
        if entry["tree"] != 3 and any(entry["specs"]) and spec_id not in entry["specs"]:
            raise ValueError("Selected entry is unavailable to this specialization.")
        # The export can mark inactive hero entries free even when this table's
        # starter-spec list does not. Preserve that bit, as SimC does; determining
        # whether a grant is valid requires the client's condition data.
        allocations = []
        if first["node_type"] == 1:
            remaining = rank
            for tier in entries:
                allocated = min(remaining, tier["max_ranks"])
                if allocated:
                    allocations.append((tier, allocated))
                remaining -= allocated
                if not remaining:
                    break
        else:
            allocations.append((entry, rank))
        for trait, allocated in allocations:
            selected.append({"node_id": node_id, "entry_id": trait["entry_id"], "rank": allocated,
                             "tree": trait["tree"], "purchased": purchased, "subtree_id": trait["subtree"]})
            if trait["tree"] == 4:
                hero_trees.add(trait["subtree"])
        node_bits[node_id] = bits.segment(start, bits.position)
    bits.finish()
    if len(hero_trees) != 1 or 0 in hero_trees:
        raise ValueError("Exactly one known hero subtree must be selected.")
    hero_subtree = next(iter(hero_trees))
    # Native/public exports can retain allocations in inactive hero subtrees.
    # Keep them in the signature rather than treating them as active effects.
    signature = lambda tree: tuple(sorted((e["node_id"], e["entry_id"], e["rank"], e["purchased"])
                                         for e in selected if e["tree"] == tree))
    return {"spec_id": spec_id, "class_signature": signature(1), "hero_signature": signature(3),
            "utility_signature": signature(1), "utility_scope": "class_tree_only",
            "hero_subtree_id": hero_subtree, "ranks": {e["entry_id"]: e["rank"] for e in selected},
            "entries": selected, "tree_hash": f"{tree_hash:032x}", "tree_hash_present": tree_hash != 0,
            "node_bits": node_bits,
            "validation_status": "structurally_decoded_needs_live_validation"}


def preserves_anchor(anchor, candidate):
    """Compare scope constraints only. True does not establish talent legality."""
    return (candidate["spec_id"] == anchor["spec_id"]
            and candidate["class_signature"] == anchor["class_signature"]
            and candidate["hero_subtree_id"] == anchor["hero_subtree_id"]
            and candidate["hero_signature"] == anchor["hero_signature"])


def _encode_node_bits(decoded, schema):
    nodes = schema["classes"][SPEC_CLASSES[decoded["spec_id"]]]
    if set(nodes) != set(decoded["node_bits"]):
        raise ValueError("Serialized node set differs from the pinned schema.")
    def bits(width, value):
        return "".join(str((value >> n) & 1) for n in range(width))
    stream = bits(8, 2) + bits(16, decoded["spec_id"]) + bits(128, int(decoded["tree_hash"], 16))
    for node in sorted(nodes):
        node_bits = decoded["node_bits"][node]
        if not isinstance(node_bits, str) or not node_bits or set(node_bits) - {"0", "1"}:
            raise ValueError("Invalid serialized node bits.")
        stream += node_bits
    stream += "0" * ((-len(stream)) % 6)
    return "".join(BASE64[sum(int(stream[i + n]) << n for n in range(6))]
                   for i in range(0, len(stream), 6))


def encode_talents(decoded, schema):
    """Roundtrip a decoded allocation, preserving its hash, grant and choice bits.

    Serialized nodes are authoritative. Mismatching edited rank/entry data is
    rejected; use the constrained graft helper for source-qualified hybrids.
    """
    code = _encode_node_bits(decoded, schema)
    check = decode_talents(code, schema)
    if check["entries"] != decoded["entries"]:
        raise ValueError("Allocation and serialized node bits disagree.")
    return code


def graft_spec_talents(anchor_code, donor_code, schema):
    """Copy a whole donor spec tree; preserve every other anchor node's bits.

    Equal paid ranks are required, but do not prove the game's point budget or
    cross-tree prerequisites. The result is a NEW HYBRID requiring live validation,
    never an unchanged source build or a legal-build certificate.
    """
    anchor = decode_talents(anchor_code, schema)
    donor = decode_talents(donor_code, schema)
    if anchor["spec_id"] != donor["spec_id"]:
        raise ValueError("Cannot graft different specializations.")
    paid_ranks = lambda decoded: sum(e["rank"] for e in decoded["entries"] if e["tree"] == 2 and e["purchased"])
    if paid_ranks(anchor) != paid_ranks(donor):
        raise ValueError("Donor specialization paid-rank total differs from the anchor.")
    hybrid = dict(anchor, node_bits=dict(anchor["node_bits"]))
    nodes = schema["classes"][SPEC_CLASSES[anchor["spec_id"]]]
    for node_id, entries in nodes.items():
        if entries[0]["tree"] == 2:
            hybrid["node_bits"][node_id] = donor["node_bits"][node_id]
    code = _encode_node_bits(hybrid, schema)
    decoded = decode_talents(code, schema)
    if not preserves_anchor(anchor, decoded) or paid_ranks(decoded) != paid_ranks(anchor):
        raise ValueError("Hybrid did not preserve the anchor constraints.")
    if [e for e in decoded["entries"] if e["tree"] == 2] != [e for e in donor["entries"] if e["tree"] == 2]:
        raise ValueError("Hybrid did not retain the complete donor specialization allocation.")
    return code
