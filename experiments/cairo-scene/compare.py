# /// script
# requires-python = ">=3.11,<3.14"
# dependencies = ["cairocffi==1.7.1", "pillow==11.3.0", "pymupdf==1.26.4"]
# ///
"""Run from the output directory populated by the Mojo exporter."""

import json
import subprocess
from pathlib import Path

import cairocffi as cairo
import pymupdf
from PIL import Image, ImageChops, ImageDraw, ImageStat
from adapter import draw

HERE = Path(__file__).resolve().parent
CELLS = "feature-cells"


def rgb(path):
    im = Image.open(path).convert("RGBA")
    # Compare RGB channels only, including the raw RGB stored in software PPM.
    return im.convert("RGB")


def mae(a, b):
    assert a.size == b.size
    return round(sum(ImageStat.Stat(ImageChops.difference(a, b)).mean) / 3, 3)


def feature_checks(img, scale=1):
    def pixel(x, y):
        return img.getpixel((x * scale, y * scale))

    black, white = (0,) * 3, (255,) * 3
    return {
        "triangle": pixel(4, 16) == black and pixel(16, 4) == white,
        "clip": pixel(30, 8) == black and pixel(36, 8) == white,
        "translation": pixel(54, 8) == black and pixel(40, 8) == white,
        "text_ink": img.crop(
            (65 * scale, 2 * scale, 82 * scale, 20 * scale)
        ).getextrema()[0][0]
        < 100,
        "bitmap": pixel(87, 8) == (255, 0, 0) and pixel(97, 8) == (0, 0, 255),
    }


def main():
    pinned = {}
    for line in (
        (HERE.parents[1] / "tests/canvas_scene_checksums.tsv").read_text().splitlines()
    ):
        if line and not line.startswith("#"):
            name, w, h, *values = line.split()
            if "-" not in values:
                pinned[name] = list(map(int, [w, h, *values]))
    report = {}
    for line in Path("parity.txt").read_text().splitlines():
        name, *counts = line.split()
        header, *commands = Path(name + ".scene").read_text().splitlines()
        header = list(map(float, header.split()))
        w, h = map(int, header[:2])
        if name != CELLS:
            assert [w, h, *map(int, counts)] == pinned[name], name
        assert len(commands) == int(counts[0])
        raster = cairo.ImageSurface(cairo.FORMAT_ARGB32, w, h)
        missing = draw(raster, header, commands)
        assert missing == ([17] if name == CELLS else [])
        raster.write_to_png(name + "-cairo.png")
        pdf = cairo.PDFSurface(name + ".pdf", w, h)
        draw(pdf, header, commands)
        pdf.finish()
        subprocess.run(
            ["rsvg-convert", name + ".svg", "-o", name + "-svg.png"], check=True
        )
        probe = rgb(name + "-cairo.png")
        refs = [
            rgb(name + suffix)
            for suffix in ("-software.ppm", "-canvas.png", "-svg.png")
        ]
        report[name] = dict(
            commands=len(commands),
            missing=missing,
            rgb_mae=dict(
                zip(("software", "canvas", "svg"), [mae(probe, ref) for ref in refs])
            ),
            pdf_bytes=Path(name + ".pdf").stat().st_size,
        )
        if name in pinned:
            # Corpus smoke ceiling on a 0..255 scale. Font resolution may vary.
            assert report[name]["rgb_mae"]["software"] < 25, (name, report[name])
        if name == CELLS:
            cells = {
                key: feature_checks(img)
                for key, img in zip(
                    ("software", "canvas", "svg", "cairo"), [*refs, probe]
                )
            }
            report[name]["cells"] = cells
            assert all(cells["cairo"].values()), cells["cairo"]
            assert probe.getpixel((110, 8)) == (255,) * 3
            with pymupdf.open(name + ".pdf") as doc:
                page = doc[0]
                assert len(doc) == 1 and page.rect == pymupdf.Rect(0, 0, w, h)
                assert (
                    page.get_drawings() and "A" in page.get_text() and page.get_images()
                )
                zoom = page.get_pixmap(matrix=pymupdf.Matrix(4, 4))
                detail = Image.frombytes("RGB", (zoom.width, zoom.height), zoom.samples)
                assert all(feature_checks(detail, 4).values()), "PDF replay"
                assert detail.getpixel((440, 32)) == (255,) * 3
                # Native-resolution pixels enlarged 4x cannot reproduce this diagonal.
                enlarged = probe.resize(detail.size, Image.Resampling.NEAREST)
                assert (
                    mae(enlarged.crop((8, 8, 80, 80)), detail.crop((8, 8, 80, 80))) > 1
                )
                detail.save("pdf-4x.png")
            rows = list(
                zip(
                    ("Software", "Canvas", "SVG", "Cairo", "PDF 4x"),
                    [*refs, probe, detail],
                )
            )
            sheet = Image.new("RGB", (560, len(rows) * 104), "white")
            for i, (label, img) in enumerate(rows):
                ImageDraw.Draw(sheet).text((4, i * 104 + 40), label, fill="black")
                sheet.paste(
                    img.resize((w * 4, h * 4), Image.Resampling.NEAREST), (76, i * 104)
                )
            sheet.save("comparison.png")
    assert set(report) == set(pinned) | {CELLS}
    result = dict(
        cairo=cairo.cairo_version_string(),
        svg=subprocess.check_output(["rsvg-convert", "--version"], text=True).strip(),
        fixtures=report,
    )
    Path("observed.json").write_text(json.dumps(result, indent=2) + "\n")


if __name__ == "__main__":
    main()
