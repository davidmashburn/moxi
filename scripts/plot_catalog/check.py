"""Check the E06 evidence from the repository root with PYTHONPATH=python."""

from pathlib import Path
import xml.etree.ElementTree as ET

import moxi
from moxi.scenarios import catalog_scenarios


# Count only the primitive that distinguishes each pinned fixture.
REFERENCES = {
    "parallel": ("path", 2),
    "funnel": ("path", 3),
    "bump": ("path", 2),
    "effect_scatter": ("circle", 6),
    "arc_diagram": ("path", 3),
}


def main():
    verified = set()
    fixtures = Path(__file__).resolve().parents[2] / "tests/fixtures/plot_catalog"
    for mark, data, spec in catalog_scenarios():
        if mark not in REFERENCES:
            continue
        tag, count = REFERENCES[mark]
        reference = ET.parse(fixtures / f"{mark}.svg")
        assert len(reference.findall(f".//{{*}}{tag}")) == count, mark

        figure = moxi.plot(data, spec)
        layer = spec.layers[0]
        rows = figure.table()
        points = figure._screen_geometry(layer).points
        assert len(rows) == len(points) == len(data["x"]), mark
        for index, point in enumerate(points):
            hit = figure.hit_test(*point, tolerance=0)
            assert hit and hit["row_index"] == index, (mark, index, hit)
            assert all(rows[index][key] == values[index] for key, values in data.items())
        ET.fromstring(figure.to_svg())
        assert figure.to_png().startswith(b"\x89PNG\r\n\x1a\n")
        print(mark, figure._raw_geometry(layer).kind, len(rows), "source rows")
        verified.add(mark)
    assert verified == REFERENCES.keys()


if __name__ == "__main__":
    main()
