#!/usr/bin/env python3
"""Compile the same column/PlotSpec fixtures in Mojo; compare primitive geometry."""
import argparse
import copy
import csv
import json
import subprocess
from PIL import Image, ImageChops
from pathlib import Path
from fixtures import CASES, ROOT, figure
from moxi.specialized import GlyphKind, layout


def generate(output):
    lines=['from moxi import test_check', 'from moxi_plot.plot_spec import plot_spec_from_json', 'from moxi_plot import PlotDataTable', 'from plot_specialized import check_case', '']
    for case in CASES:
        name=case['id'];columns=case['columns']
        lines += [f'def case_{name}() raises:', '    var data = PlotDataTable()']
        for field, values in columns.items():
            method='add_string_column' if isinstance(values[0],str) else 'add_float_column'
            lines.append(f'    _ = data.{method}({json.dumps(field)})')
        for i in range(len(columns['category'])):
            lines.append(f'    _ = data.append_with_key({i}, 0.0, 0.0)')
            for field,values in columns.items():
                method='set_string_field' if isinstance(values[0],str) else 'set_float_field'
                lines.append(f'    _ = data.{method}({json.dumps(field)}, {i}, {json.dumps(values[i],ensure_ascii=False)})')
        doc=figure(case).spec.to_json()
        lines.append(f'    check_case("{name}", {json.dumps(doc,ensure_ascii=False)}, data, {json.dumps(str(output))})')
    lines += ['', 'def main() raises:']
    for index,(field,value) in enumerate([('layout_version',True),('layout_version',1.0),('horizontal','false'),('percent',1)]):
        malformed=copy.deepcopy(json.loads(figure(CASES[0]).spec.to_json()))
        malformed['layers'][0][field]=value
        literal=json.dumps(json.dumps(malformed,separators=(',',':')))
        lines.append(f'    var malformed_{index} = plot_spec_from_json({literal})')
        lines.append(f'    test_check(not malformed_{index}.validate())')
    lines += ['    case_'+c['id']+'()' for c in CASES]
    return '\n'.join(lines)+'\n'


def main():
    parser=argparse.ArgumentParser();parser.add_argument('output', type=Path);args=parser.parse_args()
    output=args.output.resolve();output.mkdir(parents=True,exist_ok=True)
    driver=output/'wave_a_driver.mojo';driver.write_text(generate(output))
    command=['pixi','run','mojo','run','-I','src','-I','tests',str(driver)]
    result=subprocess.run(command,cwd=ROOT,text=True,capture_output=True)
    (output/'run.log').write_text(result.stdout+result.stderr)
    if result.returncode:raise SystemExit(f'Mojo failed: {output}/run.log')
    glyphs={c['id']:[] for c in CASES};bench={}
    for line in result.stdout.splitlines():
        parts=[x.strip() for x in line.split('|')]
        if parts[0]=='spec':
            case=next(c for c in CASES if c['id']==parts[1])
            assert json.loads(parts[2])==json.loads(figure(case).spec.to_json()), parts[1]
        elif parts[0]=='glyph':glyphs[parts[1]].append(parts[2:])
        elif parts[0]=='benchmark':bench[parts[1]]={'scene_30_seconds':float(parts[2]),'command_count_sum':int(parts[3])}
    for case in CASES:
        f=figure(case);g=layout(f.spec.layers[0], f.data).glyphs;actual=glyphs[case['id']]
        with (output/(case['id']+'-table.csv')).open(newline='') as source:
            rows=list(csv.DictReader(source))
        assert len(rows)==len(case['columns']['category'])
        for index,row in enumerate(rows):
            assert None not in row and int(row['key'])==index
            for field,values in case['columns'].items():
                expected=values[index]
                assert (row[field]==expected if isinstance(expected,str) else float(row[field])==expected), (case['id'],field,row)
        assert len(g)==len(actual),(case['id'],len(g),len(actual))
        for expected,a in zip(g,actual):
            kind={GlyphKind.RECT:1,GlyphKind.SEGMENT:2,GlyphKind.POINT:3}[expected.kind]
            assert (kind,expected.row,expected.part)==(int(a[0]),int(a[1]),a[2]),(case['id'],a,expected)
            assert max(abs(x-float(y)) for x,y in zip(expected.bounds,a[3:]))<0.0001,(case['id'],a,expected)
        (output/(case['id']+'-python.png')).write_bytes(f.to_png())
        original=Image.open(output/(case['id']+'-canvas.png')).convert('RGB')
        restored=Image.open(output/(case['id']+'-restored.png')).convert('RGB')
        updated=Image.open(output/(case['id']+'-updated.png')).convert('RGB')
        assert ImageChops.difference(original,restored).getbbox() is None, case['id']+' restore'
        assert ImageChops.difference(original,updated).getbbox() is not None, case['id']+' update'

    (output/'benchmarks.json').write_text(json.dumps(bench,indent=2))
    print(f'Nine Wave A layouts: Mojo/Python schema, glyphs, exact hit testing, Scene/software/Canvas/SVG passed. {output}/run.log')

if __name__=='__main__':main()
