"""Build a portable Moxi/Web Audio phrase editor."""
import argparse
from pathlib import Path

from moxi import Figure, PlotSpec


def line(x, y, color):
    spec = PlotSpec()
    spec.add_line(color=color)
    return Figure({"x": x, "y": y}, spec, width=470, height=210).to_svg().decode()


def build(target):
    source = Path(__file__).resolve().parent
    page = (source / "editor.html").read_text()
    # The three score knots are departure, apex, and landing.
    path = line([0, .35, 1], [0, 1, 0], (.07, .42, .42, 1))
    gain = line([0, .5, 1], [0, 1, 0], (.65, .29, .12, 1))
    instrument = (source / "instrument.js").read_text()
    # Inline the model as well: the portable page needs no server or module fetch.
    model_import, instrument = instrument.split("\n", 1)
    assert model_import.startswith("import ") and model_import.endswith('from "./gesture.mjs";')
    target.write_text(page.replace("<!--path-->", path).replace("<!--gain-->", gain)
                      .replace("/*instrument*/", (source / "gesture.mjs").read_text() + "\n" + instrument))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("target", type=Path)
    build(parser.parse_args().target)
