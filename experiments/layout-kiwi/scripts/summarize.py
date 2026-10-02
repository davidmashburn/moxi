#!/usr/bin/env python3
"""Validate and summarize the seven paired Mojo/C-ABI runs; retain raw samples."""
import json
import math
import platform
import statistics
import sys
from pathlib import Path

path = Path(sys.argv[1])
rows, creation = [], []
seen = set()
for line in path.read_text().splitlines():
    fields = line.split()
    if not fields:
        continue
    if fields[0] == "creation":
        _, engine, sample, ns = fields
        creation.append(dict(engine=engine, sample=int(sample), ns=int(ns)))
        continue
    engine, sample, phase, mutation, layout, publication, total, checksum = fields
    key = (engine, int(sample), phase)
    if key in seen:
        raise SystemExit(f"Duplicate sample {key}")
    seen.add(key)
    row = dict(engine=engine, sample=int(sample), phase=phase,
               mutation_ns=int(mutation), layout_ns=int(layout),
               publication_ns=int(publication), total_ns=int(total),
               checksum=float(checksum))
    if not math.isfinite(row["checksum"]) or any(row[k] < 0 for k in ("mutation_ns", "layout_ns", "publication_ns", "total_ns")):
        raise SystemExit(f"Invalid sample {row}")
    rows.append(row)
phases = ("cold", "resize", "insert", "overflow", "unchanged")
expected = {(engine, sample, phase) for engine in ("mojo", "kiwi") for sample in range(7) for phase in phases}
if seen != expected:
    raise SystemExit(f"Missing/unexpected samples: {seen ^ expected}")
if len(creation) != 14 or {(r['engine'], r['sample']) for r in creation} != {(e, s) for e in ('mojo', 'kiwi') for s in range(7)}:
    raise SystemExit("Invalid construction samples")
for sample in range(7):
    for phase in phases:
        pair = [r for r in rows if r['sample'] == sample and r['phase'] == phase]
        if abs(pair[0]['checksum'] - pair[1]['checksum']) > .01:
            raise SystemExit(f"Geometry checksum mismatch {pair}")
summary = []
for engine in ("mojo", "kiwi"):
    for phase in phases:
        group = [r for r in rows if r['engine'] == engine and r['phase'] == phase]
        item = dict(engine=engine, phase=phase)
        for field in ("mutation_ns", "layout_ns", "publication_ns", "total_ns"):
            values = sorted(r[field] for r in group)
            item[field] = dict(median=statistics.median(values), p95=values[-1])
        summary.append(item)
construction_summary = []
for engine in ("mojo", "kiwi"):
    costs = [r['ns'] for r in creation if r['engine'] == engine]
    cold_totals = [r['ns'] + next(v['total_ns'] for v in rows if v['engine'] == engine and v['sample'] == r['sample'] and v['phase'] == 'cold') for r in creation if r['engine'] == engine]
    construction_summary.append(dict(engine=engine,
        creation_ns=dict(median=statistics.median(costs), p95=max(costs)),
        creation_plus_cold_ns=dict(median=statistics.median(cold_totals), p95=max(cold_totals))))
print(json.dumps(dict(platform=platform.platform(), machine=platform.machine(),
    protocol="Seven in-process paired samples, alternating engine order; tiny CSV fixture, no rendering. P95 is nearest-rank maximum of seven. Kiwi optimization is charged to mutation/construction; layout is updateVariables. All geometry is asserted in Mojo before reporting.",
    construction=creation, construction_summary=construction_summary, samples=rows, summary=summary), indent=2))
