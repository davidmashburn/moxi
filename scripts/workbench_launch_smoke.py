#!/usr/bin/env python3
"""Prepare an isolated bundle and observe its process; CUA owns all UI actions.

prepare prints a unique app path for cua.getApp(path). Start observe before
opening that path, exercise one ordinary input action, and quit through CUA.
The report never promotes process observations to desktop acceptance.
"""
import argparse
import datetime
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

from workbench_artifact_check import validate


def processes(binary):
    listing = subprocess.check_output(["ps", "-axo", "pid=,command="], text=True)
    result = []
    for line in listing.splitlines():
        parts = line.strip().split(None, 1)
        if len(parts) == 2 and (parts[1] == str(binary) or parts[1].startswith(str(binary) + " ")):
            result.append(int(parts[0]))
    return result


def save(run, report):
    (run / "process-report.json").write_text(json.dumps(report, indent=2) + "\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    prepare = sub.add_parser("prepare")
    prepare.add_argument("--app", default="dist/Moxi Data Workbench.app")
    observe = sub.add_parser("observe")
    observe.add_argument("run", type=Path)
    observe.add_argument("--timeout", type=int, default=180)
    args = parser.parse_args()
    if args.command == "prepare":
        source = Path(args.app).resolve()
        manifest = validate(source)
        root = Path("dist/workbench-launch").resolve()
        root.mkdir(parents=True, exist_ok=True)
        run = Path(tempfile.mkdtemp(prefix="replay-", dir=root))
        app = run / source.name
        shutil.copytree(source, app)
        validate(app)
        save(run, {"status": "prepared", "app": str(app), "build": manifest,
                   "prepared_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
                   "existing_source_pids": processes(source / "Contents/MacOS/moxi-data-workbench"),
                   "desktop_acceptance": "pending CUA window, input, and ordinary quit evidence"})
        print(f"Run directory: {run}\nCUA app path: {app}")
        print(f"Before CUA launch: pixi run workbench-launch-smoke observe '{run}'")
        return 0
    run = args.run.resolve()
    report = json.loads((run / "process-report.json").read_text())
    app = Path(report["app"])
    binary = app / "Contents/MacOS/moxi-data-workbench"
    current = validate(app)
    if current["executable_sha256"] != report["build"]["executable_sha256"]:
        raise SystemExit("isolated executable changed after preparation; prepare a new replay")
    if processes(binary):
        raise SystemExit("conflict: isolated bundle is already running; prepare a new replay")
    if args.timeout < 1 or args.timeout > 600:
        raise SystemExit("timeout must be between 1 and 600 seconds")
    started = time.time()
    report.update(status="waiting_for_cua_launch", observation_started_at=started,
                  startup_stderr="unavailable: CUA owns LaunchServices launch",
                  clean_exit="requires CUA ordinary quit evidence; process disappearance is insufficient")
    save(run, report)
    pid = None
    print("Waiting for CUA to open the isolated app, interact, and quit", flush=True)
    while time.time() - started < args.timeout:
        found = processes(binary)
        if pid is None and found:
            if len(found) != 1:
                report["status"] = "conflicting_isolated_processes"
                break
            pid = found[0]
            report.update(status="process_observed", pid=pid, process_observed_at=time.time())
            save(run, report)
            print(f"Observed new PID {pid}", flush=True)
        elif pid is not None and pid not in found:
            report.update(status="process_lifecycle_observed", process_disappeared_at=time.time())
            break
        time.sleep(0.25)
    else:
        report["status"] = "timeout_waiting_for_launch" if pid is None else "timeout_waiting_for_quit"
    crashes = []
    diagnostics = Path.home() / "Library/Logs/DiagnosticReports"
    if diagnostics.is_dir():
        for path in diagnostics.glob("moxi-data-workbench*"):
            if path.is_file() and path.stat().st_mtime >= started:
                shutil.copy2(path, run / path.name)
                crashes.append(path.name)
    report["possible_matching_crash_reports"] = crashes
    if crashes:
        report["status"] = "crash_report_found_requires_review"
    save(run, report)
    print(json.dumps(report, indent=2))
    print("Native window readiness, interaction, and clean quit remain observer assertions.")
    return 0 if report["status"] == "process_lifecycle_observed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
