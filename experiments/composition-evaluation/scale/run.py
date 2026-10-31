"""Prepare and measure the isolated generic HandlerHost scale evaluation.

``--prepare`` compiles both O3 probes and runs correctness only.  ``--measure``
verifies the prepared inputs and timing binary before running the serial timing
probe.  Build and run logs stay in temporary directories under /tmp.
"""
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import platform
import shlex
import statistics
import subprocess
import sys
import tempfile


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
SRC = ROOT / "src"
METHOD_BINDING = ROOT / "experiments/method-binding"
SIMPLE_COMPOSITION = ROOT / "experiments/simple-composition"
MANIFEST = HERE / "prepared.json"
RESULTS = HERE / "results.json"
TIMEOUT_SECONDS = 240
WARMUPS = 2
SAMPLES = 5
VISIBLE_COUNTS = (10, 100, 300, 1000)
CHURN_CYCLES = (0, 100, 1000)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def compiler_command() -> list[str]:
    direct = ROOT / ".pixi/envs/default/bin/mojo"
    if direct.is_file() and direct.stat().st_mode & 0o111:
        return [str(direct)]
    return ["pixi", "run", "--locked", "mojo"]


def command_environment(command: list[str]) -> dict[str, str]:
    environment = os.environ.copy()
    direct = ROOT / ".pixi/envs/default/bin/mojo"
    if command and command[0] == str(direct):
        # Direct execution does not inherit pixi's MODULAR_HOME.  Mojo uses it
        # to locate the standard library and compiler support files.
        environment["MODULAR_HOME"] = str(ROOT / ".pixi/envs/default/share/max")
    return environment


def rel(path: Path) -> str:
    return str(path.relative_to(ROOT))


def source_inputs() -> list[Path]:
    return [
        HERE / "scale_model.mojo",
        HERE / "scale_correctness.mojo",
        HERE / "scale_timing.mojo",
        HERE / "run.py",
        METHOD_BINDING / "runtime.mojo",
        METHOD_BINDING / "bindings.mojo",
        SIMPLE_COMPOSITION / "screen.mojo",
        SIMPLE_COMPOSITION / "probe.mojo",
        SIMPLE_COMPOSITION / "timing.mojo",
        ROOT / "pixi.toml",
        ROOT / "pixi.lock",
        *sorted(SRC.glob("**/*.mojo")),
    ]


def timestamp() -> str:
    return datetime.now(timezone.utc).isoformat()


def run_logged(
    name: str,
    command: list[str],
    logs: Path,
    timeout: int = TIMEOUT_SECONDS,
) -> tuple[str, Path]:
    log = logs / f"{name}.log"
    try:
        with log.open("w") as output:
            result = subprocess.run(
                command,
                cwd=ROOT,
                stdout=output,
                stderr=subprocess.STDOUT,
                env=command_environment(command),
                timeout=timeout,
                check=False,
            )
    except subprocess.TimeoutExpired as exc:
        text = log.read_text(errors="replace")
        raise RuntimeError(
            f"{name} timed out after {timeout}s; log={log}\n{text[-4000:]}"
        ) from exc
    text = log.read_text(errors="replace")
    if result.returncode != 0:
        raise RuntimeError(
            f"{name} failed with exit {result.returncode}; log={log}\n{text[-6000:]}"
        )
    return text, log


def build_command(compiler: list[str], source: Path, binary: Path) -> list[str]:
    return [
        *compiler,
        "build",
        "-O3",
        "-I",
        str(SRC),
        "-I",
        str(METHOD_BINDING),
        "-I",
        str(HERE),
        str(source),
        "-o",
        str(binary),
    ]


