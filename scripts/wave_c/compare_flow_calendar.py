"""Check actual exported Wave C frames and capture reference/native comparisons."""
import argparse
import base64
import json
import platform
from datetime import datetime, timezone
from pathlib import Path
from xml.etree import ElementTree as ET

import numpy as np
from PIL import Image
from playwright.sync_api import sync_playwright

from fixtures import CASES, figure
from upstream import PIN


def colored_pixels(path):
    # The two palettes differ. Compare coverage within the plot, excluding title and legend.
    pixels = np.asarray(Image.open(path).convert('RGB').crop((48,28,608,428)), dtype=int)
    return pixels.max(axis=2)-pixels.min(axis=2) > 40


def check_chord(reference, replay):
    expected = colored_pixels(reference/'chord.png')
    results = {}
    for renderer in ('canvas', 'python'):
        actual = colored_pixels(replay/f'chord-{renderer}.png')
        ys, xs = np.where(actual)
        bounds = [int(xs.max()-xs.min()+1), int(ys.max()-ys.min()+1)]
        overlap = np.count_nonzero(actual & expected)/np.count_nonzero(actual | expected)
        assert max(abs(n-360) for n in bounds) <= 2, bounds
        assert overlap > .985, overlap
        results[renderer] = dict(size=bounds, coverage_iou=overlap)
    return results


def check_chord_paths(page, reference, replay):
    # Use the browser's SVG fill test to compare each corresponding object,
    # including narrow ring sectors hidden by a union-of-colors comparison.
    def paths(path, element, attribute):
        values = []
        for shape in ET.parse(path).findall('.//{*}'+element):
            if element == 'polygon' and shape.get('data-mark') != 'chord':
                continue
            value = shape.get(attribute)
            if element == 'polygon':
                value = "M " + " L ".join(value.split()) + " Z"
            values.append(value)
        assert len(values) == 9, (path,len(values))
        return values

    upstream = paths(reference/'chord.svg','path','d')
    results = {}
    for backend, element, attr in (('scene','path','d'), ('python','polygon','points')):
        actual = paths(replay/f'chord-{backend}.svg',element,attr)
        scores = page.evaluate("""([expected, actual]) => {
            const ctx = document.createElement("canvas").getContext("2d");
            return expected.map((shape,i) => {
                const a = new Path2D(shape), b = new Path2D(actual[i]);
                let intersection = 0, union = 0;
                for(let y=48.5; y<408; y+=2) for(let x=148.5; x<508; x+=2) {
                    const u = ctx.isPointInPath(a,x,y,"evenodd"), v = ctx.isPointInPath(b,x,y,"evenodd");
                    intersection += u && v;
                    union += u || v;
                }
                return intersection / union;
            });
        }""",[upstream,actual])
        assert min(scores) > .98, (backend,scores)
        results[backend] = scores
    return results


def check_labels(name, reference, replay):
    elements = ET.parse(reference/f'{name}.svg').findall('.//{*}text')
    assert len(elements) == (19 if name == 'calendar_heatmap' else 4)
    results = {}
    for backend in ('scene','python'):
        labels = ET.parse(replay/f'{name}-{backend}.svg').findall('.//{*}text')
        errors = []
        for expected in elements:
            matches = [e for e in labels if e.text == expected.text]
            assert len(matches) == 1, (name,backend,expected.text)
            label = matches[0]
            assert label.get('text-anchor') == expected.get('text-anchor')
            errors.extend(abs(float(label.get(axis))-float(expected.get(axis))) for axis in ('x','y'))
        assert max(errors) <= 1.1, (name, backend, max(errors))
        results[backend] = dict(labels=len(elements), maximum_anchor_error_px=max(errors))
    return results


def capture(page, sources, target):
    panels = []
    for caption, path in sources:
        mime = 'svg+xml' if path.suffix == '.svg' else 'png'
        payload = base64.b64encode(path.read_bytes()).decode()
        panels.append(f'<section><h2>{caption}</h2><img src="data:image/{mime};base64,{payload}"></section>')
    page.set_content('<style>*{box-sizing:border-box}body{margin:0;padding:12px;display:flex;gap:12px;background:#eee;font:14px sans-serif}h2{font-size:16px;margin:0 0 8px}img{display:block;width:640px;height:480px}</style>'+''.join(panels))
    page.locator('img').evaluate_all('(images) => Promise.all(images.map(i=>i.decode()))')
    assert page.locator('img').count() == 2
    page.screenshot(path=str(target))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for arg in ('reference','replay','destination'):
        parser.add_argument(arg, type=Path)
    args = parser.parse_args()
    args.destination.mkdir(parents=True,exist_ok=True)
    provenance = json.loads((args.reference/'provenance.json').read_text())
    assert provenance['revision'] == PIN and provenance['returncode'] == 0 and not provenance['dirty']
    selections = json.loads((args.replay/'selections.json').read_text())
    hits = {}
    for case in CASES:
        name = case['id']
        if name not in ('chord','calendar_heatmap','sankey'):
            continue
        selected = selections[name]
        hit = figure(case).hit_test(selected['x'],selected['y'],tolerance=.1)
        assert hit and hit['source_rows'] == [selected['row_index']], (name,selected,hit)
        hits[name] = selected
    results = dict(chord=check_chord(args.reference,args.replay), selections=hits,
                   reference_revision=PIN, replay=json.loads((args.replay/'results.json').read_text()))
    with sync_playwright() as pw:
        browser = pw.chromium.launch(channel='chrome')
        page = browser.new_page(viewport=dict(width=1316,height=532), device_scale_factor=1)
        results['chord_object_iou'] = check_chord_paths(page,args.reference,args.replay)
        for name in ('chord','calendar_heatmap','sankey'):
            if name != 'chord':
                results[name] = check_labels(name,args.reference,args.replay)
            native = args.replay/(name+'-canvas.png' if name == 'chord' else name+'-scene.svg')
            capture(page, [('Pinned dataviz',args.reference/(name+'.png')),
                           ('Moxi Canvas' if name=='chord' else 'Moxi Scene SVG',native)],
                    args.destination/(name+'.png'))
        results.update(browser=browser.version, host=platform.platform(), captured=datetime.now(timezone.utc).isoformat())
        browser.close()
    print(json.dumps(results,indent=2))


if __name__ == '__main__':
    main()
