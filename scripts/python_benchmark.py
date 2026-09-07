#!/usr/bin/env python3
"""Small repeatable Python export benchmark for release evidence."""

from __future__ import annotations

import json
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "python"))
import moxi


def main() -> int:
    spec = moxi.PlotSpec("benchmark")
    spec.add_line("series")
    data = {"x": list(range(256)), "y": [(index % 31) / 31.0 for index in range(256)]}
    figure = moxi.plot(data, spec, width=640, height=480)
    start = time.perf_counter()
    png = figure.to_png()
    elapsed = time.perf_counter() - start
    print(json.dumps({"python_png_wall_seconds": round(elapsed, 6), "python_png_bytes": len(png), "python_rgba_bytes": len(figure.to_rgba())}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
