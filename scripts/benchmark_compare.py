#!/usr/bin/env python3
"""Compare a structured benchmark report with a reviewed host baseline.

The comparison is deliberately split into two signals:

* deterministic metric/checksum signatures are exact contract checks; and
* wall-clock samples are same-host diagnostics, summarized with median, p95,
  and median absolute deviation (MAD).

The checked-in policy registers which host/compiler combinations have a
reviewed baseline. A report from an unregistered host is not silently treated
as comparable to the macOS reference.
"""

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


def load_json(path: Path) -> dict:
    if not path.is_file():
        raise SystemExit(f"benchmark file does not exist: {path}")
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        raise SystemExit(f"invalid JSON {path}: {error}") from error
    if not isinstance(value, dict):
        raise SystemExit(f"{path}: expected a JSON object")
    return value


def load_report(path: Path) -> dict:
    report = load_json(path)
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
    if not isinstance(report["cases"], list) or not report["cases"]:
        raise SystemExit(f"{path}: cases must be a non-empty array")
    for case in report["cases"]:
        if not isinstance(case, dict) or not isinstance(case.get("runs"), list):
            raise SystemExit(f"{path}: every case must contain a runs array")
    return report


def load_policy(path: Path) -> dict:
    policy = load_json(path)
    if policy.get("schema_version") != 1:
        raise SystemExit(
            f"{path}: expected benchmark policy schema version 1, "
            f"got {policy.get('schema_version')!r}"
        )
    comparison = policy.get("comparison")
    if not isinstance(comparison, dict):
        raise SystemExit(f"{path}: comparison must be an object")
    for key in (
        "minimum_runs",
        "max_median_regression_percent",
        "max_p95_regression_percent",
    ):
        value = comparison.get(key)
        if not isinstance(value, (int, float)) or value < 0:
            raise SystemExit(f"{path}: comparison.{key} must be non-negative")
    if comparison["minimum_runs"] < 1:
        raise SystemExit(f"{path}: comparison.minimum_runs must be positive")

    fields = policy.get("environment_match_fields")
    if not isinstance(fields, list) or not fields:
        raise SystemExit(f"{path}: environment_match_fields must be non-empty")
    baselines = policy.get("baselines")
    if not isinstance(baselines, list) or not baselines:
        raise SystemExit(f"{path}: baselines must be non-empty")
    ids: set[str] = set()
    for entry in baselines:
        if not isinstance(entry, dict):
            raise SystemExit(f"{path}: every baseline entry must be an object")
        entry_id = entry.get("id")
        if not isinstance(entry_id, str) or not entry_id or entry_id in ids:
            raise SystemExit(f"{path}: baseline ids must be unique non-empty strings")
        ids.add(entry_id)
        if entry.get("status") not in {"reviewed", "planned"}:
            raise SystemExit(f"{path}: {entry_id}: status must be reviewed or planned")
        if entry.get("status") == "reviewed" and not isinstance(
            entry.get("path"), str
        ):
            raise SystemExit(f"{path}: {entry_id}: reviewed baseline needs a path")
        if entry.get("status") == "planned" and entry.get("path") is not None:
            raise SystemExit(f"{path}: {entry_id}: planned baseline path must be null")
    return policy


def deterministic_signature(case: dict) -> tuple[Counter[str], list[str]]:
    stable_lines: Counter[str] = Counter()
    checksums: list[str] = []
    for run in case["runs"]:
        for line in run["metric_lines"]:
            if not DYNAMIC_LINE.search(line):
                stable_lines[line] += 1
            checksums.extend(CHECKSUM.findall(line))
    return stable_lines, sorted(checksums)


def percentile(values: list[float], percent: float) -> float:
    """Return a deterministic linearly interpolated percentile."""

    if not values:
        raise ValueError("percentile requires at least one value")
    ordered = sorted(values)
    if len(ordered) == 1:
        return ordered[0]
    position = (len(ordered) - 1) * (percent / 100.0)
    lower = int(position)
    upper = min(lower + 1, len(ordered) - 1)
    fraction = position - lower
    return ordered[lower] + (ordered[upper] - ordered[lower]) * fraction


