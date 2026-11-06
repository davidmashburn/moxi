"""Render recorded outputs as browser evidence; never invent command results."""
import argparse
import hashlib
import html
import importlib.util
import json
from pathlib import Path
import platform
import struct
import subprocess

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OUT = ROOT / 'artifacts/demo-slideshows/e04-python-native'
STEPS = (
    ('01-import', 'initial', 'Clean installed import and compiled ABI version'),
    ('02-render', 'interaction', 'Canonical native scene: SVG and raster PNG'),
    ('03-comparison', 'result', 'Native and unchanged facade export comparison'),
    ('04-recovery', 'recovery', 'Malformed input rejection and repeated lifetime recovery'),
    ('05-packaging', 'result', 'Inspected wheel, bounded timing and deployment decision'),
)


def read(name): return json.loads((OUT / name).read_text())
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def pre(value): return '<pre>' + html.escape(value if isinstance(value, str) else json.dumps(value, indent=2)) + '</pre>'

def page(step, body, revision):
    title = dict((s[0], s[2]) for s in STEPS)[step]
    return ("<!doctype html><html lang='en'><meta charset='utf-8'><title>E04 " + title + "</title>"
            "<style>body{font:18px system-ui;margin:28px;color:#17233a;background:#f7f9fc}"
            "h1{font-size:28px;margin:12px 0}h2{font-size:21px}small{color:#46576d}"
            "pre{white-space:pre-wrap;overflow-wrap:anywhere;font:14px ui-monospace,monospace;background:#e9eef5;padding:16px}"
            ".pair{display:flex;gap:24px}.pair>div{width:48%}img{width:480px;height:360px;border:1px solid #bec8d7;background:white}"
            "table{border-collapse:collapse;font-size:16px}td,th{border:1px solid #bec8d7;padding:9px;text-align:left}"
            ".gate{border-left:6px solid #af6313;padding:16px;background:#fff1d8}p{max-width:1200px;line-height:1.5}</style>"
            "<small>E04 · Actual installed outputs and captured test logs · browser evidence page, not a terminal emulator</small>"
            f"<h1>{html.escape(title)}</h1><small>Source {revision[:12]} + uncommitted changes; exact source/binary hashes retained in the manifest and build report.</small>" + body + '</html>')


