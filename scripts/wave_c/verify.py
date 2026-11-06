#!/usr/bin/env python3
"""Real Mojo/Python contracts, geometry, identity, rendering, events and recovery."""
import argparse, copy, csv, json, statistics, subprocess
from pathlib import Path
from PIL import Image, ImageChops
from fixtures import CASES,ROOT,figure
from moxi.specialized import layout,GlyphKind

def changed(case):
    c=copy.deepcopy(case['columns']); name=case['id']
    field=case['y'];row=0
    if name in ('treemap','sunburst'):row=3
    elif name=='tree':c[case['channels']['y2_field']][-1]='A';return c
    elif name in ('corrplot','marimekko','punchcard','barbs','tricontour'):
        field=case['layout']['series_fields'][0]
        if name=='tricontour':row=4
        if name=='barbs':row=1
    c[field][row]=c[field][row]*.7+(.05 if name=='corrplot' else 10 if name=='barbs' else 1)
    return c

def invalid(case):
    c=copy.deepcopy(case['columns']);name=case['id']
    field=case['y']
    if name in ('corrplot','marimekko','punchcard','barbs','tricontour'):field=case['layout']['series_fields'][0]
    c[field][0]=float('inf');return c

def table(lines,var,columns):
    lines.append(f'    var {var}=PlotDataTable()')
    for f,vs in columns.items():
        kind='string' if vs and isinstance(vs[0],str) else 'float'
        lines.append(f'    _ = {var}.add_{kind}_column({json.dumps(f)})')
    for i in range(len(next(iter(columns.values())))):
        lines.append(f'    _ = {var}.append_with_key({100+i*7},0,0)')
        for f,vs in columns.items():
            kind='string' if isinstance(vs[i],str) else 'float'
            value=json.dumps(vs[i],ensure_ascii=False)
            if value in ('Infinity','-Infinity','NaN'):value='Float32(1)/Float32(0)' if value=='Infinity' else 'Float32(0)/Float32(0)'
            lines.append(f'    _ = {var}.set_{kind}_field({json.dumps(f)},{i},{value})')

def generate(output):
    lines=['from moxi_plot.plot_data import PlotDataTable','from plot_specialized_c import check_case, check_rejection, check_positive','']
    for case in CASES:
        lines.append('def case_'+case['id']+'() raises:')
        table(lines,'data',case['columns']);table(lines,'changed',changed(case));table(lines,'invalid',invalid(case))
        lines.append('    changed.version = data.version + 1')
        lines.append('    check_case('+','.join(json.dumps(s) for s in [case['id'],figure(case).spec.to_json()])+',data,changed,invalid,'+json.dumps(str(output))+')')
    from boundaries import negatives,positives
    for i,(case,columns,doc) in enumerate(negatives()):
        lines.append(f'def negative_{i}():')
        lines.append(f'    print("boundary|negative_{i}|{case["id"]}")')
        table(lines,'data',columns)
        lines.append('    check_rejection('+json.dumps(json.dumps(doc,separators=(",",":")))+',data)')
    for i,(case,columns) in enumerate(positives()):
        lines.append(f'def positive_{i}():')
        lines.append(f'    print("boundary|positive_{i}|{case["id"]}")')
        table(lines,'data',columns)
        f=figure(case,columns);g=layout(f.spec.layers[0],f.data)
        doc=json.loads(f.spec.to_json());doc['layers'][0].update(opacity=.5,size=12,line_width=3)
        lines.append('    check_positive('+json.dumps(json.dumps(doc,separators=(",",":")))+',data,'+str(len(g.glyphs))+')')
    lines+=['def main() raises:']+['    case_'+c['id']+'()' for c in CASES]+[f'    negative_{i}()' for i,_ in enumerate(negatives())]+[f'    positive_{i}()' for i,_ in enumerate(positives())]
    return '\n'.join(lines)+'\n'

def main():
    p=argparse.ArgumentParser();p.add_argument('output',type=Path);a=p.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=True)
    driver=out/'driver.mojo';driver.write_text(generate(out))
    r=subprocess.run(['pixi','run','mojo','run','-I','src','-I','tests',str(driver)],cwd=ROOT,text=True,capture_output=True)
    (out/'run.log').write_text(r.stdout+r.stderr)
    if r.returncode:raise SystemExit('Mojo failed: '+str(out/'run.log'))
    glyphs={c['id']:[] for c in CASES};bench={c['id']:[] for c in CASES};selections={}
    for line in r.stdout.splitlines():
        a=[s.strip() for s in line.split('|')]
        if a[0]=='spec':assert json.loads(a[2])==json.loads(figure(next(c for c in CASES if c['id']==a[1])).spec.to_json())
        elif a[0]=='glyph':glyphs[a[1]].append(a[2:])
        elif a[0]=='benchmark':bench[a[1]].append(float(a[3]))
        elif a[0]=='selection':selections[a[1]]=dict(row_key=int(a[2]),row_index=(int(a[2])-100)//7,x=float(a[3]),y=float(a[4]),source_keys=a[5])
    for case in CASES:
        name=case['id'];f=figure(case);g=layout(f.spec.layers[0],f.data).glyphs
        actual=glyphs[name];assert len(g)==len(actual),(name,len(g),len(actual))
        for expected,a in zip(g,actual):
            kind={GlyphKind.RECT:1,GlyphKind.SEGMENT:2,GlyphKind.POINT:3,GlyphKind.TRIANGLE:5}[expected.kind]
            assert (kind,100+expected.row*7)==(int(a[0]),int(a[1])),(name,a,expected)
            assert expected.part==a[2] or (name=='tricontour' and expected.part.split(':level:')[0]==a[2].split(':level:')[0]),(name,a,expected)
            coords=expected.bounds+(expected.vertices[0] if expected.vertices else (0,0))
            assert max(abs(x-float(y)) for x,y in zip(coords,a[3:9]))<2e-5,(name,a,expected)
            assert a[9]==','.join(str(100+7*i) for i in expected.source_rows),(name,a,expected)
            assert (a[10]=='True')==expected.interactive
            assert abs(float(a[11])-expected.size)<1e-4
            assert abs(float(a[12])-expected.stroke_width)<1e-4
        with (out/(name+'-table.csv')).open() as file:rows=list(csv.DictReader(file))
        assert len(rows)==len(next(iter(case['columns'].values())))
        for i,row in enumerate(rows):
            assert int(row['key'])==100+7*i
            for field,values in case['columns'].items():assert row[field]==values[i] if isinstance(values[i],str) else float(row[field])==values[i]
        (out/(name+'-python.png')).write_bytes(f.to_png())
        f.save(out/(name+'-python.svg'));f.save(out/(name+'-python.pdf'))
        original=Image.open(out/(name+'-canvas.png')).convert('RGB')
        assert ImageChops.difference(original,Image.open(out/(name+'-restored.png')).convert('RGB')).getbbox() is None,name
        assert ImageChops.difference(original,Image.open(out/(name+'-updated.png')).convert('RGB')).getbbox() is not None,name+' update'
    summary={k:dict(samples_seconds=v,n=len(v),iterations=10,median=statistics.median(v),stdev=statistics.stdev(v),excludes='Compilation, rasterization, PNG/SVG export, browser, native input') for k,v in bench.items()}
    (out/'benchmarks.json').write_text(json.dumps(summary,indent=2));(out/'selections.json').write_text(json.dumps(selections,indent=2))
    print('12 Wave C geometry/source-key/contract/Scene/Canvas/event/update/recovery cases passed; '+str(out/'run.log'))
if __name__=='__main__':main()
