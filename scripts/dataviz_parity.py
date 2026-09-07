#!/usr/bin/env python3
"""Run the local overlap protocol against a pinned dataviz_mojo reference."""

from __future__ import annotations

import csv
import json
import os
import shlex
import subprocess
import sys
from pathlib import Path
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


def run_upstream_reference(reference: Dict[str, Any]) -> Dict[str, Any]:
    """Run a real upstream command only when an exact local checkout is supplied.

    The default command exercises the upstream test suite without modifying its
    checkout. Set DATAVIZ_REFERENCE_COMMAND to an explicit render/example
    command when generating the upstream gallery artifacts.
    """
    path = reference.get("path")
    if reference.get("status") != "available" or not path:
        return {
            "status": "not-run",
            "reason": "set DATAVIZ_MOJO_PATH to an exact pinned checkout",
        }
    command_text = os.environ.get("DATAVIZ_REFERENCE_COMMAND", "pixi run test")
    try:
        command = shlex.split(command_text)
    except ValueError as exc:
        return {"status": "failed", "command": command_text, "reason": str(exc)}
    if not command:
        return {"status": "not-run", "reason": "DATAVIZ_REFERENCE_COMMAND is empty"}
    try:
        result = subprocess.run(
            command,
            cwd=path,
            capture_output=True,
            text=True,
            timeout=int(os.environ.get("DATAVIZ_REFERENCE_TIMEOUT", "180")),
        )
    except (OSError, ValueError, subprocess.TimeoutExpired) as exc:
        return {"status": "failed", "command": command, "reason": str(exc)}
    return {
        "status": "passed" if result.returncode == 0 else "failed",
        "command": command,
        "returncode": result.returncode,
        "stdout_tail": result.stdout[-1000:],
        "stderr_tail": result.stderr[-1000:],
    }


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


def run_local_recipe_wave(repo_dir: Path) -> List[Dict[str, Any]]:
    sys.path.insert(0, str(repo_dir / "python"))
    import moxi
    from moxi.scenarios import recipe_scenarios

    results: List[Dict[str, Any]] = []
    for name, data, spec in recipe_scenarios():
        figure = moxi.plot(data, spec, width=160, height=120)
        svg = figure.to_svg()
        png = figure.to_png()
        results.append({
            "mark": name,
            "spec_version": spec.version,
            "valid": spec.validate(),
            "svg_bytes": len(svg),
            "png_bytes": len(png),
            "rgba_bytes": len(figure.to_rgba()),
        })
        if not spec.validate() or len(svg) <= 0 or len(png) <= 0:
            raise SystemExit(f"local recipe wave failed for {name}")
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
    reference = {"repository": REPO, "tag": TAG, "revision": REVISION, **reference_status()}
    manifest = {
        "reference": reference,
        "upstream_run": run_upstream_reference(reference),
        "overlap": run_local_overlap(repo_dir),
        "recipe_wave": run_local_recipe_wave(repo_dir),
        "normalization": {
            "structural": "SVG element/attribute topology and PlotSpec JSON fields",
            "raster": "RGBA byte length and stable checksum lane; native font pixels are not compared byte-for-byte",
        },
    }
    print(json.dumps(manifest, indent=2, sort_keys=True))
    if manifest["reference"]["status"] == "mismatch" or manifest["upstream_run"]["status"] == "failed":
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
