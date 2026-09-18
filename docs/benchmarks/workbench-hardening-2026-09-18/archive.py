#!/usr/bin/env python3
"""Preserve completed local evidence; no binaries or object files are copied."""
import argparse
import gzip
import hashlib
import json
from pathlib import Path
import shutil

DEST = Path(__file__).resolve().parent
REPO = DEST.parents[2]


def archive(source):
    target = DEST / source.name
    target.mkdir(exist_ok=True)
    for path in sorted(source.rglob("*")):
        if not path.is_file() or path.suffix not in {".json", ".tsv", ".stdout", ".time", ".log", ".csv", ".txt"}:
            continue
        destination = target / path.relative_to(source)
        destination.parent.mkdir(parents=True, exist_ok=True)
        data = path.read_bytes()
        if path.name == "full.json" or path.suffix in {".stdout", ".log"}:
            destination = destination.with_name(destination.name + ".gz")
            destination.write_bytes(gzip.compress(data, mtime=0))
            if gzip.decompress(destination.read_bytes()) != data:
                raise ValueError(f"compression round trip failed: {path}")
        else:
            shutil.copyfile(path, destination)
        if path.name == "full.json":
            report = json.loads(data)
            report.pop("cases", None)
            report["archive_raw_samples"] = "full.json.gz"
            (target / "summary.json").write_text(json.dumps(report, indent=2) + "\n")


def manifest():
    entries = []
    for path in sorted(DEST.rglob("*")):
        if not path.is_file() or path.name == "manifest.json" or "__pycache__" in path.parts:
            continue
        data = path.read_bytes()
        entry = {"path": str(path.relative_to(DEST)), "bytes": len(data),
                 "sha256": hashlib.sha256(data).hexdigest()}
        if path.suffix == ".gz":
            raw = gzip.decompress(data)
            entry.update(uncompressed_bytes=len(raw), uncompressed_sha256=hashlib.sha256(raw).hexdigest())
        entries.append(entry)
    (DEST / "manifest.json").write_text(json.dumps({"files": entries}, indent=2) + "\n")
    print(f"Archived {len(entries)} files, {sum(e['bytes'] for e in entries):,} bytes excluding manifest")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("lanes", nargs="*")
    args = parser.parse_args()
    for name in args.lanes:
        if name not in {"baseline-native", "candidate-native", "overhead-native", "soak", "native-window-soak"}:
            raise SystemExit(f"unknown lane: {name}")
        source = REPO / "dist/workbench-hardening" / name
        if not source.is_dir():
            raise SystemExit(f"missing completed lane: {source}")
        archive(source)
    for name in ["plot-key-baseline.tsv", "plot-key-comparison.tsv"]:
        shutil.copyfile(REPO / "dist" / name, DEST / name)
    check_log = Path("/tmp/moxi-hardening-check.log")
    check_exit = Path("/tmp/moxi-hardening-check.exit")
    if check_log.is_file() and check_exit.is_file():
        checks = DEST / "repository-check"
        checks.mkdir(exist_ok=True)
        data = check_log.read_bytes()
        (checks / "check.log.gz").write_bytes(gzip.compress(data, mtime=0))
        shutil.copyfile(check_exit, checks / "check.exit")
    manifest()