def prepare() -> None:
    logs = Path(tempfile.mkdtemp(prefix="moxi-handler-host-scale-", dir="/tmp"))
    compiler = compiler_command()
    compiler_version, compiler_version_log = run_logged(
        "compiler-version", [*compiler, "--version"], logs, timeout=30
    )

    binaries: dict[str, dict[str, object]] = {}
    correctness_source = HERE / "scale_correctness.mojo"
    timing_source = HERE / "scale_timing.mojo"
    for name, source in (("correctness", correctness_source), ("timing", timing_source)):
        binary = logs / name
        command = build_command(compiler, source, binary)
        _, build_log = run_logged(f"build-{name}", command, logs)
        binaries[name] = {
            "path": str(binary),
            "sha256": sha256(binary),
            "source": rel(source),
            "command": command,
            "log": str(build_log),
        }

    correctness_stdout, correctness_log = run_logged(
        "correctness", [str(binaries["correctness"]["path"])], logs
    )

    manifest = {
        "status": "prepared",
        "prepared_at": timestamp(),
        "logs": str(logs),
        "compiler": {
            "command": compiler,
            "environment": {
                "MODULAR_HOME": str(ROOT / ".pixi/envs/default/share/max")
                if compiler[0] == str(ROOT / ".pixi/envs/default/bin/mojo")
                else None,
            },
            "version": compiler_version.strip(),
            "version_log": str(compiler_version_log),
        },
        "platform": {
            "platform": platform.platform(),
            "system": platform.system(),
            "release": platform.release(),
            "machine": platform.machine(),
            "processor": platform.processor(),
            "python": sys.version,
        },
        "protocol": {
            "optimization": "O3",
            "warmups": WARMUPS,
            "samples": SAMPLES,
            "visible_counts": list(VISIBLE_COUNTS),
            "churn_cycles": list(CHURN_CYCLES),
            "timeout_seconds": TIMEOUT_SECONDS,
            "serial": True,
            "visible_timer": "real App.update followed by App.paint; update and paint are separate ns intervals",
            "churn_timer": "hide/refresh/rebuild and remount/refresh/rebuild intervals versus two corresponding App.paint calls per cycle",
            "setup_excluded": True,
            "diagnostic_only": True,
        },
        "source_hashes": {rel(path): sha256(path) for path in source_inputs()},
        "binaries": binaries,
        "correctness": {
            "log": str(correctness_log),
            "stdout": correctness_stdout,
        },
        "timing_execution": "deferred; run python3 experiments/composition-evaluation/scale/run.py --measure experiments/composition-evaluation/scale/prepared.json",
        "limits": [
            "The current HandlerHost rebuilds all declarations on handled updates.",
            "RetainedUI.claim and RetainedUI.index linearly scan retained controls; retired records remain in the list.",
            "UI.child renders each child and prefixes its paths; this probe does not claim universal asymptotic or native latency behavior.",
            "The machine is not isolated and timings are local diagnostics only.",
        ],
    }
    MANIFEST.write_text(json.dumps(manifest, indent=2) + "\n")
    print("PREPARED", MANIFEST)
    print("LOGS", logs)
    print("CORRECTNESS", correctness_log)
    print("TIMING BINARY", binaries["timing"]["path"])
    print("COMPILER", shlex.join(compiler))
    for name in ("correctness", "timing"):
        print("BUILD", name, shlex.join(binaries[name]["command"]))
    print("TIMING EXECUTION DEFERRED")


def verify_manifest(manifest: dict[str, object], manifest_path: Path) -> None:
    if manifest.get("status") != "prepared":
        raise RuntimeError(f"not a prepared manifest: {manifest_path}")
    for name, digest in manifest["source_hashes"].items():
        path = ROOT / name
        if not path.is_file():
            raise RuntimeError(f"prepared source is missing: {path}")
        actual = sha256(path)
        if actual != digest:
            raise RuntimeError(f"prepared source hash mismatch: {path}")
    for name, info in manifest["binaries"].items():
        path = Path(info["path"])
        if not path.is_file():
            raise RuntimeError(f"prepared binary is missing ({name}): {path}")
        if sha256(path) != info["sha256"]:
            raise RuntimeError(f"prepared binary hash mismatch ({name}): {path}")


def parse_samples(output: str) -> list[dict[str, int | str]]:
    rows: list[dict[str, int | str]] = []
    for line in output.splitlines():
        fields = line.split()
        if not fields or fields[0] != "TIMING":
            continue
        if len(fields) != 10:
            raise RuntimeError(f"unexpected timing row: {line}")
        rows.append(
            {
                "kind": fields[1],
                "case": int(fields[2]),
                "sample": int(fields[3]),
                "update_ns": int(fields[4]),
                "paint_ns": int(fields[5]),
                "active": int(fields[6]),
                "total": int(fields[7]),
                "next_id": int(fields[8]),
                "tree": int(fields[9]),
            }
        )
    return rows


