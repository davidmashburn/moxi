"""Render recorded outputs as browser evidence; never invent command results."""
import argparse
import ast
import os
from enum import Enum
import hashlib
import html
import importlib.util
import json
from pathlib import Path
import platform
import re
import struct
import subprocess
import zipfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OUT = Path(os.environ.get('MOXI_E04_ARTIFACTS', ROOT / 'artifacts/demo-slideshows/e04-python-native'))
STEPS = (
    ('01-import', 'initial', 'Clean installed import and compiled ABI version'),
    ('02-render', 'interaction', 'Canonical native scene: SVG and raster PNG'),
    ('03-comparison', 'result', 'Native and unchanged facade export comparison'),
    ('04-recovery', 'recovery', 'Malformed input rejection and repeated lifetime recovery'),
    ('05-packaging', 'result', 'Inspected wheel, bounded timing and deployment decision'),
)
# Publication is an allowlist. Full consumer/build reports retain local paths
# and stay available for verify_inputs(), outside the portable gallery bundle.
PUBLICATION_FILES = frozenset({
    '.gitignore', 'README.md', 'REVIEW.md', 'manifest.json', 'index.html',
    'capture.json', 'gallery-check.json', 'pdf-viewer.json', 'publication.json',
    'hosted.json', 'hosted-cp313.log', 'hosted-cp314.log', 'comparison.json',
    '02-render.json', '04-errors.json', 'benchmark.json',
    'native.png', 'native.svg', 'native.pdf', 'native-pdf-preview.png',
    'facade.png', 'native-tests.log', 'facade-tests.log',
    'cp313-native-tests.log', 'cp313-facade-tests.log',
    'tooling-tests.log', 'verification-tests.log',
} | {stem + suffix for stem, _, _ in STEPS for suffix in ('.html', '.png')})


class Outcome(str, Enum):
    PASS = 'pass'
    PARTIAL = 'partial'
    BLOCKED = 'blocked'


def read(name): return json.loads((OUT / name).read_text())
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def pre(value): return '<pre>' + html.escape(value if isinstance(value, str) else json.dumps(value, indent=2)) + '</pre>'

