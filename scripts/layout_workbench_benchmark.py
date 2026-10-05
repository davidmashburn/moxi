"""Validate complete profiles and distinguish reference timings from VM baselines."""
import datetime
import hashlib
import json
import math
import os
import platform
import re
import statistics
import subprocess
import sys
from pathlib import Path

WORKLOAD_NAMES = ("unchanged", "scroll", "resize", "summary", "viewport-1500x1000", "viewport-2000x1400", "mixed-churn")
PROFILES = {0: ("full", 120, 10), 1: ("smoke", 8, 2)}
PHASES = ("declarations_ns", "allocation_ns", "constraints_ns", "collection_ns", "realization_ns", "arrangement_ns", "validation_ns", "publication_ns", "presentation_ns", "provider_ns", "layout_ns", "packet_ns", "resources_ns", "commands_ns", "accessibility_ns", "draw_ns")
COUNTERS = ("measures", "solvers", "created", "realized", "nodes", "engine_edits")


def command(*args):
    try:
        return subprocess.check_output(args, text=True, stderr=subprocess.DEVNULL).strip()
    except (FileNotFoundError, subprocess.CalledProcessError):
        return ""


def read_optional(path):
    try:
        return Path(path).read_text().strip()
    except OSError:
        return ""


def host_info():
    system = platform.system()
    if system == "Darwin":
        cpu = command("sysctl", "-n", "machdep.cpu.brand_string")
        model = command("sysctl", "-n", "hw.model")
        virtual = "virtual" in model.lower() or command("sysctl", "-n", "kern.hv_vmm_present") == "1"
        libraries = {"paint": "AppKit", "text": "CoreText"}
    elif system == "Linux":
        cpu = next((line.split(":", 1)[1].strip() for line in read_optional("/proc/cpuinfo").splitlines() if line.startswith("model name")), platform.processor())
        model = " ".join(filter(None, (read_optional("/sys/class/dmi/id/sys_vendor"), read_optional("/sys/class/dmi/id/product_name"))))
        virtual = bool(command("systemd-detect-virt", "--vm")) or any(word in model.lower() for word in ("qemu", "kvm", "virtual", "vmware"))
        libraries = {name: command("pkg-config", "--modversion", name) for name in ("gtk4", "pango", "cairo")}
    else:
        raise SystemExit(f"Unsupported benchmark host: {system}")
    environment = os.environ.get("MOXI_LAYOUT_BENCHMARK_ENVIRONMENT", "")
    if environment:
        virtual = virtual or any(word in environment.lower() for word in ("vm", "qemu", "tcg", "lima"))
    return {
        "system": system, "platform": platform.platform(), "architecture": platform.machine(),
        "cpu": cpu, "model": model, "virtual_machine": virtual,
        "environment": environment or ("virtual-machine" if virtual else "native-host"),
        "environment_source": "explicit environment" if environment else "host detection",
        "libraries": libraries,
    }


