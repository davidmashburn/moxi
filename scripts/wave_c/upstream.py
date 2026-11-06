#!/usr/bin/env python3
"""Generate and run actual pinned dataviz APIs, without editing upstream sources."""
import argparse
import os
import hashlib
import json
import subprocess
from pathlib import Path
from fixtures import CASES

PIN = '3fd5a7e7c622d6130c99a290b88c4fee039deab2'


def quoted(value):
    return json.dumps(value, ensure_ascii=False)


def generate(destination):
    lines=['from dataviz import Plot','from dataviz.plot import save','from dataviz.theme import Theme','from std.time import perf_counter','']
    for case in CASES:
        name=case['id'];c=case['columns'];fields=case.get('layout',{}).get('series_fields',[])
        if name=='tricontour':continue # absent at the required pin; never substitute
        lines.append('def case_'+name+'() raises:')
        def var(key,values,kind='Float64'):
            lines.append('    var '+key+': List['+kind+'] = '+quoted(values))
        mark='mark_'+name+'()'
        if name in ('treemap','sunburst','tree'):
            var('ids',c['id'],'String');var('parents',c['parent'],'String');var('values',c['value']);method='encode_hierarchy(ids,parents,values)'
        elif name in ('sankey','chord','graph'):
            var('src',c['source'],'String');var('dst',c['target'],'String');var('values',c['value']);method='encode_chord(src,dst,values)'
            if name=='sankey':mark='mark_sankey(node_width=22.4)'
        elif name=='calendar_heatmap':
            var('dates',c['date'],'String');var('values',c['value']);method='encode_calendar(dates,values)'
        elif name=='corrplot':
            mark='mark_corrplot(bubble_fraction=0.8)'
            var('variables',c['variable'],'String');var('matrix',[[c[f][i] for f in fields] for i in range(len(c['variable']))],'List[Float64]');method='encode_corrplot(variables,matrix)'
        elif name=='marimekko':
            var('categories',c['category'],'String');var('names',fields,'String');var('matrix',[c[f] for f in fields],'List[Float64]');method='encode_marimekko(categories,names,matrix)'
        elif name=='punchcard':
            var('x',c['day'],'String');var('y',c['hour'],'String');var('sizes',c['count']);method='encode_punchcard(x,y,sizes)'
        else:
            for f in ('x','y','u','v'):var(f,c[f])
            method='encode_barbs(x,y,u,v)'
        lines.append('    var p=Plot().'+mark+'.'+method+'.theme(Theme(font_family="DejaVu Sans",margin_left=48,margin_right=32,margin_top=28,margin_bottom=36,show_legend=False)).size(640,480)')
        lines.append('    var start=perf_counter()')
        for ext in ('png','svg'):lines.append('    save(p,'+quoted(str(destination/(name+'.'+ext)))+')')
        lines.append('    print("'+name+' export_seconds=",perf_counter()-start)')
    lines+=['def main() raises:']+['    case_'+c['id']+'()' for c in CASES if c['id']!='tricontour']
    return '\n'.join(lines)+'\n'


def main():
    parser=argparse.ArgumentParser();parser.add_argument('checkout',type=Path);parser.add_argument('output',type=Path);parser.add_argument('--font-dir',type=Path,required=True);args=parser.parse_args()
    checkout=args.checkout.resolve();output=args.output.resolve();output.mkdir(parents=True,exist_ok=True)
    revision=subprocess.check_output(['git','-C',str(checkout),'rev-parse','HEAD'],text=True).strip()
    if revision!=PIN:raise SystemExit(f'upstream pin mismatch: {revision}')
    if subprocess.check_output(['git','-C',str(checkout),'status','--porcelain'],text=True).strip():raise SystemExit('upstream must be clean')
    canvas_pin='58fb12a471a65dfbc29ebc743860448439a6af22'
    lock=checkout/'pixi.lock'
    if canvas_pin not in lock.read_text():raise SystemExit('reference Canvas pin mismatch')
    if any('tricontour' in p.read_text().lower() for p in (checkout/'dataviz').rglob('*.mojo')):
        raise SystemExit('reference tricontour availability changed; inspect before claiming a missing gate')
    driver=output/'reference.mojo';driver.write_text(generate(output))
    command=['pixi','run','--manifest-path',str(checkout/'pixi.toml'),'mojo','run','-I',str(checkout),str(driver)]
    font_dir=args.font_dir.resolve()
    font=font_dir/'DejaVuSans.ttf'
    if not font.is_file():raise SystemExit('font-dir must contain DejaVuSans.ttf')
    environment=dict(os.environ, CANVAS_MOJO_FONT_PATH=str(font_dir))
    result=subprocess.run(command,capture_output=True,text=True,env=environment)
    (output/'run.log').write_text(result.stdout+result.stderr)
    compiler=subprocess.check_output(command[:5]+['--version'],text=True).strip()
    (output/'provenance.json').write_text(json.dumps({'repository':'https://github.com/randyzwitch/dataviz_mojo','revision':revision,'dirty':False,'command':command,'returncode':result.returncode,'compiler':compiler,'canvas_revision':canvas_pin,'lock_sha256':hashlib.sha256(lock.read_bytes()).hexdigest(),'driver_sha256':hashlib.sha256(driver.read_bytes()).hexdigest(),'font_dir':str(font_dir),'font_sha256':hashlib.sha256(font.read_bytes()).hexdigest(),'font_family':'DejaVu Sans','tricontour_available':False},indent=2))
    print('reference:', result.returncode, output/'run.log')
    raise SystemExit(result.returncode)

if __name__=='__main__':main()
