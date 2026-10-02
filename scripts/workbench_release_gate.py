#!/usr/bin/env python3
"""Run the repeatable automated portion of the workbench release gate.

The gate deliberately delegates validation to the existing Pixi tasks.  It
records each task's command, exit status, output, and repository provenance in
an isolated JSON evidence directory.  A passing report means only that the
automated commands passed; native desktop interaction and presentation still
require the manual checks documented alongside this script.
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
import datetime as dt
import json
import os
from pathlib import Path
import shlex
import subprocess
import sys
import time
from typing import Any, Callable, Iterable, Mapping, Sequence


UTC = dt.timezone.utc
SCRIPT_DIR = Path(__file__).resolve().parent
DEFAULT_REPO = SCRIPT_DIR.parent


@dataclass(frozen=True)
class CommandSpec:
    """One existing Pixi task included in the gate."""

    identifier: str
    task: str
    purpose: str
    optional: bool = False
    depends_on: tuple[str, ...] = ()


REQUIRED_COMMANDS: tuple[CommandSpec, ...] = (
    CommandSpec(
        "workbench-test",
        "workbench-test",
        "core workbench data and rendering correctness",
    ),
    CommandSpec(
        "native-custom-paint-cache",
        "native-custom-paint-cache",
        "native retained-paint cache equivalence and invalidation",
    ),
    CommandSpec(
        "native-accessibility-abi",
        "native-accessibility-abi",
        "native accessibility ABI probe and regression cases",
    ),
    CommandSpec(
        "data-workbench-build",
        "data-workbench-build",
        "build and package the workbench application bundle",
    ),
    CommandSpec(
        "workbench-artifact-check",
        "workbench-artifact-check",
        "validate the sealed workbench bundle and build manifest",
        depends_on=("data-workbench-build",),
    ),
)

OPTIONAL_COMMANDS: Mapping[str, CommandSpec] = {
    "benchmark": CommandSpec(
        "workbench-benchmark",
        "workbench-benchmark",
        "record the optional structured workbench benchmark",
        optional=True,
    ),
    "package_consumer": CommandSpec(
        "package-consumer",
        "package-consumer",
        "build and install-test the package consumer lane",
        optional=True,
    ),
}


def utc_now() -> dt.datetime:
    """Return an aware UTC timestamp; kept separate for deterministic tests."""

    return dt.datetime.now(UTC)


def timestamp(value: dt.datetime) -> str:
    """Serialize an aware timestamp in the report's stable format."""

    return value.astimezone(UTC).isoformat().replace("+00:00", "Z")


def _text(value: Any) -> str:
    """Convert subprocess output to safe text, including mocked byte output."""

    if value is None:
        return ""
    if isinstance(value, bytes):
        return value.decode("utf-8", errors="replace")
    return str(value)


def _write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def _unique_default_output(repo: Path, started: dt.datetime) -> Path:
    """Choose a dated evidence directory without replacing a prior run."""

    parent = repo / "dist" / "workbench-release-gate"
    stem = started.astimezone(UTC).strftime("%Y%m%dT%H%M%SZ")
    candidate = parent / stem
    suffix = 1
    while candidate.exists():
        candidate = parent / f"{stem}-{suffix}"
        suffix += 1
    return candidate


def _metadata_command(
    args: Sequence[str],
    repo: Path,
    runner: Callable[..., Any],
) -> tuple[Any | None, str | None]:
    """Run a quiet git metadata command and retain failures in the report."""

    try:
        result = runner(
            list(args),
            cwd=str(repo),
            capture_output=True,
            text=True,
            check=False,
        )
    except OSError as error:
        return None, f"{type(error).__name__}: {error}"
    return result, None


