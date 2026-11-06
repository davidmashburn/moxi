#!/usr/bin/env python3
"""Build an honest replay report from actual upstream and Moxi capture runs.

This does not manufacture screenshots: source/comparison/table views must be
captured through the collaborative preview. Other slides are real Canvas PNGs.
"""
import argparse
import csv
from collections import Counter
import hashlib
import html
import json
import platform
import shutil
import subprocess
import time
from pathlib import Path
from xml.etree import ElementTree as ET
from PIL import Image
import numpy as np
from fixtures import CASES, ROOT, figure
from moxi.specialized import layout

NOTES = {
 'lollipop':'Zero-to-value stems and endpoint markers; zero/negative values retained. Upstream circles versus Moxi rounded rectangles.',
 'waterfall':'Running total includes every delta, including total rows; total bars start at zero. Connectors are decorative and excluded from hit testing.',
 'candlestick':'Low/high wick, open/close body, sign color and zero-height doji. Moxi includes zero in its domain; upstream fits the OHLC range.',
 'bullet':'Disjoint ordered threshold bands, narrower measure, full-width target. Upstream shades .88/.67/.47; Moxi .86/.71/.56. Target contrast follows Moxi ink.',
 'grouped_bar':'Declared series order partitions each category band. Error stem and both caps are retained. Upstream errors precede bar paint; Moxi paints them on top.',
 'stacked_bar':'Separate positive and negative accumulators, declared series order. Percent mode is separately tested with zero columns and negative rejection.',
 'gantt':'Horizontal intervals, first category at the top, reversed endpoints sorted. Moxi includes zero; upstream fits the interval range.',
 'span_chart':'Vertical intervals, category order left-to-right, reversed endpoints sorted. This is a distinct orientation from Gantt.',
 'population_pyramid':'Both input sides use magnitudes, left negative/right positive, symmetric domain, first category at the top.',
}
COMMON = 'Visual: own theme, margins, rounding, grid and palette. Canvas text/series legend are absent; source table and semantic rows are the fallback. Structural: upstream SVG uses paths/groups/text; Moxi uses Scene primitives. No pixel-parity claim.'


def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def table(columns, selected=None):
    fields=list(columns)
    return '<table><thead><tr>'+''.join('<th>'+html.escape(k)+'</th>' for k in fields)+'</tr></thead><tbody>'+''.join('<tr'+(' class="selected"' if i==selected else '')+'>'+''.join('<td>'+html.escape(str(columns[k][i]))+'</td>' for k in fields)+'</tr>' for i in range(len(columns[fields[0]])))+'</tbody></table>'

def page(name,body,revision,dirty):
    state = " + modified source" if dirty else " (clean source)"
    return '<!doctype html><html><head><meta charset="utf-8"><style>body{font:16px system-ui;margin:20px;background:#f5f7fa;color:#172033}h1{font-size:24px;margin:0 0 8px}h2{font-size:18px}pre{white-space:pre-wrap;font-size:12px}table{border-collapse:collapse;font-size:12px;max-width:100%}td,th{padding:6px 7px;border:1px solid #aab4c4;text-align:left}.selected{background:#ffe1a0}.pair{display:flex;gap:20px}.pair img{width:560px;height:420px}img{max-width:640px}small{color:#4b596e}p{max-width:1150px;line-height:1.4}</style></head><body>'+f'<h1>E01 · {name}</h1><small>Actual offscreen output / recorded event replay · revision {revision[:12]}{state} · 640×480, scale 1</small>'+body+'</body></html>'


