"""Compare explicit full talent exports for SBA, retaining the anchor's utility.

Outputs stay local and outside the addon. This ranks supplied candidates; it
does not certify talent legality or search every possible talent allocation.
"""

import argparse
import hashlib
import json
import math
from pathlib import Path
import re
from statistics import NormalDist
import subprocess
import time

from run_sba_comparison import bounded_int, make_input, sanitize_profile, summarize, validate_output
from sba_talent_candidates import parse_trait_data, decode_talents


def digest(data):
    return hashlib.sha256(data).hexdigest()


def load_candidates(document, schema):
    if not isinstance(document, dict) or document.get("schema_version") != 1:
        raise ValueError("Unsupported candidate manifest version.")
    entries = document.get("candidates")
    if not isinstance(entries, list) or not 2 <= len(entries) <= 16:
        raise ValueError("Supply between two and sixteen explicit full exports.")
    ids, codes, candidates = set(), set(), []
    for entry in entries:
        if not isinstance(entry, dict):
            raise ValueError("Malformed candidate entry.")
        identifier, name, code = entry.get("id"), entry.get("name"), entry.get("import_string")
        if not isinstance(identifier, str) or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]{0,95}", identifier):
            raise ValueError("Candidate IDs must be simple unique identifiers.")
        if not isinstance(name, str) or not name or len(name) > 180 or any(ord(c) < 32 for c in name):
            raise ValueError("A short printable candidate name is required.")
        if not isinstance(code, str):
            raise ValueError("The candidate must contain an explicit full talent export.")
        if identifier in ids or code in codes:
            raise ValueError("Duplicate candidate identity or talent export.")
        decoded = decode_talents(code, schema)
        ids.add(identifier)
        codes.add(code)
        candidates.append({"id": identifier, "name": name, "import_string": code,
                           "source": entry.get("source", "Source not supplied"),
                           "patch": entry.get("patch"), "decoded": decoded})
    anchor = next((c for c in candidates if c["id"] == document.get("anchor_id")), None)
    if anchor is None:
        raise ValueError("The anchor must be one of the supplied full exports.")
    accepted, rejected = [], []
    for candidate in candidates:
        decoded = candidate["decoded"]
        if decoded["spec_id"] != anchor["decoded"]["spec_id"]:
            reason = "Different specialization"
        elif decoded["class_signature"] != anchor["decoded"]["class_signature"]:
            reason = "Different class talents; utility is not preserved"
        elif decoded["hero_subtree_id"] != anchor["decoded"]["hero_subtree_id"]:
            reason = "Different hero tree"
        elif decoded["hero_signature"] != anchor["decoded"]["hero_signature"]:
            reason = "Different hero allocation; utility is not preserved"
        else:
            reason = None
        if reason:
            rejected.append({"id": candidate["id"], "reason": reason})
        else:
            accepted.append(candidate)
    return anchor, accepted, rejected


def rank_results(results, confidence=.95):
    """Use simultaneous intervals to avoid declaring noisy candidates winners."""
    if not results:
        return {"state": "unavailable", "choices": []}
    if any(r.get("model_warning_count") != 0 for r in results):
        return {"state": "unavailable", "choices": [], "reason": "Model warnings require review"}
    n = len(results)
    z = NormalDist().inv_cdf(1 - (1 - confidence) / (2 * n))
    scored = []
    for result in results:
        mean, standard_error = result["mean_dps"], result["mean_std_dev"]
        if not math.isfinite(mean) or not math.isfinite(standard_error) or mean <= 0 or standard_error < 0:
            raise ValueError("Non-finite or invalid simulation estimate.")
        error = z * standard_error
        scored.append({"id": result["id"], "mean_dps": mean, "interval_error": error,
                       "lower": mean - error, "upper": mean + error})
    scored.sort(key=lambda r: (-r["mean_dps"], r["id"]))
    if n == 1:
        return {"state": "single-candidate", "choices": [scored[0]["id"]], "intervals": scored}
    # Include every candidate whose interval overlaps the highest mean's
    # lower bound; the ID tiebreak orders presentation, never selects a winner.
    contenders = [r["id"] for r in scored if r["upper"] >= scored[0]["lower"]]
    return {"state": "ready" if len(contenders) == 1 else "tie", "choices": contenders,
            "intervals": scored, "family_confidence": confidence, "method": "Bonferroni normal intervals"}


def validate_engine_identity(summary, schema, expected_patch, expected_build):
    wanted = f"{expected_patch}.{expected_build}"
    if wanted != schema["wow_build"]:
        raise ValueError("The requested client build does not match the pinned talent decoder.")
    if summary is None:
        return
    revision = summary.get("engine_git_revision")
    if (not isinstance(revision, str) or not re.fullmatch(r"[0-9a-f]{7,40}", revision)
        or not schema["source_revision"].startswith(revision)):
        raise ValueError("The simulation engine does not match the reviewed talent decoder revision.")
    if summary["game_data"].get("wow_version") != schema["wow_build"]:
        raise ValueError("The simulation data does not match the pinned talent decoder build.")


