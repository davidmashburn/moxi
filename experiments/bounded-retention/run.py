"""Prepare and later measure the isolated bounded-retention comparison.

``--prepare`` compiles baseline and candidate O3 probes and runs correctness
only.  ``--measure`` verifies that preparation inputs and binaries are unchanged
before running the serial timing binaries.  Build and run logs stay in /tmp.
"""
from datetime import datetime, timezone
from enum import Enum
import hashlib
import json
import os
from pathlib import Path
import platform
import shlex
import statistics
import shutil
import subprocess
import sys
import tempfile


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
SRC = ROOT / "src"
METHOD_BINDING = ROOT / "experiments/method-binding"
BASELINE_RUNTIME = METHOD_BINDING / "runtime.mojo"
CANDIDATE_RUNTIME = HERE / "runtime.mojo"
SHARED_BINDINGS = METHOD_BINDING / "bindings.mojo"
MANIFEST = HERE / "prepared.json"
RESULTS = HERE / "results.json"
TIMEOUT_SECONDS = 240
WARMUPS = 2
SAMPLES = 5
VISIBLE_COUNTS = (10, 100, 300, 1000)
CHURN_CYCLES = (0, 100, 1000)


class CommandMode(str, Enum):
    PREPARE = "--prepare"
    MEASURE = "--measure"


class ManifestStatus(str, Enum):
    PREPARED = "prepared"
    MEASURED = "measured"


class Variant(str, Enum):
    BASELINE = "baseline"
    CANDIDATE = "candidate"


class Probe(str, Enum):
    CORRECTNESS = "correctness"
    TIMING = "timing"


class TimingKind(str, Enum):
    VISIBLE = "visible"
    CHURN = "churn"


VARIANT_RUNTIMES = {
    Variant.BASELINE: BASELINE_RUNTIME,
    Variant.CANDIDATE: CANDIDATE_RUNTIME,
}
PROBES = (Probe.CORRECTNESS, Probe.TIMING)


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
        environment["MODULAR_HOME"] = str(ROOT / ".pixi/envs/default/share/max")
    return environment


def rel(path: Path) -> str:
    return str(path.relative_to(ROOT))


def timestamp() -> str:
    return datetime.now(timezone.utc).isoformat()


def source_inputs() -> list[Path]:
    return [
        HERE / "scale_model.mojo",
        HERE / "scale_correctness.mojo",
        HERE / "scale_timing.mojo",
        HERE / "run.py",
        BASELINE_RUNTIME,
        CANDIDATE_RUNTIME,
        SHARED_BINDINGS,
        ROOT / "pixi.toml",
        ROOT / "pixi.lock",
        *sorted(SRC.glob("**/*.mojo")),
    ]


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


def stage_variant(variant: Variant, runtime: Path, logs: Path) -> tuple[Path, dict[str, str]]:
    stage = logs / f"stage-{variant.value}"
    stage.mkdir()
    sources = (
        HERE / "scale_model.mojo",
        HERE / "scale_correctness.mojo",
        HERE / "scale_timing.mojo",
        runtime,
        SHARED_BINDINGS,
    )
    staged_hashes: dict[str, str] = {}
    for source in sources:
        destination = stage / source.name
        shutil.copy2(source, destination)
        staged_hashes[destination.name] = sha256(destination)
    return stage, staged_hashes


def build_command(
    compiler: list[str], source: Path, binary: Path, stage: Path
) -> list[str]:
    return [
        *compiler,
        "build",
        "-O3",
        "-I",
        str(SRC),
        "-I",
        str(stage),
        str(source),
        "-o",
        str(binary),
    ]


def parse_correctness(output: str) -> list[dict[str, int | str]]:
    rows: list[dict[str, int | str]] = []
    for line in output.splitlines():
        fields = line.split()
        if not fields or fields[0] != "PASS" or fields[1] not in {
            TimingKind.VISIBLE.value,
            TimingKind.CHURN.value,
        }:
            continue
        if len(fields) != 11:
            raise RuntimeError(f"unexpected correctness row: {line}")
        rows.append(
            {
                "kind": fields[1],
                "case": int(fields[2]),
                "total": int(fields[4]),
                "active": int(fields[6]),
                "tree": int(fields[8]),
                "next_id": int(fields[10]),
            }
        )
    return rows


