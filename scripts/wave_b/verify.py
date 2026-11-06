#!/usr/bin/env python3
"""Cross-runtime contract, vertices, provenance, event replay and timed scenes."""
import argparse, csv, hashlib, json, subprocess, time, statistics
from pathlib import Path
from PIL import Image, ImageChops
from fixtures import load_cases, figure, ROOT
from moxi.specialized import layout, GlyphKind


def runtime_source_hash():
    paths = sorted(p for folder in ('src/moxi','src/moxi_plot','python/moxi','tests/fixtures/wave_b')
                   for p in (ROOT/folder).rglob('*') if p.is_file() and p.suffix in ('.mojo','.py','.json')
                   and p.name not in ('observed.json','source-state.json'))
    paths += [ROOT/'tests/plot_wave_b.mojo', ROOT/'pixi.lock']
    inputs = {str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
    return hashlib.sha256(json.dumps(inputs,sort_keys=True).encode()).hexdigest()


def generate(cases, output):
    lines=['from moxi_plot import PlotDataTable','from plot_wave_b import check_case','']
    for c in cases:
        name=c['id'];columns=c['columns']
        lines += [f'def case_{name}() raises:','    var data = PlotDataTable()']
        for f,v in columns.items():
            method='string' if isinstance(v[0],str) else 'float'
            lines.append(f'    _ = data.add_{method}_column({json.dumps(f)})')
        for i in range(c['rows']):
            lines.append(f'    _ = data.append_with_key({c["seed"]+3*i},0,0)')
            for f,v in columns.items():
                method='string' if isinstance(v[0],str) else 'float'
                lines.append(f'    _ = data.set_{method}_field({json.dumps(f)},{i},{json.dumps(v[i])})')
        lines.append(f'    check_case("{name}",{json.dumps(figure(c).spec.to_json())},data,{json.dumps(str(output))})')
    lines+=['def main() raises:']+['    case_'+c['id']+'()' for c in cases]
    return '\n'.join(lines)+'\n'


def main():
    p=argparse.ArgumentParser();p.add_argument('output',type=Path);a=p.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=True)
    source_hash=runtime_source_hash()
    cases=load_cases();driver=out/'driver.mojo';driver.write_text(generate(cases,out))
    r=subprocess.run(['pixi','run','mojo','run','-I','src','-I','tests',str(driver)],cwd=ROOT,capture_output=True,text=True)
    (out/'run.log').write_text(r.stdout+r.stderr)
    if r.returncode:raise SystemExit(f'Mojo failed: {out}/run.log')
    results={c['id']:dict(glyphs=[],vertices={},sources={},samples=[]) for c in cases}
    for line in r.stdout.splitlines():
        p=[v.strip() for v in line.split('|')]
        if p[0] not in ('spec','glyph','vertex','source','benchmark','selection'):continue
        dst=results[p[1]]
        if p[0]=='spec':dst['spec']=json.loads(p[2])
        elif p[0]=='glyph':dst['glyphs'].append(p[2:])
        elif p[0]=='vertex':dst['vertices'].setdefault(int(p[2]),[]).append(tuple(map(float,p[3:])))
        elif p[0]=='source':dst['sources'].setdefault(int(p[2]),[]).append(int(p[3]))
        elif p[0]=='benchmark':dst['samples'].append(float(p[3]))
        else:dst['selection']=dict(key=int(p[2]),x=float(p[3]),y=float(p[4]))
    report={}
    for c in cases:
        name=c['id'];f=figure(c);dst=results[name];expected=layout(f.spec.layers[0],f.data,560,416).glyphs
        assert dst['spec']==json.loads(f.spec.to_json()),name
        assert len(expected)==len(dst['glyphs']),(name,len(expected),len(dst['glyphs']))
        for i,(g,raw) in enumerate(zip(expected,dst['glyphs'])):
            kind={GlyphKind.RECT:1,GlyphKind.SEGMENT:2,GlyphKind.POINT:3,GlyphKind.POLYGON:4}[g.kind]
            assert (kind,c['seed']+g.row*3,g.part)==(int(raw[0]),int(raw[1]),raw[2]),(name,i,raw)
            assert max(abs(a-float(b)) for a,b in zip(g.bounds,raw[3:]))<2e-5,(name,i,g.bounds,raw)
            assert dst['sources'][i]==[c['seed']+3*r for r in g.source_rows],(name,i,'source')
            vertices=dst['vertices'].get(i,[])
            if g.kind is GlyphKind.POLYGON:
                assert len(vertices)==len(g.vertices),(name,i,len(vertices),len(g.vertices))
                assert max(abs(a-b) for v,w in zip(vertices,g.vertices) for a,b in zip(v,w))<2e-5,(name,i,'vertices')
        rows=list(csv.DictReader((out/(name+'-table.csv')).open()))
        assert len(rows)==c['rows']
        for i,row in enumerate(rows):
            assert int(row['key'])==c['seed']+3*i
            for field,values in c['columns'].items():
                assert row[field]==values[i] if isinstance(values[i],str) else abs(float(row[field])-values[i])<2e-5
        def diff(a,b):return ImageChops.difference(Image.open(out/(name+'-'+a+'.png')).convert('RGB'),Image.open(out/(name+'-'+b+'.png')).convert('RGB')).getbbox()
        assert diff('canvas','restored') is None,name+' restore'
        assert diff('updated','rejected') is None,name+' rejection'
        assert diff('canvas','updated') is not None,name+' update'
        (out/(name+'-python.png')).write_bytes(f.to_png())
        samples=[]
        for _ in range(30):
            start=time.perf_counter();layout(f.spec.layers[0],f.data,560,416);samples.append(time.perf_counter()-start)
        def summary(s):return dict(n=len(s),median_seconds=statistics.median(s),min_seconds=min(s),max_seconds=max(s),stdev_seconds=statistics.stdev(s),samples_seconds=s)
        report[name]=dict(rows=c['rows'],glyphs=len(expected),vertices=sum(len(g.vertices) for g in expected),selection=dst['selection'],mojo_layout_scene=summary(dst['samples']),python_layout=summary(samples))
    assert source_hash == runtime_source_hash(), 'Runtime inputs changed during verification; rerun before recording evidence'
    (out/'results.json').write_text(json.dumps(dict(runtime_source_sha256=source_hash,driver_sha256=hashlib.sha256(driver.read_bytes()).hexdigest(),exclusions='Compilation, Canvas rasterization, file IO, browser capture and native/GPU/human latency are excluded from timings.',cases=report),indent=2)+'\n')
    print('14 Wave B contracts, vertices/source keys, Canvas/SVG, click/keyboard/linked selection, table, update/rejection/recovery passed')

if __name__=='__main__':main()
