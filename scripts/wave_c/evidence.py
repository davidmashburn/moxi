#!/usr/bin/env python3
"""Prepare actual rendered evidence; collaborative preview supplies browser captures."""
import argparse,csv,hashlib,html,json,platform,re,shutil,statistics,subprocess,time
from collections import Counter
from pathlib import Path
from xml.etree import ElementTree as ET
from fixtures import CASES,ROOT,figure
from moxi.specialized import layout

NOTES={
 'treemap':'Alternating slice/dice leaf rectangles; descendant sums ignore branch own values. Input-order siblings; branch colors.',
 'sunburst':'Depth rings and descendant-weight angles; root hidden. Tessellated sectors replace analytic arcs.',
 'tree':'DFS leaf slots, arithmetic mean child positions, depth levels; parent-child source pairs retained. This is the upstream tree algorithm.',
 'sankey':'DAG longest-path columns, pass-through nodes for long edges, per-column normalization and edge-order strips. Aggregate nodes expose incident edge keys and are table-only selection targets.',
 'chord':'Incident flow totals partition the ring; row-order subarcs connect via quadratic ribbons through the center. Tessellation replaces analytic arcs. Aggregate rim nodes are table-only targets.',
 'graph':'Deterministic circular nodes; source-list then target-list first-seen ordering. Weighted edge width. Self loops omitted. Nodes retain all incident edge identities and are table-only targets.',
 'calendar_heatmap':'Validated ISO dates in one Gregorian year, Sunday-first weeks and leap-day handling. Source dates map to exact week/day cells.',
 'corrplot':'Full square matrix, radius proportional to absolute correlation; range [-1,1], cell identity is source row plus series column. Zero radius is invisible.',
 'punchcard':'First-seen categorical axes; bubble radius equals size/10 pixels. Duplicate cells retain separate source rows; overlap selection is bounded to the topmost matching glyph.',
 'marimekko':'Wide series/category matrix. Category width is column total/grand total; stack heights normalize within each column.',
 'barbs':'Round speed to nearest five; upwind staff, 50-unit flags, 10-unit full ticks, 5-unit half ticks and calm circles. No arrow substitution.',
 'tricontour':'Explicit validated triangle mesh and strictly increasing levels; marching triangles with half-open vertex ownership. All three vertex keys retained. Pinned upstream has no tricontour module/API: reference gate is missing.',
}
COMMON='Same 640×480 source fixture. Upstream margins normalized to native Scene (48/32/28/36), legend disabled, DejaVu Sans pinned. Fixed upstream palettes cannot be overridden by these APIs; Moxi retains its palette. Moxi Canvas text/legend absent; semantic/source table is the fallback. Python export margins differ. Circular geometry is stretched by independent native x/y scales; upstream uses the smaller plot dimension. Barbs use data-space lengths in Moxi versus pixel staff length upstream. These are recorded visual/metric differences, not pixel parity. No native-window, VoiceOver, human usability or physical performance gate is claimed.'

def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def table(cols,selected=-1):
 fields=list(cols);n=len(next(iter(cols.values())))
 return '<table><tr>'+''.join('<th>'+html.escape(f)+'</th>' for f in fields)+'</tr>'+''.join('<tr'+(' class="selected"' if i==selected else '')+'>'+''.join('<td>'+html.escape(str(cols[f][i]))+'</td>' for f in fields)+'</tr>' for i in range(n))+'</table>'
def page(name,body,revision,source_hash):
 return '<!doctype html><meta charset="utf-8"><style>body{font:15px system-ui;background:#f5f7fa;color:#172033;margin:22px}h1{font-size:24px}h2{font-size:19px}p{max-width:1200px}pre{white-space:pre-wrap;font-size:12px}table{border-collapse:collapse;font-size:12px}td,th{padding:5px 8px;border:1px solid #aaa}.selected{background:#ffe1a0}.pair{display:flex;gap:20px}.pair img{width:560px;height:420px}img{max-width:640px}small{font-size:11px}</style><h1>E03 · '+html.escape(name)+'</h1><small>Actual offscreen output / recorded event replay · '+revision[:12]+' + dirty scoped source '+source_hash[:12]+' · no native input claim</small>'+body