def validate_samples(rows: list[dict[str, int | str]]) -> None:
    expected = len(VISIBLE_COUNTS) * SAMPLES + len(CHURN_CYCLES) * SAMPLES
    if len(rows) != expected:
        raise RuntimeError(f"expected {expected} timing rows, received {len(rows)}")
    seen: set[tuple[str, int, int]] = set()
    for row in rows:
        kind = str(row["kind"])
        case = int(row["case"])
        sample = int(row["sample"])
        key = (kind, case, sample)
        if key in seen or sample < 0 or sample >= SAMPLES:
            raise RuntimeError(f"duplicate or invalid timing sample: {row}")
        seen.add(key)
        if int(row["update_ns"]) < 0 or int(row["paint_ns"]) < 0:
            raise RuntimeError(f"negative timing sample: {row}")
        if kind == "visible" and case in VISIBLE_COUNTS:
            expected_active = case * 4
            expected_tree = case * 3
            expected_total = expected_active
            expected_next = expected_total + 1
        elif kind == "churn" and case in CHURN_CYCLES:
            expected_active = 32
            expected_total = 32 + case * 4
            expected_next = expected_total + 1
            expected_tree = 24
        else:
            raise RuntimeError(f"unexpected timing case: {row}")
        if (
            int(row["active"]) != expected_active
            or int(row["total"]) != expected_total
            or int(row["next_id"]) != expected_next
            or int(row["tree"]) != expected_tree
        ):
            raise RuntimeError(f"timing correctness counts mismatch: {row}")


def summarize(rows: list[dict[str, int | str]]) -> list[dict[str, object]]:
    summaries: list[dict[str, object]] = []
    cases = [("visible", case) for case in VISIBLE_COUNTS]
    cases += [("churn", case) for case in CHURN_CYCLES]
    for kind, case in cases:
        subset = [row for row in rows if row["kind"] == kind and row["case"] == case]
        summaries.append(
            {
                "kind": kind,
                "case": case,
                "samples": len(subset),
                "update_ns": {
                    "median": statistics.median(int(row["update_ns"]) for row in subset),
                    "min": min(int(row["update_ns"]) for row in subset),
                    "max": max(int(row["update_ns"]) for row in subset),
                },
                "paint_ns": {
                    "median": statistics.median(int(row["paint_ns"]) for row in subset),
                    "min": min(int(row["paint_ns"]) for row in subset),
                    "max": max(int(row["paint_ns"]) for row in subset),
                },
            }
        )
    return summaries


def measure(manifest_path: Path) -> None:
    manifest_path = manifest_path.resolve()
    manifest = json.loads(manifest_path.read_text())
    verify_manifest(manifest, manifest_path)
    logs = Path(tempfile.mkdtemp(prefix="moxi-handler-host-scale-measure-", dir="/tmp"))
    timing_binary = Path(manifest["binaries"]["timing"]["path"])
    stdout, timing_log = run_logged("timing", [str(timing_binary)], logs)
    rows = parse_samples(stdout)
    validate_samples(rows)
    result = {
        "status": "measured",
        "measured_at": timestamp(),
        "manifest": str(manifest_path),
        "logs": str(logs),
        "timing_log": str(timing_log),
        "timing_binary": str(timing_binary),
        "timing_binary_sha256": sha256(timing_binary),
        "protocol": manifest["protocol"],
        "raw_stdout": stdout,
        "samples": rows,
        "summaries": summarize(rows),
        "limits": manifest["limits"],
    }
    RESULTS.write_text(json.dumps(result, indent=2) + "\n")
    print("MEASURED", RESULTS)
    print("LOGS", logs)
    print("RAW SAMPLES", len(rows))


def main() -> None:
    if len(sys.argv) == 2 and sys.argv[1] == "--prepare":
        prepare()
        return
    if len(sys.argv) == 3 and sys.argv[1] == "--measure":
        measure(Path(sys.argv[2]))
        return
    raise SystemExit(
        "usage: run.py --prepare | run.py --measure PATH_TO_PREPARED_JSON"
    )


if __name__ == "__main__":
    main()
