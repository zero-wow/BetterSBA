"""Compare local SimC SBA and default APLs without uploading a character.

Requires an explicit local profile, scenario, intended patch, and SimC binary.
Reports and sanitized profiles stay outside this addon repository. A comparison
is evidence for its specified gear/encounter, not a globally optimal talent build.
"""

import argparse
import hashlib
import json
from pathlib import Path
import re
from statistics import NormalDist
import subprocess
import sys
import time
from datetime import datetime, timezone


ROOT = Path(__file__).resolve().parents[1]
CLASSES = set("deathknight demonhunter druid evoker hunter mage monk paladin priest rogue shaman warlock warrior".split())
GEAR = set("head neck shoulders back chest shirt tabard wrists hands waist legs feet finger1 finger2 trinket1 trinket2 main_hand off_hand".split())
PROFILE_OPTIONS = GEAR | set("spec level race role position talents class_talents spec_talents hero_talents omnium_talents professions potion flask food augmentation temporary_enchant set_bonus zandalari_loa vulpera_tricks earthen_mineral".split())
METADATA = set("source origin thumbnail guild region server name".split())
SLUG = r"[A-Za-z][A-Za-z0-9_]*"
NUMERIC_ITEM_OPTIONS = set("id bonus_id gem_id gem_bonus_id gem_ilevel enchant_id addon_id crafted_stats redirected_base_stats ilevel drop_level crafting_quality context content_tuning titan_disc_id".split())
MODE_OPTIONS = {
    "sba": ("Single-Button Assistant", 1, 1, 0),
    "sba-cooldowns": ("Single-Button Assistant With SimC Cooldowns", 1, 1, 1),
    "optimized": ("SimC Default APL", 0, 0, 0),
}


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def validate_value(key, value, number):
    """Accept gameplay values, never another SimC token or variable expansion.

    SimC tokenizes on whitespace before parsing options. An allowlisted key is
    insufficient: `spec=windwalker input=other.simc` would execute an include.
    Item attributes also have their own `source` override, so allowlist those.
    Quoted display names are deliberately unsupported; use normalized exports.
    """
    if not value or re.search(r"[\s\x00-\x1f\x7f\"'#$(){}\\]", value):
        raise ValueError(f"Unsupported value syntax at line {number}: {key}.")
    if key in GEAR:
        parts = value.split(",")
        valid = re.fullmatch(r"[A-Za-z0-9_]*", parts[0]) is not None
        seen = set()
        for part in parts[1:]:
            attribute, separator, item_value = part.partition("=")
            if (not separator or attribute not in NUMERIC_ITEM_OPTIONS or attribute in seen
                    or not re.fullmatch(r"[0-9]+(?:[/:][0-9]+)*", item_value)):
                valid = False
            seen.add(attribute)
        valid = valid and bool(parts[0] or len(parts) > 1)
    elif key == "level":
        valid = re.fullmatch(r"[0-9]{1,3}", value) is not None
    elif key == "talents":
        valid = re.fullmatch(r"[A-Za-z0-9+/]{26,}", value) is not None
    elif key in {"class_talents", "spec_talents", "hero_talents", "omnium_talents"}:
        valid = re.fullmatch(r"[A-Za-z0-9_]+:[0-9]+(?:/[A-Za-z0-9_]+:[0-9]+)*", value) is not None
    elif key == "professions":
        valid = re.fullmatch(SLUG + r"=[0-9]+(?:/" + SLUG + r"=[0-9]+)*", value) is not None
    elif key == "temporary_enchant":
        valid = re.fullmatch(r"(?:main_hand|off_hand):" + SLUG + r"(?:/(?:main_hand|off_hand):" + SLUG + r")*", value) is not None
    elif key == "set_bonus":
        valid = re.fullmatch(SLUG + r"=[01]", value) is not None
    else:
        valid = re.fullmatch(SLUG, value) is not None
    if not valid:
        raise ValueError(f"Unsupported value syntax at line {number}: {key}.")