def validate_correctness(
    output: str, variant: Variant
) -> list[dict[str, int | str]]:
    rows = parse_correctness(output)
    expected_count = len(VISIBLE_COUNTS) + len(CHURN_CYCLES)
    if len(rows) != expected_count:
        raise RuntimeError(
            f"{variant.value} correctness expected {expected_count} rows, received {len(rows)}"
        )
    seen: set[tuple[str, int]] = set()
    for row in rows:
        kind = TimingKind(str(row["kind"]))
        case = int(row["case"])
        key = (kind.value, case)
        if key in seen:
            raise RuntimeError(f"duplicate correctness row: {row}")
        seen.add(key)
        if kind is TimingKind.VISIBLE and case in VISIBLE_COUNTS:
            expected_active = case * 4
            expected_total = expected_active
            expected_next = expected_total + 1
            expected_tree = case * 3
        elif kind is TimingKind.CHURN and case in CHURN_CYCLES:
            expected_active = 32
            expected_total = (
                32
                if variant is Variant.CANDIDATE
                else 32 + case * 4
            )
            expected_next = 33 + case * 4
            expected_tree = 24
        else:
            raise RuntimeError(f"unexpected correctness row: {row}")
        if (
            int(row["active"]) != expected_active
            or int(row["total"]) != expected_total
            or int(row["next_id"]) != expected_next
            or int(row["tree"]) != expected_tree
        ):
            raise RuntimeError(
                f"{variant.value} correctness counts mismatch: {row}; "
                f"expected total={expected_total}, active={expected_active}, "
                f"next_id={expected_next}, tree={expected_tree}"
            )
    return rows


def prepare() -> None:
    logs = Path(tempfile.mkdtemp(prefix="moxi-bounded-retention-", dir="/tmp"))
    compiler = compiler_command()
    compiler_version, compiler_version_log = run_logged(
        "compiler-version", [*compiler, "--version"], logs, timeout=30
    )

    variants: dict[str, dict[str, object]] = {}
    for variant, runtime in VARIANT_RUNTIMES.items():
        stage, staged_hashes = stage_variant(variant, runtime, logs)
        binaries: dict[str, dict[str, object]] = {}
        for probe in PROBES:
            source = stage / f"scale_{probe.value}.mojo"
            binary = logs / f"{variant.value}-{probe.value}"
            command = build_command(compiler, source, binary, stage)
            _, build_log = run_logged(
                f"build-{variant.value}-{probe.value}", command, logs
            )
            binaries[probe.value] = {
                "path": str(binary),
                "sha256": sha256(binary),
                "source": str(source),
                "source_original": rel(HERE / f"scale_{probe.value}.mojo"),
                "command": command,
                "log": str(build_log),
            }

        correctness_stdout, correctness_log = run_logged(
            f"correctness-{variant.value}",
            [str(binaries[Probe.CORRECTNESS.value]["path"])],
            logs,
        )
        correctness_rows = validate_correctness(correctness_stdout, variant)
        variants[variant.value] = {
            "runtime_source": rel(runtime),
            "runtime_sha256": sha256(runtime),
            "stage": str(stage),
            "staged_source_hashes": staged_hashes,
            "binaries": binaries,
            "correctness": {
                "log": str(correctness_log),
                "stdout": correctness_stdout,
                "rows": correctness_rows,
            },
        }

    manifest = {
        "status": ManifestStatus.PREPARED.value,
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
            "variants": [variant.value for variant in VARIANT_RUNTIMES],
            "timeout_seconds": TIMEOUT_SECONDS,
            "serial": True,
            "visible_timer": "App.update followed by App.paint; update and paint are separate ns intervals",
            "churn_timer": "hide/refresh/rebuild and remount/refresh/rebuild intervals versus two corresponding App.paint calls per cycle",
            "setup_excluded": True,
            "diagnostic_only": True,
        },
        "source_hashes": {rel(path): sha256(path) for path in source_inputs()},
        "variants": variants,
        "timing_execution": "deferred; run python3 experiments/bounded-retention/run.py --measure experiments/bounded-retention/prepared.json",
        "limits": [
            "The current HandlerHost rebuilds all declarations on handled updates.",
            "This experiment changes only the copied runtime; App and production remain unchanged.",
            "Route guards remain necessary for retained callback descriptor safety; the runtime does not infer application lifetime.",
            "The scale model uses Int child keys and the existing shared bindings; it is not a claim about arbitrary key or native lifetime policies.",
            "The machine is not isolated and timings are local diagnostics only.",
        ],
    }
    MANIFEST.write_text(json.dumps(manifest, indent=2) + "\n")
    print("PREPARED", MANIFEST)
    print("LOGS", logs)
    for variant in VARIANT_RUNTIMES:
        print(
            "CORRECTNESS",
            variant.value,
            variants[variant.value]["correctness"]["log"],
        )
        print(
            "TIMING BINARY",
            variant.value,
            variants[variant.value]["binaries"][Probe.TIMING.value]["path"],
        )
    print("COMPILER", shlex.join(compiler))
    print("TIMING EXECUTION DEFERRED")


