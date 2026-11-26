"""Build the standalone folding-lamp workbench with Moxi's public plot API."""
import argparse
import json
import math
from pathlib import Path
import xml.etree.ElementTree as ET

from moxi import PlotSpec, plot

HERE = Path(__file__).resolve().parent
ANGLES = list(range(15, 76, 5))
ARMS = list(range(80, 141, 10))
ANCHORS = list(range(30, 81, 10))
TOLERANCE = 0.16  # newtons RMS across the complete angle trace


def force(arm, anchor, degrees):
    """Tangential tip force from an ideal tension spring at the arm midpoint."""
    theta = math.radians(degrees)
    radius = arm / 2
    length = math.hypot(radius * math.cos(theta), radius * math.sin(theta) + anchor)
    tension = 0.12 * max(0, length - 35)
    return tension * radius * anchor * math.cos(theta) / (length * arm)


def curve(arm, anchor):
    return [force(arm, anchor, angle) for angle in ANGLES]


def chart_points(values, spec):
    # Include two scale anchors in the Moxi projection to share the same axes
    # across designs and targets. Only the physical samples become the visible line.
    figure = plot({"angle": [15, *ANGLES, 75], "force": [0, *values, 5]},
                  spec, width=440, height=225)
    svg = ET.fromstring(figure.to_svg())
    points = svg.find(".//{*}polyline").attrib["points"].split()
    return " ".join(points[1:-1]), [points[0], points[-1]]


def build(destination):
    spec = PlotSpec("Tangential tip force")
    spec.add_layer("line", "Spring response", "angle", "force")
    designs = []
    for arm in ARMS:
        for anchor in ANCHORS:
            values = curve(arm, anchor)
            points, axes = chart_points(values, spec)
            designs.append(dict(arm=arm, anchor=anchor, values=values, points=points))
    targets = []
    for label, values in [("Light assist", curve(100, 40)), ("Firm assist", curve(120, 60)),
                          ("High load", [4.8] * len(ANGLES))]:
        targets.append(dict(label=label, values=values, points=chart_points(values, spec)[0]))
    fixture = dict(angles=ANGLES, designs=designs, targets=targets, axes=axes,
                   tolerance=TOLERANCE)
    destination.write_text((HERE / "workbench.html").read_text().replace(
        "/*MODEL*/null", json.dumps(fixture, separators=(",", ":"))))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    build(parser.parse_args().output)
