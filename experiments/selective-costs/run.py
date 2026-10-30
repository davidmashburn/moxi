"""Build once, run the isolated selective-costs Mojo timing probe, and report it."""

from __future__ import annotations

from collections import defaultdict
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import platform
import statistics
import subprocess
import tempfile


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
BASELINE = ROOT / "experiments/state-access"
METHOD_BINDING = ROOT / "experiments/method-binding"
SELECTIVE = ROOT / "experiments/selective-updates"


def run_capture(command: list[str], *, timeout: int) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        timeout=timeout,
    )


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def source_paths() -> list[Path]:
    paths = [
        ROOT / "pixi.toml",
        ROOT / "pixi.lock",
        HERE / "benchmark.mojo",
        HERE / "run.py",
        SELECTIVE / "selective.mojo",
        METHOD_BINDING / "runtime.mojo",
        METHOD_BINDING / "bindings.mojo",
    ]
    paths.extend(BASELINE.glob("*.mojo"))
    paths.extend(ROOT.glob("src/**/*.mojo"))
    return sorted(set(path for path in paths if path.is_file()))


def relative_command(command: list[str]) -> list[str]:
    result = []
    for item in command:
        try:
            result.append(str(Path(item).resolve().relative_to(ROOT)))
        except (ValueError, OSError):
            result.append(item)
    return result


def machine_info() -> dict[str, str]:
    info = {
        "platform": platform.platform(),
        "system": platform.system(),
        "release": platform.release(),
        "machine": platform.machine(),
        "processor": platform.processor(),
        "python": platform.python_version(),
    }
    if platform.system() == "Darwin":
        for key, command in {
            "macos_product": ["sw_vers", "-productVersion"],
            "cpu_brand": ["sysctl", "-n", "machdep.cpu.brand_string"],
            "logical_cpus": ["sysctl", "-n", "hw.logicalcpu"],
        }.items():
            try:
                info[key] = subprocess.check_output(command, text=True).strip()
            except (OSError, subprocess.CalledProcessError):
                info[key] = "unavailable"
    return info


def parse_samples(output: str) -> tuple[list[dict], list[dict], list[str]]:
    samples: list[dict] = []
    model_samples: list[dict] = []
    other_lines: list[str] = []
    for line in output.splitlines():
        if line.startswith("SAMPLE|"):
            phase, mode, operation, editors, sample, elapsed, view_sum, paint_sum = line.split("|")[1:]
            samples.append(
                {
                    "phase": phase,
                    "mode": mode,
                    "operation": operation,
                    "editors": int(editors),
                    "sample": int(sample),
                    "elapsed_ns": int(elapsed),
                    "view_checksum": int(view_sum),
                    "paint_checksum": int(paint_sum),
                }
            )
        elif line.startswith("MODEL|"):
            phase, history_size, sample, repeats, elapsed, total_elapsed, result, checksum = line.split("|")[1:]
            model_samples.append(
                {
                    "phase": phase,
                    "history_size": int(history_size),
                    "sample": int(sample),
                    "repeat_count": int(repeats),
                    "elapsed_ns": int(elapsed),
                    "total_elapsed_ns": int(total_elapsed),
                    "result": int(result),
                    "checksum": int(checksum),
                }
            )
        else:
            other_lines.append(line)
    return samples, model_samples, other_lines


def summarize(rows: list[dict], key_fields: tuple[str, ...]) -> list[dict]:
    groups: dict[tuple, list[dict]] = defaultdict(list)
    for row in rows:
        groups[tuple(row[field] for field in key_fields)].append(row)
    summaries = []
    for key, group in sorted(groups.items(), key=lambda item: item[0]):
        values = [row["elapsed_ns"] for row in group]
        median = statistics.median(values)
        summaries.append(
            {
                **dict(zip(key_fields, key)),
                "samples": len(values),
                "median_ns": median,
                "min_ns": min(values),
                "max_ns": max(values),
                "range_ns": [min(values), max(values)],
            }
        )
    return summaries


