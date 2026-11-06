#!/usr/bin/env python3
"""Validate/build only E03 captures using the repository slideshow contract."""
import argparse
import hashlib
import html
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from demo_slideshows import load_manifest, page, render
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT / 'scripts/wave_c'))
from fixtures import CASES


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--capture-log', type=Path,
                        help='T3 capture records containing target and page.value browser metrics')
    args = parser.parse_args()
    root = ROOT / 'artifacts/demo-slideshows'
    captures = {entry['target']: entry['page']['value']
                for entry in json.loads(args.capture_log.read_text())} if args.capture_log else {}
    manifests = [(root / ('e03-' + case['id'].replace('_', '-')) / 'manifest.json')
                 for case in CASES]
    for path in manifests:
        manifest = json.loads(path.read_text())
        for slide in manifest['slides']:
            actual = hashlib.sha256((path.parent / slide['image']).read_bytes()).hexdigest()
            if args.check:
                if slide.get('sha256') != actual:
                    raise ValueError(f"Capture hash mismatch: {path.parent / slide['image']}")
            else:
                slide['sha256'] = actual
                target = str((path.parent / slide['image']).relative_to(ROOT))
                if target in captures:
                    slide['browser_metrics'] = captures[target]
                    slide['capture_scale_note'] = 'T3 snapshot saved at CSS-pixel resolution; browser DPR is recorded separately.'
        if not args.check:
            path.write_text(json.dumps(manifest,indent=2)+'\n')
    validated = [(path, load_manifest(path)) for path in manifests]
    if not args.check:
        links = []
        for path, manifest in validated:
            (path.parent / 'index.html').write_text(render(manifest))
            links.append(f'<li><a href="{manifest["demo_id"]}/index.html">'
                         f'{html.escape(manifest["title"])}</a> · six captures</li>')
        body = ('<h1>E03 · Twelve specialized layouts</h1>'
                '<p>Actual pinned reference and Moxi offscreen output; revision and source '
                'hashes are recorded in each manifest. '
                'Selection evidence is recorded event replay. VoiceOver remains paused.</p><ul>'
                + ''.join(links) + '</ul>')
        (root / 'e03-index.html').write_text(page('E03 slideshows', body))
    print(f'Validated {len(validated)} E03 manifests, 72 captures; tricontour reference explicitly unavailable')


if __name__ == '__main__':
    main()
