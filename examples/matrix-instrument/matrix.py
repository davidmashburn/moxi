"""Bounded 2D matrix and a projection through the actual Moxi PlotSpec renderer."""
from dataclasses import dataclass
from enum import Enum
from xml.etree import ElementTree as ET

import moxi

UNIT = 1000
LIMIT = 3 * UNIT
EXTENT = 6
SVG_NS = "http://www.w3.org/2000/svg"
ET.register_namespace("", SVG_NS)


class RankState(str, Enum):
    REGULAR = "regular"
    NEAR_SINGULAR = "near-singular"
    SINGULAR = "singular"


class Basis(str, Enum):
    U = "u"
    V = "v"


def decimal_text(value, places):
    """Format a scaled integer without a binary-float round trip."""
    sign = "−" if value < 0 else ""
    whole, fraction = divmod(abs(value), 10 ** places)
    tail = f"{fraction:0{places}d}".rstrip("0")
    return f"{sign}{whole}" + (f".{tail}" if tail else "")


@dataclass(frozen=True)
class Matrix:
    # Row-major a, b, c, d; columns u=(a,c), v=(b,d).
    ticks: tuple[int, ...]

    def __post_init__(self):
        if len(self.ticks) != 4 or any(type(x) is not int or abs(x) > LIMIT for x in self.ticks):
            raise ValueError("Use four integer thousandths between −3000 and 3000.")

    @property
    def determinant(self):
        a, b, c, d = self.ticks
        return a * d - b * c

    @property
    def rank_state(self):
        if self.determinant == 0:
            return RankState.SINGULAR
        if 100 * abs(self.determinant) <= max(abs(x) for x in self.ticks) ** 2:
            return RankState.NEAR_SINGULAR
        return RankState.REGULAR

    def render(self):
        a, b, c, d = [x / UNIT for x in self.ticks]
        spec = moxi.PlotSpec("Matrix basis and transformed unit square")
        columns, names, lengths = {}, [], []

        def line(name, points, color, width=1):
            x, y = f"x{len(names)}", f"y{len(names)}"
            # Moxi's reference renderer fits each layer independently. Common
            # anchors establish a fixed shared domain; trim them from the stroke.
            padded = points + [points[-1]] * (5 - len(points))
            columns[x] = [p[0] for p in padded] + [-EXTENT, EXTENT]
            columns[y] = [p[1] for p in padded] + [-EXTENT, EXTENT]
            spec.add_line(name, x, y, color)
            spec.layers[-1].line_width = width
            names.append(name)
            lengths.append(len(points))

        for n in range(-EXTENT, EXTENT + 1):
            color = (.62, .66, .65, 1) if n == 0 else (.88, .90, .88, 1)
            line(f"grid-x-{n}", [(n, -EXTENT), (n, EXTENT)], color, 1.5 if n == 0 else .7)
            line(f"grid-y-{n}", [(-EXTENT, n), (EXTENT, n)], color, 1.5 if n == 0 else .7)
        line("square", [(0, 0), (a, c), (a + b, c + d), (b, d), (0, 0)], (.35, .42, .39, 1), 1.6)
        line(Basis.U.value, [(0, 0), (a, c)], (.02, .43, .40, 1), 3)
        line(Basis.V.value, [(0, 0), (b, d)], (.76, .31, .16, 1), 3)

        # Default Moxi layout reserves 72px horizontally and 48px vertically;
        # these dimensions give a square data region and equal x/y unit scales.
        root = ET.fromstring(moxi.plot(columns, spec, width=560, height=536).to_svg())
        root.set("role", "img")
        root.set("aria-label", "Basis u and v; each grid spacing is one unit. Dashed outline is the transformed unit square.")
        curves = root.findall(".//{*}polyline")
        endpoints = {}
        for curve, name, length in zip(curves, names, lengths):
            points = curve.get("points").split()[:length]
            curve.set("points", " ".join(points))
            curve.set("data-layer", name)
            if name == "square":
                curve.set("stroke-dasharray", "5 4")
                curve.set("fill", "#dce9df")
                curve.set("fill-opacity", ".45")
            elif name in (basis.value for basis in Basis):
                curve.set("data-basis", name)
                curve.set("stroke-linecap", "round")
                endpoints[name] = points[-1].split(",")

        for name, (x, y) in endpoints.items():
            basis = Basis(name)
            color = "#056e66" if basis is Basis.U else "#c24f29"
            ET.SubElement(root, f"{{{SVG_NS}}}circle", {
                "cx": x, "cy": y, "r": "7" if basis is Basis.U else "4",
                "fill": "white", "stroke": color, "stroke-width": "2",
                "data-basis": name,
            })
            label = ET.SubElement(root, f"{{{SVG_NS}}}text", {
                "x": str(float(x) + (13 if basis is Basis.U else -25)),
                "y": str(float(y) - 12), "fill": color, "font-size": "18",
                "font-family": "system-ui", "font-weight": "700", "data-basis": name,
            })
            label.text = name
        return dict(matrix=list(self.ticks), svg=ET.tostring(root, encoding="unicode"),
                    determinant=decimal_text(self.determinant, 6),
                    area=decimal_text(abs(self.determinant), 6),
                    rank=self.rank_state.value)