def validate(samples: list[dict], model_samples: list[dict]) -> dict:
    errors: list[str] = []
    expected_modes = {"handler", "all_inputs", "display_inputs"}
    expected_counts = {2, 100, 1000}
    expected_frame_samples = 3
    expected_stage_samples = 2
    frame_samples_by_count = {2: 3, 100: 3, 1000: 1}
    stage_samples_by_count = {2: 2, 100: 2, 1000: 1}

    frame_rows = [row for row in samples if row["phase"] == "frame"]
    stage_rows = [row for row in samples if row["phase"] != "frame"]
    expected_frame_rows = 3 * 2 * sum(frame_samples_by_count.values())
    expected_stage_rows = 3 * 3 * sum(stage_samples_by_count.values())
    if len(frame_rows) != expected_frame_rows:
        errors.append(f"frame row count={len(frame_rows)}")
    if len(stage_rows) != expected_stage_rows:
        errors.append(f"stage row count={len(stage_rows)}")

    for row in samples:
        if row["mode"] not in expected_modes:
            errors.append(f"unexpected mode {row['mode']}")
        if row["editors"] not in expected_counts:
            errors.append(f"unexpected editor count {row['editors']}")
        expected_samples = (
            frame_samples_by_count[row["editors"]]
            if row["phase"] == "frame"
            else stage_samples_by_count[row["editors"]]
        )
        if row["sample"] not in range(expected_samples):
            errors.append(f"unexpected sample index {row['sample']}")
        if row["elapsed_ns"] <= 0:
            errors.append(f"non-positive elapsed time {row}")

    # The checksums intentionally omit retained identity IDs.  Equal values
    # here are the experiment's visible-output equivalence check across modes.
    equivalence_keys = ("phase", "operation", "editors", "sample")
    for key in sorted({tuple(row[field] for field in equivalence_keys) for row in samples}):
        rows = [row for row in samples if tuple(row[field] for field in equivalence_keys) == key]
        if {row["view_checksum"] for row in rows} != {rows[0]["view_checksum"]}:
            errors.append(f"visible view checksum mismatch for {key}: {rows}")
        if {row["paint_checksum"] for row in rows} != {rows[0]["paint_checksum"]}:
            errors.append(f"paint checksum mismatch for {key}: {rows}")

    expected_model = {"snapshot_create", "equality_same", "equality_alternate_tail"}
    if len(model_samples) != 3 * 3 * 3:
        errors.append(f"model row count={len(model_samples)}")
    for row in model_samples:
        if row["phase"] not in expected_model:
            errors.append(f"unexpected model phase {row['phase']}")
        if row["history_size"] not in {0, 10_000, 100_000}:
            errors.append(f"unexpected history size {row['history_size']}")
        if row["result"] != (1 if row["phase"] in {"snapshot_create", "equality_same"} else 0):
            errors.append(f"unexpected equality result {row}")
        if row["repeat_count"] != (1024 if row["history_size"] == 0 else 1):
            errors.append(f"unexpected repeat count {row}")
        if row["elapsed_ns"] <= 0 or row["total_elapsed_ns"] <= 0:
            errors.append(f"non-positive model elapsed time {row}")

    return {"passed": not errors, "errors": errors}


def format_ms(value: float) -> str:
    return f"{value / 1_000_000:.3f}"


def print_summary(summaries: list[dict], model_summaries: list[dict]) -> None:
    print("phase\tmode\toperation\teditors\tmedian_ms\trange_ms")
    for row in summaries:
        print(
            "\t".join(
                [
                    row["phase"],
                    row["mode"],
                    row["operation"],
                    str(row["editors"]),
                    format_ms(row["median_ns"]),
                    f"{format_ms(row['min_ns'])}-{format_ms(row['max_ns'])}",
                ]
            )
        )
    print("model\tphase\thistory\tmedian_us\trange_us")
    for row in model_summaries:
        print(
            "\t".join(
                [
                    "model",
                    row["phase"],
                    str(row["history_size"]),
                    f"{row['median_ns'] / 1_000:.3f}",
                    f"{row['min_ns'] / 1_000:.3f}-{row['max_ns'] / 1_000:.3f}",
                ]
            )
        )


