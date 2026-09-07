#!/usr/bin/env python3
"""Small repeatable Python export benchmark for release evidence."""

from __future__ import annotations

import json
import math
import platform
import statistics
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "python"))
import moxi
from moxi.scenarios import recipe_scenarios


def _summary(times):
    ordered = sorted(times)
    p95_index = min(
        len(ordered) - 1,
        max(0, int(math.ceil(len(ordered) * 0.95)) - 1),
    )
    return {
        "runs": len(times),
        "seconds": [round(value, 6) for value in times],
        "median_seconds": round(statistics.median(times), 6),
        "p95_seconds": round(ordered[p95_index], 6),
    }


def main() -> int:
    spec = moxi.PlotSpec("benchmark")
    spec.add_line("series")
    data = {"x": list(range(256)), "y": [(index % 31) / 31.0 for index in range(256)]}
    figure = moxi.plot(data, spec, width=640, height=480)
    line_times = []
    png = b""
    for _ in range(3):
        start = time.perf_counter()
        png = figure.to_png()
        line_times.append(time.perf_counter() - start)
    recipe_results = {}
    for name, recipe_data, recipe_spec in recipe_scenarios():
        recipe_figure = moxi.plot(recipe_data, recipe_spec, width=640, height=480)
        times = []
        recipe_png = b""
        for _ in range(3):
            start = time.perf_counter()
            recipe_png = recipe_figure.to_png()
            times.append(time.perf_counter() - start)
        recipe_results[name] = {
            **_summary(times),
            "png_bytes": len(recipe_png),
            "rgba_bytes": len(recipe_figure.to_rgba()),
        }
    print(json.dumps({
        "python_version": platform.python_version(),
        "platform": platform.platform(),
        "python_png_wall_seconds": _summary(line_times)["median_seconds"],
        "python_png_bytes": len(png),
        "python_rgba_bytes": len(figure.to_rgba()),
        "line": _summary(line_times),
        "recipe_wave": recipe_results,
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