def repository_metadata(
    repo: Path,
    runner: Callable[..., Any] = subprocess.run,
) -> dict[str, Any]:
    """Collect revision and dirty state without making them command inputs."""

    revision_result, revision_error = _metadata_command(
        ["git", "rev-parse", "HEAD"], repo, runner
    )
    status_result, status_error = _metadata_command(
        ["git", "status", "--porcelain=v1", "--untracked-files=all"], repo, runner
    )

    errors: list[str] = []
    revision: str | None = None
    if revision_error:
        errors.append(f"revision: {revision_error}")
    elif getattr(revision_result, "returncode", 1) == 0:
        revision = _text(getattr(revision_result, "stdout", "")).strip() or None
        if revision is None:
            errors.append("revision: git returned no revision")
    else:
        errors.append(
            "revision: git rev-parse exited "
            f"{getattr(revision_result, 'returncode', 'unknown')}"
        )

    dirty: bool | None = None
    if status_error:
        errors.append(f"dirty: {status_error}")
    elif getattr(status_result, "returncode", 1) == 0:
        dirty = bool(_text(getattr(status_result, "stdout", "")).strip())
    else:
        errors.append(
            "dirty: git status exited "
            f"{getattr(status_result, 'returncode', 'unknown')}"
        )

    return {"revision": revision, "dirty": dirty, "errors": errors}


def command_specs(
    *,
    include_benchmark: bool = False,
    include_package_consumer: bool = False,
) -> tuple[CommandSpec, ...]:
    """Return the deterministic task order for one gate invocation."""

    specs = list(REQUIRED_COMMANDS)
    if include_benchmark:
        specs.append(OPTIONAL_COMMANDS["benchmark"])
    if include_package_consumer:
        specs.append(OPTIONAL_COMMANDS["package_consumer"])
    return tuple(specs)


def _status_for_exit(exit_code: int | None) -> str:
    return "passed" if exit_code == 0 else "failed"


def run_command(
    spec: CommandSpec,
    *,
    pixi: str,
    repo: Path,
    log_dir: Path,
    ordinal: int,
    runner: Callable[..., Any] = subprocess.run,
    clock: Callable[[], float] = time.monotonic,
    now: Callable[[], dt.datetime] = utc_now,
    environment: Mapping[str, str] | None = None,
) -> dict[str, Any]:
    """Run one task, save its complete JSON log, and return its summary."""

    command = [pixi, "run", spec.task]
    started_at = now()
    started_clock = clock()
    stdout = ""
    stderr = ""
    error: str | None = None
    exit_code: int | None = None

    try:
        run_kwargs: dict[str, Any] = {
            "cwd": str(repo),
            "capture_output": True,
            "text": True,
            "check": False,
        }
        if environment is not None:
            run_kwargs["env"] = dict(environment)
        result = runner(command, **run_kwargs)
        exit_code = getattr(result, "returncode", None)
        stdout = _text(getattr(result, "stdout", ""))
        stderr = _text(getattr(result, "stderr", ""))
        if exit_code is None:
            error = "runner returned no exit code"
    except subprocess.TimeoutExpired as timeout:
        stdout = _text(getattr(timeout, "stdout", ""))
        stderr = _text(getattr(timeout, "stderr", ""))
        error = f"TimeoutExpired: {timeout}"
    except OSError as os_error:
        error = f"{type(os_error).__name__}: {os_error}"
    except Exception as unexpected:  # pragma: no cover - defensive runner boundary
        error = f"{type(unexpected).__name__}: {unexpected}"

    finished_at = now()
    duration = max(0.0, clock() - started_clock)
    if error is not None:
        status = "failed"
    else:
        status = _status_for_exit(exit_code)

    filename = f"{ordinal:02d}-{spec.identifier}.json"
    log_path = log_dir / filename
    record: dict[str, Any] = {
        "identifier": spec.identifier,
        "task": spec.task,
        "purpose": spec.purpose,
        "optional": spec.optional,
        "command": command,
        "command_string": shlex.join(command),
        "cwd": str(repo),
        "started_at": timestamp(started_at),
        "finished_at": timestamp(finished_at),
        "duration_seconds": round(duration, 6),
        "exit_code": exit_code,
        "status": status,
        "stdout": stdout,
        "stderr": stderr,
    }
    if environment is not None:
        # The full environment is intentionally not copied into evidence. Keep
        # only the gate-owned override that affects artifact placement.
        record["environment_overrides"] = {
            "MOXI_WORKBENCH_DIR": environment.get("MOXI_WORKBENCH_DIR", "")
        }
    if error is not None:
        record["error"] = error
    _write_json(log_path, record)

    summary = dict(record)
    summary.pop("stdout", None)
    summary.pop("stderr", None)
    summary["log"] = str(log_path)
    if error is not None:
        summary["failure"] = error
    elif exit_code != 0:
        summary["failure"] = f"command exited with status {exit_code}"
    return summary