def main() -> int:
    logs = Path(tempfile.mkdtemp(prefix="moxi-selective-costs-"))
    binary = logs / "selective-costs"
    includes = [
        ROOT / "src",
        BASELINE,
        METHOD_BINDING,
        SELECTIVE,
        HERE,
    ]
    build_command = ["pixi", "run", "--locked", "mojo", "build", "-O3"]
    for include in includes:
        build_command.extend(["-I", str(include)])
    build_command.extend([str(HERE / "benchmark.mojo"), "-o", str(binary)])
    build = run_capture(build_command, timeout=300)
    (logs / "build.log").write_text(build.stdout)
    if build.returncode:
        print(build.stdout, end="")
        print(f"Build failed; full log: {logs / 'build.log'}")
        return build.returncode

    run = run_capture([str(binary)], timeout=300)
    (logs / "run.log").write_text(run.stdout)
    if run.returncode:
        print(run.stdout, end="")
        print(f"Run failed; full log: {logs / 'run.log'}")
        return run.returncode

    samples, model_samples, other_lines = parse_samples(run.stdout)
    validation = validate(samples, model_samples)
    summaries = summarize(samples, ("phase", "mode", "operation", "editors"))
    model_summaries = summarize(model_samples, ("phase", "history_size"))
    compiler = run_capture(
        ["pixi", "run", "--locked", "mojo", "--version"], timeout=60
    )
    status = subprocess.check_output(["git", "status", "--short"], cwd=ROOT, text=True)
    report = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "implementation_head": subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True
        ).strip(),
        "branch": subprocess.check_output(
            ["git", "branch", "--show-current"], cwd=ROOT, text=True
        ).strip(),
        "compiler": compiler.stdout.strip(),
        "machine": machine_info(),
        "optimization": "mojo build -O3 (the Mojo build default, stated explicitly)",
        "scope": {
            "editor_counts": [2, 100, 1000],
            "history_sizes": [0, 10_000, 100_000],
            "frame_warmups": 2,
            "frame_samples": 3,
            "stage_warmups": 2,
            "stage_samples": 2,
            "large_editor_cap": {
                "editor_count": 1000,
                "frame_warmups": 1,
                "frame_samples": 1,
                "stage_warmups": 1,
                "stage_samples": 1,
                "reason": "Bounded coverage for the expensive full-render baseline",
            },
            "model_warmups": 1,
            "model_samples": 3,
            "frame_timing": "App.update(event) plus App.paint() after a warmed baseline paint; backend-neutral commands only",
            "build_timing": "component build() including parent composition and ColumnView layout, without App runtime reconciliation",
            "rebuild_timing": "idle App.rebuild() including component build and runtime reconciliation, without paint",
            "paint_timing": "App.paint() after a real local App.update(), excluding that update",
        },
        "commands": {
            "build": relative_command(build_command),
            "run": relative_command([str(binary)]),
            "runner": ["python3", "experiments/selective-costs/run.py"],
            "compiler_version": ["pixi", "run", "--locked", "mojo", "--version"],
        },
        "working_tree_status_at_run": status.splitlines(),
        "source_hashes": {
            str(path.relative_to(ROOT)): digest(path) for path in source_paths()
        },
        "validation": validation,
        "samples": samples,
        "model_samples": model_samples,
        "summaries": summaries,
        "model_summaries": model_summaries,
        "raw_stdout": run.stdout,
        "unparsed_stdout_lines": other_lines,
        "temporary_logs": str(logs),
        "not_verified": [
            "native window or renderer time",
            "GPU submission or GPU execution",
            "allocator counts, memory footprint, or latency percentiles",
            "cross-machine performance generalization",
        ],
    }
    (HERE / "results.json").write_text(json.dumps(report, indent=2) + "\n")
    print_summary(summaries, model_summaries)
    print(f"validation={'PASS' if validation['passed'] else 'FAIL'}")
    print(f"raw report: {HERE / 'results.json'}")
    print(f"temporary logs: {logs}")
    if other_lines:
        print("protocol lines:")
        for line in other_lines:
            print(line)
    return 0 if validation["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
