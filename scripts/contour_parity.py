#!/usr/bin/env python3
"""Supplement the historical Wave B/C review with genuine newer contour APIs.

The old upstream pin has no contour APIs. This separately pinned comparison
does not rewrite that review or equate marching squares with triangulated grids.
Run with PYTHONPATH=python and Pillow/numpy/matplotlib/Playwright installed.
"""
import argparse
from datetime import datetime, timezone
from enum import Enum
import hashlib
import html
import json
import math
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
from xml.etree import ElementTree as ET

from PIL import Image, ImageChops
from moxi import PlotSpec, plot
from moxi.specialized import GlyphKind, layout

ROOT = Path(__file__).resolve().parents[1]
PIN = '377b519e07f017d4a120b7fc3551f972a0b3fe16'
CANVAS_PIN = '8fcb0c83966ef872248239f9dafd6baaba06204e'
TOLERANCE = 2e-5


class Family(str, Enum):
    CONTOUR = 'contour'
    CONTOURF = 'contourf'
    TRICONTOUR = 'tricontour'


class Stage(str, Enum):
    REFERENCE = 'reference'
    COMPARISON = 'comparison'
    INTERACTION = 'interaction'
    RECOVERY = 'recovery'

    @property
    def phase(self):
        return {Stage.REFERENCE: 'initial', Stage.COMPARISON: 'result',
            Stage.INTERACTION: 'interaction', Stage.RECOVERY: 'recovery'}[self]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def recorded_command(command, checkout, output):
    """Keep the reproducible recipe without publishing local checkout paths."""
    roots = ((str(checkout), '${UPSTREAM_ROOT}'),
             (str(output), '${OUTPUT_ROOT}'), (str(ROOT), '.'))
    return [next((replacement+part[len(root):] for root, replacement in roots
                  if part == root or part.startswith(root+'/')), part)
            for part in command]


def source_state():
    paths = sorted(p for folder in ('src/moxi', 'src/moxi_plot', 'python/moxi')
                   for p in (ROOT/folder).rglob('*') if p.suffix in ('.mojo', '.py'))
    paths += [ROOT/p for p in ('scripts/contour_parity.py', 'tests/plot_wave_b.mojo',
        'tests/plot_specialized_c.mojo', 'tests/fixtures/wave_b/contour.json',
        'tests/fixtures/wave_b/contourf.json', 'tests/fixtures/wave_c/cases.json', 'pixi.lock')]
    return {str(p.relative_to(ROOT)): digest(p) for p in paths}


def cases():
    result = {}
    for family in Family:
        if family is Family.TRICONTOUR:
            payload = json.loads((ROOT/'tests/fixtures/wave_c/cases.json').read_text())[family.value]
        else:
            payload = json.loads((ROOT/f'tests/fixtures/wave_b/{family.value}.json').read_text())
        spec = PlotSpec('Contour parity: '+family.value)
        identity = spec.add_catalog_mark(family.value, family.value,
            payload['x'], payload['y'], **payload.get('channels', {}))
        spec.specialize(identity, **payload.get('layout', {}))
        spec.add_hover(); spec.add_click_select(); spec.add_keyboard()
        figure = plot(payload['columns'], spec, width=640, height=480)
        values = payload['columns']['z']
        levels = payload['layout']['levels'] if family is Family.TRICONTOUR else [
            min(values)+(max(values)-min(values))*k/8 for k in range(1, 8)]
        result[family] = dict(payload=payload, figure=figure, levels=levels)
    return result


def table(lines, name, columns):
    lines.append(f'    var {name}=PlotDataTable()')
    for field in columns:
        lines.append(f'    _ = {name}.add_float_column({json.dumps(field)})')
    for i in range(len(columns['z'])):
        lines.append(f'    _ = {name}.append_with_key({100+7*i},0,0)')
        for field, values in columns.items():
            value = 'Float32(1)/Float32(0)' if not math.isfinite(values[i]) else repr(values[i])
            lines.append(f'    _ = {name}.set_float_field({json.dumps(field)},{i},{value})')