def skip_command(
    spec: CommandSpec,
    *,
    pixi: str,
    repo: Path,
    log_dir: Path,
    ordinal: int,
    reason: str,
    now: Callable[[], dt.datetime] = utc_now,
) -> dict[str, Any]:
    """Record a dependency skip without inspecting a stale artifact."""

    instant = timestamp(now())
    filename = f"{ordinal:02d}-{spec.identifier}.json"
    log_path = log_dir / filename
    record: dict[str, Any] = {
        "identifier": spec.identifier,
        "task": spec.task,
        "purpose": spec.purpose,
        "optional": spec.optional,
        "command": [pixi, "run", spec.task],
        "command_string": shlex.join([pixi, "run", spec.task]),
        "cwd": str(repo),
        "started_at": instant,
        "finished_at": instant,
        "duration_seconds": 0.0,
        "exit_code": None,
        "status": "skipped",
        "skip_reason": reason,
        "stdout": "",
        "stderr": "",
    }
    _write_json(log_path, record)
    summary = dict(record)
    summary.pop("stdout", None)
    summary.pop("stderr", None)
    summary["log"] = str(log_path)
    summary["failure"] = reason
    return summary


def manual_acceptance() -> dict[str, Any]:
    """Describe evidence that automation must never infer."""

    return {
        "status": "pending",
        "policy": (
            "Automation does not promote process observation or command success "
            "to native desktop acceptance. Review the linked records separately."
        ),
        "items": [
            {
                "id": "launch-quit",
                "status": "pending",
                "check": "Open the packaged app, exercise the visible workbench, and quit normally.",
            },
            {
                "id": "real-ime",
                "status": "pending",
                "check": "Use a real IME to compose, commit, cancel, and replace text in the native fields.",
            },
            {
                "id": "voiceover",
                "status": "pending",
                "check": "Traverse the workbench with VoiceOver and verify labels, order, and announcements.",
            },
            {
                "id": "on-screen-timing",
                "status": "pending",
                "check": "Measure presentation or input-to-screen timing on the physical display.",
            },
        ],
        "references": [
            "docs/workbench-native-acceptance.md",
            "docs/workbench-native-latency.md",
        ],
    }