def sanitize_profile(text, talents=None):
    """Keep one actor's gameplay data; reject includes and arbitrary sim options."""
    actor, lines, discarded_actions = None, [], 0
    for number, raw in enumerate(text.splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        match = re.fullmatch(r"([a-zA-Z0-9_.]+)(\+?=)(.*)", line)
        if not match:
            raise ValueError(f"Unsupported profile syntax at line {number}.")
        key, operator, value = match.groups()
        if key == "actions" or key.startswith("actions."):
            discarded_actions += 1
            continue
        if key in METADATA:
            continue
        if key in CLASSES:
            if actor is not None:
                raise ValueError("Use a profile containing exactly one player.")
            actor = key
            continue
        if key not in PROFILE_OPTIONS or operator != "=":
            raise ValueError(f"Unsupported profile option at line {number}: {key}.")
        validate_value(key, value, number)
        lines.append((key, value))
    if actor is None or not any(key == "spec" for key, _ in lines):
        raise ValueError("A class and specialization are required in the profile.")
    if talents is not None:
        if not re.fullmatch(r"[A-Za-z0-9+/]{26,}", talents):
            raise ValueError("The talent export must be a WoW talent string.")
        lines = [(key, value) for key, value in lines if key not in {"talents", "class_talents", "spec_talents", "hero_talents"}]
        lines.append(("talents", talents))
    return [f'{actor}="BetterSBA_Comparison"'] + [f"{key}={value}" for key, value in lines], discarded_actions


def validate_output(path):
    resolved = path.resolve()
    if resolved == ROOT or ROOT in resolved.parents:
        raise ValueError("Keep simulation profiles/reports outside the addon repository.")
    return resolved


def make_input(profile, mode, *, iterations, threads, seconds, targets, seed):
    _, assisted, one_button, cooldowns = MODE_OPTIONS[mode]
    global_options = [
        f"iterations={iterations}", f"threads={threads}", f"max_time={seconds}",
        "fixed_time=1", "vary_combat_length=0", f"desired_targets={targets}",
        "fight_style=Patchwerk", "ptr=0", "item_db_source=local", f"seed={seed}",
        "report_details=1", "confidence=0.95", "optimal_raid=1",
    ]
    mode_options = [
        f"use_blizzard_action_list={assisted}", f"one_button_mode={one_button}",
        f"use_cds_with_blizzard_action_list={cooldowns}",
        "enable_spell_queue=0", "json2=report.json",
    ]
    return "\n".join(global_options + profile + mode_options) + "\n"


def summarize(report, expected_patch):
    player = report["sim"]["players"][0]
    dbc = player["dbc"]
    live = dbc.get("Live", {})
    actual_patch = ".".join(live.get("wow_version", "").split(".")[:3])
    if dbc.get("version_used") != "Live" or actual_patch != expected_patch:
        raise ValueError("Simulation data does not match the requested live patch; inspect the local report.")
    dps = player["collected_data"]["dps"]
    confidence = report["sim"]["options"].get("confidence", 0.95)
    error = NormalDist().inv_cdf((1 + confidence) / 2) * dps["mean_std_dev"]
    # Keep raw engine messages in the local report, not console output or data
    # that might be copied into the addon. Only bounded known severity labels
    # and counts enter the summary; unfamiliar labels become "other".
    logs = report.get("logs", [])
    logs = [logs] if isinstance(logs, dict) else logs
    warning_levels = {}
    for log in logs:
        level = log.get("level") if isinstance(log, dict) else None
        if level in {"debug", "info"}:
            continue
        level = level if level in {"warning", "error", "implementation_not_yet_verified"} else "other"
        warning_levels[level] = warning_levels.get(level, 0) + 1
    return {
        "engine_version": report["version"], "engine_git_revision": report.get("git_revision"),
        "engine_git_branch": report.get("git_branch"), "game_data": live,
        "talents": player.get("talents"), "specialization": player.get("specialization"),
        "level": player.get("level"), "mean_dps": dps["mean"],
        "dps_error": error, "confidence": confidence, "samples": dps["count"],
        "engine_elapsed_seconds": report["sim"]["statistics"]["elapsed_time_seconds"],
        "model_warning_count": sum(warning_levels.values()), "model_warning_levels": warning_levels,
        "model_warning_source": "report.json:logs",
    }


def run(args):
    destination = validate_output(args.output)
    if destination.exists() and any(destination.iterdir()):
        raise ValueError("Choose a new or empty output directory to preserve earlier reports.")
    if not args.simc.is_file() or not args.profile.is_file():
        raise ValueError("The explicit SimC executable and profile must both exist.")
    original = args.profile.read_bytes()
    profile, discarded = sanitize_profile(original.decode("utf-8-sig"), args.talents)
    modes = args.modes.split(",")
    if len(set(modes)) != len(modes) or any(mode not in MODE_OPTIONS for mode in modes):
        raise ValueError("Modes must be unique choices from sba,sba-cooldowns,optimized.")
    destination.mkdir(parents=True, exist_ok=True)
    summary = {
        "created_at": datetime.now(timezone.utc).isoformat(),
        "profile_sha256": sha256(original), "simc_sha256": sha256(args.simc.read_bytes()),
        "expected_patch": args.expected_patch,
        "scenario": {"style": "Patchwerk", "targets": args.targets, "seconds": args.seconds,
                     "iterations": args.iterations, "threads": args.threads, "seed": args.seed,
                     "optimal_raid": True, "spell_queue": False},
        "discarded_custom_apl_lines": discarded,
        "limitations": ["Fixed gear and encounter; not a global talent optimum.",
                        "SimC default APL is not GSE or a measurement of player performance.",
                        "SBA With SimC Cooldowns is not an exact emulation of BetterSBA's secure macro.",
                        "SimC assisted rules can differ from live WoW; retain warnings in mode logs."],
        "results": [],
    }
    summary_path = destination / "comparison.json"
    try:
        for mode in modes:
            mode_dir = destination / mode
            mode_dir.mkdir()
            contents = make_input(profile, mode, iterations=args.iterations, threads=args.threads,
                                  seconds=args.seconds, targets=args.targets, seed=args.seed)
            (mode_dir / "input.simc").write_text(contents, encoding="utf-8")
            started = time.monotonic()
            with (mode_dir / "run.log").open("wb") as log:
                result = subprocess.run([str(args.simc.resolve()), "input.simc"], cwd=mode_dir,
                                        stdout=log, stderr=subprocess.STDOUT, timeout=args.timeout,
                                        check=False)
            if result.returncode:
                raise ValueError(f"{mode} failed; inspect its local run.log. Exit code {result.returncode}.")
            report = json.loads((mode_dir / "report.json").read_text(encoding="utf-8"))
            item = summarize(report, args.expected_patch)
            item.update(mode=mode, label=MODE_OPTIONS[mode][0],
                        input_sha256=sha256(contents.encode()), elapsed_seconds=time.monotonic() - started)
            summary["results"].append(item)
            print(f"{MODE_OPTIONS[mode][0]}: {item['mean_dps']:.0f} DPS +/- {item['dps_error']:.0f} (95% confidence interval for mean simulated DPS)")
            if item["model_warning_count"]:
                print(f"  {item['model_warning_count']} model warning(s); inspect this mode's local report.json logs.")
    except (ValueError, subprocess.TimeoutExpired, OSError, KeyError) as error:
        summary["status"] = "failed"
        summary["failure_type"] = type(error).__name__
        raise
    else:
        summary["status"] = "completed"
    finally:
        summary_path.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    print(f"Local comparison: {summary_path}")


def bounded_int(low, high):
    def parse(value):
        number = int(value)
        if not low <= number <= high:
            raise argparse.ArgumentTypeError(f"Choose a value from {low} to {high}.")
        return number
    return parse


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--simc", required=True, type=Path)
    parser.add_argument("--profile", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--expected-patch", required=True, help="Exact live patch, for example 12.1.0")
    parser.add_argument("--targets", required=True, type=bounded_int(1, 20))
    parser.add_argument("--seconds", required=True, type=bounded_int(10, 600))
    parser.add_argument("--talents", help="Optional talent export overriding the profile's build")
    parser.add_argument("--modes", default="sba,sba-cooldowns,optimized")
    parser.add_argument("--iterations", default=1000, type=bounded_int(10, 10000))
    parser.add_argument("--threads", default=2, type=bounded_int(1, 2))
    parser.add_argument("--timeout", default=60, type=bounded_int(1, 60))
    parser.add_argument("--seed", default=246801, type=int)
    args = parser.parse_args()
    try:
        run(args)
    except (ValueError, OSError, KeyError, subprocess.TimeoutExpired) as error:
        if isinstance(error, subprocess.TimeoutExpired):
            print("Simulation exceeded its wall-time limit; local logs were preserved.", file=sys.stderr)
        elif isinstance(error, ValueError):
            print(str(error), file=sys.stderr)
        else:
            print(f"Comparison failed ({type(error).__name__}); inspect the local output.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