def verify_manifest(manifest: dict[str, object], manifest_path: Path) -> None:
    if manifest.get("status") != ManifestStatus.PREPARED.value:
        raise RuntimeError(f"not a prepared manifest: {manifest_path}")
    for name, digest in manifest["source_hashes"].items():
        path = ROOT / name
        if not path.is_file():
            raise RuntimeError(f"prepared source is missing: {path}")
        actual = sha256(path)
        if actual != digest:
            raise RuntimeError(f"prepared source hash mismatch: {path}")
    manifest_variants = manifest["variants"]
    for variant in VARIANT_RUNTIMES:
        info = manifest_variants[variant.value]
        for probe in PROBES:
            binary_info = info["binaries"][probe.value]
            path = Path(binary_info["path"])
            if not path.is_file():
                raise RuntimeError(
                    f"prepared binary is missing ({variant.value}/{probe.value}): {path}"
                )
            if sha256(path) != binary_info["sha256"]:
                raise RuntimeError(
                    f"prepared binary hash mismatch ({variant.value}/{probe.value}): {path}"
                )


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


def validate_samples(
    rows: list[dict[str, int | str]], variant: Variant
) -> None:
    expected = (len(VISIBLE_COUNTS) + len(CHURN_CYCLES)) * SAMPLES
    if len(rows) != expected:
        raise RuntimeError(
            f"{variant.value} expected {expected} timing rows, received {len(rows)}"
        )
    seen: set[tuple[str, int, int]] = set()
    for row in rows:
        kind = TimingKind(str(row["kind"]))
        case = int(row["case"])
        sample = int(row["sample"])
        key = (kind.value, case, sample)
        if key in seen or sample < 0 or sample >= SAMPLES:
            raise RuntimeError(f"duplicate or invalid timing sample: {row}")
        seen.add(key)
        if int(row["update_ns"]) < 0 or int(row["paint_ns"]) < 0:
            raise RuntimeError(f"negative timing sample: {row}")
        if kind is TimingKind.VISIBLE and case in VISIBLE_COUNTS:
            expected_active = case * 4
            expected_total = expected_active
            expected_next = expected_total + 1
            expected_tree = case * 3
        elif kind is TimingKind.CHURN and case in CHURN_CYCLES:
            expected_active = 32
            expected_total = (
                32
                if variant is Variant.CANDIDATE
                else 32 + case * 4
            )
            expected_next = 33 + case * 4
            expected_tree = 24
        else:
            raise RuntimeError(f"unexpected timing case: {row}")
        if (
            int(row["active"]) != expected_active
            or int(row["total"]) != expected_total
            or int(row["next_id"]) != expected_next
            or int(row["tree"]) != expected_tree
        ):
            raise RuntimeError(f"{variant.value} timing correctness counts mismatch: {row}")


def summarize(rows: list[dict[str, int | str]]) -> list[dict[str, object]]:
    summaries: list[dict[str, object]] = []
    cases = [(TimingKind.VISIBLE.value, case) for case in VISIBLE_COUNTS]
    cases += [(TimingKind.CHURN.value, case) for case in CHURN_CYCLES]
    for kind, case in cases:
        subset = [
            row
            for row in rows
            if row["kind"] == kind and int(row["case"]) == case
        ]
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
    logs = Path(tempfile.mkdtemp(prefix="moxi-bounded-retention-measure-", dir="/tmp"))
    variants: dict[str, dict[str, object]] = {}
    for variant in VARIANT_RUNTIMES:
        timing_binary = Path(
            manifest["variants"][variant.value]["binaries"][Probe.TIMING.value]["path"]
        )
        stdout, timing_log = run_logged(
            f"timing-{variant.value}", [str(timing_binary)], logs
        )
        rows = parse_samples(stdout)
        validate_samples(rows, variant)
        variants[variant.value] = {
            "timing_log": str(timing_log),
            "timing_binary": str(timing_binary),
            "timing_binary_sha256": sha256(timing_binary),
            "raw_stdout": stdout,
            "samples": rows,
            "summaries": summarize(rows),
        }
    result = {
        "status": ManifestStatus.MEASURED.value,
        "measured_at": timestamp(),
        "manifest": str(manifest_path),
        "logs": str(logs),
        "protocol": manifest["protocol"],
        "variants": variants,
        "limits": manifest["limits"],
    }
    RESULTS.write_text(json.dumps(result, indent=2) + "\n")
    print("MEASURED", RESULTS)
    print("LOGS", logs)
    print("RAW SAMPLES", sum(len(info["samples"]) for info in variants.values()))


def main() -> None:
    if len(sys.argv) == 2 and sys.argv[1] == CommandMode.PREPARE.value:
        prepare()
        return
    if len(sys.argv) == 3 and sys.argv[1] == CommandMode.MEASURE.value:
        measure(Path(sys.argv[2]))
        return
    raise SystemExit(
        "usage: run.py --prepare | run.py --measure PATH_TO_PREPARED_JSON"
    )


if __name__ == "__main__":
    main()