def pages():
    initial = read('01-import.json'); renders = read('02-render.json')
    packaging = read('packaging.json'); benchmark = read('benchmark.json')
    build = read('build.json'); revision = build['revision']
    assert 'passed' in (OUT / 'native-tests.log').read_text()
    assert 'passed' in (OUT / 'facade-tests.log').read_text()
    small = {k: initial[k] for k in ('python', 'platform', 'moxi_version', 'native_version', 'mojo_on_path', 'isolated', 'process_audit')}
    small.update(compiler=build['compiler'], abi_version=initial['capabilities']['abi_version'],
                 abi3=False, copy_policy=initial['capabilities']['copy_policy'])
    body = '<p>Fresh venv outside the repository. <code>env -i</code>, Python isolated mode, no Mojo/Python import paths, no compiler on PATH. Process creation is rejected by the probe audit hook.</p>'
    body += pre(small) + '<h2>Actual import locations</h2>' + pre(initial['import_paths'])
    body += '<p>Compiled Mojo called through the CPython extension; the base <code>moxi</code> facade remains a separate compiler-independent wheel.</p>'
    (OUT / '01-import.html').write_text(page('01-import', body, revision))
    body = '<p>Fixture: six samples, two line/scatter layers, 320×240. Both images below come from the installed native extension. SVG includes text; the software raster backend omits resource text pixels.</p>'
    body += "<div class='pair'><div><h2>Mojo SVG</h2><img src='native.svg'></div><div><h2>Mojo RGBA → PNG</h2><img src='native.png'></div></div>"
    body += '<h2>Actual returned bytes</h2>' + pre({k: dict(bytes=v['native_bytes'], sha256=v['native_sha256']) for k, v in renders.items()})
    (OUT / '02-render.html').write_text(page('02-render', body, revision))
    left = (OUT / 'native.rgba').read_bytes(); right = (OUT / 'facade.rgba').read_bytes()
    difference = sum(abs(a-b) for a,b in zip(left,right)) / len(left)
    body = "<div class='pair'><div><h2>Native experimental PNG</h2><img src='native.png'></div><div><h2>Existing facade PNG</h2><img src='facade.png'></div></div>"
    body += f'<p>Same fixture and dimensions. Mean absolute unaligned RGBA byte difference: {difference:.4f}/255. This is descriptive, not a parity threshold. Axis layout and raster text coverage differ.</p>'
    body += '<table><tr><th>Format</th><th>Native bytes</th><th>Facade bytes</th><th>Contract check</th></tr>'
    for kind, values in renders.items():
        body += f"<tr><td>{kind}</td><td>{values['native_bytes']}</td><td>{values['facade_bytes']}</td><td>Owned bytes; signatures/dimensions checked</td></tr>"
    body += '</table><p>Independent Pillow/pypdf decoding checks PNG against native RGBA and PDF image data against native RGB. Native PDF is raster; the existing facade retains its vector PDF implementation.</p>'
    (OUT / '03-comparison.html').write_text(page('03-comparison', body, revision))
    body = '<h2>Actual malformed-input results; valid rendering succeeds afterward</h2>' + pre(read('04-errors.json'))
    body += '<h2>Captured clean installed test output</h2>' + pre((OUT / 'native-tests.log').read_text() + '\n' + (OUT / 'facade-tests.log').read_text())
    body += '<p>500 successful renders alternate with 500 public malformed calls and 500 malformed Mojo-parser calls; owned outputs survive GC and input mutation/destruction. Forty calls from four Python threads also pass (GIL held). Nullable masks supported; category/string/timestamp rejected.</p>'
    body += '<p>Bounded lifetime/error evidence only. No sanitizer, leak detector, free-threaded Python or production load claim.</p>'
    (OUT / '04-recovery.html').write_text(page('04-recovery', body, revision))
    body = '<p class="gate"><strong>Decision: retain local experimental wheel. Production E4 gate OPEN.</strong><br>Clean installed native rendering works without a compiler or import-path setup. Bundled proprietary-runtime redistribution is unreviewed; host/ABI portability and broader rendering remain unverified.</p>'
    body += pre(dict(wheel=packaging['wheel'], bytes=packaging['bytes'], sha256=packaging['sha256'],
                     dependency_check=packaging['dependency_check'], runtime_license=build['runtime_license']))
    body += '<h2>Loaded runtime comes from the wheel</h2>' + pre([Path(p).name for p in read('loaded-runtime.json')])
    body += '<table><tr><th>Format</th><th>Samples</th><th>Median ms</th><th>Sample SD ms</th><th>p95 ms</th></tr>'
    for kind, record in benchmark['measurements'].items():
        body += f"<tr><td>{kind}</td><td>{record['n']}</td><td>{record['median_ms']:.3f}</td><td>{record['stdev_ms']:.3f}</td><td>{record['p95_ms']:.3f}</td></tr>"
    body += '</table><p>Three warmups per format. Includes validation, copies, native parse/render and encoding. Excludes build/install/import, initial warmup, file IO and screenshots. Six rows, two layers, 320×240; no broad performance claim.</p>'
    (OUT / '05-packaging.html').write_text(page('05-packaging', body, revision))
    print('Generated five evidence pages from actual installed-run outputs:', OUT)


