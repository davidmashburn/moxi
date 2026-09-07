#!/usr/bin/env python3
"""Compare a structured benchmark report with a compatible reviewed baseline."""

from __future__ import annotations

import argparse
import json
import os
import re
import statistics
from collections import Counter
from pathlib import Path


DYNAMIC_LINE = re.compile(
    r"(?:\b(?:expansion|paint|metal|gpu|cpu|frame|wall|query|brush|cold|hot|"
    r"time|timing|fps|throughput|lines_sec)\b|(?:^|[\s/:])ms(?:/|:|\s|$))",
    re.IGNORECASE,
)
CHECKSUM = re.compile(r"\bchecksum(?:\s*[:=]|\s+)\s*([0-9]+)", re.IGNORECASE)


def load_report(path: Path) -> dict:
    if not path.is_file():
        raise SystemExit(f"benchmark report does not exist: {path}")
    try:
        report = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        raise SystemExit(f"invalid benchmark JSON {path}: {error}") from error
    required = {
        "schema_version",
        "profile",
        "requested_runs",
        "warmup_runs",
        "environment",
        "cases",
    }
    missing = sorted(required - set(report))
    if missing:
        raise SystemExit(f"{path}: missing report fields {missing}")
    if report["schema_version"] != 2:
        raise SystemExit(
            f"{path}: expected benchmark schema version 2, "
            f"got {report['schema_version']}"
        )
    return report


def deterministic_signature(case: dict) -> tuple[Counter[str], list[str]]:
    stable_lines: Counter[str] = Counter()
    checksums: list[str] = []
    for run in case["runs"]:
        for line in run["metric_lines"]:
            if not DYNAMIC_LINE.search(line):
                stable_lines[line] += 1
            checksums.extend(CHECKSUM.findall(line))
    return stable_lines, sorted(checksums)


def compare_reports(
    baseline: dict,
    candidate: dict,
    max_regression_percent: float,
    allow_dirty: bool,
) -> list[str]:
    failures: list[str] = []
    if baseline["profile"] != candidate["profile"]:
        failures.append(
            f"profile differs: baseline={baseline['profile']} "
            f"candidate={candidate['profile']}"
        )
    if baseline["requested_runs"] != candidate["requested_runs"]:
        failures.append(
            f"requested run count differs: baseline={baseline['requested_runs']} "
            f"candidate={candidate['requested_runs']}"
        )
    if baseline["warmup_runs"] != candidate["warmup_runs"]:
        failures.append(
            f"warmup run count differs: baseline={baseline['warmup_runs']} "
            f"candidate={candidate['warmup_runs']}"
        )

    baseline_env = baseline["environment"]
    candidate_env = candidate["environment"]
    for key in ("mojo_version", "os", "architecture"):
        if baseline_env.get(key) != candidate_env.get(key):
            failures.append(
                f"environment {key} differs: baseline={baseline_env.get(key)!r} "
                f"candidate={candidate_env.get(key)!r}"
            )
    if candidate_env.get("git_dirty") and not allow_dirty:
        failures.append(
            "candidate report was generated from a dirty tree; "
            "use --allow-dirty for diagnostic comparison"
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
        candidate_case = candidate_cases[name]
        baseline_signature = deterministic_signature(baseline_case)
        candidate_signature = deterministic_signature(candidate_case)
        if baseline_signature != candidate_signature:
            failures.append(f"{name}: deterministic metrics/checksums differ")

        baseline_walls = [run["wall_seconds"] for run in baseline_case["runs"]]
        candidate_walls = [run["wall_seconds"] for run in candidate_case["runs"]]
        if not baseline_walls or not candidate_walls:
            failures.append(f"{name}: missing timing samples")
            continue
        if any(run["status"] != 0 for run in candidate_case["runs"]):
            failures.append(f"{name}: candidate run failed")
            continue
        baseline_median = statistics.median(baseline_walls)
        candidate_median = statistics.median(candidate_walls)
        if baseline_median <= 0:
            continue
        regression = (candidate_median / baseline_median - 1.0) * 100.0
        if regression > max_regression_percent:
            failures.append(
                f"{name}: median wall time regressed {regression:.1f}% "
                f"(limit {max_regression_percent:.1f}%)"
            )
    return failures


def main() -> int:
    repo = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--baseline",
        type=Path,
        default=repo / "benchmarks/results/macos-arm64-full.json",
    )
    parser.add_argument(
        "--candidate",
        type=Path,
        default=repo / "dist/benchmark-results/full.json",
    )
    parser.add_argument(
        "--max-regression-percent",
        type=float,
        default=float(os.environ.get("MOXI_BENCHMARK_MAX_REGRESSION_PERCENT", "20")),
    )
    parser.add_argument(
        "--allow-dirty",
        action="store_true",
        default=os.environ.get("MOXI_BENCHMARK_ALLOW_DIRTY", "0") == "1",
    )
    args = parser.parse_args()
    if args.max_regression_percent < 0:
        raise SystemExit("--max-regression-percent must be non-negative")

    baseline = load_report(args.baseline)
    candidate = load_report(args.candidate)
    failures = compare_reports(
        baseline,
        candidate,
        args.max_regression_percent,
        args.allow_dirty,
    )
    if failures:
        print("Moxi benchmark comparison failed:")
        for failure in failures:
            print(f"  - {failure}")
        return 1

    print(
        "Moxi benchmark comparison passed "
        f"({len(candidate['cases'])} cases; "
        f"baseline {args.baseline}; candidate {args.candidate})"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
