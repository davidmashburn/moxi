"""Compare both Moxi exports to the checked-in v0.8.0 reference geometry."""
import argparse
import csv
import re
import xml.etree.ElementTree as ET
from pathlib import Path


def normalized(path, tag, attribute):
    root = ET.parse(path)
    bands = []
    for band in root.findall(f".//{{*}}{tag}"):
        numbers = list(map(float, re.findall(r"-?[0-9]+(?:\.[0-9]+)?", band.attrib[attribute])))
        assert len(numbers) == 8, path
        bands.append(list(zip(numbers[::2], numbers[1::2])))
    assert len(bands) == 3, path
    left, top = bands[0][0]
    width = bands[0][1][0] - left
    height = bands[-1][2][1] - top
    return [((x-left)/width, (y-top)/height) for band in bands for x, y in band]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    output = parser.parse_args().directory
    fixture = Path(__file__).resolve().parents[2] / "tests/fixtures/plot_catalog/funnel.svg"
    reference = normalized(fixture, "path", "d")
    for filename, tag, attr in [("native.svg", "path", "d"), ("funnel.svg", "polygon", "points")]:
        vertices = normalized(output / filename, tag, attr)
        delta = max(abs(a-b) for want, got in zip(reference, vertices) for a, b in zip(want, got))
        assert delta < .003, (filename, delta)
        print(f"{filename}: 12 vertices; maximum normalized coordinate difference {delta:.6f}")
    with (output / "source.csv").open() as source:
        assert [(r["key"], r["stage"]) for r in csv.DictReader(source)] == [
            ("10", "A"), ("11", "B"), ("12", "C")]
    assert (output / "funnel.pdf").read_bytes().count(b" h f") == 3
    assert (output / "funnel.png").read_bytes().startswith(b"\x89PNG\r\n\x1a\n")


if __name__ == "__main__":
    main()
