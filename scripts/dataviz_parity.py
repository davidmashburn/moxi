#!/usr/bin/env python3
"""Run the local overlap protocol against a pinned dataviz_mojo reference."""

from __future__ import annotations

import csv
import json
import os
import subprocess
import sys
from pathlib import Path
from tempfile import TemporaryDirectory
from typing import Any, Dict, List

REPO = "https://github.com/randyzwitch/dataviz_mojo.git"
TAG = "v0.8.0"
REVISION = "3fd5a7e7c622d6130c99a290b88c4fee039deab2"
OVERLAP = ("point/scatter", "line", "bar", "area", "box", "heatmap")


def reference_status() -> Dict[str, Any]:
    local = os.environ.get("DATAVIZ_MOJO_PATH")
    if local:
        path = Path(local)
        if not (path / ".git").exists():
            return {"status": "unavailable", "reason": "DATAVIZ_MOJO_PATH is not a git checkout", "path": str(path)}
        result = subprocess.run(["git", "-C", str(path), "rev-parse", "HEAD"], capture_output=True, text=True)
        commit = result.stdout.strip() if result.returncode == 0 else ""
        return {"status": "available" if commit == REVISION else "mismatch", "path": str(path), "commit": commit, "expected": REVISION}
    try:
        result = subprocess.run(["git", "ls-remote", REPO, f"refs/tags/{TAG}"], capture_output=True, text=True, timeout=15)
    except (OSError, subprocess.TimeoutExpired) as exc:
        return {"status": "unavailable", "reason": str(exc), "expected": REVISION}
    remote = result.stdout.split()[0] if result.returncode == 0 and result.stdout.split() else ""
    return {"status": "available" if remote == REVISION else "mismatch", "remote": remote, "expected": REVISION}


def run_local_overlap(repo_dir: Path) -> List[Dict[str, Any]]:
    sys.path.insert(0, str(repo_dir / "python"))
    import moxi
    from moxi.scenarios import overlap_scenarios

    results: List[Dict[str, Any]] = []
    for name, data, spec in overlap_scenarios():
        figure = moxi.plot(data, spec, width=160, height=120)
        results.append({
            "mark": name,
            "spec_version": spec.version,
            "valid": spec.validate(),
            "svg_bytes": len(figure.to_svg()),
            "png_bytes": len(figure.to_png()),
            "rgba_bytes": len(figure.to_rgba()),
        })
        if not spec.validate() or results[-1]["svg_bytes"] <= 0 or results[-1]["png_bytes"] <= 0:
            raise SystemExit(f"local overlap failed for {name}")
    return results


def check_inventory(repo_dir: Path) -> None:
    rows = list(csv.DictReader((repo_dir / "docs" / "dataviz-capabilities.tsv").open(), delimiter="\t"))
    by_mark = {row["upstream_mark"]: row for row in rows}
    for mark in OVERLAP:
        if mark not in by_mark:
            raise SystemExit(f"missing overlap inventory row: {mark}")
        row = by_mark[mark]
        if row["python_status"] != "implemented":
            raise SystemExit(f"Python overlap is not implemented: {mark}")
        if row["parity_fixture"] in {"", "pending"} or row["benchmark"] in {"", "pending"}:
            raise SystemExit(f"overlap evidence is incomplete: {mark}")


def main() -> int:
    repo_dir = Path(__file__).resolve().parents[1]
    check_inventory(repo_dir)
    manifest = {
        "reference": {"repository": REPO, "tag": TAG, "revision": REVISION, **reference_status()},
        "overlap": run_local_overlap(repo_dir),
        "normalization": {
            "structural": "SVG element/attribute topology and PlotSpec JSON fields",
            "raster": "RGBA byte length and stable checksum lane; native font pixels are not compared byte-for-byte",
        },
    }
    print(json.dumps(manifest, indent=2, sort_keys=True))
    if manifest["reference"]["status"] == "mismatch":
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
