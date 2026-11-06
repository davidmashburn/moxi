"""Independent PNG/PDF reopen assertions. Requires Pillow and pypdfium2.

Usage: python verify_artifacts.py DIRECTORY (current.svg/png/pdf from replay).
"""
import json
from pathlib import Path
import sys
import xml.etree.ElementTree as ET
from PIL import Image, ImageChops, ImageStat
import pypdfium2 as pdfium


def verify(directory):
    directory = Path(directory)
    svg = ET.parse(directory / "current.svg").getroot()
    ns = {"s": "http://www.w3.org/2000/svg"}
    width, height = int(svg.attrib["width"]), int(svg.attrib["height"])
    labels = [node.text for node in svg.findall(".//s:text", ns)]
    assert labels == ["A & <α>", "B β", "C γ"], labels
    assert "isolated" not in labels, "Neighborhood filter lost"
    lines = svg.findall(".//s:line", ns)
    assert len(lines) == 5, "Lost weighted edges or self-loop"
    assert len({line.attrib["stroke-width"] for line in lines}) >= 2, "Lost weight styling"
    assert (directory / "current.svg").read_bytes() == (directory / "recovered.svg").read_bytes(), "Recovery changed graph state"
    assert (directory / "current.png").read_bytes().startswith(b"\x89PNG\r\n\x1a\n")
    assert (directory / "current.pdf").read_bytes().startswith(b"%PDF-")
    png = Image.open(directory / "current.png").convert("RGB")
    pdf = pdfium.PdfDocument(directory / "current.pdf")
    assert len(pdf) == 1
    page = pdf[0]
    assert abs(page.get_width() - width * .75) < 1
    assert abs(page.get_height() - height * .75) < 1
    text_page = page.get_textpage()
    text = text_page.get_text_range()
    assert "α" in text and "β" in text and "γ" in text, text
    reopened = page.render(scale=96/72).to_pil().convert("RGB")
    assert png.size == reopened.size == (width, height), (png.size, reopened.size)
    reopened.save(directory / "reopened-pdf.png")
    # Independent PDFium raster vs librsvg PNG, allowing edge antialiasing.
    mae = sum(ImageStat.Stat(ImageChops.difference(png, reopened)).mean) / 3
    assert mae < 3, mae
    nodes = [node for node in svg.findall(".//s:rect", ns) if "rx" in node.attrib and node.attrib["fill"] != "rgba(255,255,255,1.0)"]
    radii = {float(node.attrib["rx"]) for node in nodes}
    assert len(radii) >= 2 and max(radii) > min(radii), "Selected node emphasis lost"
    checked = 0
    for node in nodes:
        a = node.attrib
        if a["fill"].startswith("rgba(255,255,255,"):
            continue
        x, y = float(a["x"]) + float(a["width"])/2, float(a["y"]) + float(a["height"])/2
        if 2 <= x < width-2 and 2 <= y < height-2:
            p, q = png.getpixel((int(x),int(y))), reopened.getpixel((int(x),int(y)))
            assert max(abs(a-b) for a,b in zip(p,q)) < 5, (x,y,p,q)
            assert max(p)-min(p) > 20, p
            checked += 1
    assert checked >= 2, checked
    # Real app content capture: the fixed replay window places the graph at
    # (16,178). Check each label box for dark text ink, catching native FFI font
    # failures that export-only assertions cannot detect. No font pixel parity.
    native = Image.open(directory / "phase-2.png").convert("RGB")
    scale = native.width / 1100
    assert native.size == (int(1100*scale), int(800*scale))
    text_ink = []
    for label in svg.findall(".//s:text", ns):
        x, y = float(label.attrib["x"])+16, float(label.attrib["y"])-20+178
        crop = native.crop(tuple(int(v*scale) for v in (x,y,x+90,y+20)))
        dark = sum(1 for r,g,b in crop.get_flattened_data() if r < 100 and g < 120 and b < 150)
        assert dark > 15*scale*scale, (label.text, dark, "Missing native graph text")
        text_ink.append(dark)
    for node in nodes:
        a = node.attrib
        x, y = float(a["x"])+float(a["width"])/2, float(a["y"])+float(a["height"])/2
        if 2 <= x < width-2 and 2 <= y < height-2:
            # AppKit color management changes RGB values. Compare the colored
            # core's location, not native/export channel equality.
            cx, cy = (x+16)*scale, (y+178)*scale
            colored = [(px+.5,py+.5)
                       for py in range(int(cy-7*scale),int(cy+7*scale))
                       for px in range(int(cx-7*scale),int(cx+7*scale))
                       if max(native.getpixel((px,py)))-min(native.getpixel((px,py))) > 50]
            assert len(colored) > 60*scale*scale, (x,y,"Missing native node core")
            for axis, center in [(0,cx),(1,cy)]:
                assert abs(sum(p[axis] for p in colored)/len(colored)-center) < 2*scale
    report = {"dimensions": [width,height], "labels": labels, "pdf_text": text,
              "node_centers_compared": checked, "png_pdf_mean_absolute_error": mae,
              "native_label_ink_pixels": text_ink, "native_node_centers_match": True,
              "pdf_rasterizer": "PDFium via pypdfium2", "native_pixel_parity": "not asserted"}
    (directory / "export-check.json").write_text(json.dumps(report, indent=2)+"\n")
    print(json.dumps(report))

if __name__ == "__main__":
    verify(sys.argv[1])