def run_gate(
    *,
    repo: Path = DEFAULT_REPO,
    output_dir: Path | None = None,
    pixi: str = "pixi",
    include_benchmark: bool = False,
    include_package_consumer: bool = False,
    runner: Callable[..., Any] = subprocess.run,
    now: Callable[[], dt.datetime] = utc_now,
    clock: Callable[[], float] = time.monotonic,
) -> dict[str, Any]:
    """Run the gate and return the report; command failures do not abort logging."""

    repo = Path(repo).expanduser().resolve()
    if not repo.is_dir():
        raise ValueError(f"repository path is not a directory: {repo}")

    started = now()
    evidence_dir = (
        Path(output_dir).expanduser().resolve()
        if output_dir is not None
        else _unique_default_output(repo, started)
    )
    if output_dir is not None and evidence_dir.exists() and any(evidence_dir.iterdir()):
        raise ValueError(
            f"output directory already contains evidence; choose a new path: {evidence_dir}"
        )
    evidence_dir.mkdir(parents=True, exist_ok=True)
    log_dir = evidence_dir / "commands"
    log_dir.mkdir(parents=True, exist_ok=True)

    metadata = repository_metadata(repo, runner=runner)
    specs = command_specs(
        include_benchmark=include_benchmark,
        include_package_consumer=include_package_consumer,
    )
    commands: list[dict[str, Any]] = []
    for ordinal, spec in enumerate(specs, start=1):
        print(f"==> {spec.task}", flush=True)
        dependency_failures = [
            entry
            for entry in commands
            if entry["identifier"] in spec.depends_on
            and entry["status"] != "passed"
        ]
        if dependency_failures:
            reason = "dependency failed: " + ", ".join(
                entry["identifier"] for entry in dependency_failures
            )
            result = skip_command(
                spec,
                pixi=pixi,
                repo=repo,
                log_dir=log_dir,
                ordinal=ordinal,
                reason=reason,
                now=now,
            )
            commands.append(result)
            print(f"    skipped ({reason}; log={result['log']})", flush=True)
            continue
        environment = None
        if spec.identifier == "workbench-benchmark":
            environment = os.environ.copy()
            environment["MOXI_WORKBENCH_DIR"] = str(evidence_dir / "benchmark")
        result = run_command(
            spec,
            pixi=pixi,
            repo=repo,
            log_dir=log_dir,
            ordinal=ordinal,
            runner=runner,
            clock=clock,
            now=now,
            environment=environment,
        )
        commands.append(result)
        print(
            f"    {result['status']} (exit={result['exit_code']}; log={result['log']})",
            flush=True,
        )

    finished = now()
    failed_commands = [entry for entry in commands if entry["status"] == "failed"]
    skipped_commands = [entry for entry in commands if entry["status"] == "skipped"]
    metadata_errors = list(metadata["errors"])
    failure_reasons = [
        f"{entry['identifier']}: {entry.get('failure', 'command failed')}"
        for entry in failed_commands
    ]
    failure_reasons.extend(
        f"{entry['identifier']}: {entry['failure']}" for entry in skipped_commands
    )
    failure_reasons.extend(metadata_errors)
    status = "passed" if not failure_reasons else "failed"

    benchmark_entry = next(
        (entry for entry in commands if entry["identifier"] == "workbench-benchmark"),
        None,
    )
    if benchmark_entry is None:
        benchmark = {
            "requested": False,
            "status": "not-run",
            "latency_thresholds": None,
            "interpretation": "No latency or throughput threshold is inferred.",
        }
    else:
        benchmark = {
            "requested": True,
            "status": "recorded" if benchmark_entry["status"] == "passed" else "failed",
            "task": benchmark_entry["task"],
            "log": benchmark_entry["log"],
            "latency_thresholds": None,
            "interpretation": (
                "Results are recorded for review; this gate applies no latency "
                "threshold and does not claim on-screen timing."
            ),
        }

    report: dict[str, Any] = {
        "schema_version": 1,
        "gate": "workbench-release-gate",
        "status": status,
        "timestamp": timestamp(started),
        "started_at": timestamp(started),
        "finished_at": timestamp(finished),
        "repository": str(repo),
        "revision": metadata["revision"],
        "dirty": metadata["dirty"],
        "metadata_errors": metadata_errors,
        "commands": commands,
        "required_tasks": [spec.task for spec in REQUIRED_COMMANDS],
        "optional_tasks": [
            spec.task
            for spec in specs
            if spec.optional
        ],
        "benchmark": benchmark,
        "manual_acceptance": manual_acceptance(),
        "failure_reasons": failure_reasons,
        "evidence_directory": str(evidence_dir),
        "report": str(evidence_dir / "report.json"),
    }
    _write_json(evidence_dir / "report.json", report)

    if status == "passed":
        print(f"Workbench automated release gate passed: {evidence_dir / 'report.json'}")
    else:
        print("Workbench automated release gate failed:", file=sys.stderr)
        for reason in failure_reasons:
            print(f"  - {reason}", file=sys.stderr)
        print(f"Report: {evidence_dir / 'report.json'}", file=sys.stderr)
    return report


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--repo",
        type=Path,
        default=DEFAULT_REPO,
        help=f"repository root (default: {DEFAULT_REPO})",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        help=(
            "evidence directory; defaults to dist/workbench-release-gate/"
            "<UTC timestamp>"
        ),
    )
    parser.add_argument(
        "--pixi",
        default=os.environ.get("MOXI_PIXI", "pixi"),
        help="Pixi executable (default: MOXI_PIXI or pixi)",
    )
    parser.add_argument(
        "--benchmark",
        action="store_true",
        help="also run workbench-benchmark and record its results",
    )
    parser.add_argument(
        "--package-consumer",
        action="store_true",
        help="also run the expensive package-consumer lane",
    )
    return parser


def main(argv: Iterable[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        report = run_gate(
            repo=args.repo,
            output_dir=args.output_dir,
            pixi=args.pixi,
            include_benchmark=args.benchmark,
            include_package_consumer=args.package_consumer,
        )
    except (OSError, ValueError) as error:
        print(f"Workbench automated release gate could not start: {error}", file=sys.stderr)
        return 2
    return 0 if report["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