def main():
    p=argparse.ArgumentParser();p.add_argument('reference',type=Path);p.add_argument('moxi',type=Path);p.add_argument('--root',type=Path,default=ROOT/'artifacts/demo-slideshows');a=p.parse_args()
    revision=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
    source_paths = ["python/moxi", "src/moxi_plot", "src/moxi", "scripts/wave_a", "scripts/demo_slideshows.py", "tests/plot_specialized.mojo", "tests/fixtures/wave_a/cases.json", "pixi.toml", "pixi.lock"]
    files = sorted(p for name in source_paths for p in ((ROOT/name).rglob("*") if (ROOT/name).is_dir() else [ROOT/name]) if p.is_file() and "__pycache__" not in p.parts)
    source_hashes = {str(p.relative_to(ROOT)):digest(p) for p in files}
    source_hash = hashlib.sha256(json.dumps(source_hashes,sort_keys=True).encode()).hexdigest()
    dirty=subprocess.check_output(['git','status','--porcelain','--',*source_paths],cwd=ROOT,text=True)
    source_state = {"dirty":bool(dirty), "sha256":source_hash, "files":source_hashes}
    upstream=json.loads((a.reference/'provenance.json').read_text());assert upstream['returncode']==0
    mojo_bench=json.loads((a.moxi/'benchmarks.json').read_text())
    reference_times={line.split()[0]:float(line.split('=')[1]) for line in (a.reference/'run.log').read_text().splitlines() if 'export_seconds=' in line}
    selections={}
    for line in (a.moxi/'run.log').read_text().splitlines():
        fields=[x.strip() for x in line.split('|')]
        if fields[0]=='selection':selections[fields[1]]={'row_key':int(fields[2]),'x':float(fields[3]),'y':float(fields[4])}
    report={'revision':revision,'dirty':bool(dirty),'source_state':source_state,'host':platform.platform(),'upstream':upstream,'method':'Unaligned 640x480 pixel delta is descriptive only; structural signatures and cross-language primitive assertions are the correctness checks. Timings are workload-specific, no ratio/physical latency claim.','cases':{}}
    for case in CASES:
        name=case['id'];demo_id='e01-'+name.replace('_','-');out=a.root/demo_id;out.mkdir(parents=True,exist_ok=True)
        with (a.moxi/(name+'-table.csv')).open(newline='') as source:
            csv_rows=list(csv.DictReader(source))
        assert len(csv_rows)==len(case['columns']['category']) and all(None not in row for row in csv_rows)
        exported_columns={field:[row[field] for row in csv_rows] for field in case['columns']}
        f=figure(case);g=layout(f.spec.layers[0],f.data)
        svg=ET.parse(a.reference/(name+'.svg')).getroot();tags=Counter(e.tag.split('}')[-1] for e in svg.iter());ns={'s':'http://www.w3.org/2000/svg'}
        titles=[e.text for e in svg.findall('s:g/s:title',ns)]
        if name in ('grouped_bar','stacked_bar'):
            expected=[f'{c} / {field}: {case["columns"][field][i]:g}' for i,c in enumerate(case['columns']['category']) for field in case['layout']['series_fields']]
            assert titles==expected,(name,titles,expected)
        if name=='lollipop':assert titles==[f'{c}: {v:g}' for c,v in zip(case['columns']['category'],case['columns']['value'])]
        ref=np.asarray(Image.open(a.reference/(name+'.png')).convert('RGB')).astype(float)
        own=np.asarray(Image.open(a.moxi/(name+'-canvas.png')).convert('RGB')).astype(float)
        assert ref.shape==own.shape==(480,640,3)
        start=time.perf_counter()
        for _ in range(30):layout(f.spec.layers[0],f.data)
        layout_time=time.perf_counter()-start
        start=time.perf_counter();f.to_png();png_time=time.perf_counter()-start
        record={'classification':NOTES[name],'common_differences':COMMON,'upstream_svg_elements':dict(tags),'upstream_svg_row_titles':titles,'moxi_glyphs':dict(Counter(x.kind.value for x in g.glyphs)),'source_rows':len(g.rows),'unaligned_mean_absolute_rgb_delta':round(float(np.abs(ref-own).mean()),3),'sha256':{'reference_png':digest(a.reference/(name+'.png')),'reference_svg':digest(a.reference/(name+'.svg')),'moxi_canvas':digest(a.moxi/(name+'-canvas.png'))},'selection':selections[name],'benchmark':dict(mojo_bench[name],python_layout_30_seconds=layout_time,python_png_seconds=png_time,upstream_png_svg_seconds=reference_times[name])}
        report['cases'][name]=record
        for source,target in [(a.reference/(name+'.png'),'02-reference.png'),(a.moxi/(name+'-canvas.png'),'moxi.png'),(a.moxi/(name+'-selected.png'),'selected.png'),(a.moxi/(name+'-updated.png'),'05-update.png'),(a.moxi/(name+'-restored.png'),'06-recovery.png')]:shutil.copyfile(source,out/target)
        for extension in ('svg','pdf','png'):
            getattr(f,'save')(out/('export.'+extension)) if hasattr(f,'save') else None
        body='<h2>1 · Source</h2>'+table(case['columns'])+'<h2>Versioned layout contract</h2><pre>'+html.escape(json.dumps({k:v for k,v in json.loads(f.spec.to_json())['layers'][0].items() if k in ('id','mark','layout_version','x','y','y2','stat_low_field','stat_high_field','series_fields','range_fields','error_fields','total_field','horizontal','percent') and v not in ('',[])},indent=2))+'</pre>'
        (out/'source.html').write_text(page(name,body,revision,bool(dirty)))
        body='<h2>3 · Real reference → actual Moxi Canvas</h2><div class="pair"><img src="02-reference.png" alt="Pinned dataviz output"><img src="moxi.png" alt="Moxi Canvas output"></div><p>'+html.escape(NOTES[name])+'</p><p>'+COMMON+'</p><pre>'+html.escape(json.dumps({'upstream':dict(tags),'moxi':record['moxi_glyphs'],'mean_RGB_delta':record['unaligned_mean_absolute_rgb_delta']}))+'</pre>'
        (out/'comparison.html').write_text(page(name,body,revision,bool(dirty)))
        body='<h2>4 · Real PlotView click dispatch → selected row/table</h2><div class="pair"><img src="selected.png" alt="Canvas rendering after click"><section>'+table(exported_columns,selections[name]['row_key'])+'<pre>'+html.escape(json.dumps(selections[name],indent=2))+'</pre><p>selected_count = 1; source row identity retained.<br>Table parsed from PlotView CSV export.<br>Semantic row count verified in Mojo and Python.<br>Recorded event replay, no physical input claim.<br>VoiceOver remains paused.</p></section></div>'
        (out/'selection.html').write_text(page(name,body,revision,bool(dirty)))
        repro='See docs/plot-specialized-wave-a.md: reproduce both pinned runners, evidence.py, then capture source.html, comparison.html, selection.html through collaborative preview at 1280x900. Copy saved PNGs to 01-source.png, 03-comparison.png, 04-selection.png. Run scripts/wave_a/slideshows.py (shared validator/renderer). Captures record the source revision and scoped hashes; rerun after source changes.'
        phases=[('initial','browser','01-source.png','Source columns and specialized v1 schema','Open source.html','Source categories and all shape channels visible'),('initial','offscreen-render','02-reference.png','Real dataviz v0.8.0 output','Run upstream.py against exact pin','Actual pinned PNG, no substituted image'),('result','browser','03-comparison.png','Actual Moxi and classified differences','Open comparison.html','Upstream and actual Scene/Canvas output side by side'),('interaction','browser','04-selection.png','Selection and source table: event replay','Runner dispatches click at recorded coordinates; open selection.html','One source row selected with semantic/CSV fallback'),('result','offscreen-render','05-update.png','Export/update: first-row numeric data ×1.25','Verify.py exports SVG/Canvas; PlotView.replace_data with first-row numeric columns multiplied except total flags','Recompiled actual Canvas output; selection clears'),('recovery','offscreen-render','06-recovery.png','Restore original source snapshot','PlotView.replace_data(original)','Original bounds restored after update')]
        slides=[dict(phase=phase,capture_kind=kind,image=image,dimensions=[1280,900] if kind=='browser' else [640,480],caption=caption,action=action,expected=expected) for phase,kind,image,caption,action,expected in phases]
        manifest=dict(version=1,demo_id=demo_id,title='E01 '+name,scenario=NOTES[name]+' Offscreen rendering and recorded event replay; no physical performance or human usability claim.',revision=revision,source_dirty=bool(dirty),source_state=source_state,host=platform.platform(),backend='Mojo Scene/Canvas; dataviz v0.8.0; browser evidence replay',scale=1,fixture='tests/fixtures/wave_a/cases.json#'+name,reproduce=repro,slides=slides)
        (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    (ROOT/'tests/fixtures/wave_a/observed.json').write_text(json.dumps(report,indent=2)+'\n')
    print('Prepared nine evidence reports; browser captures remain required.')

if __name__=='__main__':main()
