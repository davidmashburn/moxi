#!/usr/bin/env python3
"""Validate real capture manifests and make portable, offline demo slideshows."""

import argparse
import base64
from enum import Enum
import html
import json
from pathlib import Path
import re
import struct


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
"""


def nonempty(record, key):
    value = record.get(key)
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"{key}: expected nonempty text")
    return value


def load_manifest(path):
    """Fail closed on missing evidence; never fill a sequence with mock images."""
    manifest = json.loads(path.read_text())
    if manifest.get("version") != 1:
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
        slide["phase"] = Phase(slide["phase"])
        slide["capture_kind"] = CaptureKind(slide["capture_kind"])
        phases.add(slide["phase"])
        for key in ("caption", "action", "expected"):
            nonempty(slide, key)
        relative = Path(nonempty(slide, "image"))
        image_path = (path.parent / relative).resolve()
        if relative.is_absolute() or not image_path.is_relative_to(path.parent.resolve()):
            raise ValueError("capture image must remain inside its demo directory")
        data = image_path.read_bytes()
        if len(data) < 33 or data[:8] != PNG_SIGNATURE or data[12:16] != b"IHDR":
            raise ValueError(f"not a PNG: {relative}")
        width, height = struct.unpack(">II", data[16:24])
        if width < 1 or height < 1 or [width, height] != slide.get("dimensions"):
            raise ValueError(f"capture dimensions do not match PNG: {relative}")
        slide["data_url"] = "data:image/png;base64," + base64.b64encode(data).decode()
    if phases != set(Phase):
        raise ValueError("sequence requires initial, interaction, result, and recovery evidence")
    return manifest


def page(title, body, script=""):
    return ("<!doctype html><html lang='en'><meta charset='utf-8'>"
            "<meta name='viewport' content='width=device-width,initial-scale=1'>"
            f"<title>{html.escape(title)}</title><style>{STYLE}</style><body>{body}"
            f"<script>{script}</script></body></html>")


def render(manifest):
    esc = html.escape
    figures, thumbs = [], []
    for index, slide in enumerate(manifest["slides"]):
        caption = esc(slide["caption"])
        figures.append(
            f"<figure data-slide='{index}'{' hidden' if index else ''}>"
            f"<img class='shot' src='{slide['data_url']}' alt='{caption}'>"
            f"<figcaption><strong>{caption}</strong><br>Action: {esc(slide['action'])}"
            f"<br>Expected: {esc(slide['expected'])}</figcaption>"
            f"<p class='meta'>{slide['phase'].value} · {slide['capture_kind'].value} · "
            f"{slide['dimensions'][0]} × {slide['dimensions'][1]} pixels</p></figure>")
        thumbs.append(f"<button data-jump='{index}' aria-label='Slide {index + 1}: {caption}'>"
                      f"<img src='{slide['data_url']}' alt=''><br>{index + 1}. {caption}</button>")
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
    script = """
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
    return page(manifest["title"], body, script)


def build(root, check_only=False):
    manifests = [(path, load_manifest(path)) for path in sorted(root.glob("*/manifest.json"))]
    if not check_only:
        root.mkdir(parents=True, exist_ok=True)
        links = []
        for path, manifest in manifests:
            (path.parent / "index.html").write_text(render(manifest))
            links.append(f"<li><a href='{manifest['demo_id']}/index.html'>"
                         f"{html.escape(manifest['title'])}</a> — {len(manifest['slides'])} captures</li>")
        body = ("<h1>Moxi demo slideshows</h1><p>Actual captured sequences. Missing or "
                "blocked demos are tracked in the implementation ledger, not represented by mockups.</p>"
                f"<ul>{''.join(links)}</ul>")
        (root / "index.html").write_text(page("Moxi demo slideshows", body))
    return len(manifests)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", type=Path, nargs="?", default=Path("artifacts/demo-slideshows"))
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    print(f"Validated {build(args.root, args.check)} demo slideshow manifests")
