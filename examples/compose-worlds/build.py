"""Build an offline consumer using the Moxi plotting API from this checkout."""
import json
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(ROOT / "python"))
from moxi import PlotSpec, plot


def curves():
    rules = {}
    for midpoint in range(0, 101, 10):
        values = [0, midpoint, 100]
        spec = PlotSpec("Grazing response")
        spec.add_line("Consumption", "cover", "feeding", (0.04, 0.40, 0.34, 1))
        svg = plot({"cover": [0, 50, 100], "feeding": values}, spec,
                   width=320, height=140).to_svg()
        rules[midpoint] = {"values": values, "svg": svg.decode()}
    return rules


if __name__ == "__main__":
    out = ROOT / "dist/compose-worlds/index.html"
    out.parent.mkdir(parents=True, exist_ok=True)
    page = (HERE / "template.html").read_text()
    script = (HERE / "world.mjs").read_text() + (HERE / "ui.js").read_text()
    out.write_text(page.replace("/*RULES*/", json.dumps(curves())).replace("/*APP*/", script))
    print(out)
