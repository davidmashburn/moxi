"""Compare prebuilt Mojo and Taffy executables on their shared geometry fixtures."""
import json
import math
import subprocess
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
mojo = Path(sys.argv[1]) if len(sys.argv) > 1 else root / "dist/moxi-layout-reference"
taffy = root / "experiments/layout-taffy/target/release/layout-taffy"
reference = json.loads(subprocess.check_output([str(taffy), "correctness-json"], text=True))
actual = {}
for line in subprocess.check_output([str(mojo)], text=True).splitlines():
    name, index, x, y, width, height = line.split()
    key = (name, int(index))
    if key in actual:
        raise SystemExit(f"Duplicate Mojo rectangle: {key}")
    actual[key] = tuple(map(float, (x, y, width, height)))
count = 0
for fixture in reference:
    for index, rectangle in enumerate(fixture["rects"]):
        key = (fixture["name"], index)
        if key not in actual:
            raise SystemExit(f"Missing Mojo rectangle: {key}")
        observed = actual.pop(key)
        expected = tuple(rectangle[key] for key in ("x", "y", "width", "height"))
        if not all(math.isfinite(a) and abs(a - b) <= 0.01 for a, b in zip(observed, expected)):
            raise SystemExit(f"{fixture['name']} node {index}: Mojo {observed}, Taffy {expected}")
        count += 1
if actual:
    raise SystemExit(f"Extra Mojo fixtures: {list(actual)}")
print(f"Layout reference check passed: {count} rectangles across {len(reference)} fixtures")
