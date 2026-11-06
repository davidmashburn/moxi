"""Validate generated replay artifacts without claiming visual acceptance."""
from pathlib import Path
import re
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1] / "dist" / "text-laboratory"
html = (root / "index.html").read_text()
for state in ("mixed", "wrap", "fallback", "selection", "edit"):
    assert f'id="{state}"' in html and f'href="#{state}"' in html, state
    image = ET.parse(root / f"{state}.svg").getroot()
    assert float(image.attrib["width"]) > 0 and float(image.attrib["height"]) > 0
    paths = image.findall(".//{http://www.w3.org/2000/svg}path")
    assert len(paths) > 10, state
    assert all(p.attrib.get("d") != "Z" for p in paths), state
    print(state, "width", image.attrib["width"], "height", image.attrib["height"], "paths", len(paths))
assert (root / "mixed.svg").read_bytes() == (root / "retained.svg").read_bytes()
if (root / "wrap.svg").read_bytes() == (root / "fallback.svg").read_bytes():
    print("Host fallback substitution produced identical outlines; choose distinct families for visual fallback acceptance")
else:
    print("Fallback order changed the rendered outlines")
selection = ET.parse(root / "selection.svg").getroot()
assert len(selection.findall(".//{http://www.w3.org/2000/svg}rect")) > 2
metrics = re.findall(r'Builds: (\d+) · Cache hits: (\d+)', html)
assert metrics == [("1", "0"), ("2", "0"), ("3", "0"), ("3", "1"), ("4", "1")], metrics
print("Text laboratory artifacts passed; browser screenshots and human acceptance remain separate")
