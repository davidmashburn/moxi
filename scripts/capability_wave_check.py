#!/usr/bin/env python3
"""Validate the explicit capability-wave inventory used for E7."""

from __future__ import annotations

import csv
from collections import Counter
from pathlib import Path

REQUIRED = {
    "upstream_revision", "upstream_mark", "upstream_module", "moxi_equivalent",
    "schema_status", "scene_status", "interaction_status", "accessibility_status",
    "python_status", "parity_fixture", "benchmark", "strategy",
}
CORE = {"point/scatter", "line", "bar", "area", "box", "heatmap"}


def main() -> int:
    path = Path(__file__).resolve().parents[1] / "docs" / "dataviz-capabilities.tsv"
    with path.open() as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        if set(reader.fieldnames or ()) != REQUIRED:
            raise SystemExit("capability inventory columns changed without a gate update")
        rows = list(reader)
    marks = [row["upstream_mark"] for row in rows]
    if len(marks) != len(set(marks)):
        raise SystemExit("capability inventory contains duplicate marks")
    rows_by_mark = {row["upstream_mark"]: row for row in rows}
    for mark in CORE:
        row = rows_by_mark.get(mark)
        if row is None or row["python_status"] != "implemented":
            raise SystemExit(f"core overlap row is not complete: {mark}")
    strategies = Counter(row["strategy"] for row in rows)
    print("Moxi capability waves:", len(rows), "marks", dict(sorted(strategies.items())))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
