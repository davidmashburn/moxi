"""Preserve raw timings and summarize the declared reference-host workload budget."""
import datetime
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
if len(rows) != 480:
    raise SystemExit(f"Expected 480 frames, got {len(rows)}")
workloads = {}
for index, name in enumerate(("unchanged", "scroll", "resize", "summary")):
    samples = [row for row in rows if row["frame"] == index]
    times = sorted(row["total_ns"] / 1e6 for row in samples)
    workloads[name] = {
        "frames": len(samples), "median_ms": statistics.median(times),
        "p95_ms": times[int(len(times) * .95) - 1], "max_ms": max(times),
        "max_realized": max(row["realized"] for row in samples),
        "measurements": sum(row["measures"] for row in samples),
        "solver_builds": sum(row["solvers"] for row in samples),
        "new_mounts": sum(row["created"] for row in samples),
    }
result = {
    "recorded_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "host": platform.platform(),
    "cpu": subprocess.check_output(["sysctl", "-n", "machdep.cpu.brand_string"], text=True).strip(),
    "mojo": subprocess.check_output(["mojo", "--version"], text=True).strip(),
    "taffy": "0.14.0", "kiwi_commit": "5e76d91fd77dc443cb0db36e7398fc13844a0524",
    "budget": {"warm_frame_p95_ms": 16.67, "declared_before_optimization": True},
    "workload": {"rows": 100000, "columns": 4, "viewport_points": [1100,800], "bitmap_scale": 1},
    "includes": ["declaration sync", "measurement", "strategy stage/solve", "publication", "paint commands", "AX snapshot/submission", "AppKit/CoreText bitmap paint", "chart commands"],
    "excludes": ["compilation", "source initialization", "event loop", "compositor", "scanout", "active native IME", "VoiceOver"],
    "source_init_ns": source_init, "workloads": workloads, "samples": rows,
}
Path(sys.argv[2]).write_text(json.dumps(result, indent=2) + "\n")
for name, values in workloads.items():
    print(name, json.dumps(values, sort_keys=True))
if any(values["p95_ms"] > 16.67 for values in workloads.values()):
    raise SystemExit("Declared reference-host frame budget exceeded")
