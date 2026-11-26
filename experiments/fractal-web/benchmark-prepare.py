#!/usr/bin/env python3
"""Prepare pinned JS and the existing native throughput fixtures for benchmark.html."""

import argparse
import hashlib
import json
import math
import platform
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

ORIGINAL = "5f78b3fb3e167365d86dc21b79788bec454c16ec"
EXPECTED = [("Koch", 4096), ("SampleFractal", 65536), ("Peano Serpent", 1_000_000)]
ORIGINAL_FILES = ("constants.js", "drawFractal.js", "generator.js", "helpers.js")


def command(args, cwd=None):
    return subprocess.check_output(args, cwd=cwd, text=True).strip()


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def point_line(fields):
    if len(fields) != 4:
        raise ValueError("Expected four line coordinates")
    x0, y0, x1, y1 = map(float, fields)
    return {"start": {"x": x0, "y": y0}, "end": {"x": x1, "y": y1}}


def parse_native(stdout):
    cases = []
    for row in stdout.splitlines():
        tag, *fields = row.split()
        if tag == "CASE":
            index, depth = map(int, fields[:2])
            if index != len(cases) or index >= len(EXPECTED):
                raise ValueError("Unexpected native fixture order")
            name, expected_leaves = EXPECTED[index]
            cases.append({"name": name, "expectedLeaves": expected_leaves,
                          "depth": depth, "base": point_line(fields[2:]),
                          "lines": [], "nativeTrials": []})
        elif tag == "LINE":
            cases[-1]["lines"].append(point_line(fields))
        elif tag == "TIME":
            trial, leaves = map(int, fields[:2])
            ms = float(fields[2])
            if trial != len(cases[-1]["nativeTrials"]) or leaves != cases[-1]["expectedLeaves"] or not math.isfinite(ms) or ms < 0:
                raise ValueError("Invalid native trial or leaf count")
            cases[-1]["nativeTrials"].append({"leaves": leaves, "ms": ms})
        else:
            raise ValueError(f"Unexpected native benchmark output tag: {tag}")
    if len(cases) != len(EXPECTED) or any(len(c["nativeTrials"]) != 9 or not c["lines"] for c in cases):
        raise ValueError("Expected three canonical fixtures, each with two warmups and seven trials")
    return cases


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("original", type=Path, help="Clone of davidmashburn/canvas-line-fractal containing the pinned revision")
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2], help="Moxi checkout root")
    parser.add_argument("--output", type=Path, default=Path(__file__).resolve().parent / "dist" / "benchmark")
    parser.add_argument("--native-stdout", type=Path, help="Reuse a prior exact benchmarks/fractal_throughput.mojo output")
    args = parser.parse_args()
    root, output = args.root.resolve(), args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    native_command = None
    if args.native_stdout:
        stdout = args.native_stdout.read_text()
    else:
        binary = output / "native-fractal-throughput"
        native_command = ["bash", "scripts/build_native_demo.sh", "-I", "src",
                          "benchmarks/fractal_throughput.mojo", "-o", str(binary)]
        # Invoke under `pixi run python ...` to use the repository's pinned Mojo.
        with (output / "native-build.log").open("w") as log:
            subprocess.run(native_command, cwd=root, check=True, stdout=log, stderr=subprocess.STDOUT)
        stdout = command([str(binary)], cwd=root)
    cases = parse_native(stdout)
    (output / "native-stdout.txt").write_text(stdout + "\n")
    original_output = output / "original"
    original_output.mkdir(exist_ok=True)
    originals = {}
    for name in ORIGINAL_FILES:
        data = subprocess.check_output(["git", "-C", str(args.original), "show", f"{ORIGINAL}:{name}"])
        (original_output / name).write_bytes(data)
        originals[name] = hashlib.sha256(data).hexdigest()
    inputs = [root / "benchmarks/fractal_throughput.mojo", root / "scripts/build_native_demo.sh"]
    inputs.extend(sorted((root / "src/moxi").rglob("*.mojo")))
    fixture_source = root / "benchmarks/fractal_fixtures.mojo"
    if not fixture_source.is_file():
        raise FileNotFoundError(f"Required Wasm fixture source is missing: {fixture_source}")
    inputs.append(fixture_source)
    source_hashes = {str(path.relative_to(root)): sha256(path) for path in inputs}
    toolchain = {}
    for name, cmd in [("mojo", ["mojo", "--version"]), ("clang", ["clang", "--version"])]:
        try:
            toolchain[name] = command(cmd).splitlines()[0]
        except (OSError, subprocess.CalledProcessError) as error:
            toolchain[name] = {"unavailable": str(error)}
    provenance = {"preparedAt": datetime.now(timezone.utc).isoformat(),
                  "originalRevision": ORIGINAL, "originalSha256": originals,
                  "nativeSourceRevision": command(["git", "rev-parse", "HEAD"], root),
                  "nativeWorkingTree": command(["git", "status", "--porcelain", "--untracked-files=all", "--",
                                                "benchmarks/fractal_throughput.mojo", "scripts/build_native_demo.sh",
                                                "src/moxi", "benchmarks/fractal_fixtures.mojo"], root).splitlines(),
                  "nativeInputSha256": source_hashes,
                  "nativeStdoutSha256": sha256(output / "native-stdout.txt"),
                  "nativeBuildCommand": (native_command[:-1] + ["<output>/native-fractal-throughput"]
                                         if native_command else None),
                  "nativeStdoutReused": bool(args.native_stdout),
                  "nativeMachine": {"platform": platform.platform(), "machine": platform.machine(), "processor": platform.processor()},
                  "toolchain": toolchain, "python": sys.version.split()[0]}
    (output / "cases.mjs").write_text("// Generated by benchmark-prepare.py; do not edit.\n"
                                       + "export const cases = " + json.dumps(cases) + ";\n"
                                       + "export const provenance = " + json.dumps(provenance) + ";\n")
    (output / "provenance.json").write_text(json.dumps(provenance, indent=2) + "\n")
    print(json.dumps({"output": str(output), "fixtures": len(cases), "nativeMeasuredTrialsPerFixture": 7,
                      "originalRevision": ORIGINAL}))


if __name__ == "__main__":
    main()
