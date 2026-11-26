#!/usr/bin/env python3
"""Validate captures and make offline demo slideshows, preserving existing decks.

New decks embed images by default. Use --relative-images to link the original
image files instead; retain those files beside the HTML when copying a deck.
"""

import argparse
import base64
from enum import Enum
import hashlib
import html
import json
from pathlib import Path
import re
import struct
from urllib.parse import quote
import zlib


class CaptureKind(str, Enum):
    NATIVE = "native-window"
    BROWSER = "browser"
    OFFSCREEN = "offscreen-render"
    TERMINAL = "terminal"


class Phase(str, Enum):
    INITIAL = "initial"
    INTERACTION = "interaction"
    RESULT = "result"
    RECOVERY = "recovery"


PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
# PNG color type -> sample count and legal sample/index bit depths.
PNG_ENCODINGS = {
    0: (1, (1, 2, 4, 8, 16)),
    2: (3, (8, 16)),
    3: (1, (1, 2, 4, 8)),
    4: (2, (8, 16)),
    6: (4, (8, 16)),
}
# Each Adam7 pass gives its first x/y coordinate and column/row step.
PNG_ADAM7_PASSES = (
    (0, 0, 8, 8), (4, 0, 8, 8), (0, 4, 4, 8), (2, 0, 4, 4),
    (0, 2, 2, 4), (1, 0, 2, 2), (0, 1, 1, 2),
)
STYLE = """
body{font:16px system-ui,sans-serif;background:#101822;color:#eef3fb;margin:0 auto;
max-width:1100px;padding:24px}a{color:#9bd5ff}button{font:inherit;padding:8px 14px;
border:1px solid #65758b;border-radius:6px;background:#22354c;color:inherit;cursor:pointer}
button:focus-visible,a:focus-visible{outline:3px solid #ffcf6a;outline-offset:3px}
nav{display:flex;gap:12px;align-items:center;flex-wrap:wrap}figure{margin:20px 0}
.shot{max-width:100%;height:auto;border:1px solid #65758b}figcaption{line-height:1.5}
.meta{color:#b8c9da;font-size:14px;overflow-wrap:anywhere}.contact{display:flex;gap:12px;
flex-wrap:wrap}.contact button{width:150px}.contact img{width:100%;height:85px;object-fit:contain}
details{margin:20px 0}li{margin:14px 0}[hidden]{display:none!important}
pre{white-space:pre-wrap;overflow-wrap:anywhere}input{font:inherit;max-width:100%;box-sizing:border-box}
"""
SLIDESHOW_SCRIPT = """
const slides=[...document.querySelectorAll('[data-slide]')];let current=0;
function show(index){current=(index+slides.length)%slides.length;
slides.forEach((slide,i)=>slide.hidden=i!==current);
document.getElementById('counter').textContent=`${current+1} / ${slides.length}`;}
document.getElementById('prev').onclick=()=>show(current-1);
document.getElementById('next').onclick=()=>show(current+1);
document.querySelectorAll('[data-jump]').forEach(b=>b.onclick=()=>show(Number(b.dataset.jump)));
document.addEventListener('keydown',event=>{if(event.altKey||event.ctrlKey||event.metaKey)return;
if(event.key==='ArrowLeft'){event.preventDefault();show(current-1);}
if(event.key==='ArrowRight'){event.preventDefault();show(current+1);}});show(0);
"""


def nonempty(record, key):
    value = record.get(key)
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"{key}: expected nonempty text")
    return value


def capture_path(directory, name):
    relative = Path(name)
    path = (directory / relative).resolve()
    if relative.is_absolute() or not path.is_relative_to(directory.resolve()):
        raise ValueError("capture image must remain inside its demo directory")
    return path


