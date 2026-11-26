"""Run the real Chrome regressions and build a navigable, offline evidence deck."""
import argparse
import html
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parent.parent


def deck(out):
    manifest = json.loads((out / "manifest.json").read_text())
    slides = manifest["slides"]
    escape = html.escape
    figures = []
    for i, slide in enumerate(slides, 1):
        figures.append(f'''<figure id="s{i}" {'hidden' if i != 1 else ''}>
<figcaption><h2>{i}. {escape(slide['title'])}</h2>
<p><b>Steps:</b> {escape(slide['steps'])}</p>
<p><b>Observed / pass:</b> {escape(slide['observed'])}</p></figcaption>
<a href="{escape(slide['image'])}" target="_blank" rel="noopener"><img src="{escape(slide['image'])}" alt="{escape(slide['observed'])}"></a>
</figure>''')
    links = " ".join(f'<a href="#s{i}" aria-label="Slide {i}">{i}</a>' for i in range(1, len(slides) + 1))
    (out / "index.html").write_text(f'''<!doctype html>
<html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>I02 · Matrix instrument evidence</title>
<style>
*{{box-sizing:border-box}}body{{max-width:1200px;margin:auto;padding:24px;background:#f3f2eb;color:#203a34;font:16px/1.5 system-ui}}
h1{{font-size:32px;margin:0}}h2{{font-size:23px;margin:10px 0}}.meta{{font-size:12px;color:#5d6c65}}nav{{display:flex;flex-wrap:wrap;align-items:center;gap:8px;margin:20px 0}}button,a{{color:#056e66}}button{{padding:10px 15px;border:1px solid #b7c6bc;border-radius:8px;background:white;cursor:pointer}}a{{padding:4px}}a[aria-current=true]{{font-weight:800;text-decoration-thickness:3px}}figure{{margin:0}}figure[hidden]{{display:none}}figcaption p{{margin:8px 0;font-size:14px}}img{{display:block;max-width:100%;max-height:72vh;margin:20px auto;object-fit:contain;border:1px solid #d7ded5}}:focus-visible{{outline:3px solid #254fac;outline-offset:3px}}
</style><body>
<h1>I02 · A matrix you can move</h1>
<p>Live Chrome captures of the normal consumer. Use Previous / Next, the numbered links, or ← / →. Open an image for its full size.</p>
<p class="meta">Captured {escape(manifest['captured'])} · Chrome {escape(manifest['chrome'])} · {escape(manifest['platform'])}<br>
Tested checkout HEAD {escape(manifest['revision'])}; exact tested file hashes and scenario results in <a href="manifest.json">manifest.json</a>.<br>
Synthetic local matrix · Moxi Python reference renderer · VoiceOver paused. No learner, physical-keyboard, assistive-technology, native-host or cross-browser evaluation.</p>
<nav aria-label="Slideshow"><button id="prev">Previous</button><span id="counter" aria-live="polite"></span><button id="next">Next</button>{links}</nav>
{''.join(figures)}
<script>
const slides=[...document.querySelectorAll('figure')];
function show(n){{n=Math.max(0,Math.min(slides.length-1,n));slides.forEach((e,i)=>e.hidden=i!==n);document.getElementById('counter').textContent=`${{n+1}} / ${{slides.length}}`;document.getElementById('prev').disabled=n===0;document.getElementById('next').disabled=n===slides.length-1;document.querySelectorAll('nav a').forEach((e,i)=>e.setAttribute('aria-current',String(i===n)));}}
function current(){{const match=location.hash.match(/^#s([0-9]+)$/);return match?Number(match[1])-1:0;}}
function move(delta){{location.hash='s'+(Math.max(0,Math.min(slides.length-1,current()+delta))+1);}}
document.getElementById('prev').onclick=()=>move(-1);document.getElementById('next').onclick=()=>move(1);window.addEventListener('hashchange',()=>show(current()));document.addEventListener('keydown',e=>{{if(e.key==='ArrowRight'){{e.preventDefault();move(1);}}if(e.key==='ArrowLeft'){{e.preventDefault();move(-1);}}}});show(current());
</script></body></html>''')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=REPO / "artifacts/demo-slideshows/matrix-instrument")
    args = parser.parse_args()
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    log = Path(tempfile.mkdtemp(prefix="moxi-i02-capture-", dir="/tmp")) / "checks.log"
    env = dict(os.environ, PYTHONPATH=os.pathsep.join((str(REPO / "python"), str(ROOT))), MATRIX_EVIDENCE=str(out))
    with log.open("w") as stream:
        result = subprocess.run([sys.executable, "-m", "unittest", "discover", "-s", str(ROOT), "-p", "test_*.py", "-v"],
                                cwd=REPO, env=env, stdout=stream, stderr=subprocess.STDOUT)
    print(f"Regression log: {log}")
    if result.returncode:
        print("Checks failed; no deck was generated.")
        return result.returncode
    deck(out)
    print(f"Evidence deck: {out / 'index.html'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
