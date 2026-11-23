"""An effect is paint on a source point, including in vector exports."""
from xml.etree import ElementTree

import moxi
import pytest


def test_effect_scatter_marker_and_halo():
    spec = moxi.PlotSpec()
    spec.add_catalog_mark("effect_scatter", color=(0.1, 0.4, 0.7, 0.5))
    figure = moxi.plot({"x": [3, 9, 6], "y": [8, 4, 7]}, spec)
    circles = ElementTree.fromstring(figure.to_svg()).findall(".//{*}circle")
    assert len(circles) == 6
    for index, (halo, dot) in enumerate(zip(circles[::2], circles[1::2])):
        assert halo.get("cx") == dot.get("cx") and halo.get("cy") == dot.get("cy")
        assert float(halo.get("r")) == pytest.approx(2.2 * float(dot.get("r")))
        assert halo.get("fill") != dot.get("fill")
        assert figure.hit_test(float(dot.get("cx")), float(dot.get("cy")))["row_index"] == index
    assert len(figure.table()) == 3
    pdf = figure.to_pdf()
    assert pdf.count(b"1 J ") == 6
    assert b"/CA 0.5" in pdf
