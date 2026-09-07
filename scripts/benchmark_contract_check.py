#!/usr/bin/env python3
"""Check a host-independent deterministic benchmark contract."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

from benchmark_compare import load_policy, load_report


CHECKSUM = re.compile(r"\bchecksum(?:\s*[:=]|\s+)\s*([0-9]+)", re.IGNORECASE)
TIMING_LINE = re.compile(
    r"(?:\b(?:time|timing|fps|throughput|lines_sec|gpu_timing)\b|"
    r"\b[A-Za-z0-9]+_ms\b|\bms\b|(?:^|\s)(?:real|user|sys)\s+[0-9])",
    re.IGNORECASE,
)


def load_json(path: Path) -> dict:
    if not path.is_file():
        raise SystemExit(f"benchmark contract does not exist: {path}")
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        raise SystemExit(f"invalid JSON {path}: {error}") from error
    if not isinstance(value, dict):
        raise SystemExit(f"{path}: expected a JSON object")
    return value


def load_contract(path: Path) -> dict:
    contract = load_json(path)
    required = {"schema_version", "profile", "source_report_schema_version", "cases"}
    missing = sorted(required - set(contract))
    if missing:
        raise SystemExit(f"{path}: missing contract fields {missing}")
    if contract["schema_version"] != 1:
        raise SystemExit(
            f"{path}: expected contract schema version 1, "
            f"got {contract['schema_version']!r}"
        )
    if contract["source_report_schema_version"] != 2:
        raise SystemExit(f"{path}: source report schema must be version 2")
    if contract["profile"] not in {"quick", "full"}:
        raise SystemExit(f"{path}: profile must be quick or full")
    cases = contract["cases"]
    if not isinstance(cases, list) or not cases:
        raise SystemExit(f"{path}: cases must be a non-empty array")
    names: set[str] = set()
    for case in cases:
        if not isinstance(case, dict) or not isinstance(case.get("name"), str):
            raise SystemExit(f"{path}: every case needs a name")
        if case["name"] in names:
            raise SystemExit(f"{path}: duplicate case {case['name']!r}")
        names.add(case["name"])
        signature = case.get("signature")
        if not isinstance(signature, dict):
            raise SystemExit(f"{path}/{case['name']}: missing signature")
        if not isinstance(signature.get("metric_lines"), list) or not isinstance(
            signature.get("checksums"), list
        ):
            raise SystemExit(f"{path}/{case['name']}: malformed signature")
    return contract


def deterministic_signature(case: dict) -> dict[str, list[str]]:
    """Extract exact structural lines while excluding wall-clock fields."""

    metric_lines: set[str] = set()
    checksums: set[str] = set()
    for run in case["runs"]:
        for line in run["metric_lines"]:
            if not TIMING_LINE.search(line):
                metric_lines.add(line)
            checksums.update(CHECKSUM.findall(line))
    return {
        "metric_lines": sorted(metric_lines),
        "checksums": sorted(checksums),
    }


def contract_from_report(report: dict) -> dict:
    cases = []
    for case in report["cases"]:
        if any(run["status"] != 0 for run in case["runs"]):
            raise SystemExit(f"{case['name']}: candidate contains a failed run")
        cases.append(
            {
                "name": case["name"],
                "signature": deterministic_signature(case),
            }
        )
    return {
        "schema_version": 1,
        "profile": report["profile"],
        "source_report_schema_version": report["schema_version"],
        "cases": cases,
    }


def contract_entry(policy: dict, profile: str) -> dict | None:
    for entry in policy.get("deterministic_contracts", []):
        if entry.get("profile") == profile:
            return entry
    return None


def compare_contracts(baseline: dict, candidate: dict) -> list[str]:
    failures: list[str] = []
    if baseline["profile"] != candidate["profile"]:
        failures.append(
            f"profile differs: baseline={baseline['profile']} "
            f"candidate={candidate['profile']}"
        )
    baseline_cases = {case["name"]: case for case in baseline["cases"]}
    candidate_cases = {case["name"]: case for case in candidate["cases"]}
    if set(baseline_cases) != set(candidate_cases):
        failures.append(
            "case inventory differs: "
            f"missing={sorted(set(baseline_cases) - set(candidate_cases))}, "
            f"extra={sorted(set(candidate_cases) - set(baseline_cases))}"
        )
        return failures
    for name, baseline_case in baseline_cases.items():
        if baseline_case["signature"] != candidate_cases[name]["signature"]:
            failures.append(f"{name}: deterministic contract differs")
    return failures


def main() -> int:
    repo = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--policy", type=Path, default=repo / "benchmarks/benchmark-policy.json"
    )
    parser.add_argument("--baseline", type=Path, default=None)
    parser.add_argument(
        "--candidate", type=Path, default=repo / "dist/benchmark-results/quick.json"
    )
    parser.add_argument("--output", type=Path, default=None)
    parser.add_argument(
        "--write",
        action="store_true",
        help="write a contract from the candidate report instead of comparing",
    )
    args = parser.parse_args()
    policy = load_policy(args.policy)
    candidate_report = load_report(args.candidate)
    candidate_contract = contract_from_report(candidate_report)

    entry = contract_entry(policy, candidate_contract["profile"])
    baseline_path = args.baseline
    if baseline_path is None and entry is not None and entry.get("path") is not None:
        baseline_path = repo / entry["path"]

    if args.write:
        if candidate_report["environment"].get("git_dirty"):
            raise SystemExit("refusing to write a contract from a dirty report")
        output = args.output or baseline_path
        if output is None:
            raise SystemExit("--write needs --output or a registered contract path")
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(candidate_contract, indent=2) + "\n")
        print(f"Wrote deterministic benchmark contract: {output}")
        return 0

    if entry is None:
        raise SystemExit(
            f"no deterministic contract is registered for profile {candidate_contract['profile']!r}"
        )
    if entry.get("status") != "reviewed":
        raise SystemExit(f"deterministic contract {entry['id']} is not reviewed")
    if baseline_path is None:
        raise SystemExit(f"deterministic contract {entry['id']} has no path")
    baseline_contract = load_contract(baseline_path)
    failures = compare_contracts(baseline_contract, candidate_contract)
    if failures:
        print("Moxi benchmark contract check failed:")
        for failure in failures:
            print(f"  - {failure}")
        return 1
    print(
        "Moxi benchmark contract passed "
        f"({len(candidate_contract['cases'])} cases; host-independent; "
        f"candidate {args.candidate})"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
