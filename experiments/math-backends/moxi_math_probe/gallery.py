"""Turn actual native captures into a portable, self-contained slideshow."""
import argparse
import base64
import html
import json
from enum import StrEnum
from pathlib import Path

class CapturePhase(StrEnum):
    INITIAL = "initial"
    INTERACTION = "interaction"
    RESULT = "result"
    RECOVERY = "recovery"

# Thirteen actual states per backend, followed by the measured decision.
PHASES = (CapturePhase.INITIAL, CapturePhase.RESULT, CapturePhase.INTERACTION,
          CapturePhase.RESULT, CapturePhase.RESULT, CapturePhase.RESULT,
          CapturePhase.RESULT, CapturePhase.RECOVERY, CapturePhase.INTERACTION,
          CapturePhase.INTERACTION, CapturePhase.RECOVERY, CapturePhase.RECOVERY,
          CapturePhase.RECOVERY)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("captures", type=Path)
    args = parser.parse_args()
    root = args.captures
    manifest = json.loads((root / "captures.json").read_text())
    if not manifest:
        raise SystemExit("No actual captures: refusing to generate a gallery")
    figures = []
    thumbnails = []
    for i, entry in enumerate(manifest):
        path = root / entry["image"]
        raw = path.read_bytes()
        if raw[:8] != b"\x89PNG\r\n\x1a\n":
            raise ValueError("Not a PNG: " + str(path))
        width, height = int.from_bytes(raw[16:20], "big"), int.from_bytes(raw[20:24], "big")
        entry["pixels"] = [width, height]
        caption = html.escape(entry["caption"])
        uri = "data:image/png;base64," + base64.b64encode(raw).decode()
        figures.append(f'<figure id="slide-{i}" {"" if i == 0 else "hidden"}><img src="{uri}" alt="{caption}"><figcaption>{i+1}/{len(manifest)} · {caption}<br>{html.escape(entry["capture"])} · {width}×{height}</figcaption></figure>')
        thumbnails.append(f'<button onclick="show({i})"><img data-slide="{i}" alt="">{i+1}. {caption}</button>')
    (root / "captures.json").write_text(json.dumps(manifest, indent=2) + "\n")
    first = manifest[0]
    shared = {
        "version": 1, "demo_id": "d01-math-backends", "title": "Moxi symbolic backend comparison",
        "scenario": "D01: real native AppKit content-view captures, scripted through the same controller as the buttons. OS compositor and physical input behavior are unverified. Exact state and source provenance are in captures.json.",
        "revision": first["source_revision"].split()[0], "host": first["host"],
        "backend": "Moxi AppKit; persistent SymPy and Mojo/C SymEngine workers",
        "scale": first["pixels"][0] / first["window_points"][0],
        "fixture": "Shared exact-expression corpus; working-source SHA256 " + first["source_sha256"],
        "reproduce": first["reproduction"] + "; then run python -m moxi_math_probe.gallery on that directory (see REPRODUCE.md).",
        "slides": [{"phase": PHASES[i % len(PHASES)] if i < 2 * len(PHASES) else CapturePhase.RESULT,
                    "capture_kind": "native-window", "image": c["image"], "dimensions": c["pixels"],
                    "caption": c["caption"], "action": c["caption"], "expected": c["status"]}
                   for i, c in enumerate(manifest)],
    }
    (root / "manifest.json").write_text(json.dumps(shared, indent=2) + "\n")
    page = '''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>Moxi D01 · actual native captures</title>
<style>body{margin:24px auto;max-width:1200px;background:#111a2a;color:#edf3ff;font:16px system-ui}button{padding:10px;margin:4px;background:#263c5d;color:white;border:1px solid #80a5d4;border-radius:6px;cursor:pointer}figure{margin:16px 0}figure img{width:100%;height:auto}figcaption{padding:12px}#contact{display:grid;grid-template-columns:repeat(4,1fr)}#contact img{width:100%}[hidden]{display:none!important}a{color:#a9d6ff}</style>
<h1>Moxi D01 · symbolic backend comparison</h1><p>Captured from the running Mojo/Moxi AppKit window, using its live content view. OS screencapture was unavailable. These are not offscreen scene renders. Fixtures, actions and source fingerprints are in captures.json.</p>
<nav><button onclick="show(current-1)">← Previous</button><button onclick="show(current+1)">Next →</button><button onclick="document.getElementById('contact').hidden=!document.getElementById('contact').hidden">Contact sheet</button></nav>
''' + "".join(figures) + '<section id="contact" hidden>' + "".join(thumbnails) + '</section>' + f'''<script>let current=0;const count={len(manifest)};function show(n){{document.getElementById('slide-'+current).hidden=true;current=(n+count)%count;document.getElementById('slide-'+current).hidden=false;}}document.querySelectorAll('[data-slide]').forEach(img=>img.src=document.querySelector('#slide-'+img.dataset.slide+' img').src);document.addEventListener('keydown',e=>{{if(e.key==='ArrowRight')show(current+1);if(e.key==='ArrowLeft')show(current-1);}});</script></html>'''
    (root / "index.html").write_text(page)

if __name__ == "__main__":
    main()