def native_driver(data, output):
    lines = ['from moxi_plot.plot_data import PlotDataTable',
        'from plot_wave_b import check_case as check_grid',
        'from plot_specialized_c import check_case as check_mesh', '']
    for family, case in data.items():
        columns = case['payload']['columns']
        lines.append(f'def case_{family.value}() raises:')
        table(lines, 'data', columns)
        arguments = [json.dumps(family.value), json.dumps(case['figure'].spec.to_json()), 'data']
        if family is Family.TRICONTOUR:
            changed = {key: list(values) for key, values in columns.items()}
            changed['z'][4] = changed['z'][4]*.7+1
            invalid = {key: list(values) for key, values in columns.items()}
            invalid['z'][0] = float('inf')
            table(lines, 'changed', changed)
            table(lines, 'invalid', invalid)
            lines.append('    changed.version = data.version + 1')
            arguments += ['changed', 'invalid']
        arguments.append(json.dumps(str(output)))
        lines.append('    '+('check_mesh' if family is Family.TRICONTOUR else 'check_grid')+'('+','.join(arguments)+')')
    return '\n'.join(lines+['def main() raises:']+['    case_'+f.value+'()' for f in data])+'\n'


def reference_driver(data, output):
    lines = ['from dataviz import Plot, Theme, save, delaunay', 'from canvas import Color',
        'from dataviz.multivariate.contour import _contour_segments',
        'from dataviz.multivariate.tricontour import _tricontour_segments', '']
    for family, case in data.items():
        columns = case['payload']['columns']
        lines.append(f'def case_{family.value}() raises:')
        def var(name, values, kind='Float64'):
            lines.append('    var '+name+': List['+kind+'] = '+json.dumps(values))
        var('levels', case['levels'])
        if family is Family.TRICONTOUR:
            for field in ('x', 'y', 'z'):
                var(field, columns[field])
            method = 'encode_tricontour(x,y,z,levels)'
            lines += ['    var tri=delaunay(x,y)', '    for k in range(tri.count()):',
                '        print("triangle|",tri.triangles[3*k],"|",tri.triangles[3*k+1],"|",tri.triangles[3*k+2])',
                '    for level in levels:', '        var segments=_tricontour_segments(tri,z,level)']
        else:
            xs, ys = sorted(set(columns['x'])), sorted(set(columns['y']))
            lookup = dict(zip(zip(columns['x'], columns['y']), columns['z']))
            var('xs', xs); var('ys', ys)
            var('matrix', [[lookup[(x, y)] for x in xs] for y in ys], 'List[Float64]')
            method = 'encode_contour(matrix,levels,xs,ys)'
            lines += ['    for level in levels:',
                f'        var segments=_contour_segments(matrix,{len(ys)},{len(xs)},level)']
        lines += ['        for i in range(len(segments.ax)):',
            f'            print("segment|{family.value}|",level,"|",segments.ax[i],"|",segments.ay[i],"|",segments.bx[i],"|",segments.by[i])',
            '    var theme=Theme(background=Color(17,22,35),axis_color=Color(191,204,229),text_color=Color(191,204,229),font_family="DejaVu Sans",margin_left=48,margin_right=32,margin_top=28,margin_bottom=52,show_gridlines=False,show_legend=False)',
            f'    var p=Plot().mark_{family.value}().{method}.theme(theme).size(640,480)']
        for extension in ('png', 'svg'):
            lines.append('    save(p,'+json.dumps(str(output/(family.value+'.'+extension)))+')')
    return '\n'.join(lines+['def main() raises:']+['    case_'+f.value+'()' for f in data])+'\n'


def run(command, log, environment=None):
    result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, env=environment)
    log.write_text(result.stdout+result.stderr)
    if result.returncode:
        raise SystemExit(f'Command failed ({result.returncode}); see {log}')
    return result.stdout


def unique(points):
    result = []
    for point in points:
        if not any(math.dist(point, other) <= TOLERANCE for other in result):
            result.append(point)
    return result


def endpoint_error(left, right):
    assert left and right, 'Missing contour endpoints'
    assert len(left) == len(right), (len(left), len(right))
    return max(max(min(math.dist(p, q) for q in right) for p in left),
               max(min(math.dist(p, q) for q in left) for p in right))


