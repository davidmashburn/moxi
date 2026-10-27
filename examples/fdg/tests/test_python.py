"""Integration checks against a built viewer; requires a macOS desktop session."""

import json
from pathlib import Path
import shlex
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from moxi_fdg import fdg, render_svg, view_graph


def main():
    graph = json.loads((ROOT / "examples/triangle.json").read_text())
    svg = render_svg(graph)
    assert svg == render_svg(graph)
    root = ET.fromstring(svg)
    assert root.tag == "{http://www.w3.org/2000/svg}svg"
    assert len(root.findall(".//{http://www.w3.org/2000/svg}text")) == len(graph["nodes"])
    unicode_graph = {"nodes": [{"id": "A<&🔥", "group": 0}], "links": []}
    assert "A<&🔥" in "".join(ET.fromstring(render_svg(unicode_graph)).itertext())

    for bad in (
        {"nodes": [{"id": "A"}], "links": [{"source": "A", "target": "missing"}]},
        {"nodes": [{"id": "A"}, {"id": "A"}], "links": []},
    ):
        try:
            render_svg(bad)
        except subprocess.CalledProcessError as exc:
            assert exc.stderr
        else:
            raise AssertionError("Invalid graph accepted")
    for bad in ({"value": float("nan")}, {"padding": "x" * 262145}):
        try:
            view_graph(bad)
        except ValueError:
            pass
        else:
            raise AssertionError("Nonfinite or oversized input accepted")

    with tempfile.TemporaryDirectory(prefix="moxi-fdg-python-test-") as directory:
        try:
            render_svg(graph, executable=Path(directory) / "missing")
        except FileNotFoundError:
            pass
        else:
            raise AssertionError("Missing executable accepted")
        # Exercise the public launcher with the real native event loop, while
        # adding only the existing auto-close smoke flag through an executable.
        smoke = Path(directory) / "viewer smoke"
        smoke.write_text(
            "#!/bin/sh\nexec " + shlex.quote(str(ROOT / "dist" / "moxi-fdg"))
            + ' "$@" --smoke\n'
        )
        smoke.chmod(0o700)
        process = view_graph(graph, executable=smoke)
        try:
            assert process.wait(timeout=15) == 0
        finally:
            if process.poll() is None:
                process.kill()
                process.wait()
        process = fdg([("Python A", 0), ("Python B", 1)], [("Python A", "Python B", 1)],
                      executable=smoke, wait=True)
        assert process.returncode == 0
        try:
            view_graph({"nodes": [], "links": [{"source": "missing", "target": "missing"}]},
                       executable=smoke, wait=True)
        except subprocess.CalledProcessError:
            pass
        else:
            raise AssertionError("Blocking viewer suppressed an invalid graph error")
    print("PASS: Python SVG, Unicode, validation, async/blocking native launch and exit")


if __name__ == "__main__":
    main()
