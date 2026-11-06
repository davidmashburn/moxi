#!/usr/bin/env python3
"""Prepare genuine exports/replay pages. Browser screenshots must be captured separately."""
import argparse, csv, hashlib, html, json, platform, shutil, subprocess
from pathlib import Path
from PIL import Image
from fixtures import ROOT, load_cases, figure
from verify import runtime_source_hash

NOTES={
'pie':'Value-proportional clockwise wedges from twelve o’clock; sampled arcs versus analytic upstream arcs.',
'donut':'Value-proportional annular sectors; the center is excluded from hit-testing. Inner radius 0.5.',
'radar':'Indicator-wise maxima and closed series polygons match upstream vertices. Moxi translucent fill differs from upstream white-lightened fill; Moxi adds sample anchors.',
'gauge':'270-degree dial, 20/80 percent thresholds and clamped needle. Palette, needle ink and numeric label differ.',
'polar':'Clockwise radians, connected source points and shared radius maximum. Float projection versus upstream integer-rounded circle centers.',
'polar_bar':'Equal angles, linear radius and 20 percent angular padding; sampled sectors.',
'radialbar':'Outside-in rings, 25 percent slot gap, value/max sweep and noninteractive full tracks.',
'beeswarm':'Pixel-rounded value sorting, neighbor-chain grouping and deterministic alternating horizontal offsets. Points retain source identities despite geometry ordering.',
'violin':'Thirty-point Gaussian KDE, standard-deviation Silverman bandwidth and peak-normalized mirrored width. Constant groups yield zero-area silhouettes.',
'ridgeline':'Same KDE; first group at top, 1.3-unit peak height and overlapping filled baselines. Moxi clamps the top ridge to the plot boundary; upstream overflows into the margin. The silhouette check covers only the shared plot rectangle.',
'nightingale':'Equal angles with radius proportional to value: the pinned default radius mode, not area mode.',
'streamgraph':'Declared series order, source-order categories, centered total baseline and linear segment polygons (upstream smoothing=0). Each interval retains both rows.',
'contour':'No contour API exists at the pinned upstream revision. Moxi uses real fixed-diagonal piecewise-linear grid isolines, seven interior levels; no upstream parity claim.',
'contourf':'No contourf API exists at the pinned upstream revision. Moxi clips each scalar triangle into eight bands, with explicit boundary ownership; no upstream parity claim.'}
COMMON='Same 640×480 canvas, 48/32/28/36 margins and source values. Canvas lacks text/legend labels. Moxi retains Cartesian axes/grid even for radial marks; upstream uses its own radial/category presentation. Palette differences, arc tessellation and antialiasing remain. No physical input, native, VoiceOver or human-performance claim.'

def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def table(rows,selected=None):
    fields=list(rows[0]) if rows else []
    return '<table><tr>'+''.join('<th>'+html.escape(f)+'</th>' for f in fields)+'</tr>'+''.join('<tr'+(' class="selected"' if str(r.get('key'))==str(selected) else '')+'>'+''.join('<td>'+html.escape(str(r[f]))+'</td>' for f in fields)+'</tr>' for r in rows)+'</table>'
def page(name,body,revision):
    return '<!doctype html><meta charset="utf-8"><style>body{font:15px system-ui;margin:18px;background:#f5f7fa;color:#172033}h1{font-size:23px}h2{font-size:18px}pre{font-size:12px;white-space:pre-wrap}table{border-collapse:collapse;font-size:11px}td,th{border:1px solid #aaa;padding:3px 7px}.selected{background:#ffe1a0}.pair{display:flex;gap:16px}.pair img{width:560px;height:420px}p{max-width:1180px}small{color:#526174}</style><h1>E02 · '+name+'</h1><small>Actual offscreen artifacts / recorded PlotView event replay · '+revision[:12]+' + scoped modified source · no live plot UI claim</small>'+body