def main():
    if len(sys.argv) != 3:
        raise SystemExit("Usage: layout_workbench_benchmark.py RAW_TIMINGS OUTPUT_JSON")
    rows, metadata, source_init = [], None, None
    for line in Path(sys.argv[1]).read_text().splitlines():
        pairs = {key: int(value) for key, value in re.findall(r"(\w+)=\s*(\d+)", line)}
        if "frame" in pairs:
            rows.append(pairs)
        elif "benchmark_profile" in pairs:
            if metadata is not None:
                raise SystemExit("Duplicate benchmark profile header")
            metadata = pairs
        elif "source_init_ns" in pairs:
            if source_init is not None:
                raise SystemExit("Duplicate source initialization header")
            source_init = pairs["source_init_ns"]
    if metadata is None or source_init is None:
        raise SystemExit("Missing profile or source initialization header")
    if metadata["benchmark_profile"] not in PROFILES:
        raise SystemExit("Unknown benchmark profile")
    profile, sample_count, warmup = PROFILES[metadata["benchmark_profile"]]
    if metadata.get("samples_per_workload") != sample_count or metadata.get("warmup_frames_per_workload") != warmup:
        raise SystemExit("Sample/warmup counts do not match the declared profile")
    expected = sample_count * len(WORKLOAD_NAMES)
    if len(rows) != expected:
        raise SystemExit(f"Expected {expected} frames for {profile}, got {len(rows)}")
    required = set(PHASES + COUNTERS + ("frame", "sample", "total_ns", "submission_ns"))
    for row in rows:
        if required - row.keys():
            raise SystemExit(f"Incomplete timing row: missing {sorted(required - row.keys())}")
        if row["frame"] not in range(len(WORKLOAD_NAMES)):
            raise SystemExit(f"Unknown workload: {row['frame']}")
        if row["total_ns"] != row["layout_ns"] + row["submission_ns"] + row["draw_ns"]:
            raise SystemExit("Frame total does not match measured phases")
        if row["submission_ns"] != sum(row[phase] for phase in ("packet_ns", "resources_ns", "commands_ns", "accessibility_ns")):
            raise SystemExit("Submission total does not match measured phases")
    workloads = {}
    for index, name in enumerate(WORKLOAD_NAMES):
        samples = [row for row in rows if row["frame"] == index]
        if len(samples) != sample_count or {row["sample"] for row in samples} != set(range(sample_count)):
            raise SystemExit(f"Invalid or incomplete samples for {name}")
        times = sorted(row["total_ns"] / 1e6 for row in samples)
        workloads[name] = {
            "frames": len(samples), "median_ms": statistics.median(times),
            "p95_ms": times[math.ceil(len(times) * .95) - 1], "max_ms": max(times),
            "phases_median_ms": {phase.removesuffix("_ns"): statistics.median(row[phase] / 1e6 for row in samples) for phase in PHASES},
            "max_nodes": max(row["nodes"] for row in samples), "max_realized": max(row["realized"] for row in samples),
            "engine_edits": sum(row["engine_edits"] for row in samples), "measurements": sum(row["measures"] for row in samples),
            "solver_builds": sum(row["solvers"] for row in samples), "new_mounts": sum(row["created"] for row in samples),
        }
    host = host_info()
    backend = {2: "macos-appkit", 5: "linux-cairo"}.get(metadata.get("backend_kind"))
    if backend is None or (host["system"] == "Darwin") != (backend == "macos-appkit"):
        raise SystemExit("Benchmark backend does not match the host")
    reference_host = host["system"] == "Darwin" and host["cpu"] == "Apple M4" and not host["virtual_machine"]
    enforcement = os.environ.get("MOXI_LAYOUT_BENCHMARK_ENFORCE_BUDGET")
    if enforcement not in (None, "0", "1"):
        raise SystemExit("MOXI_LAYOUT_BENCHMARK_ENFORCE_BUDGET must be 0 or 1")
    enforced = reference_host and profile == "full" if enforcement is None else enforcement == "1"
    budget_workloads = list(WORKLOAD_NAMES[:4])
    exceeded = [name for name in budget_workloads if workloads[name]["p95_ms"] > 16.67]
    sources = ["benchmarks/layout_workbench.mojo", "src/moxi/retained_engine.mojo", "src/moxi/layout_workbench.mojo", "src/moxi/layout_workbench_replay.mojo", "src/moxi/frame.mojo", "src/moxi/native_frame.mojo", "src/moxi/native_window.mojo", "src/moxi/retained_leaf.mojo"]
    sources += ["benchmarks/layout_workbench_host.m", "native/macos_window.m", "native/macos_text.m"] if backend == "macos-appkit" else ["benchmarks/layout_workbench_host.c", "native/linux_window.c", "native/linux_text.c"]
    result = {
        "recorded_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "host": host, "backend": backend, "profile": profile,
        "classification": "native-mac-reference" if reference_host and profile == "full" else "exploratory-vm-baseline" if host["virtual_machine"] else "exploratory-smoke" if profile == "smoke" else "exploratory-native-baseline",
        "mojo": command("mojo", "--version"), "layout_engine": "mojo-retained",
        "source_sha256": {path: hashlib.sha256(Path(path).read_bytes()).hexdigest() for path in sources},
        "kiwi_commit": "5e76d91fd77dc443cb0db36e7398fc13844a0524",
        "budget": {"warm_frame_p95_ms": 16.67, "declared_before_optimization": True, "reference_host": "native Apple M4, full profile", "applies_to": budget_workloads, "enforced": enforced, "enforcement_source": "explicit environment" if enforcement is not None else "reference host/profile detection", "exceeded_workloads": exceeded},
        "workload": {"rows": 100000, "columns": 4, "viewport_points": [1100, 800], "growth_viewports": [[1500, 1000], [2000, 1400]], "churn_viewports": [[1100, 900], [540, 900]], "samples_per_workload": sample_count, "warmup_frames_per_workload": warmup, "bitmap_scale": 1},
        "includes": ["declaration sync", "measurement", "strategy stage/solve", "retained publication", "portable packet and semantic projection", "shared chart projection", "paragraph resource binding", "native command submission", "host AX submission" if backend == "macos-appkit" else "headless semantic host call (no live GTK proxy updates)", "host end_frame", "AppKit/CoreText bitmap paint" if backend == "macos-appkit" else "Cairo/Pango bitmap paint"],
        "excludes": ["compilation", "source initialization", "event loop", "compositor", "scanout", "active native IME", "screen-reader interaction", "native window coordinate conversion", "display-server accessibility delivery"] + (["live GTK accessibility proxy construction and AT-SPI updates"] if backend == "linux-cairo" else []),
        "phase_definitions": {"packet": "packet/semantic/chart construction and host size update", "resources": "pin measured paragraph payloads for this generation", "commands": "native render command and chart submission; excludes pixel draw", "accessibility": "host semantic submission; excludes semantic projection in packet phase" if backend == "macos-appkit" else "headless host call; GTK proxy publication is a no-op without an opened surface; portable semantic construction is measured in packet phase", "draw": "host end_frame and production painter into a bitmap"},
        "source_init_ns": source_init, "workloads": workloads, "samples": rows,
    }
    Path(sys.argv[2]).write_text(json.dumps(result, indent=2) + "\n")
    print(f"{profile}: {backend}; {result['classification']}; budget enforced={enforced}")
    for name, values in workloads.items():
        print(f"{name}: frames={values['frames']} median={values['median_ms']:.3f}ms p95={values['p95_ms']:.3f}ms max={values['max_ms']:.3f}ms realized={values['max_realized']}")
    if enforced and exceeded:
        raise SystemExit("Declared reference-host frame budget exceeded: " + ", ".join(exceeded))


if __name__ == "__main__":
    main()
