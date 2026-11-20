#!/usr/bin/env python3
"""Refresh/check only E02/E03 evidence; never change the common gallery index.

Use --refresh after the documented browser batch, --sheets for local review
panels, and no options for a fail-closed audit of the completed review.
"""
import argparse
from collections import Counter
from datetime import datetime, timezone
from enum import Enum
import hashlib
import json
from pathlib import Path
import subprocess
import sys
from xml.etree import ElementTree

from PIL import Image, ImageChops, ImageDraw
from matplotlib import get_data_path
from demo_slideshows import load_manifest, render

ROOT = Path(__file__).resolve().parents[1]
GALLERIES = ROOT / 'artifacts/demo-slideshows'
REVIEW = GALLERIES / 'plot-wave-b-c-review'
REVISION = 'd7fa3ed563948860f4baf18bcc9f3eb279197135'
REFERENCE = '3fd5a7e7c622d6130c99a290b88c4fee039deab2'
FONT = '3fdf69cabf06049ea70a00b5919340e2ce1e6d02b0cc3c4b44fb6801bd1e0d22'


class ReviewOutcome(str, Enum):
    PASS = 'pass'
    PARTIAL = 'partial'
    BLOCKED = 'blocked'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def git_json(path):
    return json.loads(subprocess.check_output(
        ['git', 'show', f'{REVISION}:{path}'], cwd=ROOT, text=True))


def runtime_hash(wave):
    code = (f"import sys;sys.path.insert(0,'scripts/wave_{wave}');"
            'from verify import runtime_source_hash;print(runtime_source_hash())')
    return subprocess.check_output([sys.executable, '-c', code], cwd=ROOT, text=True).strip()