def main():
    p=argparse.ArgumentParser();p.add_argument('reference',type=Path);p.add_argument('actual',type=Path);a=p.parse_args()
    revision=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
    scope=['python/moxi','src/moxi_plot','src/moxi','scripts/wave_b','scripts/demo_slideshows.py','tests/plot_wave_b.mojo','tests/plot_specialized.mojo','tests/python/test_specialized.py','tests/package_consumer.mojo','tests/scene_extended_path.mojo','tests/python/test_wave_b.py','tests/fixtures/wave_b','pixi.toml','pixi.lock']
    files=sorted(p for name in scope for p in ((ROOT/name).rglob('*') if (ROOT/name).is_dir() else [ROOT/name]) if p.is_file() and '__pycache__' not in p.parts and p.name not in ('observed.json','source-state.json','results.json'))
    hashes={str(p.relative_to(ROOT)):digest(p) for p in files}
    source_state=dict(revision=revision,dirty=bool(subprocess.check_output(['git','status','--porcelain','--',*scope],cwd=ROOT)),files=hashes,sha256=hashlib.sha256(json.dumps(hashes,sort_keys=True).encode()).hexdigest())
    state_path=ROOT/'tests/fixtures/wave_b/source-state.json';state_path.write_text(json.dumps(source_state,indent=2)+'\n')
    results=json.loads((a.actual/'results.json').read_text());comparison=json.loads((a.actual/'comparison.json').read_text());upstream=json.loads((a.reference/'provenance.json').read_text());assert upstream['returncode']==0
    assert results['runtime_source_sha256'] == runtime_source_hash(), 'Runtime inputs differ from the verified/captured build'
    report=dict(source_state_sha256=digest(state_path),runtime_source_sha256=results['runtime_source_sha256'],moxi_driver_sha256=results['driver_sha256'],timing_exclusions=results['exclusions'],upstream=upstream,moxi_canvas_revision='8fcb0c83966ef872248239f9dafd6baaba06204e',moxi_lock_sha256=digest(ROOT/'pixi.lock'),host=platform.platform(),cases={},missing_gates=['contour/contourf pinned upstream output','native window input/rendering','VoiceOver paused','independent human/scientific review','physical/GPU/large-workload performance'])
    for c in load_cases():
        name=c['id'];demo='e02-'+name.replace('_','-');out=ROOT/'artifacts/demo-slideshows'/demo;out.mkdir(parents=True,exist_ok=True)
        actual=[('canvas','moxi.png'),('selected','selected.png'),('updated','05-update.png'),('rejected','06-rejected.png'),('restored','07-recovery.png')]
        for suffix,target in actual:shutil.copyfile(a.actual/(name+'-'+suffix+'.png'),out/target)
        shutil.copyfile(a.actual/(name+'-scene.svg'),out/'scene.svg')
        f=figure(c)
        for ext in ('png','svg','pdf'):(out/('python-export.'+ext)).write_bytes(getattr(f,'to_'+ext)())
        rows=list(csv.DictReader((a.actual/(name+'-table.csv')).open()));sel=results['cases'][name]['selection']
        record=dict(classification=NOTES[name],common_differences=COMMON,comparison=comparison[name],benchmark_and_interaction=results['cases'][name],artifacts={target:digest(out/target) for _,target in actual})
        if c['reference_available']:
            shutil.copyfile(a.reference/(name+'.png'),out/'02-reference.png');record['artifacts']['02-reference.png']=digest(out/'02-reference.png');record['reference_svg_sha256']=digest(a.reference/(name+'.svg'))
            left='<img src="02-reference.png" alt="Real pinned upstream render">'
        else:
            text=(a.reference/'contour-reference-unavailable.txt').read_text();left='<section style="width:560px"><h2>Reference gate missing</h2><pre>'+html.escape(text)+'</pre><p>The pinned source cannot produce this family. This is an absence report, not an upstream chart.</p></section>'
            (out/'reference-gap.html').write_text(page(name,left,revision))
        schema=json.loads(f.spec.to_json())['layers'][0];schema={k:v for k,v in schema.items() if v not in ('',[],False) and k in ('mark','layout_version','x','y','y2','series_fields','stat_low_field','stat_high_field')}
        (out/'source.html').write_text(page(name,'<h2>1 · Actual source and schema</h2><div class="pair">'+table(rows)+'<section><pre>'+html.escape(json.dumps(schema,indent=2))+'</pre><p>'+NOTES[name]+'</p><p>Fixture seed '+str(c['seed'])+'; keys = seed + 3 × source row.</p></section></div>',revision))
        (out/'comparison.html').write_text(page(name,'<h2>3 · Pinned upstream → actual Moxi Scene/Canvas</h2><div class="pair">'+left+'<img src="moxi.png" alt="Actual Moxi Canvas"></div><p>'+NOTES[name]+'</p><p>'+COMMON+'</p><pre>'+html.escape(json.dumps(comparison[name]))+'</pre>',revision))
        (out/'selection.html').write_text(page(name,'<h2>4 · Real click dispatch → source-key selection/table fallback</h2><div class="pair"><img src="selected.png" alt="Actual Canvas after event dispatch"><section>'+table(rows,sel['key'])+'</section></div><pre>'+html.escape(json.dumps(sel))+'</pre><p>Recorded PlotView click; selected_count=1. Table comes from the actual CSV export. Multi-source shapes select a representative row; all contributing keys remain keyboard/linked-selection stops. This page presents event replay, not a browser implementation of the plot.</p>',revision))
        phases=[('initial','browser','01-source.png','Source data/schema','Open source.html','Source fields and nontrivial stable keys'),('initial','offscreen-render' if c['reference_available'] else 'browser','02-reference.png','Pinned upstream output' if c['reference_available'] else 'Missing pinned upstream API: primary-source evidence','Run upstream.py' if c['reference_available'] else 'Open reference-gap.html','Genuine upstream chart' if c['reference_available'] else 'Explicit absence; no substitute chart'),('result','browser','03-comparison.png','Actual Moxi comparison with narrow assertions','Open comparison.html','Real Canvas output and classified remaining differences'),('interaction','browser','04-selection.png','Source-key selection/table fallback: recorded event replay','Runner dispatches recorded click; open selection.html','Selected key and exported source table agree'),('result','offscreen-render','05-update.png','Export and data update','Canvas/SVG/Python PNG/PDF export; add 1.5 to first source value (grid scalar for contours)','Actual changed output; selection clears'),('recovery','offscreen-render','06-rejected.png','Reject nonfinite replacement','replace_data(nonfinite); assert false','Last valid updated output preserved pixel-for-pixel'),('recovery','offscreen-render','07-recovery.png','Restore original source data','replace_data(original)','Actual restored output equals initial Canvas pixels')]
        slides=[dict(phase=ph,capture_kind=kind,image=img,dimensions=[1280,900] if kind=='browser' else [640,480],caption=cap,action=act,expected=exp) for ph,kind,img,cap,act,exp in phases]
        manifest=dict(version=1,demo_id=demo,title='E02 '+name,scenario=NOTES[name]+' '+COMMON,revision=revision,source_dirty=True,source_state_path='tests/fixtures/wave_b/source-state.json',source_state_sha256=digest(state_path),host=platform.platform(),backend='Mojo Scene/Canvas offscreen; pinned dataviz; T3 browser evidence replay',scale=1,fixture=c['fixture'],reproduce='Follow docs/plot-specialized-wave-b.md; run registry, verify, upstream, compare and evidence. Capture source/comparison/selection (and absent reference report) in T3 preview at 1280×900. Run scripts/wave_b/slideshows.py.',missing_gates=report['missing_gates'],slides=slides)
        (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n');record['artifacts'].update({p.name:digest(p) for p in out.iterdir() if p.suffix in ('.svg','.pdf')});report['cases'][name]=record
    report['timing_environment'] = 'Shared host with concurrent compilation; not an isolated performance benchmark.'
    (ROOT/'tests/fixtures/wave_b/observed.json').write_text(json.dumps(report,indent=2)+'\n')
    print('Prepared 14 sequences; 44 genuine T3 browser captures still required.')
if __name__=='__main__':main()
