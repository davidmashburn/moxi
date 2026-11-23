"""Render the five E06 reference layouts with dataviz_mojo v0.8.0."""

from dataviz.parallel import parallel
from dataviz.funnel import funnel
from dataviz.bump import bump
from dataviz.effect_scatter import effect_scatter
from dataviz.arc_diagram import arc_diagram
from dataviz.plot import save
from dataviz.theme import Theme


def main() raises:
    var stages: List[String] = ["A", "B", "C"]
    var teams: List[String] = ["East", "West"]
    var values: List[Float64] = [3.0, 9.0, 6.0]
    var other: List[Float64] = [8.0, 4.0, 7.0]
    var matrix: List[List[Float64]] = [values.copy(), other.copy()]
    var destinations: List[String] = ["C", "A", "B"]

    var theme = Theme(font_family="DejaVu Sans")
    save(parallel(matrix, stages, teams, theme=theme), "parallel.svg")
    save(funnel(stages, values, theme=theme), "funnel.svg")
    save(bump(stages, teams, matrix, theme=theme), "bump.svg")
    save(effect_scatter(values, other, theme=theme), "effect_scatter.svg")
    save(arc_diagram(stages, destinations, values, theme=theme), "arc_diagram.svg")
