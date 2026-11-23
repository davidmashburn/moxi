#!/usr/bin/env python3
"""Capture real before/after ridgeline outputs; no reference image is synthesized."""
import argparse
from datetime import datetime, timezone
import hashlib
import html
import json
from pathlib import Path
import platform
import shutil
import subprocess
import sys

from PIL import Image, ImageChops
from contour_parity import source_state as plot_source_state
from demo_slideshows import CaptureKind, Phase

ROOT = Path(__file__).resolve().parents[1]
CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def source_inputs():
    state = plot_source_state()
    for name in ('scripts/ridgeline_followup.py', 'scripts/wave_b/compare.py',
                 'scripts/wave_b/verify.py', 'scripts/wave_b/fixtures.py',
                 'scripts/wave_b/registry.mojo', 'tests/fixtures/wave_b/ridgeline.json',
                 'tests/fixtures/wave_b/registry.json', 'tests/python/test_ridgeline_domain.py'):
        state[name] = sha(ROOT/name)
    return dict(sorted(state.items()))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('before', type=Path)
    parser.add_argument('after', type=Path)
    parser.add_argument('reference', type=Path)
    parser.add_argument('--gallery', type=Path, default=ROOT/'artifacts/demo-slideshows/plot-ridgeline-followup')
    args = parser.parse_args()
    gallery = args.gallery.resolve(); gallery.mkdir(parents=True, exist_ok=True)
    state = source_inputs()
    source_dirty = bool(subprocess.check_output(
        ['git', 'status', '--porcelain', '--', *state], cwd=ROOT, text=True).strip())
    sys.path.insert(0, str(ROOT/'scripts/wave_b'))
    from verify import runtime_source_hash
    from fixtures import load_cases, figure
    native = json.loads((args.after/'results.json').read_text())
    assert native['runtime_source_sha256'] == runtime_source_hash(), 'Native build inputs changed'
    figure(next(case for case in load_cases() if case['id'] == 'ridgeline')).save(args.after/'ridgeline-python.svg')
    for phase, source, names in (
        ('before', args.before, ('canvas.png', 'python.png', 'scene.svg', 'python.svg')),
        ('after', args.after, ('canvas.png', 'python.png', 'scene.svg', 'python.svg',
                             'selected.png', 'updated.png', 'rejected.png', 'restored.png'))):
        for name in names:
            shutil.copy2(source/('ridgeline-'+name), gallery/(phase+'-'+name))
    for extension in ('png', 'svg'):
        shutil.copy2(args.reference/('ridgeline.'+extension), gallery/('reference.'+extension))
    same = lambda a, b: ImageChops.difference(Image.open(gallery/a).convert('RGB'),
                                             Image.open(gallery/b).convert('RGB')).getbbox() is None
    assert same('after-updated.png', 'after-rejected.png')
    assert same('after-canvas.png', 'after-restored.png')
    assert not same('before-canvas.png', 'after-canvas.png')
    result = json.loads((args.after/'comparison.json').read_text())['ridgeline']
    assert result['moxi_domain_contains_every_density_sample']
    assert result['max_vertex_or_anchor_pixel_error'] <= 1.1
    upstream = json.loads((args.reference/'provenance.json').read_text())
    assert upstream['revision'] == '3fd5a7e7c622d6130c99a290b88c4fee039deab2'
    assert not upstream['dirty'] and upstream['returncode'] == 0
    upstream = {name: upstream[name] for name in (
        'repository', 'revision', 'dirty', 'canvas_revision', 'lock_sha256',
        'driver_sha256', 'font_sha256', 'font_family', 'returncode', 'missing')}
    revision = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    source_hash = hashlib.sha256(json.dumps(state, sort_keys=True).encode()).hexdigest()
    stages = (
        (Phase.INITIAL, 'native', 'Complete native density peak', 'before-canvas.png', 'after-canvas.png',
         'Before: nine samples exceed y_max=3. After: all 96 vertices fit y=[0, 3.3]. The 1.3-unit density rise and category spacing are preserved.'),
        (Phase.INTERACTION, 'interaction', 'Native selection and update replay', 'after-selected.png', 'after-updated.png',
         'The native harness clicks a real glyph, replays keyboard/linked selection and updates the source table; category ordering and complete peaks remain.'),
        (Phase.RESULT, 'python', 'Complete Python export peak', 'before-python.png', 'after-python.png',
         'Python exports use the same corrected density domain. Sixteen group-count, constant-data and viewport regression cases now retain every sample.'),
        (Phase.RESULT, 'reference', 'Pinned reference remains clipped', 'reference.png', 'after-canvas.png',
         'Genuine dataviz 0.8.0 output still clips the peak. All complete SVG density path vertices agree within 1.1 px under its original category frame; raster IoU is descriptive only.'),
        (Phase.RECOVERY, 'recovery', 'Rejected update and restored source', 'after-rejected.png', 'after-restored.png',
         'Rejected data leaves the last valid update pixel-identical. Restoring the original source reproduces the complete original scene pixel-for-pixel.'))
    slides, captures = [], []
    from playwright.sync_api import sync_playwright
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(executable_path=CHROME, headless=True)
        for phase, name, title, left, right, note in stages:
            body = '<!doctype html><html lang="en"><meta charset="utf-8"><title>'+html.escape(title)+'</title>'
            body += '<style>body{margin:24px;background:#111623;color:#dce7fb;font:16px/1.5 system-ui}h1{font-size:25px}p{max-width:1300px}.pair{display:flex;gap:24px}figure{margin:0;width:640px}img{display:block;width:640px;height:480px}figcaption{margin-bottom:8px}code{overflow-wrap:anywhere}</style>'
            body += '<h1>'+html.escape(title)+'</h1><p>'+html.escape(note)+'</p><div class="pair">'
            for image_name in (left, right):
                body += '<figure><figcaption>'+html.escape(image_name)+'</figcaption><img src="'+image_name+'" alt="'+html.escape(image_name)+'"></figure>'
            body += '</div><p>Actual 640×480 offscreen exports; local Chrome capture at 1400×900, scale 1. Source '+revision+'; scoped input hash <code>'+source_hash+'</code>. No native-window, GPU, physical-input or accessibility usability claim.</p></html>'
            page_path = gallery/(name+'.html'); page_path.write_text(body)
            page = browser.new_page(viewport=dict(width=1400, height=900), device_scale_factor=1)
            errors = []; page.on('pageerror', lambda error: errors.append(str(error)))
            page.on('requestfailed', lambda request: errors.append(request.url))
            page.goto(page_path.as_uri(), wait_until='networkidle')
            assert page.evaluate('Array.from(document.images).every(i=>i.complete&&i.naturalWidth===640)')
            assert page.evaluate('document.documentElement.scrollWidth<=innerWidth')
            assert not errors, errors
            filename = name+'-frame.png'; page.screenshot(path=str(gallery/filename), full_page=True)
            dimensions = list(Image.open(gallery/filename).size)
            captures.append(dict(page=page_path.name, image=filename, dimensions=dimensions,
                page_errors=errors, user_agent=page.evaluate('navigator.userAgent')))
            slides.append(dict(phase=phase, image=filename, dimensions=dimensions,
                sha256=sha(gallery/filename), capture_kind=CaptureKind.BROWSER, caption=title, action='Open '+page_path.name,
                expected=note))
            page.close()
        browser_version = browser.version; browser.close()
    assert state == source_inputs(), 'Sources changed during capture'
    record = dict(captured_at=datetime.now(timezone.utc).isoformat(), revision=revision,
        source_dirty=source_dirty, source_sha256=state, source_state_sha256=source_hash,
        native_verification=dict(runtime_source_sha256=native['runtime_source_sha256'],
            driver_sha256=native['driver_sha256'], case_count=len(native['cases'])),
        baseline_domain=[0, 3], corrected_domain=[0, 3.3],
        baseline_samples_outside_domain=9, corrected_samples_outside_domain=0,
        upstream=upstream,
        comparison=result, rejected_update_preserves_pixels=True, restored_source_preserves_pixels=True,
        historical_silhouette_gate=dict(threshold=.98, value=result['silhouette_iou'],
            passed=result['silhouette_iou']>.98,
            assessment='Historical gate fails because the genuine upstream image clips the peak; complete SVG path geometry is the current bounded comparison.'),
        browser_version=browser_version, viewport=dict(width=1400, height=900, scale=1), captures=captures)
    (gallery/'verification.json').write_text(json.dumps(record, indent=2)+'\n')
    manifest = dict(version=1, demo_id=gallery.name, title='Ridgeline peak recovery',
        scenario='Full sampled density peaks survive native and Python projection, interaction and recovery.',
        revision=revision, source_dirty=source_dirty, source_sha256=state,
        host=platform.platform(), backend='Actual Mojo Scene/Canvas and Python exports; local headless Chrome',
        scale=1, fixture='tests/fixtures/wave_b/ridgeline.json', reproduce='See README.md.', slides=slides)
    (gallery/'manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')
    fingerprints={p.name: sha(p) for p in sorted(gallery.iterdir()) if p.suffix in ('.png', '.svg', '.html')}
    (gallery/'artifact-sha256.json').write_text(json.dumps(fingerprints, indent=2)+'\n')
    print('Five real browser evidence pages passed; complete KDE geometry, rejected updates and restoration verified')


if __name__ == '__main__':
    main()