def compare(data, native_output, upstream_output, output):
    actual = {family: [] for family in Family}
    vertices = {family: {} for family in Family}
    styles = {family: {} for family in Family}
    for line in native_output.splitlines():
        fields = [field.strip() for field in line.split('|')]
        if fields[0] == 'glyph':
            family = Family(fields[1])
            actual[family].append(dict(part=fields[4], bounds=list(map(float, fields[5:9]))))
        elif fields[0] == 'vertex':
            vertices[Family(fields[1])].setdefault(int(fields[2]), []).append(tuple(map(float, fields[3:5])))
        elif fields[0] == 'style':
            styles[Family(fields[1])][int(fields[2])] = (list(map(float, fields[3:7])), fields[7])
    upstream = {family: {} for family in Family}
    triangles = []
    for line in upstream_output.splitlines():
        fields = [field.strip() for field in line.split('|')]
        if fields[0] == 'triangle':
            triangles.append(sorted(map(int, fields[1:4])))
        elif fields[0] == 'segment':
            upstream[Family(fields[1])].setdefault(float(fields[2]), []).append(list(map(float, fields[3:7])))
    results = {}
    for family, case in data.items():
        columns = case['payload']['columns']
        geometry = layout(case['figure'].spec.layers[0], case['figure'].data, 560, 400)
        glyphs = geometry.glyphs
        assert len(glyphs) == len(actual[family]), family
        for index, (glyph, native) in enumerate(zip(glyphs, actual[family])):
            if family is Family.TRICONTOUR:
                assert native['part'].split(':level:')[0] == glyph.part.split(':level:')[0]
                assert float(native['part'].split(':level:')[1]) == float(glyph.part.split(':level:')[1])
            else:
                assert native['part'] == glyph.part, (family, index, native['part'], glyph.part)
            assert max(abs(a-b) for a, b in zip(native['bounds'], glyph.bounds)) < TOLERANCE
            color, label = styles[family][index]
            assert max(abs(a-b) for a, b in zip(color, glyph.color)) < TOLERANCE
            field = case['payload']['channels'].get('y2') if family is not Family.TRICONTOUR else case['payload']['layout']['series_fields'][0]
            assert label.startswith(field+' ') and glyph.label.startswith(field+' '), (label, glyph.label)
            assert label[-1] == glyph.label[-1] or family is not Family.CONTOURF, (label, glyph.label)
            numbers = lambda value: list(map(float, re.findall(r'-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?', value[len(field):])))
            assert len(numbers(label)) == len(numbers(glyph.label))
            assert max(abs(a-b) for a,b in zip(numbers(label), numbers(glyph.label))) < TOLERANCE
            if glyph.kind is GlyphKind.POLYGON:
                assert len(vertices[family][index]) == len(glyph.vertices)
                assert max(math.dist(a, b) for a, b in zip(vertices[family][index], glyph.vertices)) < TOLERANCE
        native_image = Image.open(output/(family.value+'-canvas.png')).convert('RGB')
        restored = Image.open(output/(family.value+'-restored.png')).convert('RGB')
        updated = Image.open(output/(family.value+'-updated.png')).convert('RGB')
        rejected = Image.open(output/(family.value+'-rejected.png')).convert('RGB')
        assert ImageChops.difference(native_image, restored).getbbox() is None
        assert ImageChops.difference(updated, rejected).getbbox() is None
        assert ImageChops.difference(native_image, updated).getbbox() is not None
        record = dict(reference_available=True, reference_revision=PIN,
            source_rows=len(columns['z']), levels=case['levels'], native_glyphs=len(glyphs),
            mojo_python_geometry_pass=True, mojo_python_scalar_color_and_label_pass=True,
            scalar_labels=list(dict.fromkeys(g.label for g in glyphs)),
            rejected_update_preserves_pixels=True,
            restoration_matches_original=True, full_visual_parity=False)
        if family is Family.TRICONTOUR:
            supplied = sorted(sorted(t) for t in case['payload']['layout']['triangles'])
            assert sorted(triangles) == supplied, (triangles, supplied)
            errors = []
            for level in case['levels']:
                own = [p for g in actual[family] if float(g['part'].split(':level:')[1]) == level
                       for p in (g['bounds'][:2], g['bounds'][2:])]
                reference = [p for segment in upstream[family][level] for p in (segment[:2], segment[2:])]
                errors.append(endpoint_error(unique(own), unique(reference)))
            assert max(errors) < TOLERANCE
            record.update(delaunay_matches_supplied_mesh=True, max_endpoint_error=max(errors),
                assessment='Fixture mesh and all three isoline levels agree. Moxi accepts supplied meshes; upstream computes Delaunay connectivity. Arbitrary mesh parity is unverified. Axis padding, palette, grid and missing Moxi labels differ.')
        elif family is Family.CONTOUR:
            xs, ys = sorted(set(columns['x'])), sorted(set(columns['y']))
            errors = []
            for index, level in enumerate(case['levels'], 1):
                own = unique([p for glyph in actual[family] if glyph['part'] == f'level:{index}'
                    for p in (glyph['bounds'][:2], glyph['bounds'][2:])
                    if any(abs(p[0]-x)<TOLERANCE for x in xs) or any(abs(p[1]-y)<TOLERANCE for y in ys)])
                def coordinate(values, value):
                    low = min(len(values)-2, int(value))
                    return values[low]+(values[low+1]-values[low])*(value-low)
                reference = unique([(coordinate(xs, p[0]), coordinate(ys, p[1]))
                    for segment in upstream[family][level] for p in (segment[:2], segment[2:])])
                errors.append(endpoint_error(own, reference))
            assert max(errors) < TOLERANCE
            record.update(max_grid_edge_crossing_error=max(errors),
                upstream_segments=sum(map(len, upstream[family].values())),
                assessment='Seven scalar levels and their grid-edge crossings agree. Moxi fixed-diagonal marching triangles and upstream marching squares connect crossings differently inside cells. Full isoline geometry parity remains open; padding, palette, grid and labels also differ.')
        else:
            area = sum(abs(sum(a[0]*b[1]-b[0]*a[1] for a, b in zip(g.vertices, g.vertices[1:]+g.vertices[:1])))/2 for g in glyphs)
            expected = (max(columns['x'])-min(columns['x']))*(max(columns['y'])-min(columns['y']))
            assert abs(area-expected) < TOLERANCE
            svg = ET.parse(output/(family.value+'-reference.svg'))
            filled = [element for element in svg.iter() if element.tag.endswith('}path') and element.get('fill') not in (None, 'none')]
            assert filled, 'Reference contains no filled contour paths'
            record.update(bands=8, moxi_total_band_area=area, source_grid_area=expected,
                assessment='The same seven thresholds produce eight bands and Moxi covers the complete source grid. Moxi clips fixed-diagonal triangles; upstream fills marching-squares above-level regions. Band topology/area equality against upstream is unverified; native seams, palette, padding and labels differ.')
        results[family.value] = record
    return results