def verify_inputs(out=OUT):
    """Bind installed outputs to this checkout, not just an advertised revision."""
    def read_report(name): return json.loads((out / name).read_text())
    build = read_report('build.json'); packaging = read_report('packaging.json')
    revision = build['revision']
    # Other units can be integrated after this build. Permit those descendants
    # only while every compiled/facade source still matches the tested commit.
    subprocess.run(['git', '-C', str(ROOT), 'merge-base', '--is-ancestor', revision, 'HEAD'],
                   check=True, capture_output=True)
    sources = build['sources']
    assert hashlib.sha256(json.dumps(sources, sort_keys=True).encode()).hexdigest() == build['sources_sha256']
    for name, digest in sources.items():
        assert sha(ROOT / name) == digest, 'Stale build source: ' + name
    subprocess.run(['git', '-C', str(ROOT), 'diff', '--exit-code', revision, '--', *sources],
                   check=True, capture_output=True)
    assert sha(HERE / 'dist/render.o') == build['object_sha256'], 'Stale native object'
    wheel = HERE / 'dist/wheels' / packaging['wheel']
    assert sha(wheel) == packaging['sha256'], 'Stale wheel'
    with zipfile.ZipFile(wheel) as archive:
        embedded = ast.literal_eval(ast.parse(archive.read('moxi_native/_build.py')).body[0].value)
        assert embedded == build, 'Installed report differs from wheel build metadata'
        for name, record in packaging['binaries'].items():
            assert hashlib.sha256(archive.read(name)).hexdigest() == record['sha256'], name
    initial = read_report('01-import.json')
    package = Path(initial['import_paths'][1]).parent
    assert initial['isolated'] == 1 and initial['mojo_on_path'] is False
    assert initial['process_audit'] == 'enabled'
    loaded = read_report('loaded-runtime.json')
    assert len(loaded) == 3 and all(Path(p).parent == package / '.libs' for p in loaded)
    for name, record in packaging['binaries'].items():
        installed = package / Path(name).relative_to('moxi_native')
        assert sha(installed) == record['sha256'], 'Installed binary mismatch: ' + name
    with zipfile.ZipFile(wheel) as archive:
        for name in ('__init__.py', 'formats.py', '_build.py'):
            data = archive.read('moxi_native/' + name)
            assert (package / name).read_bytes() == data, 'Installed wrapper mismatch: ' + name
            if name != '_build.py':
                assert (HERE / 'moxi_native' / name).read_bytes() == data, 'Stale wrapper: ' + name
    facade_wheels = list((HERE / 'dist/wheels').glob('moxi-*.whl'))
    assert len(facade_wheels) == 1, 'Expected one facade wheel'
    facade_sources = {}
    with zipfile.ZipFile(facade_wheels[0]) as archive:
        for name in archive.namelist():
            if name.startswith('moxi/') and not name.endswith('/'):
                source = ROOT / 'python' / name
                assert hashlib.sha256(archive.read(name)).hexdigest() == sha(source), 'Stale facade wheel: ' + name
                installed = Path(initial['import_paths'][0]).parent.parent / name
                assert sha(installed) == sha(source), 'Stale installed facade: ' + name
                facade_sources[str(source.relative_to(ROOT))] = sha(source)
    subprocess.run(['git', '-C', str(ROOT), 'diff', '--exit-code', revision, '--', *facade_sources],
                   check=True, capture_output=True)
    exports = read_report('02-render.json')
    assert set(exports) == {'rgba', 'png', 'svg', 'pdf'}
    for kind, record in exports.items():
        for backend in ('native', 'facade'):
            artifact = out / (backend + '.' + kind)
            assert artifact.stat().st_size == record[backend + '_bytes'], artifact.name
            assert sha(artifact) == record[backend + '_sha256'], artifact.name
    counts = {}
    for name in ('native-tests.log', 'facade-tests.log'):
        log = (out / name).read_text()
        assert not re.search(r'\b[1-9]\d* (failed|errors?)\b', log), name
        counts[name] = int(re.search(r'\b(\d+) passed\b', log).group(1))
    return dict(native_source_count=len(sources), native_sources_match_revision=True,
                installed_binary_count=len(packaging['binaries']), installed_binaries_match_wheel=True,
                facade_sources=facade_sources, facade_wheel=facade_wheels[0].name,
                facade_wheel_sha256=sha(facade_wheels[0]), exports_checked=8, test_counts=counts)


def page(step, body, revision):
    title = dict((s[0], s[2]) for s in STEPS)[step]
    return ("<!doctype html><html lang='en'><meta charset='utf-8'><link rel='icon' href='data:,'><title>E04 " + title + "</title>"
            "<style>body{font:18px system-ui;margin:28px;color:#17233a;background:#f7f9fc}"
            "h1{font-size:28px;margin:12px 0}h2{font-size:21px}small{color:#46576d}"
            "pre{white-space:pre-wrap;overflow-wrap:anywhere;font:14px ui-monospace,monospace;background:#e9eef5;padding:16px}"
            ".pair{display:flex;gap:24px}.pair>div{width:48%}img{width:480px;height:360px;border:1px solid #bec8d7;background:white}"
            "table{border-collapse:collapse;font-size:16px}td,th{border:1px solid #bec8d7;padding:9px;text-align:left}"
            ".gate{border-left:6px solid #af6313;padding:16px;background:#fff1d8}p{max-width:1200px;line-height:1.5}</style>"
            "<small>E04 · Actual installed outputs and captured test logs · browser evidence page, not a terminal emulator</small>"
            f"<h1>{html.escape(title)}</h1><small>Built source {revision[:12]}; native and facade fingerprints verified against that revision. Capture-tool edits are recorded separately in the manifest.</small>" + body + '</html>')


