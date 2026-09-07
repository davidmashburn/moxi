#!/usr/bin/env python3
"""Validate the reviewed benchmark host matrix and its checked-in reports."""

from __future__ import annotations

import argparse
from pathlib import Path

from benchmark_compare import load_policy, load_report


def main() -> int:
    repo = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--policy",
        type=Path,
        default=repo / "benchmarks/benchmark-policy.json",
    )
    args = parser.parse_args()
    policy = load_policy(args.policy)
    minimum_runs = int(policy["comparison"]["minimum_runs"])
    reviewed = 0
    seen_hosts: set[tuple[str, str, str, str]] = set()
    failures: list[str] = []

    for entry in policy["baselines"]:
        entry_id = entry["id"]
        if entry.get("status") != "reviewed":
            continue
        reviewed += 1
        path = repo / entry["path"]
        try:
            report = load_report(path)
        except SystemExit as error:
            failures.append(str(error))
            continue
        if report["profile"] != entry.get("profile"):
            failures.append(f"{entry_id}: profile does not match registered policy")
        if report["environment"].get("git_dirty"):
            failures.append(f"{entry_id}: reviewed report is marked dirty")
        for field in policy["environment_match_fields"]:
            expected = entry.get(field)
            if expected is not None and report["environment"].get(field) != expected:
                failures.append(
                    f"{entry_id}: environment {field} does not match policy"
                )
        if report["requested_runs"] < minimum_runs:
            failures.append(
                f"{entry_id}: requested_runs={report['requested_runs']} "
                f"is below policy minimum {minimum_runs}"
            )
        for case in report["cases"]:
            if len(case["runs"]) < minimum_runs:
                failures.append(
                    f"{entry_id}/{case['name']}: fewer than {minimum_runs} samples"
                )
            if any(run["status"] != 0 for run in case["runs"]):
                failures.append(f"{entry_id}/{case['name']}: contains a failed run")
        host_key = (
            report["profile"],
            report["environment"].get("mojo_version", ""),
            report["environment"].get("os", ""),
            report["environment"].get("architecture", ""),
        )
        if host_key in seen_hosts:
            failures.append(f"{entry_id}: duplicate reviewed host/profile registration")
        seen_hosts.add(host_key)

    if reviewed == 0:
        failures.append("benchmark policy has no reviewed baselines")
    if failures:
        print("Moxi benchmark policy check failed:")
        for failure in failures:
            print(f"  - {failure}")
        return 1
    print(
        f"Moxi benchmark policy passed ({reviewed} reviewed baseline(s); "
        f"minimum {minimum_runs} samples/case)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
