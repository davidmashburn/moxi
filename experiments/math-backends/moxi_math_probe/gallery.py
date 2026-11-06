"""Turn actual native captures into a portable, self-contained slideshow."""
import argparse
import base64
import html
import json
from pathlib import Path

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("captures", type=Path)
    args = parser.parse_args()
    root = args.captures
    manifest = json.loads((root / "manifest.json").read_text())
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
    (root / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    page = '''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>Moxi D01 · actual native captures</title>
<style>body{margin:24px auto;max-width:1200px;background:#111a2a;color:#edf3ff;font:16px system-ui}button{padding:10px;margin:4px;background:#263c5d;color:white;border:1px solid #80a5d4;border-radius:6px;cursor:pointer}figure{margin:16px 0}figure img{width:100%;height:auto}figcaption{padding:12px}#contact{display:grid;grid-template-columns:repeat(4,1fr)}#contact img{width:100%}[hidden]{display:none!important}a{color:#a9d6ff}</style>
<h1>Moxi D01 · symbolic backend comparison</h1><p>Captured from the running Mojo/Moxi AppKit window, using its live content view. OS screencapture was unavailable. These are not offscreen scene renders. Fixtures, actions and source fingerprints are in manifest.json.</p>
<nav><button onclick="show(current-1)">← Previous</button><button onclick="show(current+1)">Next →</button><button onclick="document.getElementById('contact').hidden=!document.getElementById('contact').hidden">Contact sheet</button></nav>
''' + "".join(figures) + '<section id="contact" hidden>' + "".join(thumbnails) + '</section>' + f'''<script>let current=0;const count={len(manifest)};function show(n){{document.getElementById('slide-'+current).hidden=true;current=(n+count)%count;document.getElementById('slide-'+current).hidden=false;}}document.querySelectorAll('[data-slide]').forEach(img=>img.src=document.querySelector('#slide-'+img.dataset.slide+' img').src);document.addEventListener('keydown',e=>{{if(e.key==='ArrowRight')show(current+1);if(e.key==='ArrowLeft')show(current-1);}});</script></html>'''
    (root / "index.html").write_text(page)

if __name__ == "__main__":
    main()
