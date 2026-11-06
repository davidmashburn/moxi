#!/usr/bin/env python3
"""Run real pinned upstream APIs; record absent contour APIs without substitution."""
import argparse
import hashlib
import json
import os
import subprocess
from pathlib import Path
from fixtures import load_cases

PIN='3fd5a7e7c622d6130c99a290b88c4fee039deab2'
CANVAS_PIN='58fb12a471a65dfbc29ebc743860448439a6af22'


def generate(output):
    lines=['from dataviz import Plot','from dataviz.plot import save','from dataviz.theme import Theme','from canvas import Color','from std.time import perf_counter','']
    for case in load_cases():
        if not case['reference_available']:continue
        name=case['id'];c=case['columns'];lines += [f'def case_{name}() raises:']
        def var(key,values,kind='Float64'):lines.append(f'    var {key}: List[{kind}] = '+json.dumps(values))
        var('values',c[case['y']])
        method='encode_categorical(categories, values)';mark=f'mark_{name}()'
        if isinstance(c[case['x']][0],str):var('categories',c[case['x']],'String')
        if name in ('pie','donut'):mark='mark_arc(inner_radius_fraction='+('0.5' if name=='donut' else '0.0')+')'
        elif name=='gauge':method=f'encode_gauge({c[case["y"]][0]}, {c["minimum"][0]}, {c["maximum"][0]})'
        elif name=='polar':
            var('angles',c['angle']);method='encode_polar(angles, values)'
        elif name=='radar':
            var('maxima',c['maximum']);var('names',case['layout']['series_fields'],'String');var('matrix',[c[f] for f in case['layout']['series_fields']],'List[Float64]');method='encode_radar(categories, maxima, names, matrix)'
        elif name=='streamgraph':
            var('names',case['layout']['series_fields'],'String');var('matrix',[c[f] for f in case['layout']['series_fields']],'List[Float64]');method='encode_grouped_bar(categories, names, matrix)'
        elif name in ('beeswarm','violin','ridgeline'):
            groups=list(dict.fromkeys(c[case['x']]))
            var('groups',groups,'String');var('matrix',[[c[case['y']][i] for i,g in enumerate(c[case['x']]) if g==group] for group in groups],'List[Float64]');method='encode_distribution(groups, matrix)'
        # No title reserve: the same 560×416 margin box as Moxi. Fonts still
        # recorded because real upstream renders axis labels and gauge values.
        lines += ['    var theme = Theme(background=Color(17,22,35), axis_color=Color(191,204,229), text_color=Color(191,204,229), gridline_color=Color(63,76,102), font_family="DejaVu Sans", margin_left=48, margin_right=32, margin_top=28, margin_bottom=36, show_legend=False, show_gridlines=False, point_radius=3.0, mark_color=Color(64,191,255), line_smoothing=0.0)',f'    var p = Plot().{mark}.{method}.theme(theme).size({case["width"]},{case["height"]})','    var start = perf_counter()']
        for ext in ('png','svg'):lines.append('    save(p, '+json.dumps(str(output/(name+'.'+ext)))+')')
        lines.append(f'    print("{name}"," export_seconds=",perf_counter()-start)')
    lines += ['','def main() raises:']+['    case_'+c['id']+'()' for c in load_cases() if c['reference_available']]
    return '\n'.join(lines)+'\n'


def main():
    p=argparse.ArgumentParser();p.add_argument('checkout',type=Path);p.add_argument('output',type=Path);p.add_argument('--font-dir',type=Path,required=True);a=p.parse_args()
    checkout=a.checkout.resolve();output=a.output.resolve();output.mkdir(parents=True,exist_ok=True)
    revision=subprocess.check_output(['git','-C',str(checkout),'rev-parse','HEAD'],text=True).strip();assert revision==PIN
    assert not subprocess.check_output(['git','-C',str(checkout),'status','--porcelain'],text=True).strip()
    lock=(checkout/'pixi.lock').read_text();assert CANVAS_PIN in lock
    assert not (checkout/'dataviz/contour.mojo').exists()
    # A tracked-tree search is retained as evidence of the absent API, not an image.
    absent=subprocess.run(['git','-C',str(checkout),'grep','-n','-i','contour','HEAD','--','dataviz'],capture_output=True,text=True)
    assert absent.returncode==1,absent.stdout
    (output/'contour-reference-unavailable.txt').write_text('git grep -n -i contour HEAD -- dataviz\nexit 1: no matches at '+revision+'\nNo upstream contour or contourf output exists at this pin.\n')
    driver=output/'reference.mojo';driver.write_text(generate(output))
    command=['pixi','run','--manifest-path',str(checkout/'pixi.toml'),'mojo','run','-I',str(checkout),str(driver)]
    font=a.font_dir.resolve()/'DejaVuSans.ttf';assert font.is_file()
    result=subprocess.run(command,capture_output=True,text=True,env=dict(os.environ,CANVAS_MOJO_FONT_PATH=str(a.font_dir.resolve())))
    (output/'run.log').write_text(result.stdout+result.stderr)
    provenance=dict(repository='https://github.com/randyzwitch/dataviz_mojo',revision=revision,dirty=False,canvas_revision=CANVAS_PIN,lock_sha256=hashlib.sha256((checkout/'pixi.lock').read_bytes()).hexdigest(),driver_sha256=hashlib.sha256(driver.read_bytes()).hexdigest(),font_sha256=hashlib.sha256(font.read_bytes()).hexdigest(),font_path=str(font),font_family='DejaVu Sans',command=command,returncode=result.returncode,missing=['contour','contourf'])
    (output/'provenance.json').write_text(json.dumps(provenance,indent=2)+'\n')
    print('Reference exit',result.returncode,'log',output/'run.log')
    raise SystemExit(result.returncode)

if __name__=='__main__':main()
