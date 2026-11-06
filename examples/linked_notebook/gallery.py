#!/usr/bin/env python3
"""Build a self-contained slideshow from verified actual screenshots only."""
import base64
import hashlib
from html import escape
import json
from pathlib import Path
import statistics

ROOT=Path(__file__).resolve().parents[2]
DEST=ROOT/'artifacts/demo-slideshows/linked-notebook'


def main():
    report=json.loads((DEST/'evidence.json').read_text())
    for path,digest in report['sourceHashes'].items():
        assert hashlib.sha256((ROOT/path).read_bytes()).hexdigest()==digest,f'Source changed: {path}; recapture'
    for path,digest in report['screenshotHashes'].items():
        assert hashlib.sha256((DEST/path).read_bytes()).hexdigest()==digest,f'Capture changed: {path}'
    slides=[]
    for shot in report['screenshots']:
        image='data:image/png;base64,'+base64.b64encode((DEST/shot['file']).read_bytes()).decode()
        slides.append(dict(image=image,caption=shot['caption'],kind=shot['capture'],hash=report['screenshotHashes'][shot['file']]))
    metrics=[]
    for group in ('pipeline','channel'):
        for name,values in report['metrics'][group].items():
            if isinstance(values,list) and values:
                metrics.append(f'<tr><td>{escape(name)}</td><td>{len(values)}</td><td>{statistics.median(values):.3f}</td><td>{max(values):.3f}</td></tr>')
    paint=report['metrics']['chromePaintMs']
    if paint:metrics.append(f'<tr><td>Chrome main-thread Paint (ms)</td><td>{len(paint)}</td><td>{statistics.median(paint):.3f}</td><td>{max(paint):.3f}</td></tr>')
    html='''<!doctype html><html><head><meta charset="utf-8"><title>P05 linked selection — actual notebook captures</title><style>
body{font:14px system-ui;color:var(--foreground,#213547);margin:0}button,select{font:inherit;padding:7px 12px;margin:3px;background:var(--card,#fff);color:inherit;border:1px solid var(--border,#bbc);border-radius:5px}img{display:block;max-width:100%;max-height:660px;object-fit:contain;margin:8px auto}figure{margin:0}figcaption{font-weight:600;margin:8px 0}.meta{color:var(--muted-foreground,#536576);font-size:12px;overflow-wrap:anywhere}table{border-collapse:collapse;width:100%;font-variant-numeric:tabular-nums}th,td{text-align:left;padding:5px;border-bottom:1px solid var(--border,#ccd)}select{max-width:100%;min-width:0;flex:1 1 250px}nav{display:flex;flex-wrap:wrap;align-items:center}details{margin-top:12px}p{line-height:1.5}</style></head><body>
<nav aria-label="Notebook capture slides"><button id="prev">Previous</button><select id="select" aria-label="Choose a captured state"></select><button id="next">Next</button><span id="count"></span></nav><figure><img id="shot"><figcaption id="caption" aria-live="polite"></figcaption></figure><div id="kind" class="meta"></div><div id="hash" class="meta"></div>
<p>Actual Mojo PlotSpec → PlotRuntime selection → Scene/SVG, linked to details and records. Experimental example package; general adapter extraction remains deferred.</p>
<details><summary>Measured local limits and evidence</summary>'''
    html+=f'<p>Base revision <code>{escape(report["sourceRevision"])}</code>; P05 scoped working-tree status: {escape(report["scopedStatus"] or "clean")}. Exact content hashes are in evidence.json. Two queue slots, 4 KiB requests, 128 KiB frames, 64 records, 2-second process deadline, 4-second comm lease.</p>'
    html+='<table><thead><tr><th>Phase / unit</th><th>Samples</th><th>Median</th><th>Max</th></tr></thead><tbody>'+''.join(metrics)+'</tbody></table><p>Timing arrays mix initial, filtered, recovery and deliberate busy-kernel cases; these are observations, not performance guarantees. Paint is not GPU completion or display latency.</p></details>'
    html+='<details><summary>Executed checks and remaining gates</summary><ul>'+''.join('<li>'+escape(k.replace('_',' '))+'</li>' for k in report['checks'])+'</ul><p>Unverified: '+escape(', '.join(report['gaps']))+'. VoiceOver remains paused. No independent usability approval.</p></details>'
    html+='<script>const slides='+json.dumps(slides).replace('</','<\\/')+''';let i=0;const select=document.querySelector('#select');slides.forEach((s,n)=>{const o=document.createElement('option');o.value=n;o.textContent=`${n+1}. ${s.caption}`;select.append(o)});function show(n){i=(n+slides.length)%slides.length;const s=slides[i];document.querySelector('#shot').src=s.image;document.querySelector('#shot').alt=s.caption;document.querySelector('#caption').textContent=s.caption;document.querySelector('#kind').textContent=s.kind;document.querySelector('#hash').textContent='PNG SHA-256: '+s.hash;document.querySelector('#count').textContent=`${i+1} / ${slides.length}`;select.value=i}select.onchange=()=>show(+select.value);document.querySelector('#prev').onclick=()=>show(i-1);document.querySelector('#next').onclick=()=>show(i+1);show(0);</script></body></html>'''
    (DEST/'index.html').write_text(html)
    print(DEST/'index.html')


if __name__=='__main__':main()
