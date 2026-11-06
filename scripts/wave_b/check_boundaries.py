#!/usr/bin/env python3
"""Compile independent rejection/degeneracy examples through the Mojo parser."""
import json, math, subprocess
from pathlib import Path
from fixtures import ROOT, figure, load_cases
from boundaries import examples

out=Path('/tmp/moxi-e02-boundaries');out.mkdir(exist_ok=True)
lines=['from moxi import test_check, Rect','from moxi_plot import PlotDataTable','from moxi_plot.plot_spec import plot_spec_from_json, plot_from_spec','from std.math import isfinite','']
original={c['id']:c for c in load_cases()}
for index,(label,c,valid) in enumerate(examples()):
    lines += [f'def boundary_{index}() raises:','    var data = PlotDataTable()']
    for f,v in original[c['id']]['columns'].items():
        kind='string' if isinstance(v[0],str) else 'float';lines.append(f'    _ = data.add_{kind}_column({json.dumps(f)})')
    for i in range(len(c['columns'][c['x']])):
        lines.append(f'    _ = data.append_with_key({100+i*7},0,0)')
        for f,v in c['columns'].items():
            kind='string' if isinstance(original[c['id']]['columns'][f][0],str) else 'float'
            value=json.dumps(v[i])
            if isinstance(v[i],float) and not math.isfinite(v[i]):value='Float32(0)/Float32(0)' if math.isnan(v[i]) else 'Float32(1)/Float32(0)'
            lines.append(f'    _ = data.set_{kind}_field({json.dumps(f)},{i},{value})')
    lines += [f'    var spec = plot_spec_from_json({json.dumps(figure(original[c["id"]]).spec.to_json())})',f'    print("boundary|{label}")',f'    test_check(spec.validate_data(data) == {valid})']
    if valid:
        lines += ['    var plot = plot_from_spec(spec,data,Rect(0,0,640,480))','    for p in plot.series[0].points:','        test_check(isfinite(p.x) and isfinite(p.y) and isfinite(p.x2) and isfinite(p.y2))']
        if label.endswith('-plane'):
            if c['id']=='contour':lines+=['    for p in plot.series[0].points:', '        test_check(abs((p.x+p.y)-(p.x2+p.y2)) < .00001)']
            else:lines+=['    var area: Float32 = 0', '    for p in plot.series[0].points:', '        var cross: Float32 = 0', '        for i in range(len(p.vertices)):', '            var a = p.vertices[i]', '            var b = p.vertices[(i+1)%len(p.vertices)]', '            cross += a.x*b.y-b.x*a.y', '        area += abs(cross)*.5', '    test_check(abs(area-1) < .00001)']
        if label.endswith('-flat'):lines+=['    test_check(len(plot.series[0].points) == 0)']
lines += ['def radar_capacity() raises:', '    var data = PlotDataTable()',
          '    _ = data.add_float_column("maximum")',
          '    for i in range(4096):', '        _ = data.append_with_key(i,Float32(i),1)',
          '        _ = data.set_float_field("maximum",i,2)',
          f'    var spec = plot_spec_from_json({json.dumps(figure(original["radar"]).spec.to_json())})']
# Reuse the actual parsed radar layer, with the existing default numeric fields.
lines += ['    spec.layers[0].x_field = "x"', '    spec.layers[0].y_field = "y"',
          '    spec.layers[0].y2_field = "maximum"', '    spec.layers[0].series_fields_json = "[]"',
          '    test_check(spec.validate() and not spec.validate_data(data))',
          '    print("boundary|radar-capacity")']
lines+=['def main() raises:', '    radar_capacity()']+['    boundary_'+str(i)+'()' for i in range(len(examples()))]
driver=out/'driver.mojo';driver.write_text('\n'.join(lines)+'\n')
r=subprocess.run(['pixi','run','mojo','run','-I','src',str(driver)],cwd=ROOT,capture_output=True,text=True)
Path('/tmp/moxi-e02-boundaries.log').write_text(r.stdout+r.stderr)
print(len(examples())+1,'boundary examples; exit',r.returncode)
raise SystemExit(r.returncode)
