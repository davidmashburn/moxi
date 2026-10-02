#!/usr/bin/env python3
"""Compare Kiwi fixture geometry with prebuilt Moxi and Taffy references."""
import json
import math
import subprocess
import sys
from pathlib import Path

kiwi = json.loads(Path(sys.argv[1]).read_text())['rect_arrays']
mojo = {}
for line in subprocess.check_output([sys.argv[2]], text=True).splitlines():
    name, index, *coordinates = line.split()
    key = (name, int(index))
    if key in mojo or len(coordinates) != 4:
        raise SystemExit(f"Invalid Mojo rectangle {line}")
    mojo[key] = tuple(map(float, coordinates))
taffy = json.loads(subprocess.check_output([sys.argv[3], 'correctness-json'], text=True))
references = {}
for fixture in taffy:
    for index, rect in enumerate(fixture['rects']):
        key = (fixture['name'], index)
        if key in references:
            raise SystemExit(f"Duplicate Taffy rectangle {key}")
        references[key] = tuple(rect[field] for field in ('x', 'y', 'width', 'height'))
actual = {(name, i): tuple(rect[field] for field in ('x', 'y', 'width', 'height'))
          for name, rects in kiwi.items() for i, rect in enumerate(rects)}
if set(actual) != set(mojo) or set(actual) != set(references):
    raise SystemExit("Fixture identity mismatch")
for key, coords in actual.items():
    for engine, expected in (('Mojo', mojo[key]), ('Taffy', references[key])):
        if not all(math.isfinite(a) and math.isfinite(b) and abs(a-b) <= .01 for a, b in zip(coords, expected)):
            raise SystemExit(f"{key}: Kiwi {coords}, {engine} {expected}")
print(f"Kiwi/Moxi/Taffy geometry parity passed: {len(actual)} rectangles")
