"""Preserve raw timings and summarize the declared reference-host workload budget."""
import datetime
import hashlib
import json
import platform
import re
import statistics
import subprocess
import sys
from pathlib import Path

rows = []
source_init = None
for line in Path(sys.argv[1]).read_text().splitlines():
    pairs = {key: int(value) for key, value in re.findall(r"(\w+)=\s*(\d+)", line)}
    if "frame" in pairs:
        rows.append(pairs)
    elif "source_init_ns" in pairs:
        source_init = pairs["source_init_ns"]
if len(rows) != 840:
    raise SystemExit(f"Expected 840 frames, got {len(rows)}")
workloads = {}
for index, name in enumerate(("unchanged", "scroll", "resize", "summary", "viewport-1500x1000", "viewport-2000x1400", "mixed-churn")):
    samples = [row for row in rows if row["frame"] == index]
    if len(samples) != 120 or {row["sample"] for row in samples} != set(range(120)):
        raise SystemExit(f"Invalid or incomplete samples for {name}")
    times = sorted(row["total_ns"] / 1e6 for row in samples)
    workloads[name] = {
        "frames": len(samples), "median_ms": statistics.median(times),
        "p95_ms": times[int(len(times) * .95) - 1], "max_ms": max(times),
        "phases_median_ms": {phase.removesuffix("_ns"): statistics.median(row[phase] / 1e6 for row in samples)
                             for phase in ("declarations_ns", "allocation_ns", "constraints_ns", "collection_ns", "realization_ns", "arrangement_ns", "validation_ns", "publication_ns", "presentation_ns", "provider_ns", "layout_ns", "commands_ns", "accessibility_ns", "draw_ns")},
        "max_nodes": max(row["nodes"] for row in samples),
        "max_realized": max(row["realized"] for row in samples),
        "engine_edits": sum(row["engine_edits"] for row in samples),
        "measurements": sum(row["measures"] for row in samples),
        "solver_builds": sum(row["solvers"] for row in samples),
        "new_mounts": sum(row["created"] for row in samples),
    }
result = {
    "recorded_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "host": platform.platform(),
    "cpu": subprocess.check_output(["sysctl", "-n", "machdep.cpu.brand_string"], text=True).strip(),
    "mojo": subprocess.check_output(["mojo", "--version"], text=True).strip(),
    "layout_engine": "mojo-retained",
    "layout_engine_source_sha256": hashlib.sha256(Path("src/moxi/retained_engine.mojo").read_bytes()).hexdigest(),
    "kiwi_commit": "5e76d91fd77dc443cb0db36e7398fc13844a0524",
    "budget": {"warm_frame_p95_ms": 16.67, "declared_before_optimization": True, "applies_to": ["unchanged", "scroll", "resize", "summary"]},
    "workload": {"rows": 100000, "columns": 4, "viewport_points": [1100,800], "growth_viewports": [[1500,1000],[2000,1400]], "churn_viewports": [[1100,900],[540,900]], "warmup_frames_per_workload": 10, "bitmap_scale": 1},
    "includes": ["declaration sync", "measurement", "strategy stage/solve", "publication", "paint commands", "AX snapshot/submission", "AppKit/CoreText bitmap paint", "chart commands"],
    "excludes": ["compilation", "source initialization", "event loop", "compositor", "scanout", "active native IME", "VoiceOver", "NSWindow coordinate conversion"],
    "source_init_ns": source_init, "workloads": workloads, "samples": rows,
}
Path(sys.argv[2]).write_text(json.dumps(result, indent=2) + "\n")
for name, values in workloads.items():
    print(name, json.dumps(values, sort_keys=True))
if any(values["p95_ms"] > 16.67 for name, values in workloads.items() if name in ("unchanged", "scroll", "resize", "summary")):
    raise SystemExit("Declared reference-host frame budget exceeded")