def pages():
    verify_inputs()
    initial = read('01-import.json'); renders = read('02-render.json')
    packaging = read('packaging.json'); benchmark = read('benchmark.json')
    build = read('build.json'); revision = build['revision']
    assert 'passed' in (OUT / 'native-tests.log').read_text()
    assert 'passed' in (OUT / 'facade-tests.log').read_text()
    small = {k: initial[k] for k in ('python', 'platform', 'moxi_version', 'native_version', 'mojo_on_path', 'isolated', 'process_audit')}
    small.update(compiler=build['compiler'], abi_version=initial['capabilities']['abi_version'],
                 abi3=False, copy_policy=initial['capabilities']['copy_policy'])
    body = '<p>Fresh venv outside the repository. <code>env -i</code>, Python isolated mode, no Mojo/Python import paths, no Mojo compiler on PATH. Process creation is rejected by the probe audit hook.</p>'
    locations = ['<isolated-consumer>/site-packages/' + p.split('/site-packages/', 1)[1]
                 for p in initial['import_paths']]
    body += pre(small) + '<h2>Installed modules (consumer-relative locations)</h2>' + pre(locations)
    body += '<p>The absolute temporary directory is omitted here; the local probe retains and verifies the full installed paths.</p>'
    body += '<p>Compiled Mojo called through the CPython extension; the base <code>moxi</code> facade remains a separate compiler-independent wheel.</p>'
    (OUT / '01-import.html').write_text(page('01-import', body, revision))
    body = '<p>Fixture: six samples, two line/scatter layers, 320×240. Both images below come from the installed native extension. The compiled Mojo scene drives SVG serialization and a CoreGraphics/CoreText sink; PNG includes title, tick and legend glyphs.</p>'
    body += "<div class='pair'><div><h2>Mojo SVG</h2><img src='native.svg'></div><div><h2>Mojo RGBA → PNG</h2><img src='native.png'></div></div>"
    body += '<h2>Actual returned bytes</h2>' + pre({k: dict(bytes=v['native_bytes'], sha256=v['native_sha256']) for k, v in renders.items()})
    (OUT / '02-render.html').write_text(page('02-render', body, revision))
    left = (OUT / 'native.rgba').read_bytes(); right = (OUT / 'facade.rgba').read_bytes()
    difference = sum(abs(a-b) for a,b in zip(left,right)) / len(left)
    body = "<div class='pair'><div><h2>Native experimental PNG</h2><img src='native.png'></div><div><h2>Existing facade PNG</h2><img src='facade.png'></div></div>"
    body += f'<p>Same fixture and dimensions. Mean absolute unaligned RGBA byte difference: {difference:.4f}/255. This is descriptive, not a parity threshold. Fonts, colors and axis layout differ.</p>'
    body += '<table><tr><th>Format</th><th>Native bytes</th><th>Facade bytes</th><th>Native contract check</th></tr>'
    for kind, values in renders.items():
        check = 'Owned bytes; 320×240; decoded by Pillow/pypdf' if kind in ('png', 'pdf') else ('Owned bytes; 320×240×4 byte extent' if kind == 'rgba' else 'Owned bytes; parsed native SVG 320×240')
        body += f"<tr><td>{kind}</td><td>{values['native_bytes']}</td><td>{values['facade_bytes']}</td><td>{check}</td></tr>"
    body += '</table><p>Independent Pillow/pypdf decoding checks PNG against native RGBA, requires selectable PDF title/legend text, and verifies vector strokes without embedded page images. Both renderers produce vector PDF; visual/layout and scientific parity remain unestablished.</p>'
    (OUT / '03-comparison.html').write_text(page('03-comparison', body, revision))
    body = '<h2>Actual malformed-input results; valid rendering succeeds afterward</h2>' + pre(read('04-errors.json'))
    body += '<h2>Captured clean installed test output</h2>' + pre((OUT / 'native-tests.log').read_text() + '\n' + (OUT / 'facade-tests.log').read_text())
    body += '<p>500 successful renders alternate with 500 public malformed calls and 500 malformed Mojo-parser calls; owned outputs survive GC and input mutation/destruction. Forty calls from four Python threads also pass (GIL held). Nullable masks supported; category/string/timestamp rejected.</p>'
    body += '<p>Bounded lifetime/error evidence only. No sanitizer, leak detector, free-threaded Python or production load claim.</p>'
    (OUT / '04-recovery.html').write_text(page('04-recovery', body, revision))
    body = '<p class="gate"><strong>Decision: retain local experimental wheel. Production native-extension gate OPEN.</strong><br>Clean installed rendering passes with process creation blocked and no Mojo compiler on the consumer PATH. Bundled proprietary-runtime redistribution is unreviewed; support beyond tested host/ABI pairs and broader rendering remain unverified.</p>'
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
    verification = verify_inputs()
    build = read('build.json'); packaging = read('packaging.json')
    consumers = []
    directories = [(OUT, '')]
    if (OUT / 'abi-cp313/01-import.json').is_file():
        directories.append((OUT / 'abi-cp313', 'cp313-'))
    for directory, prefix in directories:
        initial = json.loads((directory / '01-import.json').read_text())
        package = json.loads((directory / 'packaging.json').read_text())
        checked = verification if directory == OUT else verify_inputs(directory)
        assert checked['native_sources_match_revision'] and checked['installed_binaries_match_wheel']
        assert checked['native_source_count'] == len(build['sources'])
        logs = {}
        for name in ('native-tests.log', 'facade-tests.log'):
            data = (directory / name).read_bytes()
            count = int(re.search(rb'\b(\d+) passed\b', data).group(1))
            assert count == checked['test_counts'][name]
            target = prefix + name
            if prefix:
                (OUT / target).write_bytes(data)
            logs[target] = dict(passed=count, sha256=sha(OUT / target))
        consumers.append(dict(python=initial['python'], platform=initial['platform'],
            isolated=initial['isolated'], mojo_on_path=initial['mojo_on_path'],
            process_audit=initial['process_audit'], wheel=package['wheel'],
            wheel_sha256=package['sha256'], wheel_bytes=package['bytes'], tests=logs,
            dependency_check=package['dependency_check'],
            binaries={name: {key: record[key] for key in ('sha256', 'architectures')}
                      for name, record in package['binaries'].items()},
            source_verification={key: checked[key] for key in
                ('native_source_count', 'native_sources_match_revision', 'installed_binary_count',
                 'installed_binaries_match_wheel', 'exports_checked')},
            local_only_report_hashes={name: sha(directory / name) for name in
                ('01-import.json', 'packaging.json', 'source-verification.json')
                if (directory / name).is_file()}))
    (OUT / 'publication.json').write_text(json.dumps(dict(version=1,
        revision=build['revision'], native_sources=build['sources'],
        native_sources_sha256=build['sources_sha256'], facade_sources=verification['facade_sources'],
        compiler=build['compiler'], compiler_sha256=build['compiler_sha256'],
        object_sha256=build['object_sha256'], consumers=consumers,
        scope='Portable summaries derived from locally verified reports. Raw reports and binary artifacts remain local; hashes identify those retained reports without publishing their paths.',
        runtime_redistribution='unreviewed; experimental gate remains open'), indent=2) + '\n')
    (OUT / '.gitignore').write_text('# Only the portable evidence bundle is publishable.\n*\n' +
                                  ''.join('!' + name + '\n' for name in sorted(PUBLICATION_FILES)))
    files = subprocess.check_output(['git', '-C', str(ROOT), 'ls-files', 'experiments/python-native'], text=True).splitlines()
    sources = {name: sha(ROOT / name) for name in files}
    capture = read('capture.json')
    slides = []
    for stem, phase, title in STEPS:
        image = OUT / (stem + '.png')
        data = image.read_bytes(); assert data[:8] == b'\x89PNG\r\n\x1a\n'
        dimensions = list(struct.unpack('>II', data[16:24]))
        record = capture['frames'][stem]
        assert record['sha256'] == sha(image) and record['page_sha256'] == sha(OUT / (stem + '.html')), 'Stale capture: ' + stem
        assert record['visual_observation']
        assert not record['page_errors'] and all(i['complete'] and i['natural_width'] for i in record['images'])
        slides.append(dict(phase=phase, capture_kind='browser', image=image.name,
                           dimensions=dimensions, caption=title,
                           action='Load the generated ' + stem + '.html evidence page, await its images/fonts, and save the unaltered browser PNG using the method recorded in capture.json',
                           expected=title + '; recorded results from the clean installed artifact, with limits shown',
                           sha256=sha(image), evidence_page=stem + '.html', page_sha256=sha(OUT / (stem + '.html')),
                           outcome=Outcome(record['scenario_outcome']), visual_outcome=Outcome(record['visual_outcome']),
                           observation=record['visual_observation']))
    artifacts = {str(p.relative_to(OUT)): sha(p) for p in sorted(OUT.rglob('*')) if p.is_file()
                 and p.suffix in ('.svg', '.pdf', '.rgba', '.json', '.log', '.png', '.html')
                 and p.name not in ('manifest.json', 'index.html')}
    published = {name: digest for name, digest in artifacts.items() if name in PUBLICATION_FILES}
    local = {name: digest for name, digest in artifacts.items() if name not in PUBLICATION_FILES}
    manifest = dict(version=1, demo_id='e04-python-native', title='E04: native Mojo/CPython boundary proof',
        scenario='Clean same-host wheel import, actual native exports, unchanged facade comparison, malformed/lifetime recovery, inspected deployment decision',
        revision=build['revision'], host=platform.platform(), backend='CPython C ABI → Mojo PlotSpec/Scene → CoreGraphics/CoreText RGBA/PDF and native SVG', scale=capture['device_pixel_ratio'],
        fixture='experiments/python-native/tests/fixture.py: canonical six-row line/scatter',
        reproduce='bash experiments/python-native/build.sh; bash experiments/python-native/check.sh; python3 experiments/python-native/evidence.py pages; serve artifact folder on loopback; capture and visually review all five pages using the browser method and actual viewport/scale recorded in capture.json; python3 experiments/python-native/evidence.py finalize; python3 experiments/python-native/evidence.py verify. See README.md for prerequisites and exact capture steps.',
        source_state=dict(dirty=bool(subprocess.check_output(['git', '-C', str(ROOT), 'status', '--porcelain'])), build_dirty=build['dirty'], build_sources_sha256=build['sources_sha256'],
                          build_source_count=len(build['sources']), proof_sources=sources),
        verification=verification,
        binary_provenance=dict(compiler=build['compiler'], compiler_sha256=build['compiler_sha256'],
                               object_sha256=build['object_sha256'], wheel=packaging['wheel'], wheel_sha256=packaging['sha256'],
                               runtime_hashes=build['runtimes']),
        artifacts_sha256=published,
        local_only_artifacts_sha256=local,
        capture_environment=dict(captured_at=capture['captured_at'], browser=capture['browser'],
            viewport_css=capture['viewport_css'], device_pixel_ratio=capture['device_pixel_ratio'],
            saved_png_dimensions=[slide['dimensions'] for slide in slides],
            note=capture['note']),
        gates=dict(clean_installed_native='passed', facade_regression='passed', repeated_lifetime='bounded pass',
                   dependency_inspection=packaging['dependency_check'], native_abi3='not claimed',
                   production='open', runtime_redistribution='unreviewed', other_hosts='not included in this local capture',
                   voiceover='paused; not exercised', sanitizer_or_leak_detector='not run',
                   screenshot_scope='browser evidence pages of actual terminal logs and renderer outputs; not native UI captures'),
        slides=slides)
    (OUT / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    module_spec = importlib.util.spec_from_file_location('demo_slideshows', ROOT / 'scripts/demo_slideshows.py')
    module = importlib.util.module_from_spec(module_spec); module_spec.loader.exec_module(module)
    loaded = module.load_manifest(OUT / 'manifest.json')
    (OUT / 'index.html').write_text(module.render(loaded))
    verify()
    print('Validated and generated only the E04 slideshow; root gallery unchanged')


def verify():
    """The common gallery checks PNG extents; also check all E04 hash claims."""
    verification = verify_inputs()
    manifest = read('manifest.json')
    build = read('build.json'); packaging = read('packaging.json'); capture = read('capture.json')
    assert manifest['revision'] == build['revision']
    assert manifest['source_state']['build_sources_sha256'] == build['sources_sha256']
    assert manifest['source_state']['build_source_count'] == len(build['sources'])
    assert manifest['source_state']['build_dirty'] == build['dirty']
    assert manifest['binary_provenance'] == dict(compiler=build['compiler'], compiler_sha256=build['compiler_sha256'],
        object_sha256=build['object_sha256'], wheel=packaging['wheel'], wheel_sha256=packaging['sha256'], runtime_hashes=build['runtimes'])
    assert manifest['scale'] == capture['device_pixel_ratio']
    for key in ('captured_at', 'browser', 'viewport_css', 'device_pixel_ratio', 'note'):
        assert manifest['capture_environment'][key] == capture[key], key
    assert manifest['capture_environment']['saved_png_dimensions'] == [s['dimensions'] for s in manifest['slides']]
    assert manifest['verification'] == verification, 'Stale verification metadata'
    for name, digest in manifest['source_state']['proof_sources'].items():
        assert sha(ROOT / name) == digest, 'Stale evidence source: ' + name
    for name, digest in (manifest['artifacts_sha256'] | manifest.get('local_only_artifacts_sha256', {})).items():
        assert sha(OUT / name) == digest, 'Stale evidence artifact: ' + name
    assert len(manifest['slides']) == len(STEPS)
    for slide, (stem, phase, title) in zip(manifest['slides'], STEPS):
        assert slide['image'] == stem + '.png' and slide['phase'] == phase and slide['caption'] == title
        assert sha(OUT / slide['image']) == slide['sha256'], slide['image']
        assert sha(OUT / slide['evidence_page']) == slide['page_sha256'], slide['evidence_page']
        record = capture['frames'][stem]
        assert slide['sha256'] == record['sha256'] and slide['page_sha256'] == record['page_sha256'], stem
        assert Outcome(slide['outcome']) is Outcome(record['scenario_outcome'])
        assert Outcome(slide['visual_outcome']) is Outcome(record['visual_outcome'])
        assert slide['observation'] == record['visual_observation'], stem
        data = (OUT / slide['image']).read_bytes()
        assert data[:8] == b'\x89PNG\r\n\x1a\n' and list(struct.unpack('>II', data[16:24])) == slide['dimensions']
    print('E04 verified:', verification['native_source_count'], 'build sources,', len(verification['facade_sources']),
          'facade files,', len(manifest['source_state']['proof_sources']), 'proof sources,',
          len(manifest['artifacts_sha256']), 'portable artifacts,',
          len(manifest.get('local_only_artifacts_sha256', {})),
          'local-only artifacts, 5 frames/pages, 8 exports, 4 installed binaries')


def verify_publication():
    """Check portable files without requiring local wheels or consumer venvs."""
    manifest = read('manifest.json')
    capture = read('capture.json')
    assert len(manifest['slides']) == len(STEPS) == len(capture['frames'])
    for name, digest in manifest['artifacts_sha256'].items():
        assert name in PUBLICATION_FILES, 'Not approved for publication: ' + name
        assert sha(OUT / name) == digest, 'Stale portable artifact: ' + name
    for slide, (stem, _, _) in zip(manifest['slides'], STEPS):
        assert slide['image'] == stem + '.png' and slide['evidence_page'] == stem + '.html'
        assert slide['sha256'] == sha(OUT / slide['image']) == capture['frames'][stem]['sha256']
        assert slide['page_sha256'] == sha(OUT / slide['evidence_page']) == capture['frames'][stem]['page_sha256']
        assert slide['visual_outcome'] == Outcome.PASS
    gallery = read('gallery-check.json')
    assert sha(OUT / 'index.html') == gallery['index_sha256']
    assert gallery['offline'] is True and len(gallery['images']) == 10
    assert all(image['complete'] and image['natural_width'] for image in gallery['images'])
    assert len(gallery['checks']) == 16 and all(check['outcome'] == Outcome.PASS for check in gallery['checks'])
    assert not any(gallery[key] for key in ('page_errors', 'console_errors', 'failed_requests'))
    for name in PUBLICATION_FILES:
        path = OUT / name
        if path.is_file() and path.suffix in ('.md', '.json', '.html', '.log'):
            assert not re.search(r'/Users/|/private/(?:tmp|var)/|file:///|moxi-e04-consumer\.', path.read_text()), name
    print('E04 portable publication verified:', len(manifest['artifacts_sha256']),
          'hashed artifacts, 5 captures and offline gallery; local binary/consumer proof is separate')

if __name__ == '__main__':
    parser = argparse.ArgumentParser(); parser.add_argument('mode', choices=('pages', 'finalize', 'verify', 'verify-publication'))
    args = parser.parse_args()
    {'pages': pages, 'finalize': finalize, 'verify': verify, 'verify-publication': verify_publication}[args.mode]()
