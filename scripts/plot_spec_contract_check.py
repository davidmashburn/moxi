#!/usr/bin/env python3
"""Compare Mojo and Python producers at the PlotSpec JSON boundary."""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

repo_dir = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(repo_dir / "python"))
from moxi import PlotSpec


def python_fixture() -> dict:
    spec = PlotSpec("Core overlap")
    spec.add_line("line")
    spec.add_scatter("points")
    spec.add_bar("bars")
    spec.add_area("area")
    spec.add_box("box", "y", "group")
    spec.add_heatmap("heatmap", "x", "y", 4, 4)
    return json.loads(spec.to_json())


def main() -> int:
    result = subprocess.run(
        ["pixi", "run", "mojo", "run", "-I", "src", "tests/plot_spec_contract_fixture.mojo"],
        cwd=repo_dir,
        capture_output=True,
        text=True,
        check=True,
    )
    mojo_json = next((line for line in result.stdout.splitlines() if line.startswith('{"version"')), "")
    if not mojo_json:
        raise SystemExit("Mojo fixture did not emit PlotSpec JSON")
    if json.loads(mojo_json) != python_fixture():
        raise SystemExit("Mojo and Python PlotSpec JSON contracts differ")
    print("Moxi Mojo/Python PlotSpec contract passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