def gallery(output, destination, results, provenance, state):
    """Capture six comparisons plus actual update/rejection/restoration evidence."""
    from playwright.sync_api import sync_playwright
    destination.mkdir(parents=True, exist_ok=True)
    for name in ('source-state.json', 'results.json', 'provenance.json'):
        shutil.copyfile(output/name, destination/name)
    style = ('body{margin:24px;background:#111623;color:#dfebff;font:16px system-ui}'
        'h1{font-size:25px}h2{font-size:19px}p{max-width:1320px;line-height:1.5}'
        '.pair{display:flex;gap:24px}figure{margin:0}figcaption{margin:8px 0}'
        'img{width:640px;height:480px}code{color:#9dd6ff}')
    footer = ('<p>Offscreen Canvas outputs and local browser replay, 640×480 charts. '
        'Moxi uses its explicit data extent; upstream adds 5% axis padding with supplied coordinates. '
        'No native input, physical input, GPU, accessibility usability, independent scientific review '
        'or performance acceptance is claimed.</p><p>Upstream <code>'+PIN+'</code>; Moxi <code>'+
        provenance['moxi_revision']+'</code> with recorded uncommitted source fingerprint <code>'+
        provenance['source_state_sha256']+'</code>.</p>')
    pages = []
    for family in Family:
        name = family.value
        for suffix in ('reference.png', 'reference.svg', 'canvas.png', 'scene.svg',
                'updated.png', 'rejected.png', 'restored.png'):
            shutil.copyfile(output/(name+'-'+suffix), destination/(name+'-'+suffix))
        for stage in Stage:
            body = '<h1>'+name+' · '+stage.value+'</h1>'
            body += '<p>'+html.escape(results[name]['assessment'])+'</p>'
            images = {
                Stage.REFERENCE: [('reference', 'dataviz 0.15.0 · genuine pinned API')],
                Stage.COMPARISON: [('reference', 'dataviz 0.15.0 · genuine pinned API'), ('canvas', 'Moxi · actual Scene/Canvas')],
                Stage.INTERACTION: [('canvas', 'Moxi · initial'), ('updated', 'Moxi · valid data update')],
                Stage.RECOVERY: [('rejected', 'Moxi · invalid update rejected; valid update retained'), ('restored', 'Moxi · original data restored')],
            }[stage]
            body += '<div class="pair">'+''.join('<figure><figcaption>'+caption+'</figcaption><img alt="'+html.escape(caption)+'" src="'+name+'-'+suffix+'.png"></figure>' for suffix, caption in images)
            body += '</div>'+footer
            page = name+'-'+stage.value+'.html'
            (destination/page).write_text('<!doctype html><meta charset="utf-8"><title>'+name+' '+stage.value+'</title><style>'+style+'</style>'+body)
            pages.append((name, stage, page))
    captures, slides = [], []
    executable = shutil.which('google-chrome') or shutil.which('chromium')
    mac_chrome = Path('/Applications/Google Chrome.app/Contents/MacOS/Google Chrome')
    if not executable and mac_chrome.exists():
        executable = str(mac_chrome)
    with sync_playwright() as pw:
        browser = pw.chromium.launch(headless=True, executable_path=executable)
        context = browser.new_context(viewport=dict(width=1400, height=900), device_scale_factor=1)
        for name, stage, filename in pages:
            page = context.new_page()
            errors, failures = [], []
            page.on('pageerror', lambda error: errors.append(str(error)))
            page.on('requestfailed', lambda request: failures.append(request.url))
            page.goto((destination/filename).as_uri(), wait_until='networkidle')
            page.evaluate('async () => { await document.fonts.ready; await Promise.all([...document.images].map(i => i.decode())); }')
            metrics = page.evaluate('''() => ({innerWidth, innerHeight, devicePixelRatio,
                scrollWidth:document.documentElement.scrollWidth,
                scrollHeight:document.documentElement.scrollHeight,userAgent:navigator.userAgent,
                images:[...document.images].map(i=>({src:i.getAttribute('src'),complete:i.complete,
                    width:i.naturalWidth,height:i.naturalHeight}))})''')
            assert not errors and not failures, (filename, errors, failures)
            assert metrics['scrollWidth'] <= metrics['innerWidth'] and metrics['scrollHeight'] <= metrics['innerHeight'], metrics
            target = name+'-'+stage.value+'-frame.png'
            page.screenshot(path=str(destination/target), animations='disabled')
            record = dict(page=filename, image=target, captured_at=datetime.now(timezone.utc).isoformat(),
                browser_version=browser.version, viewport=metrics, sha256=digest(destination/target),
                page_errors=[], failed_requests=[])
            captures.append(record)
            expected = {
                Stage.REFERENCE: 'Genuine pinned upstream chart',
                Stage.COMPARISON: results[name]['assessment'],
                Stage.INTERACTION: 'Valid data update changes the rendered chart.',
                Stage.RECOVERY: 'Rejected data preserves the last valid chart; restoring original data restores identical pixels.',
            }[stage]
            slides.append(dict(phase=stage.phase, capture_kind='browser',
                image=target, dimensions=[1400,900], sha256=record['sha256'],
                caption=name+' · '+stage.value, action='Open '+filename,
                expected=expected))
            page.close()
        browser.close()
    assert state == source_state(), 'Runtime inputs changed during browser capture; rerun'
    (destination/'captures.json').write_text(json.dumps(captures, indent=2)+'\n')
    manifest = dict(version=1, demo_id=destination.name, title='Contour reference follow-up',
        scenario='Three real upstream references and bounded comparisons; full visual parity remains partial.',
        revision=provenance['moxi_revision'], source_dirty=provenance['moxi_dirty'],
        source_state_path=str((destination/'source-state.json').relative_to(ROOT)),
        source_state_sha256=provenance['source_state_sha256'],
        host=platform.platform(), backend='Mojo Scene/Canvas; pinned dataviz; local headless Chrome',
        scale=1, fixture='tests/fixtures/wave_b/{contour,contourf}.json; tests/fixtures/wave_c/cases.json#tricontour',
        reproduce='See README.md in this directory.', slides=slides)
    (destination/'manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')
    artifacts = {p.name:digest(p) for p in destination.iterdir() if p.suffix in ('.png','.svg')}
    (destination/'artifact-sha256.json').write_text(json.dumps(artifacts, indent=2)+'\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('checkout', type=Path)
    parser.add_argument('output', type=Path)
    parser.add_argument('--font-dir', type=Path, required=True)
    parser.add_argument('--gallery', type=Path, default=ROOT/'artifacts/demo-slideshows/plot-contour-followup')
    args = parser.parse_args()
    checkout, output = args.checkout.resolve(), args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    revision = subprocess.check_output(['git', '-C', str(checkout), 'rev-parse', 'HEAD'], text=True).strip()
    assert revision == PIN, f'Expected upstream {PIN}, got {revision}'
    assert not subprocess.check_output(['git', '-C', str(checkout), 'status', '--porcelain'], text=True).strip(), 'Upstream must be clean'
    assert CANVAS_PIN in (checkout/'pixi.lock').read_text()
    font = args.font_dir.resolve()/'DejaVuSans.ttf'
    assert font.is_file(), font
    state = source_state()
    data = cases()
    native = output/'native.mojo'; native.write_text(native_driver(data, output))
    reference = output/'reference.mojo'; reference.write_text(reference_driver(data, output))
    native_command = ['pixi', 'run', 'mojo', 'run', '-I', 'src', '-I', 'tests', str(native)]
    upstream_command = ['pixi', 'run', '--manifest-path', str(checkout/'pixi.toml'), 'mojo', 'run', '-I', str(checkout), str(reference)]
    native_output = run(native_command, output/'native.log')
    upstream_output = run(upstream_command, output/'reference.log',
        dict(os.environ, CANVAS_MOJO_FONT_PATH=str(args.font_dir.resolve())))
    for family in Family:
        for extension in ('png', 'svg'):
            shutil.copyfile(output/(family.value+'.'+extension), output/(family.value+'-reference.'+extension))
    results = compare(data, native_output, upstream_output, output)
    assert state == source_state(), 'Runtime inputs changed; rerun before recording evidence'
    (output/'source-state.json').write_text(json.dumps(state, indent=2)+'\n')
    provenance = dict(captured_at=datetime.now(timezone.utc).isoformat(), platform=platform.platform(),
        upstream_revision=PIN, upstream_dirty=False, canvas_revision=CANVAS_PIN,
        moxi_revision=subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
        moxi_dirty=bool(subprocess.check_output(['git', 'status', '--porcelain'], text=True).strip()),
        source_state_sha256=digest(output/'source-state.json'), font_sha256=digest(font),
        upstream_lock_sha256=digest(checkout/'pixi.lock'), moxi_lock_sha256=digest(ROOT/'pixi.lock'),
        native_driver_sha256=digest(native), reference_driver_sha256=digest(reference),
        native_command=recorded_command(native_command, checkout, output),
        upstream_command=recorded_command(upstream_command, checkout, output),
        native_compiler=subprocess.check_output(['pixi', 'run', 'mojo', '--version'], text=True).strip(),
        upstream_compiler=subprocess.check_output(['pixi', 'run', '--manifest-path', str(checkout/'pixi.toml'), 'mojo', '--version'], text=True).strip())
    (output/'provenance.json').write_text(json.dumps(provenance, indent=2)+'\n')
    (output/'results.json').write_text(json.dumps(results, indent=2)+'\n')
    gallery(output, args.gallery.resolve(), results, provenance, state)
    print('Three genuine pinned contour references and bounded comparisons passed:', output)


if __name__ == '__main__':
    main()