def check_state(state, key):
    for name, expected in state['files'].items():
        assert sha(ROOT/name) == expected, f'Stale source fingerprint: {name}'
    actual = hashlib.sha256(json.dumps(state['files'], sort_keys=True).encode()).hexdigest()
    assert actual == state[key], 'Source fingerprint aggregate mismatch'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--refresh', action='store_true')
    parser.add_argument('--sheets', action='store_true')
    args = parser.parse_args()
    paths = sorted(GALLERIES.glob('e02-*/manifest.json')) + sorted(GALLERIES.glob('e03-*/manifest.json'))
    assert len(paths) == 26
    assert subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip() == REVISION
    # Published runtime, fixture inputs and native assertions must remain exact.
    runtime_paths = ['src/moxi', 'src/moxi_plot', 'python/moxi', 'pixi.lock', 'pixi.toml',
                     'tests/plot_wave_b.mojo', 'tests/plot_specialized_c.mojo',
                     'tests/fixtures/wave_c/cases.json']
    runtime_paths += [str(p.relative_to(ROOT)) for p in (ROOT/'tests/fixtures/wave_b').glob('*.json')
                      if p.name not in ('observed.json', 'source-state.json', 'registry.json')]
    assert not subprocess.check_output(['git', 'diff', REVISION, '--', *runtime_paths], cwd=ROOT), 'Runtime differs from published source'
    captures = json.loads((REVIEW/'captures.json').read_text())
    capture_map = {entry['target']: entry for entry in captures}
    assert len(capture_map) == len(captures) == 81
    plan = json.loads((REVIEW/'capture-plan.json').read_text())
    assert len(plan) == 81
    assert {entry['target'] for entry in plan} == set(capture_map)
    for entry in plan:
        capture = capture_map[entry['target']]
        assert capture['page_path'] == entry['page']
        assert capture['requested_viewport'] == dict(width=entry['width'], height=entry['height'])
        for error in capture['ignored_browser_errors']:
            assert error['location']['url'].endswith('/favicon.ico')
    state_b = json.loads((ROOT/'tests/fixtures/wave_b/source-state.json').read_text())
    check_state(state_b, 'sha256')
    observed = {wave: json.loads((ROOT/f'tests/fixtures/wave_{wave}/observed.json').read_text())
                for wave in ('b', 'c')}
    prior_observed = {wave: git_json(f'tests/fixtures/wave_{wave}/observed.json') for wave in ('b', 'c')}
    check_state(observed['c']['source_state'], 'scoped_sha256')
    upstream = ROOT/'output/e02-e03-d7fa3ed/upstream'
    assert subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=upstream, text=True).strip() == REFERENCE
    assert not subprocess.check_output(['git', 'status', '--porcelain'], cwd=upstream), 'Upstream checkout is dirty'
    for wave, record in observed.items():
        assert record['runtime_source_sha256'] == runtime_hash(wave)
        assert record['upstream']['revision'] == REFERENCE
        assert record['upstream']['returncode'] == 0
        assert record['upstream']['dirty'] is False
        assert record['upstream']['font_sha256'] == FONT
        assert record['upstream']['canvas_revision'] == '58fb12a471a65dfbc29ebc743860448439a6af22'
        assert (record['upstream']['moxi_lock_sha256'] if wave == 'c' else record['moxi_lock_sha256']) == sha(ROOT/'pixi.lock')
        run_root = ROOT/'output/e02-e03-d7fa3ed'
        reference = run_root/f'e0{2 if wave == "b" else 3}-reference'
        actual = run_root/f'e0{2 if wave == "b" else 3}-actual'
        assert sha(reference/'reference.mojo') == record['upstream']['driver_sha256']
        assert sha(actual/'driver.mojo') == record['moxi_driver_sha256' if wave == 'b' else 'driver_sha256']
        results = json.loads((actual/'results.json').read_text())
        assert results['runtime_source_sha256'] == record['runtime_source_sha256']
        assert sha(run_root/'upstream/pixi.lock') == record['upstream']['lock_sha256']
        assert sha(Path(get_data_path())/'fonts/ttf/DejaVuSans.ttf') == FONT
    assert observed['b']['upstream']['missing'] == ['contour', 'contourf']
    assert observed['c']['upstream']['tricontour_available'] is False
    review_path = REVIEW/'review.json'
    reviews = json.loads(review_path.read_text()) if review_path.exists() else None
    if reviews is not None and not (args.refresh or args.sheets):
        assert reviews['revision'] == REVISION
        assert reviews['environment']['runtime_source_sha256'] == {w:r['runtime_source_sha256'] for w,r in observed.items()}
        assert set(reviews['families']) == {p.parent.name for p in paths}
    counts = Counter()
    families = []
    for path in paths:
        manifest = json.loads(path.read_text())
        demo = manifest['demo_id']
        wave = 'b' if demo.startswith('e02-') else 'c'
        name = demo[4:].replace('-', '_')
        folder = path.parent
        assert manifest['revision'] == REVISION
        if wave == 'b':
            assert manifest['source_state_sha256'] == sha(ROOT/manifest['source_state_path'])
            assert manifest['source_dirty'] == state_b['dirty']
        else:
            assert manifest['source_state'] == observed['c']['source_state']
        old = git_json(path.relative_to(ROOT))
        baseline = {slide['image']: slide['sha256'] for slide in old['slides']}
        frames = []
        for slide in manifest['slides']:
            target = str((folder/slide['image']).relative_to(ROOT))
            digest = sha(ROOT/target)
            with Image.open(ROOT/target) as image:
                image.verify()
            with Image.open(ROOT/target) as image:
                dimensions = list(image.size)
            if args.refresh:
                slide.update(sha256=digest, dimensions=dimensions)
                if slide['capture_kind'] == 'browser':
                    slide['browser_metrics'] = capture_map[target]['page']['value']
                    slide['capture_scale_note'] = 'Local headless Chrome screenshot in CSS pixels at DPR 1; see batch capture metrics. Viewport enlarged when needed to include the complete page.'
            assert slide['sha256'] == digest, f'Frame hash mismatch: {target}'
            if slide['capture_kind'] == 'browser':
                capture = capture_map[target]
                metrics = capture['page']['value']
                assert not capture['console_errors'] and not capture['failed_requests']
                assert capture['sha256'] == digest
                assert [metrics['innerWidth'], metrics['innerHeight']] == dimensions
                assert metrics['scrollHeight'] <= dimensions[1], f'Page clipped vertically: {target}'
                assert metrics['scrollWidth'] <= dimensions[0], f'Page clipped horizontally: {target}'
                assert all(i['complete'] and i['naturalWidth'] > 0 for i in metrics['images'])
                for loaded in metrics['images']:
                    image_path = GALLERIES/loaded['src'].lstrip('/')
                    assert image_path.parent == folder and image_path.is_file()
                counts['browser_frames'] += 1
            frames.append(dict(image=slide['image'], sha256=digest, dimensions=dimensions,
                               baseline_sha256=baseline[slide['image']],
                               matches_baseline=digest == baseline[slide['image']]))
        if args.refresh:
            manifest['runtime_source_sha256'] = observed[wave]['runtime_source_sha256']
            manifest['backend'] = 'Mojo Scene/Canvas offscreen; pinned dataviz; local headless Chrome evidence replay'
            manifest['reproduce'] = 'See ../plot-wave-b-c-review/REPRODUCE.md for this integrated-source batch and checks.'
            path.write_text(json.dumps(manifest, indent=2)+'\n')
            (folder/'index.html').write_text(render(load_manifest(path)))
        else:
            load_manifest(path)
        assert manifest['runtime_source_sha256'] == observed[wave]['runtime_source_sha256']
        artifacts = {p.name: sha(p) for p in sorted(folder.iterdir()) if p.suffix in ('.png', '.pdf', '.svg')}
        for p in folder.glob('*.svg'):
            assert ElementTree.parse(p).getroot().tag.endswith('svg')
            counts['svg_files'] += 1
        for p in folder.glob('*.pdf'):
            assert p.read_bytes().startswith(b'%PDF-')
            counts['pdf_files'] += 1
        for filename, expected in observed[wave]['cases'][name]['artifacts' if wave == 'b' else 'artifact_sha256'].items():
            assert artifacts[filename] == expected, f'Observed artifact mismatch: {demo}/{filename}'
        case = observed[wave]['cases'][name]
        actual = ROOT/'output/e02-e03-d7fa3ed'/('e02-actual' if wave == 'b' else 'e03-actual')
        reference = ROOT/'output/e02-e03-d7fa3ed'/('e02-reference' if wave == 'b' else 'e03-reference')
        if 'reference_svg_sha256' in case:
            assert sha(reference/(name+'.svg')) == case['reference_svg_sha256']
        if wave == 'c':
            assert sha(actual/(name+'-scene.svg')) == case['scene_svg_sha256']
            assert sha(actual/(name+'-table.csv')) == case['source_csv_sha256']
        for p in folder.glob('*.png'):
            with Image.open(p) as image:
                image.verify()
            counts['png_files'] += 1
        restore = folder/('07-recovery.png' if wave == 'b' else '06-recovery.png')
        original = Image.open(folder/'moxi.png').convert('RGB')
        updated = Image.open(folder/'05-update.png').convert('RGB')
        assert ImageChops.difference(original, Image.open(restore).convert('RGB')).getbbox() is None
        assert ImageChops.difference(original, updated).getbbox() is not None
        if wave == 'b':
            assert ImageChops.difference(updated, Image.open(folder/'06-rejected.png').convert('RGB')).getbbox() is None
        missing = name in ('contour', 'contourf', 'tricontour')
        if missing:
            page = folder/('reference-gap.html' if wave == 'b' else 'reference.html')
            assert 'no substitute' in page.read_text().lower() or 'no replacement' in page.read_text().lower() or 'absence report' in page.read_text().lower()
            assert manifest['slides'][1]['capture_kind'] == 'browser'
        if args.sheets:
            # Every image at original resolution. Review each identified frame;
            # open individual files as needed for small table text or geometry.
            sequence = [s['image'] for s in manifest['slides']] + ['moxi.png', 'selected.png', 'python-export.png' if wave == 'b' else 'export.png']
            for group in ('browser', 'plots'):
                names = [n for n in sequence if (Image.open(folder/n).width > 640) == (group == 'browser')]
                images = [Image.open(folder/n).convert('RGB') for n in names]
                columns = 1 if group == 'browser' else 2
                cell_width = max(i.width for i in images)
                row_heights = [max(i.height+36 for i in images[j:j+columns]) for j in range(0,len(images),columns)]
                panel = Image.new('RGB', (columns*cell_width, sum(row_heights)), '#e7ebf2')
                draw = ImageDraw.Draw(panel)
                for j,(filename, image) in enumerate(zip(names, images)):
                    x = (j % columns)*cell_width
                    y = sum(row_heights[:j//columns])
                    draw.text((x+12, y+8), f'{demo} / {filename}', fill='black')
                    panel.paste(image, (x, y+36))
                panel.save(REVIEW/f'{demo}-review-{group}.png')
        if not args.refresh and not args.sheets:
            assert reviews is not None, 'Missing visual review record'
            r = reviews['families'][demo]
            ReviewOutcome(r['outcome'])
            assert r['reviewed_sha256'] == {f['image']: f['sha256'] for f in frames}, f'Review is stale: {demo}'
            assert r['supporting_image_sha256'] == {n: h for n, h in artifacts.items() if n.endswith('.png') and n not in r['reviewed_sha256']}
            assert set(r['scenario_outcomes']) == {'source', 'reference', 'comparison', 'selection', 'update_export', 'rejection_recovery'}
            all_reviewed = r['reviewed_sha256'] | r['supporting_image_sha256']
            assert set(r['frame_assessments']) == set(all_reviewed)
            for filename, assessment in r['frame_assessments'].items():
                assert assessment['sha256'] == all_reviewed[filename]
                assert assessment['observation'].strip()
                assert (REVIEW/assessment['evidence']).resolve() == (folder/filename).resolve()
            for scenario in r['scenario_outcomes'].values():
                ReviewOutcome(scenario['outcome'])
                assert all(scenario[field].strip() for field in ('steps', 'expected', 'observed'))
                assert scenario['evidence']
                for link in scenario['evidence']:
                    assert not Path(link).is_absolute() and (REVIEW/link).exists(), link
            assert ReviewOutcome(r['scenario_outcomes']['reference']['outcome']) is (ReviewOutcome.BLOCKED if missing else ReviewOutcome.PASS)
        counts['families'] += 1
        counts['frames'] += len(frames)
        counts['frames_matching_baseline'] += sum(f['matches_baseline'] for f in frames)
        current_case = observed[wave]['cases'][name]
        previous_case = prior_observed[wave]['cases'][name]
        fields = ('classification', 'comparison') if wave == 'b' else ('classification', 'geometry', 'source_rows', 'selection', 'upstream_structure', 'missing_gate')
        semantic_comparison = {key: dict(matches=current_case.get(key) == previous_case.get(key),
                                         previous=previous_case.get(key), current=current_case.get(key))
                               for key in fields if key in current_case or key in previous_case}
        if wave == 'b':
            for key in ('rows', 'glyphs', 'vertices', 'selection'):
                previous = previous_case['benchmark_and_interaction'][key]
                current = current_case['benchmark_and_interaction'][key]
                semantic_comparison[key] = dict(matches=previous == current, previous=previous, current=current)
        families.append(dict(demo_id=demo, baseline_revision=old['revision'],
            baseline_source_dirty=old['source_dirty'], frames=frames, artifact_sha256=artifacts,
            baseline_observations=semantic_comparison,
            upstream_reference_available=not missing))
    assert counts['frames'] == 170 and counts['browser_frames'] == 81
    if not (args.refresh or args.sheets):
        outcomes = Counter(scenario['outcome'] for family in reviews['families'].values()
                           for scenario in family['scenario_outcomes'].values())
        assert reviews['counts']['scenario_outcomes'] == dict(outcomes)
        assert reviews['counts']['family_outcomes'] == dict(Counter(
            family['outcome'] for family in reviews['families'].values()))
        assert reviews['counts']['visually_inspected_pngs'] == counts['png_files']
    report = dict(revision=REVISION, checked_at=datetime.now(timezone.utc).isoformat(),
                  counts=dict(counts), runtime_source_sha256={w:r['runtime_source_sha256'] for w,r in observed.items()},
                  families=families, visual_review_checked=not(args.refresh or args.sheets),
                  evidence_tool_sha256={str(p.relative_to(ROOT)):sha(p) for p in
                      (ROOT/'scripts/capture_plot_gallery_evidence.py', Path(__file__))},
                  baseline_image_limit='Old PNG files were absent; compare their committed hashes and observations, not an invented side-by-side image review.')
    (REVIEW/'checks.json').write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps(dict(counts), sort_keys=True))


if __name__ == '__main__':
    main()
