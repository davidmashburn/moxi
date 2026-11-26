#!/usr/bin/env python3
"""Compile the same column/PlotSpec fixtures in Mojo; compare primitive geometry."""
import argparse
import copy
import csv
import hashlib
import json
import xml.etree.ElementTree as ET
import subprocess
from pathlib import Path
from fixtures import CASES, ROOT, figure
from moxi.specialized import GlyphKind, PALETTE, layout


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


def check_canvas_labels(case, output):
    from PIL import Image

    name = case['id']
    root = ET.parse(output / (name + '-scene.svg'))
    labels = root.findall('.//{*}text[@font-family="monospace"]')
    categories = case['columns']['category']
    if name in ('population_pyramid', 'gantt'):
        categories = categories[::-1]
    legend = (['Left', 'Right'] if name == 'population_pyramid'
              else case['layout'].get('series_fields', []))
    assert [node.text for node in labels] == categories + legend, name
    with Image.open(output / (name + '-canvas.png')) as canvas, Image.open(output / (name + '-software.ppm')) as software:
        boxes = []
        for index, node in enumerate(labels):
            x = int(float(node.get('x')))
            y = int(float(node.get('y'))) - 9
            box = (x, y, x + 7 * len(node.text), y + 9)
            assert 0 <= x < box[2] <= canvas.width and 0 <= y < box[3] <= canvas.height
            assert all(box[2] <= a or x >= c or box[3] <= b or y >= d for a,b,c,d in boxes), (name, node.text)
            boxes.append(box)
            for frame in (canvas, software):
                assert len(frame.crop(box).getcolors()) > 1, (name, node.text)
                if index >= len(categories):
                    color = frame.getpixel((x - 9, y + 4))
                    expected = PALETTE[(index - len(categories)) % len(PALETTE)]
                    assert all(abs(c - 255 * v) <= 1 for c, v in zip(color[:3], expected)), (name, node.text)
                    assert color in {c for _, c in frame.crop((48, 28, 608, 428)).getcolors(640 * 480)}, (name, node.text)


def compare_reference(case, output, gallery, observed):
    """Compare the pinned image, native Canvas and Python PNG at original scale."""
    from PIL import Image

    name = case['id']
    reference = gallery / ('e01-' + name.replace('_', '-')) / '02-reference.png'
    assert hashlib.sha256(reference.read_bytes()).hexdigest() == observed[name]['sha256']['reference_png'], name
    paths = [reference, output / (name + '-canvas.png'), output / (name + '-python.png')]
    comparison = Image.new('RGB', (1920, 480))
    for column, path in enumerate(paths):
        with Image.open(path) as frame:
            assert frame.size == (640, 480)
            comparison.paste(frame.convert('RGB'), (640 * column, 0))
    comparison.save(output / (name + '-comparison.png'))


def main():
    parser=argparse.ArgumentParser();parser.add_argument('output', type=Path)
    parser.add_argument('--gallery', type=Path, help='directory containing verified e01-*/02-reference.png captures')
    parser.add_argument('--mojo-only', action='store_true', help='run fixture-backed Mojo regressions without Python image comparisons or Pillow')
    args=parser.parse_args()
    output=args.output.resolve();output.mkdir(parents=True,exist_ok=True)
    driver=output/'wave_a_driver.mojo';driver.write_text(generate(output))
    command=['pixi','run','mojo','run','-I','src','-I','tests',str(driver)]
    result=subprocess.run(command,cwd=ROOT,text=True,capture_output=True)
    (output/'run.log').write_text(result.stdout+result.stderr)
    if result.returncode:raise SystemExit(f'Mojo failed: {output}/run.log')
    if args.mojo_only:
        print(f'Nine Wave A Mojo fixture regressions passed. {output}/run.log')
        return
    from PIL import Image, ImageChops

    observed = json.loads((ROOT / 'tests/fixtures/wave_a/observed.json').read_text())['cases']
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
        check_canvas_labels(case, output)
        if args.gallery:
            compare_reference(case, output, args.gallery, observed)
        original=Image.open(output/(case['id']+'-canvas.png')).convert('RGB')
        restored=Image.open(output/(case['id']+'-restored.png')).convert('RGB')
        updated=Image.open(output/(case['id']+'-updated.png')).convert('RGB')
        assert ImageChops.difference(original,restored).getbbox() is None, case['id']+' restore'
        assert ImageChops.difference(original,updated).getbbox() is not None, case['id']+' update'

    (output/'benchmarks.json').write_text(json.dumps(bench,indent=2))
    print(f'Nine Wave A layouts: Mojo/Python schema, glyphs, exact hit testing, Scene/software/Canvas/SVG passed. {output}/run.log')

if __name__=='__main__':main()