def timing_summary(values: list[float]) -> dict[str, float | int]:
    """Summarize repeated process timings, including dispersion."""

    if not values:
        raise ValueError("timing_summary requires at least one value")
    median = statistics.median(values)
    return {
        "samples": len(values),
        "min": min(values),
        "median": median,
        "p95": percentile(values, 95.0),
        "mad": statistics.median([abs(value - median) for value in values]),
        "max": max(values),
    }


def _case_timings(case: dict) -> list[float]:
    return [float(run["wall_seconds"]) for run in case["runs"]]


def report_timing_summaries(report: dict) -> dict[str, dict[str, float | int]]:
    return {
        case["name"]: timing_summary(_case_timings(case))
        for case in report["cases"]
        if case.get("runs")
    }


def _same_environment(
    left: dict, right: dict, fields: list[str]
) -> list[str]:
    failures: list[str] = []
    for key in fields:
        if left.get(key) != right.get(key):
            failures.append(
                f"environment {key} differs: baseline={left.get(key)!r} "
                f"candidate={right.get(key)!r}"
            )
    return failures


def _registered_baseline(
    policy: dict, baseline_path: Path, repo: Path
) -> dict | None:
    resolved = baseline_path.resolve()
    for entry in policy["baselines"]:
        path = entry.get("path")
        if path is not None and (repo / path).resolve() == resolved:
            return entry
    return None


def _candidate_host_entry(policy: dict, candidate: dict) -> dict | None:
    environment = candidate["environment"]
    for entry in policy["baselines"]:
        if entry.get("profile") != candidate["profile"]:
            continue
        if any(
            entry.get(field) is not None
            and entry.get(field) != environment.get(field)
            for field in policy["environment_match_fields"]
        ):
            continue
        return entry
    return None


