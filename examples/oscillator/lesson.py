"""Fixed, undamped spring released from rest. All inputs use SI units."""
from dataclasses import dataclass
from math import cos, isfinite, pi, sin, sqrt

from xml.etree import ElementTree as ET

import moxi


@dataclass(frozen=True)
class Spring:
    mass: float
    stiffness: float
    amplitude: float

    def __post_init__(self):
        for name, value, lo, hi in (
            ("Mass (kg)", self.mass, .1, 10),
            ("Stiffness (N/m)", self.stiffness, 1, 100),
            ("Amplitude (m)", self.amplitude, 0, 1),
        ):
            if not isfinite(value) or not lo <= value <= hi:
                raise ValueError(f"{name} must be between {lo:g} and {hi:g}.")

    @property
    def omega(self):
        return sqrt(self.stiffness / self.mass)

    @property
    def period(self):
        return 2 * pi / self.omega

    def sample(self, time):
        phase = self.omega * time
        return self.amplitude * cos(phase), -self.amplitude * self.omega * sin(phase)


BASE = Spring(1, 16, .5)
TRANSFER = Spring(2, 32, .75)


def comparison(run, time):
    if not isfinite(time) or not 0 <= time <= 8:
        raise ValueError("Probe time must be between 0 and 8 seconds.")
    times = [i / 50 for i in range(401)]
    spec = moxi.PlotSpec("Displacement over eight seconds")
    columns = {"time": times}
    for label, spring, color in (
        ("Reference", BASE, (.58, .42, .16, 1)),
        ("Trial", run, (.05, .40, .46, 1)),
    ):
        columns[label] = [spring.sample(t)[0] for t in times]
        spec.add_line(label, "time", label, color)
    position, velocity = run.sample(time)
    columns["probeTime"] = [time] * len(times)
    columns["cursor"] = [-1] * (len(times) - 1) + [1]
    spec.add_line("Time probe", "probeTime", "cursor", (.75, .23, .17, 1))

    # The reference renderer fits each layer independently. Give each line
    # identical domain endpoints, then omit those two points from its stroke.
    for key, column in columns.items():
        column.extend((0, 8) if key in ("time", "probeTime") else (-1, 1))
    namespace = "http://www.w3.org/2000/svg"
    ET.register_namespace("", namespace)
    root = ET.fromstring(moxi.plot(columns, spec, width=680, height=190).to_svg())
    curves = root.findall(".//{*}polyline")
    for line in curves:
        points = line.get("points").split()[:-2]
        line.set("points", " ".join(points))
    # Keep the key inside the SVG so an inserted/offline plot is self-contained.
    root.set("height", "220")
    root.set("viewBox", "0 0 680 220")
    legend = ET.SubElement(root, f"{{{namespace}}}g", {"data-legend": "comparison",
                           "font-size": "13", "font-family": "system-ui", "fill": "#183638"})
    for x, label, curve in zip((54, 276, 476),
                               (f"Reference ({BASE.mass:g} kg)", f"Trial ({run.mass:g} kg)", "Time probe"), curves):
        ET.SubElement(legend, f"{{{namespace}}}line", dict(x1=str(x), x2=str(x + 24),
                      y1="201", y2="201", stroke=curve.get("stroke"), **{"stroke-width": "3"}))
        ET.SubElement(legend, f"{{{namespace}}}text", dict(x=str(x + 30), y="205")).text = label
    svg = ET.tostring(root, encoding="unicode")
    return dict(svg=svg, period=run.period, reference=BASE.period, position=position,
                referenceParameters=dict(m=BASE.mass, k=BASE.stiffness, a=BASE.amplitude),
                velocity=velocity, omega=run.omega)