def run(args):
    output = validate_output(args.output)
    if output.exists() and any(output.iterdir()):
        raise ValueError("Use a new or empty output directory to preserve previous reports.")
    original = args.profile.read_bytes()
    schema = parse_trait_data(args.traits)
    validate_engine_identity(None, schema, args.expected_patch, args.expected_build)
    base_profile, _ = sanitize_profile(original.decode("utf-8-sig"))
    specs = [line for line in base_profile if line.startswith("spec=")]
    if not base_profile[0].startswith("monk=") or specs != ["spec=windwalker"]:
        raise ValueError("The reviewed talent search currently requires one Windwalker Monk profile.")
    manifest_bytes = args.candidates.read_bytes()
    anchor, candidates, rejected = load_candidates(json.loads(manifest_bytes), schema)
    # Source-qualified full exports are screened independently of SimC.
    # A matching patch label is metadata, not proof of legal prerequisites.
    stale = [c for c in candidates if c["patch"] != args.expected_patch]
    for candidate in stale:
        rejected.append({"id": candidate["id"], "reason": "Unverified or different source patch"})
    candidates = [c for c in candidates if c not in stale]
    if anchor not in candidates:
        raise ValueError("The anchor source must identify the requested patch.")
    if len(candidates) < 2:
        raise ValueError("Fewer than two same-spec, same-class, same-hero, patch-qualified candidates remain.")
    output.mkdir(parents=True, exist_ok=True)
    result = {"schema_version": 1, "status": "running", "anchor_id": anchor["id"],
              "spec_id": anchor["decoded"]["spec_id"], "expected_patch": args.expected_patch,
              "expected_build": args.expected_build, "profile_label": args.profile_label,
              "profile_sha256": digest(original), "simc_sha256": digest(args.simc.read_bytes()),
              "traits_sha256": digest(args.traits.read_bytes()), "manifest_sha256": digest(manifest_bytes),
              "scenario": {"targets": args.targets, "seconds": args.seconds,
                           "iterations": args.iterations, "threads": args.threads, "seed": args.seed,
                           "fight_style": "Patchwerk", "mode": "sba", "spell_queue": False},
              "rejected": rejected, "results": [],
              "limitations": ["Best among supplied exports only; not a global talent optimum.",
                              "Source patch and successful simulation do not prove live talent legality.",
                              "Class and hero allocations match the anchor; spec utility can still differ.",
                              "Fixed example gear and encounter; not a prediction for another character.",
                              "SimulationCraft SBA can differ from the live game's assisted rotation."]}
    started = time.monotonic()
    try:
        for candidate in candidates:
            remaining = args.total_timeout - (time.monotonic() - started)
            if remaining <= 0:
                raise TimeoutError("The candidate search exceeded its total time limit.")
            candidate_dir = output / candidate["id"]
            candidate_dir.mkdir()
            profile, discarded = sanitize_profile(original.decode("utf-8-sig"), candidate["import_string"])
            contents = make_input(profile, "sba", iterations=args.iterations, threads=args.threads,
                                  seconds=args.seconds, targets=args.targets, seed=args.seed)
            (candidate_dir / "input.simc").write_text(contents, encoding="utf-8")
            with (candidate_dir / "run.log").open("wb") as log:
                process = subprocess.run([str(args.simc.resolve()), "input.simc"], cwd=candidate_dir,
                                         stdout=log, stderr=subprocess.STDOUT,
                                         timeout=min(args.timeout, remaining), check=False)
            if process.returncode:
                raise ValueError("A candidate simulation failed; inspect its preserved local run.log.")
            report = json.loads((candidate_dir / "report.json").read_text(encoding="utf-8"))
            summary = summarize(report, args.expected_patch)
            validate_engine_identity(summary, schema, args.expected_patch, args.expected_build)
            if str(summary["game_data"].get("build_level")) != str(args.expected_build):
                raise ValueError("The engine's live build differs from the requested build.")
            if summary["talents"] != candidate["import_string"]:
                raise ValueError("The engine did not use the candidate's exact full export.")
            dps = report["sim"]["players"][0]["collected_data"]["dps"]
            summary.update(id=candidate["id"], name=candidate["name"],
                           import_string=candidate["import_string"], source=candidate["source"],
                           mean_std_dev=dps["mean_std_dev"], input_sha256=digest(contents.encode()),
                           discarded_custom_apl_lines=discarded)
            result["results"].append(summary)
        # All reports must share hotfix/engine identities, not only a patch label.
        fingerprints = {(r["engine_version"], r["engine_git_revision"],
                         r["game_data"].get("hotfix_hash")) for r in result["results"]}
        if len(fingerprints) != 1:
            raise ValueError("Candidates were simulated with different engine or hotfix data.")
        result["ranking"] = rank_results(result["results"])
        result["status"] = "completed"
        print(f'SBA search: {len(candidates)} candidates; result {result["ranking"]["state"]}.')
    except (ValueError, OSError, KeyError, TimeoutError, subprocess.TimeoutExpired) as error:
        result["status"], result["failure_type"] = "failed", type(error).__name__
        raise
    finally:
        result["elapsed_seconds"] = time.monotonic() - started
        (output / "search.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--simc", required=True, type=Path)
    parser.add_argument("--profile", required=True, type=Path)
    parser.add_argument("--traits", required=True, type=Path, help="Pinned SimC generated/trait_data.inc")
    parser.add_argument("--candidates", required=True, type=Path, help="Explicit full-export JSON manifest")
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--profile-label", required=True, help="Describe example gear and intentional alterations")
    parser.add_argument("--expected-patch", required=True)
    parser.add_argument("--expected-build", required=True)
    parser.add_argument("--targets", required=True, type=bounded_int(1, 20))
    parser.add_argument("--seconds", default=180, type=bounded_int(10, 600))
    parser.add_argument("--iterations", default=2000, type=bounded_int(10, 10000))
    parser.add_argument("--threads", default=2, type=bounded_int(1, 2))
    parser.add_argument("--timeout", default=60, type=bounded_int(1, 60))
    parser.add_argument("--total-timeout", default=180, type=bounded_int(1, 600))
    parser.add_argument("--seed", default=246801, type=int)
    args = parser.parse_args()
    try:
        run(args)
    except (ValueError, OSError, KeyError, TimeoutError, subprocess.TimeoutExpired) as error:
        if isinstance(error, ValueError):
            print(str(error))
        else:
            print(f"Search failed ({type(error).__name__}); local reports were preserved.")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
