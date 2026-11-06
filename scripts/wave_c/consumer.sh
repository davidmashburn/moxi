#!/usr/bin/env bash
# Local precompiled-package isolation; no registry publication.
set -eu
consumer_dir="${MOXI_E03_CONSUMER_DIR:-/tmp/moxi-e03-consumer}"
python_bin="${MOXI_E03_PYTHON:-/tmp/moxi-e03-venv/bin/python}"
export MOXI_E03_CONSUMER_DIR="$consumer_dir"
mkdir -p "$consumer_dir"
pixi run mojo precompile src/moxi -o "$consumer_dir/moxi.mojoc"
pixi run mojo precompile -I "$consumer_dir" src/moxi_plot -o "$consumer_dir/moxi_plot.mojoc"
cp tests/package_consumer.mojo "$consumer_dir/base.mojo"
pixi run mojo run -I "$consumer_dir" "$consumer_dir/base.mojo"
PYTHONPATH=python:scripts/wave_c "$python_bin" - <<'PY'
import json,os
from pathlib import Path
from fixtures import CASES,figure
from verify import table
from moxi.specialized import layout
lines=['from moxi import Rect, CanvasSceneRenderer, Color, test_check','from moxi_plot import PlotDataTable','from moxi_plot.plot_spec import plot_spec_from_json, plot_from_spec','']
for c in CASES:
 lines.append('def case_'+c['id']+'() raises:');table(lines,'data',c['columns']);f=figure(c);g=layout(f.spec.layers[0],f.data)
 lines+=['    var spec=plot_spec_from_json('+json.dumps(f.spec.to_json())+')','    test_check(spec.validate_data(data))','    var plot=plot_from_spec(spec,data,Rect(0,0,640,480))','    test_check(plot.series[0].count()=='+str(len(g.glyphs))+')','    var renderer=CanvasSceneRenderer(640,480,Color(1,1,1,1))','    renderer.render_scene(plot.build_scene())','    test_check(renderer.error_count()==0)']
lines+=['def main() raises:']+['    case_'+c['id']+'()' for c in CASES]+['    print("Twelve Wave C packaged consumers passed")']
(Path(os.environ['MOXI_E03_CONSUMER_DIR'])/'wave_c.mojo').write_text('\n'.join(lines)+'\n')
PY
pixi run mojo run -I "$consumer_dir" "$consumer_dir/wave_c.mojo"