def structural(reference,name,g):
 root=ET.parse(reference/(name+'.svg')).getroot();tags=Counter(e.tag.split('}')[-1] for e in root)
 elements=lambda tag:[e for e in root if e.tag.split('}')[-1]==tag]
 checks=[]
 if name=='treemap':
  rects=elements('rect')[1:];assert len(rects)==4
  for r,p in zip(rects,g.glyphs):
   x,y,xx,yy=p.bounds;expected=(48+560*x,28+416*(1-yy),560*(xx-x),416*(yy-y));actual=[float(r.attrib[k]) for k in ('x','y','width','height')]
   assert max(abs(a-b) for a,b in zip(expected,actual))<=1.1
  checks.append('All four leaf rectangle bounds within 1.1 px of integer-rounded upstream')
 elif name=='tree':
  lines=elements('line');edges=[p for p in g.glyphs if p.part=='parent-edge'];assert len(lines)==len(edges)==6
  for e,p in zip(lines,edges):
   expected=[48+560*p.bounds[0],28+416*(1-p.bounds[1]),48+560*p.bounds[2],28+416*(1-p.bounds[3])]
   assert max(abs(float(e.attrib[k])-v) for k,v in zip(('x1','y1','x2','y2'),expected))<=1.1
  assert tags['circle']==7;checks.append('Six parent-child edge endpoints within 1.1 px; seven nodes')
 elif name=='graph':
  assert tags['line']==5 and tags['circle']==4
  for e,p in zip(elements('line'),g.glyphs[:5]):assert abs(float(e.attrib['stroke-width'])-p.stroke_width)<.001
  checks.append('Five source edges, four nodes, exact relative edge stroke widths; aspect differs')
 elif name=='sankey':
  assert tags['path']==6 and tags['rect']==5
  flows=[p for p in g.glyphs if p.part=='flow']
  for path,p,q in zip(elements('path'),flows[::2],flows[1::2]):
   vertices=[p.bounds[:2],p.bounds[2:],p.vertices[0],q.vertices[0]]
   expected=[v for x,y in vertices for v in (48+560*x,28+416*(1-y))]
   actual=list(map(float,re.findall(r'-?\d+(?:\.\d+)?',path.attrib['d'])))
   assert len(actual)==8 and max(abs(a-b) for a,b in zip(actual,expected))<1.1
  checks.append('All six flow-strip vertices within 1.1 px; includes long-edge splitting and unequal column totals')
 elif name in ('chord','sunburst'):
  paths=elements('path');assert len(paths)==(9 if name=='chord' else 6)
  # Compare every analytic arc/line endpoint against tessellated boundaries,
  # with the documented uniform-circle mapping, not Moxi's stretched pixels.
  rows=list(range(5)) if name=='chord' else [1,3,4,2,5,6]
  for path,row in zip(paths,rows):
   points=[point for p in g.glyphs if p.row==row and (name!='chord' or p.part in ('ribbon','rim')) for point in (p.bounds[:2],p.bounds[2:],*p.vertices)]
   for command,args in re.findall(r'([MLAQ])([^MLAQZ]+)',path.attrib['d']):
    nums=list(map(float,re.findall(r'-?\d+(?:\.\d+)?',args)));x,y=nums[-2:]
    assert min(max(abs(x-(328+416*(a-.5))),abs(y-(236+416*(.5-b)))) for a,b in points)<.002,(name,row,x,y)
  checks.append('Every ribbon/sector analytic boundary endpoint agrees within .002 px under the documented uniform-circle mapping; arc interiors are tessellated')
 elif name=='marimekko':
  rects=elements('rect')[1:];assert len(rects)==6
  for r,p in zip(rects,g.glyphs):
   x,y,xx,yy=p.bounds;expected=(48+560*x,28+416*(1-yy),560*(xx-x),416*(yy-y));assert max(abs(float(r.attrib[k])-v) for k,v in zip(('x','y','width','height'),expected))<=1.1
  checks.append('Six matrix rectangle bounds within 1.1 px of upstream rounding')
 elif name=='punchcard':
  assert [float(e.attrib['r']) for e in elements('circle')]==[2,5,0,9,4];checks.append('Five bubbles with upstream integer-rounded size/10 radii')
 elif name=='corrplot':
  assert tags['circle']==9
  case=next(c for c in CASES if c['id']==name)
  for i,e in enumerate(elements('circle')):
   row,col=divmod(i,3);v=case['columns'][case['layout']['series_fields'][col]][row]
   expected=(48+560*(col+.5)/3,28+416*(row+.5)/3,.4*416/3*abs(v))
   assert max(abs(float(e.attrib[k])-x) for k,x in zip(('cx','cy','r'),expected))<.51
  checks.append('All nine centers and absolute-correlation radii within .51 px after public bubble_fraction=.8 normalization; Moxi x radius stretches with aspect')
 elif name=='calendar_heatmap':
  cells=elements('rect')[1:];assert len(cells)==5
  for e,p in zip(cells,g.glyphs):
   week,dow=p.bounds[0],7-p.bounds[3]
   expected=(48+560*week/53,44+400*dow/7,560/53,400/7)
   assert max(abs(float(e.attrib[k])-v) for k,v in zip(('x','y','width','height'),expected))<1.1
  checks.append('All five week/day bounds within 1.1 px after accounting for upstream month-label reserve of 16 px')
 elif name=='barbs':
  assert tags['ellipse']==1 and tags['path']==7
  paths=elements('path');groups=[[0],[1],[2],[3,4],[5,6]]
  case=next(c for c in CASES if c['id']==name);length=.08*2.8
  for row,group in enumerate(groups,1):
   source=(case['columns']['x'][row],case['columns']['y'][row])
   numbers=list(map(float,re.findall(r'-?\d+(?:\.\d+)?',paths[group[0]].attrib['d'])));anchor=numbers[:2]
   points=[point for p in g.glyphs if p.row==row for point in (p.bounds[:2],p.bounds[2:],*p.vertices)]
   for index in group:
    nums=list(map(float,re.findall(r'-?\d+(?:\.\d+)?',paths[index].attrib['d'])))
    for x,y in zip(nums[::2],nums[1::2]):
     assert min(max(abs(x-anchor[0]-28*(a-source[0])/length),abs(y-anchor[1]+28*(b-source[1])/length)) for a,b in points)<.002
  checks.append('All staff, full/half tick and flag vertices agree within .002 px after translation and 28 px length normalization; default hemisphere orientation checked')
 return dict(svg_elements=dict(tags),assertions=checks)

