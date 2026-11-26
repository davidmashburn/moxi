#!/usr/bin/env python3
"""Interleave two compiled canvas_benchmark --large-only consumers; keep samples."""

import argparse
import csv
import hashlib
import json
import math
from pathlib import Path
import platform
import re
import subprocess
from datetime import datetime, timezone


def percentile(values, percent):
    return sorted(values)[math.ceil(len(values) * percent / 100) - 1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("before", type=Path)
    parser.add_argument("after", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--runs", type=int, default=3)
    args = parser.parse_args()
    if args.runs < 1:
        parser.error("--runs must be positive")
    args.output.mkdir(parents=True, exist_ok=True)
    binaries = {name: getattr(args, name).resolve() for name in ("before", "after")}
    manifest = {
        "started_utc": datetime.now(timezone.utc).isoformat(),
        "platform": platform.platform(),
        "machine": platform.machine(),
        "binaries_sha256": {name: hashlib.sha256(path.read_bytes()).hexdigest()
                            for name, path in binaries.items()},
        "samples_per_operation_per_run": 40,
        "percentile": "nearest rank; ceil(n*p/100)-1",
        "scope": "CPU pan/selection/move through scene construction; no native submission",
        "runs": [],
    }
    rows = []
    checksums = set()
    sample_pattern = re.compile(r"^sample simple-1000-visible (.+) index (\d+) ms ([\d.eE+-]+)$", re.M)
    operations = {"pan through scene construction (no native submission)": "pan",
                  "selection through scene construction": "selection",
                  "drag preview through scene construction": "move"}
    for run in range(args.runs):
        order = ("before", "after") if run % 2 == 0 else ("after", "before")
        for variant in order:
            log = args.output / f"{run + 1}-{variant}.log"
            started = datetime.now(timezone.utc).isoformat()
            with log.open("w") as stream:
                subprocess.run([str(binaries[variant]), "--large-only"], stdout=stream,
                               stderr=subprocess.STDOUT, check=True)
            output = log.read_text()
            assert "published_nodes 3015 scene_commands 8443" in output, log
            assert "selection_index_writes 0 unrelated_measurements 0" in output, log
            checksum = re.search(r"published_geometry_checksum ([\d.eE+-]+)", output)
            assert checksum, log
            checksums.add(checksum[1])
            samples = {op: {} for op in operations.values()}
            for label, index, value in sample_pattern.findall(output):
                operation = operations[label]
                assert int(index) not in samples[operation], (log, operation, index)
                samples[operation][int(index)] = float(value)
            metrics = {}
            for operation, indexed in samples.items():
                assert set(indexed) == set(range(40)), (log, operation)
                values = list(indexed.values())
                metrics[operation] = {"p95_ms": percentile(values, 95),
                                      "p99_ms": percentile(values, 99), "worst_ms": max(values)}
                rows.extend({"variant": variant, "run": run + 1, "operation": operation,
                             "sample": index, "ms": value} for index, value in indexed.items())
            manifest["runs"].append({"variant": variant, "run": run + 1,
                                     "started_utc": started, "log": log.name, "metrics": metrics})
            print(f"run={run + 1} {variant}: pan p95={metrics['pan']['p95_ms']:.3f} ms", flush=True)
    assert len(checksums) == 1, "published geometry differs between builds/runs"
    manifest["published_geometry_checksum"] = checksums.pop()
    manifest["completed_utc"] = datetime.now(timezone.utc).isoformat()
    manifest["aggregate"] = {}
    for variant in binaries:
        manifest["aggregate"][variant] = {}
        for operation in operations.values():
            values = [row["ms"] for row in rows if row["variant"] == variant and row["operation"] == operation]
            manifest["aggregate"][variant][operation] = {
                "samples": len(values), "p95_ms": percentile(values, 95),
                "p99_ms": percentile(values, 99), "worst_ms": max(values)}
    with (args.output / "samples.csv").open("w", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=("variant", "run", "operation", "sample", "ms"))
        writer.writeheader()
        writer.writerows(rows)
    (args.output / "summary.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(json.dumps(manifest["aggregate"], indent=2))


if __name__ == "__main__":
    main()
