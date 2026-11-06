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
    lines = ['from dataviz import Plot', 'from dataviz.plot import save', 'from dataviz.theme import Theme', 'from std.time import perf_counter', '']
    for case in CASES:
        name = case['id']; c = case['columns']; options = case['layout']
        lines += [f'# Fixture {name}; identical inputs to Moxi.', f'def case_{name}() raises:']
        def var(key, values, kind='Float64'):
            lines.append(f'        var {key}: List[{kind}] = '+ ('['+', '.join('True' if v else 'False' for v in values)+']' if kind=='Bool' else quoted(values)))
        var('categories', c['category'], 'String');var('values',c['value'])
        method = 'encode_categorical(categories, values)'
        mark = f'mark_{name}()'
        if name=='waterfall':
            var('totals',c['total'],'Bool');method='encode_waterfall(categories, values, totals)'
        elif name=='candlestick':
            for field in ('open','high','low'):var(field,c[field])
            method='encode_candlestick(categories, open, high, low, values)'
        elif name=='bullet':
            var('targets',c['target'])
            var('ranges',[[c[f][i] for f in options['range_fields']] for i in range(len(c['category']))], 'List[Float64]')
            method='encode_bullet(categories, values, targets, ranges)'
        elif name in ('grouped_bar','stacked_bar'):
            var('names',options['series_fields'],'String');var('matrix',[c[f] for f in options['series_fields']], 'List[Float64]')
            method='encode_grouped_bar(categories, names, matrix)'
            if options.get('error_fields'):
                var('errors',[c[f] for f in options['error_fields']], 'List[Float64]')
                method='encode_grouped_bar(categories, names, matrix, errors)'
        elif name in ('gantt','span_chart'):
            var('ends',c['end']);method='encode_gantt(categories, values, ends)'
        elif name=='population_pyramid':
            var('right',c['right']);method='encode_population_pyramid(categories, values, right)'
        lines.append(f'        var p = Plot().{mark}.{method}.theme(Theme(font_family="DejaVu Sans")).size(640, 480).labels(title="Wave A: {name}")')
        lines.append('        var start = perf_counter()')
        for extension in ('png','svg'):
            lines.append(f'        save(p, {quoted(str(destination / (name+"."+extension)))})')
        lines.append(f'        print("{name}", " export_seconds=", perf_counter()-start)')
    lines = [line[4:] if line.startswith('        ') else line for line in lines]
    lines += ['', 'def main() raises:'] + ['    case_'+case['id']+'()' for case in CASES]
    return '\n'.join(lines)+'\n'


def main():
    parser=argparse.ArgumentParser();parser.add_argument('checkout',type=Path);parser.add_argument('output',type=Path);parser.add_argument('--font-dir',type=Path,required=True);args=parser.parse_args()
    checkout=args.checkout.resolve();output=args.output.resolve();output.mkdir(parents=True,exist_ok=True)
    revision=subprocess.check_output(['git','-C',str(checkout),'rev-parse','HEAD'],text=True).strip()
    if revision!=PIN:raise SystemExit(f'upstream pin mismatch: {revision}')
    if subprocess.check_output(['git','-C',str(checkout),'status','--porcelain'],text=True).strip():raise SystemExit('upstream must be clean')
    driver=output/'reference.mojo';driver.write_text(generate(output))
    command=['pixi','run','--manifest-path',str(checkout/'pixi.toml'),'mojo','run','-I',str(checkout),str(driver)]
    font_dir=args.font_dir.resolve()
    font=font_dir/'DejaVuSans.ttf'
    if not font.is_file():raise SystemExit('font-dir must contain DejaVuSans.ttf')
    environment=dict(os.environ, CANVAS_MOJO_FONT_PATH=str(font_dir))
    result=subprocess.run(command,capture_output=True,text=True,env=environment)
    (output/'run.log').write_text(result.stdout+result.stderr)
    (output/'provenance.json').write_text(json.dumps({'repository':'https://github.com/randyzwitch/dataviz_mojo','revision':revision,'dirty':False,'command':command,'returncode':result.returncode,'font_dir':str(font_dir),'font_sha256':hashlib.sha256(font.read_bytes()).hexdigest(),'font_family':'DejaVu Sans'},indent=2))
    print('reference:', result.returncode, output/'run.log')
    raise SystemExit(result.returncode)

if __name__=='__main__':main()
