#!/usr/bin/env python3
"""Observe an explicitly selected workbench process; never launch or control it."""

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import platform
import plistlib
import subprocess
import sys
import time


WARMUP_SECONDS = 30
MEASURE_SECONDS = 600
SAMPLE_SECONDS = 30


def utc_now():
    return datetime.now(timezone.utc).isoformat()


def positive_pid(value):
    pid = int(value)
    if pid <= 0:
        raise argparse.ArgumentTypeError("PID must be positive")
    return pid


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def verify_bundle(app):
    info_path = app / "Contents/Info.plist"
    with info_path.open("rb") as source:
        info = plistlib.load(source)
    if info.get("CFBundleIdentifier") != "org.moxi.data-workbench":
        raise ValueError("unexpected bundle identifier")
    if info.get("CFBundleExecutable") != "moxi-data-workbench":
        raise ValueError("unexpected bundle executable")
    binary = app / "Contents/MacOS/moxi-data-workbench"
    if not binary.is_file() or not os.access(binary, os.X_OK):
        raise ValueError("bundle executable is missing or not executable")
    checked = subprocess.run(
        ["/usr/bin/codesign", "--verify", "--deep", "--strict", "--verbose=2", str(app)],
        capture_output=True, text=True, timeout=30,
    )
    if checked.returncode:
        raise ValueError("bundle signature failed: " + checked.stderr.strip())
    return {
        "verified_at": utc_now(),
        "executable_sha256": sha256(binary),
        "info_plist_sha256": sha256(info_path),
        "codesign_stderr": checked.stderr.strip(),
    }


def process_sample(pid, binary):
    # -ww prevents command-path truncation. lstart detects PID reuse; comm is
    # the executable path, not an ambiguous argv prefix or substring match.
    sampled = subprocess.run(
        ["/bin/ps", "-ww", "-p", str(pid), "-o", "pid=,lstart=,rss=,comm="],
        capture_output=True, text=True, timeout=10,
        env={**os.environ, "LC_ALL": "C"},
    )
    fields = sampled.stdout.strip().split(maxsplit=7)
    if sampled.returncode or len(fields) != 8 or int(fields[0]) != pid:
        raise ValueError("selected process disappeared or ps could not identify it")
    if fields[7] != str(binary):
        raise ValueError(f"PID executable mismatch: {fields[7]!r} != {str(binary)!r}")
    rss_kib = int(fields[6])
    if rss_kib <= 0:
        raise ValueError("ps returned nonpositive RSS")
    return {
        "observed_at": utc_now(),
        "pid": pid,
        "process_started": " ".join(fields[1:6]),
        "command": fields[7],
        "resident_bytes": rss_kib * 1024,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pid", required=True, type=positive_pid)
    parser.add_argument("--app", required=True, type=Path)
    parser.add_argument("--output-dir", required=True, type=Path)
    args = parser.parse_args()
    if sys.platform != "darwin":
        parser.error("this observer requires macOS ps and codesign")
    app = args.app.expanduser().resolve()
    binary = app / "Contents/MacOS/moxi-data-workbench"
    output = args.output_dir.expanduser().resolve()
    output.mkdir(parents=True, exist_ok=True)
    result_path = output / "result.json"
    if result_path.exists():
        parser.error(f"refusing to replace existing evidence: {result_path}")
    result = {
        "status": "running",
        "boundary": "RSS of an existing native window process; interactions supplied separately",
        "app": str(app), "executable": str(binary), "pid": args.pid,
        "started_at": utc_now(), "macos_version": platform.mac_ver()[0],
        "architecture": platform.machine(),
        "warmup_seconds": WARMUP_SECONDS,
        "measured_seconds": MEASURE_SECONDS,
        "sample_interval_seconds": SAMPLE_SECONDS,
        "samples": [],
        "interaction_evidence": "not observed by this script; pair with native replay",
        "leak_verdict": "not established; inspect post-warmup interval samples",
    }
    exit_code = 1
    try:
        result["bundle_before"] = verify_bundle(app)
        initial = process_sample(args.pid, binary)
        origin = time.monotonic()
        initial["elapsed_seconds"] = 0.0
        initial["phase"] = "warmup"
        result["samples"].append(initial)
        duration = WARMUP_SECONDS + MEASURE_SECONDS
        for scheduled in range(SAMPLE_SECONDS, duration + 1, SAMPLE_SECONDS):
            time.sleep(max(0.0, origin + scheduled - time.monotonic()))
            sample = process_sample(args.pid, binary)
            sample["elapsed_seconds"] = time.monotonic() - origin
            sample["scheduled_elapsed_seconds"] = scheduled
            sample["phase"] = "measurement" if scheduled >= WARMUP_SECONDS else "warmup"
            if sample["process_started"] != initial["process_started"]:
                raise ValueError("selected PID was reused by a different process")
            result["samples"].append(sample)
        result["bundle_after"] = verify_bundle(app)
        final = process_sample(args.pid, binary)
        if final["process_started"] != initial["process_started"]:
            raise ValueError("selected process changed during final signature verification")
        for field in ("executable_sha256", "info_plist_sha256"):
            if result["bundle_before"][field] != result["bundle_after"][field]:
                raise ValueError(f"bundle changed during observation: {field}")
        result["status"] = "passed"
        exit_code = 0
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        result["status"] = "failed"
        result["error"] = str(error)
    finally:
        result["completed_at"] = utc_now()
        with result_path.open("x") as destination:
            json.dump(result, destination, indent=2)
            destination.write("\n")
    print(f"Native window observation {result['status']}: {result_path}")
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