def read_png(path, dimensions=None, digest=None):
    """Check PNG encoding, filtered scanlines, CRCs and recorded metadata."""
    data = path.read_bytes()
    if len(data) < 33 or data[:8] != PNG_SIGNATURE or data[12:16] != b"IHDR":
        raise ValueError(f"not a PNG: {path.name}")
    if struct.unpack(">I", data[8:12])[0] != 13:
        raise ValueError(f"broken PNG header: {path.name}")
    width, height, depth, color, compression, filtering, interlace = struct.unpack(
        ">IIBBBBB", data[16:29])
    if width < 1 or height < 1 or (dimensions is not None and [width, height] != dimensions):
        raise ValueError(f"capture dimensions do not match PNG: {path.name}")
    if (color not in PNG_ENCODINGS or depth not in PNG_ENCODINGS[color][1]
            or compression != 0 or filtering != 0 or interlace not in (0, 1)):
        raise ValueError(f"unsupported PNG encoding: {path.name}")
    offset, chunks, compressed, palettes = 8, [], [], []
    while offset + 12 <= len(data):
        length = struct.unpack(">I", data[offset:offset + 4])[0]
        end = offset + 12 + length
        chunk = data[offset + 4:end - 4]
        if end > len(data) or zlib.crc32(chunk) != struct.unpack(">I", data[end - 4:end])[0]:
            raise ValueError(f"broken PNG chunk: {path.name}")
        chunks.append(chunk[:4])
        if chunk[:4] == b"IDAT":
            compressed.append(chunk[4:])
        if chunk[:4] == b"PLTE":
            palettes.append(chunk[4:])
        offset = end
        if chunk[:4] == b"IEND":
            if length != 0:
                raise ValueError(f"broken PNG end: {path.name}")
            break
    if (offset != len(data) or chunks[-1:] != [b"IEND"] or b"IDAT" not in chunks
            or chunks.count(b"IHDR") != 1):
        raise ValueError(f"incomplete PNG: {path.name}")
    if (palettes and (len(palettes) != 1 or not 0 < len(palettes[0]) <= 768
                      or len(palettes[0]) % 3 or color in (0, 4)
                      or chunks.index(b"PLTE") > chunks.index(b"IDAT"))
            or color == 3 and (not palettes or len(palettes[0]) > 3 * (1 << depth))):
        raise ValueError(f"invalid PNG palette: {path.name}")
    try:
        decoder = zlib.decompressobj()
        pixels = decoder.decompress(b"".join(compressed)) + decoder.flush()
        if not decoder.eof or decoder.unused_data:
            raise ValueError(f"incomplete PNG pixels: {path.name}")
    except zlib.error as error:
        raise ValueError(f"broken PNG pixels: {path.name}") from error
    offset = 0
    channels = PNG_ENCODINGS[color][0]
    for x, y, dx, dy in PNG_ADAM7_PASSES if interlace else ((0, 0, 1, 1),):
        pass_width = max(0, (width - x + dx - 1) // dx)
        pass_height = max(0, (height - y + dy - 1) // dy)
        if not pass_width or not pass_height:
            continue
        stride = 1 + (pass_width * channels * depth + 7) // 8
        end = offset + stride * pass_height
        if end > len(pixels) or any(pixels[row] > 4 for row in range(offset, end, stride)):
            raise ValueError(f"invalid PNG scanlines: {path.name}")
        offset = end
    if offset != len(pixels):
        raise ValueError(f"invalid PNG pixel length: {path.name}")
    if digest is not None and hashlib.sha256(data).hexdigest() != digest:
        raise ValueError(f"capture SHA-256 mismatch: {path.name}")
    return data


def load_manifest(path):
    """Fail closed on missing evidence; never fill a sequence with mock images."""
    manifest = json.loads(path.read_text())
    if not isinstance(manifest, dict) or manifest.get("version") != 1:
        raise ValueError("manifest version must be 1")
    demo_id = nonempty(manifest, "demo_id")
    if not re.fullmatch(r"[a-z0-9][a-z0-9-]*", demo_id) or path.parent.name != demo_id:
        raise ValueError("demo_id must match its directory name")
    for key in ("title", "scenario", "host", "backend", "fixture", "reproduce"):
        nonempty(manifest, key)
    if not re.fullmatch(r"[a-f0-9]{7,40}", nonempty(manifest, "revision")):
        raise ValueError("revision must identify the captured source commit")
    if type(manifest.get("scale")) not in (int, float) or not 0 < manifest["scale"] <= 8:
        raise ValueError("scale must be in (0, 8]")
    slides = manifest.get("slides")
    if not isinstance(slides, list) or not slides:
        raise ValueError("slides must contain real captures")
    phases = set()
    for slide in slides:
        if not isinstance(slide, dict):
            raise ValueError("version-1 slides must be objects")
        slide["phase"] = Phase(slide["phase"])
        slide["capture_kind"] = CaptureKind(slide["capture_kind"])
        phases.add(slide["phase"])
        for key in ("caption", "action", "expected"):
            nonempty(slide, key)
        image_path = capture_path(path.parent, nonempty(slide, "image"))
        if not isinstance(slide.get("dimensions"), list) or len(slide["dimensions"]) != 2:
            raise ValueError("dimensions must contain width and height")
        data = read_png(image_path, slide["dimensions"], slide.get("sha256", slide.get("png_sha256")))
        slide["data_url"] = "data:image/png;base64," + base64.b64encode(data).decode()
    if phases != set(Phase):
        raise ValueError("sequence requires initial, interaction, result, and recovery evidence")
    return manifest


def page(title, body, script=""):
    return ("<!doctype html><html lang='en'><meta charset='utf-8'>"
            "<meta name='viewport' content='width=device-width,initial-scale=1'>"
            f"<title>{html.escape(title)}</title><style>{STYLE}</style><body>{body}"
            f"<script>{script}</script></body></html>")


def render(manifest, relative_images=False):
    esc = html.escape
    figures, thumbs = [], []
    for index, slide in enumerate(manifest["slides"]):
        caption = esc(slide["caption"])
        source = esc(quote(slide["image"], safe="/")) if relative_images else slide["data_url"]
        figures.append(
            f"<figure data-slide='{index}'{' hidden' if index else ''}>"
            f"<img class='shot' src='{source}' alt='{caption}'>"
            f"<figcaption><strong>{caption}</strong><br>Action: {esc(slide['action'])}"
            f"<br>Expected: {esc(slide['expected'])}</figcaption>"
            f"<p class='meta'>{slide['phase'].value} · {slide['capture_kind'].value} · "
            f"{slide['dimensions'][0]} × {slide['dimensions'][1]} pixels</p></figure>")
        thumbs.append(f"<button data-jump='{index}' aria-label='Slide {index + 1}: {caption}'>"
                      f"<img src='{source}' alt=''><br>{index + 1}. {caption}</button>")
    metadata = " · ".join(esc(str(manifest[key])) for key in
                          ("demo_id", "revision", "host", "backend", "fixture"))
    body = (f"<h1>{esc(manifest['title'])}</h1><p class='meta'>{metadata}</p>"
            "<nav aria-label='Slideshow'><button id='prev'>Previous</button>"
            "<span id='counter' aria-live='polite'></span><button id='next'>Next</button></nav>"
            + "".join(figures) + "<details open><summary>Contact sheet</summary>"
            "<div class='contact'>" + "".join(thumbs) + "</div></details>"
            f"<details><summary>Reproduce</summary><pre>{esc(manifest['reproduce'])}</pre>"
            f"<p>{esc(manifest['scenario'])}</p></details>"
            "<p class='meta'>Screenshots show recorded states. They do not establish latency, "
            "scientific accuracy, physical IME, screen-reader behavior, or human usability.</p>")
    return page(manifest["title"], body, SLIDESHOW_SCRIPT)


def build(root, check_only=False, index_only=False, relative_images=False):
    from demo_gallery import build_catalog
    return build_catalog(root, check_only, index_only, relative_images)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", type=Path, nargs="?", default=Path("artifacts/demo-slideshows"))
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--index-only", action="store_true", help="Refresh the master using delivered decks only; never write individual decks")
    parser.add_argument("--relative-images", action="store_true", help="Use original image files in newly generated decks instead of embedding them")
    args = parser.parse_args()
    print(f"Cataloged {build(args.root, args.check, args.index_only, args.relative_images)} demo galleries")