def compare_reports(
    baseline: dict,
    candidate: dict,
    max_regression_percent: float,
    allow_dirty: bool,
    *,
    max_p95_regression_percent: float | None = None,
    minimum_runs: int = 1,
    policy: dict | None = None,
    baseline_path: Path | None = None,
    repo: Path | None = None,
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
    failures.extend(
        _same_environment(
            baseline_env,
            candidate_env,
            (policy or {}).get(
                "environment_match_fields", ["mojo_version", "os", "architecture"]
            ),
        )
    )
    if not baseline_env.get("git_dirty", False):
        pass
    else:
        failures.append("reviewed baseline report was generated from a dirty tree")
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

        baseline_walls = _case_timings(baseline_case)
        candidate_walls = _case_timings(candidate_case)
        if len(baseline_walls) < minimum_runs:
            failures.append(
                f"{name}: baseline has {len(baseline_walls)} timing samples; "
                f"policy requires at least {minimum_runs}"
            )
        if len(candidate_walls) < minimum_runs:
            failures.append(
                f"{name}: candidate has {len(candidate_walls)} timing samples; "
                f"policy requires at least {minimum_runs}"
            )
        if not baseline_walls or not candidate_walls:
            failures.append(f"{name}: missing timing samples")
            continue
        if any(run["status"] != 0 for run in candidate_case["runs"]):
            failures.append(f"{name}: candidate run failed")
            continue
        baseline_summary = timing_summary(baseline_walls)
        candidate_summary = timing_summary(candidate_walls)
        baseline_median = float(baseline_summary["median"])
        candidate_median = float(candidate_summary["median"])
        if baseline_median > 0:
            regression = (candidate_median / baseline_median - 1.0) * 100.0
            if regression > max_regression_percent:
                failures.append(
                    f"{name}: median wall time regressed {regression:.1f}% "
                    f"(limit {max_regression_percent:.1f}%)"
                )
        if max_p95_regression_percent is not None:
            baseline_p95 = float(baseline_summary["p95"])
            candidate_p95 = float(candidate_summary["p95"])
            if baseline_p95 > 0:
                p95_regression = (candidate_p95 / baseline_p95 - 1.0) * 100.0
                if p95_regression > max_p95_regression_percent:
                    failures.append(
                        f"{name}: p95 wall time regressed {p95_regression:.1f}% "
                        f"(limit {max_p95_regression_percent:.1f}%)"
                    )
    return failures


def print_timing_summaries(baseline: dict, candidate: dict) -> None:
    baseline_summaries = report_timing_summaries(baseline)
    candidate_summaries = report_timing_summaries(candidate)
    print("Timing dispersion (seconds; samples / median / p95 / MAD):")
    for name in sorted(baseline_summaries):
        old = baseline_summaries[name]
        new = candidate_summaries.get(name)
        if new is None:
            continue
        print(
            f"  {name}: "
            f"baseline {old['samples']} / {old['median']:.4f} / "
            f"{old['p95']:.4f} / {old['mad']:.4f}; "
            f"candidate {new['samples']} / {new['median']:.4f} / "
            f"{new['p95']:.4f} / {new['mad']:.4f}"
        )


def main() -> int:
    repo = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--policy",
        type=Path,
        default=repo / "benchmarks/benchmark-policy.json",
    )
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
        default=None,
        help="override the policy median wall-time limit",
    )
    parser.add_argument(
        "--max-p95-regression-percent",
        type=float,
        default=None,
        help="override the policy p95 wall-time limit",
    )
    parser.add_argument(
        "--allow-dirty",
        action="store_true",
        default=os.environ.get("MOXI_BENCHMARK_ALLOW_DIRTY", "0") == "1",
    )
    args = parser.parse_args()
    policy = load_policy(args.policy)
    max_median = (
        args.max_regression_percent
        if args.max_regression_percent is not None
        else float(
            os.environ.get(
                "MOXI_BENCHMARK_MAX_REGRESSION_PERCENT",
                policy["comparison"]["max_median_regression_percent"],
            )
        )
    )
    max_p95 = (
        args.max_p95_regression_percent
        if args.max_p95_regression_percent is not None
        else float(
            os.environ.get(
                "MOXI_BENCHMARK_MAX_P95_REGRESSION_PERCENT",
                policy["comparison"]["max_p95_regression_percent"],
            )
        )
    )
    if max_median < 0 or max_p95 < 0:
        raise SystemExit("benchmark regression limits must be non-negative")

    baseline = load_report(args.baseline)
    candidate = load_report(args.candidate)
    failures: list[str] = []
    entry = _registered_baseline(policy, args.baseline, repo)
    if entry is None:
        failures.append(
            f"baseline is not registered in {args.policy}; "
            "add a reviewed host entry before comparing"
        )
    elif entry.get("status") != "reviewed":
        failures.append(f"baseline {entry['id']} is not marked reviewed")
    else:
        if entry.get("profile") != baseline["profile"]:
            failures.append(
                f"registered baseline {entry['id']} profile does not match report"
            )
        for key in policy["environment_match_fields"]:
            expected = entry.get(key)
            if expected is not None and baseline["environment"].get(key) != expected:
                failures.append(
                    f"registered baseline {entry['id']} environment {key} differs: "
                    f"policy={expected!r} report={baseline['environment'].get(key)!r}"
                )

    candidate_entry = _candidate_host_entry(policy, candidate)
    if candidate_entry is None:
        failures.append(
            "candidate environment has no registered baseline; "
            "cross-host wall-clock comparisons are blocked until that host is reviewed"
        )
    elif candidate_entry.get("status") != "reviewed":
        failures.append(
            f"candidate host matches planned baseline {candidate_entry['id']}; "
            "collect and review a clean baseline before comparing"
        )

    failures.extend(
        compare_reports(
            baseline,
            candidate,
            max_median,
            args.allow_dirty,
            max_p95_regression_percent=max_p95,
            minimum_runs=int(policy["comparison"]["minimum_runs"]),
            policy=policy,
            baseline_path=args.baseline,
            repo=repo,
        )
    )
    print_timing_summaries(baseline, candidate)
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