def finalize():
    build = read('build.json'); packaging = read('packaging.json')
    files = sorted(p for p in HERE.rglob('*') if p.is_file() and
                   not any(part in ('dist', 'build', '__pycache__', '.libs') or part.endswith('.egg-info') for part in p.parts)
                   and p.name != '_build.py')
    sources = {str(p.relative_to(ROOT)): sha(p) for p in files}
    slides = []
    for stem, phase, title in STEPS:
        image = OUT / (stem + '.png')
        data = image.read_bytes(); assert data[:8] == b'\x89PNG\r\n\x1a\n'
        dimensions = list(struct.unpack('>II', data[16:24]))
        slides.append(dict(phase=phase, capture_kind='browser', image=image.name,
                           dimensions=dimensions, caption=title,
                           action='Navigate the T3 collaborative browser to the generated ' + stem + '.html evidence page; save preview_snapshot PNG',
                           expected=title + '; recorded results from the clean installed artifact, with limits shown',
                           sha256=sha(image), evidence_page=stem + '.html', page_sha256=sha(OUT / (stem + '.html'))))
    artifacts = {p.name: sha(p) for p in sorted(OUT.iterdir()) if p.is_file() and p.suffix in ('.svg', '.pdf', '.rgba', '.json', '.log', '.png') and p.name != 'manifest.json'}
    manifest = dict(version=1, demo_id='e04-python-native', title='E04: native Mojo/CPython boundary proof',
        scenario='Clean host wheel import, actual native exports, unchanged facade comparison, malformed/lifetime recovery, inspected deployment decision',
        revision=build['revision'], host=platform.platform(), backend='CPython C ABI → Mojo PlotSpec/Scene → software RGBA and SVG', scale=2,
        fixture='experiments/python-native/tests/fixture.py: canonical six-row line/scatter',
        reproduce='bash experiments/python-native/build.sh; bash experiments/python-native/check.sh; python3 experiments/python-native/evidence.py pages; serve artifact folder on loopback; use T3 preview at 1400x1100 to save each of five HTML pages as matching PNG; python3 experiments/python-native/evidence.py finalize. See README for exact environment and capture steps.',
        source_state=dict(dirty=True, build_dirty=build['dirty'], build_sources_sha256=build['sources_sha256'],
                          build_source_count=len(build['sources']), proof_sources=sources),
        binary_provenance=dict(compiler=build['compiler'], compiler_sha256=build['compiler_sha256'],
                               object_sha256=build['object_sha256'], wheel=packaging['wheel'], wheel_sha256=packaging['sha256'],
                               runtime_hashes=build['runtimes']),
        artifacts_sha256=artifacts,
        capture_environment=dict(viewport_css=[1400, 1100], device_pixel_ratio=2,
            saved_png_dimensions=[slide['dimensions'] for slide in slides],
            note='T3 preview_snapshot downsampled saved captures to 1280x1006; returned PNG bytes were copied unmodified. scale records browser devicePixelRatio, not saved pixels per CSS pixel.'),
        gates=dict(clean_installed_native='passed', facade_regression='passed', repeated_lifetime='bounded pass',
                   dependency_inspection=packaging['dependency_check'], native_abi3='not claimed',
                   production='open', runtime_redistribution='unreviewed', other_hosts='not tested',
                   voiceover='paused; not exercised', sanitizer_or_leak_detector='not run',
                   screenshot_scope='browser evidence pages of actual terminal logs and renderer outputs; not native UI captures'),
        slides=slides)
    (OUT / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    module_spec = importlib.util.spec_from_file_location('demo_slideshows', ROOT / 'scripts/demo_slideshows.py')
    module = importlib.util.module_from_spec(module_spec); module_spec.loader.exec_module(module)
    loaded = module.load_manifest(OUT / 'manifest.json')
    (OUT / 'index.html').write_text(module.render(loaded))
    print('Validated and generated only the E04 slideshow; root gallery unchanged')

if __name__ == '__main__':
    parser = argparse.ArgumentParser(); parser.add_argument('mode', choices=('pages', 'finalize'))
    args = parser.parse_args()
    pages() if args.mode == 'pages' else finalize()