def main():
 p=argparse.ArgumentParser();p.add_argument('reference',type=Path);p.add_argument('moxi',type=Path);a=p.parse_args()
 root=ROOT/'artifacts/demo-slideshows';revision=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
 scopes=['python/moxi','src/moxi_plot','src/moxi/scenarios.mojo','scripts/wave_c','tests/plot_specialized_c.mojo','tests/test_specialized_c.py','tests/fixtures/wave_c/cases.json','pixi.toml','pixi.lock','docs/dataviz-capabilities.tsv','docs/plot-specialized-wave-c.md']
 files=sorted(p for name in scopes for p in ((ROOT/name).rglob('*') if (ROOT/name).is_dir() else [ROOT/name]) if p.is_file() and '__pycache__' not in p.parts)
 hashes={str(p.relative_to(ROOT)):digest(p) for p in files};source_hash=hashlib.sha256(json.dumps(hashes,sort_keys=True).encode()).hexdigest()
 dirty=subprocess.check_output(['git','status','--porcelain','--',*scopes],cwd=ROOT,text=True)
 source_state=dict(scoped_sha256=source_hash,files=hashes,status=dirty)
 selections=json.loads((a.moxi/'selections.json').read_text());bench=json.loads((a.moxi/'benchmarks.json').read_text());provenance=json.loads((a.reference/'provenance.json').read_text())
 provenance.update(moxi_canvas_revision='8fcb0c83966ef872248239f9dafd6baaba06204e',moxi_lock_sha256=digest(ROOT/'pixi.lock'))
 report=dict(revision=revision,source_state=source_state,upstream=provenance,host=platform.platform(),python=platform.python_version(),mojo=subprocess.check_output(['pixi','run','mojo','--version'],cwd=ROOT,text=True).strip(),common_differences=COMMON,cases={})
 for case in CASES:
  name=case['id'];demo='e03-'+name.replace('_','-');out=root/demo;out.mkdir(parents=True,exist_ok=True);f=figure(case);g=layout(f.spec.layers[0],f.data)
  samples=[]
  for _ in range(7):
   start=time.perf_counter()
   for _ in range(10):layout(f.spec.layers[0],f.data)
   samples.append(time.perf_counter()-start)
  record=dict(classification=NOTES[name],geometry=dict(Counter(p.kind.value for p in g.glyphs)),source_rows=len(g.rows),selection=selections[name],benchmark=dict(mojo=bench[name],python=dict(n=7,iterations=10,samples_seconds=samples,median=statistics.median(samples),stdev=statistics.stdev(samples),excludes='Rendering/export/browser/native input')))
  if name!='tricontour':record['upstream_structure']=structural(a.reference,name,g)
  else:record['missing_gate']='No tricontour implementation in pinned dataviz; no reference image substituted'
  sources=[(a.moxi/(name+'-canvas.png'),'moxi.png'),(a.moxi/(name+'-selected.png'),'selected.png'),(a.moxi/(name+'-updated.png'),'05-update.png'),(a.moxi/(name+'-restored.png'),'06-recovery.png')]
  if name!='tricontour':sources.append((a.reference/(name+'.png'),'02-reference.png'))
  for source,target in sources:shutil.copyfile(source,out/target)
  for ext in ('svg','pdf','png'):shutil.copyfile(a.moxi/(name+'-python.'+ext),out/('export.'+ext))
  record['artifact_sha256']={target:digest(out/target) for _,target in sources}
  record['artifact_sha256'].update({'export.'+ext:digest(out/('export.'+ext)) for ext in ('svg','pdf','png')})
  if name!='tricontour':record['reference_svg_sha256']=digest(a.reference/(name+'.svg'))
  record['scene_svg_sha256']=digest(a.moxi/(name+'-scene.svg'))
  record['source_csv_sha256']=digest(a.moxi/(name+'-table.csv'))
  report['cases'][name]=record
  layer=json.loads(f.spec.to_json())['layers'][0]
  contract={k:v for k,v in layer.items() if k in ('mark','layout_version','x','y','y2','series_fields','triangles','levels') and v not in ('',[])}
  schema='{\n'+',\n'.join('  '+json.dumps(k)+': '+json.dumps(v) for k,v in contract.items())+'\n}'
  (out/'source.html').write_text(page(name,'<h2>1 · Source data and schema</h2><div class="pair"><section>'+table(case['columns'])+'</section><pre>'+html.escape(schema)+'</pre></div>',revision,source_hash))
  missing='<h2>Reference unavailable</h2><p>The exact pinned checkout has no tricontour module or API. Inventory mismatch confirmed by source inspection. No replacement reference is shown.</p><pre>'+html.escape(json.dumps(provenance,indent=2))+'</pre>'
  if name=='tricontour':(out/'reference.html').write_text(page(name,missing,revision,source_hash))
  reference='<img src="02-reference.png" alt="Pinned dataviz output">' if name!='tricontour' else '<section style="width:560px"><h2>Reference unavailable</h2><p>The pinned checkout has no tricontour module or API. No replacement image is shown. Full dependency provenance is on the preceding reference slide.</p></section>'
  (out/'comparison.html').write_text(page(name,'<h2>3 · Pinned upstream / actual Moxi Scene and Canvas</h2><div class="pair">'+reference+'<img src="moxi.png" alt="Moxi Canvas output"></div><p>'+NOTES[name]+'</p><p>'+COMMON+'</p>',revision,source_hash))
  with (a.moxi/(name+'-table.csv')).open() as file:rows=list(csv.DictReader(file))
  columns={k:[r[k] for r in rows] for k in rows[0]}
  (out/'selection.html').write_text(page(name,'<h2>4 · Recorded PlotView click and actual source-table export</h2><div class="pair"><img src="selected.png"><section>'+table(columns,selections[name]['row_index'])+'<pre>'+html.escape(json.dumps(selections[name],indent=2))+'</pre><p>Actual dispatch: selected_count=1.<br>Keys deliberately non-contiguous.<br>Aggregate source identities retained.<br>Source semantic subtree includes invisible rows.<br>VoiceOver remains paused.</p></section></div>',revision,source_hash))
  phases=[('initial','browser','01-source.png','Source data/schema','Open source.html','Actual fixture and version-1 contract'),('initial','browser' if name=='tricontour' else 'offscreen-render','02-reference.png','Missing pinned reference' if name=='tricontour' else 'Real pinned upstream output','Open reference.html' if name=='tricontour' else 'Run pinned upstream.py','Missing gate is explicit' if name=='tricontour' else 'Actual pinned PNG'),('result','browser','03-comparison.png','Actual Moxi / reference comparison','Open comparison.html','Classified structural and visual differences'),('interaction','browser','04-selection.png','Actual source-key event replay and CSV fallback','Open selection.html after Mojo click dispatch','Selected source row and complete table'),('result','offscreen-render','05-update.png','Source update and export','PlotView.replace_data(changed); Python SVG/PDF/PNG exports','Actual recomputed geometry and cleared selection'),('recovery','offscreen-render','06-recovery.png','Reject invalid data and restore source','Reject nonfinite replacement; restore original snapshot','Original Canvas pixels restored exactly')]
  slides=[dict(phase=phase,capture_kind=kind,image=image,dimensions=[1280,800] if kind=='browser' else [640,480],caption=caption,action=action,expected=expected) for phase,kind,image,caption,action,expected in phases]
  manifest=dict(version=1,demo_id=demo,title='E03 '+name,scenario=NOTES[name]+' '+COMMON,revision=revision,source_dirty=bool(dirty),source_state=source_state,host=platform.platform(),backend='Mojo Scene/Canvas, pinned dataviz, collaborative browser evidence replay',scale=1,fixture='tests/fixtures/wave_c/cases.json#'+name,reproduce='Follow docs/plot-specialized-wave-c.md. Run upstream.py, verify.py, evidence.py; capture source/comparison/selection pages through T3 preview at 1280x800 (tricontour reference.html too); run scripts/wave_c/slideshows.py.',slides=slides)
  (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
 (ROOT/'tests/fixtures/wave_c/observed.json').write_text(json.dumps(report,indent=2)+'\n')
 print('Prepared 12 evidence sequences. Browser captures required; tricontour reference remains missing.')
if __name__=='__main__':main()
