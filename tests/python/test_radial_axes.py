"""Radial layouts use their own geometry to convey position."""
import sys
from pathlib import Path
from xml.etree import ElementTree

import pytest

sys.path.insert(0, str(Path(__file__).parents[2]))
from scripts.wave_b import fixtures as wave_b
from scripts.wave_c import fixtures as wave_c
from moxi.wave_b import RADIAL
from moxi.specialized_c import WaveCMark


@pytest.mark.parametrize("case", wave_b.load_cases() + wave_c.CASES, ids=lambda case: case["id"])
def test_specialized_coordinate_axes(case):
    fig = (wave_b if "fixture" in case else wave_c).figure(case)
    radial = case["id"] in RADIAL or case["id"] in (WaveCMark.CHORD, WaveCMark.SUNBURST)
    svg = ElementTree.fromstring(fig.to_svg())
    axes = svg.findall(".//{*}line[@stroke='#667085']")
    assert len(axes) == (0 if radial else 2)
    # The PDF reference writer leaves its vector content stream uncompressed.
    assert fig.to_pdf().count(b"0.4 0.44 0.52 RG 1 w ") == (0 if radial else 2)
    if radial:
        left, top, *_ = fig._layout()
        offset = 4 * (int(top) * fig.width + int(left))
        assert fig.to_rgba()[offset:offset + 4] == bytes((255, 255, 255, 255))
