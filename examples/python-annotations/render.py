"""Export focused annotation examples using the checked-in public fixtures."""
import argparse
import json
from pathlib import Path

from moxi import PlotSpec, plot
from moxi.specialized import CatalogMark
from moxi.specialized_c import WaveCMark
from moxi.wave_b import WaveBMark

ROOT = Path(__file__).resolve().parents[2]
FAMILIES = (WaveCMark.CALENDAR, WaveCMark.SANKEY, CatalogMark.PARALLEL,
            CatalogMark.BUMP, CatalogMark.ARC, WaveBMark.PIE, WaveBMark.DONUT,
            WaveBMark.POLAR_BAR, WaveBMark.NIGHTINGALE, WaveBMark.RADIALBAR,
            WaveBMark.RADAR, WaveBMark.GAUGE)


def figures(width=640, height=480, families=FAMILIES):
    wave_c = json.loads((ROOT / "tests/fixtures/wave_c/cases.json").read_text())
    for family in families:
        if family in CatalogMark._value2member_map_:
            mark = CatalogMark(family)
        elif family in WaveCMark._value2member_map_:
            mark = WaveCMark(family)
        else:
            mark = WaveBMark(family)
        name = mark.value
        spec = PlotSpec()
        if mark in (CatalogMark.PARALLEL, CatalogMark.BUMP):
            data = {"team": ["East", "West"], "A": [3, 8], "B": [9, 4], "C": [6, 7]}
            spec.specialize(spec.add_catalog_mark(name, "Teams", "team", "A"), series_fields=["B", "C"])
        elif mark is CatalogMark.ARC:
            data = {"source": ["A", "B", "C"], "target": ["C", "A", "B"], "weight": [3, 9, 6]}
            spec.specialize(spec.add_catalog_mark(name, "Edges", "source", "weight", x2_field="target"))
        else:
            case = (wave_c[name] if name in wave_c else
                    json.loads((ROOT / "tests/fixtures/wave_b" / (name + ".json")).read_text()))
            data = case["columns"]
            spec.specialize(spec.add_catalog_mark(name, name, case["x"], case["y"], **case.get("channels", {})),
                            **case.get("layout", {}))
        yield name, plot(data, spec, width=width, height=height)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    parser.add_argument("--family", choices=[mark.value for mark in FAMILIES])
    parser.add_argument("--width", type=int, default=640)
    parser.add_argument("--height", type=int, default=480)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    for name, figure in figures(args.width, args.height, (args.family,) if args.family else FAMILIES):
        for format in ("svg", "png", "pdf"):
            figure.save(args.output / (name + "." + format))
        print(name, f"{figure.width}×{figure.height}", len(figure.table()), "source rows")


if __name__ == "__main__":
    main()
