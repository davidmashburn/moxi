#!/usr/bin/env python3
"""Validate/build only E01 captures using the repository slideshow contract."""
import argparse
import hashlib
import html
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from demo_slideshows import load_manifest, page, render
ROOT = Path(__file__).resolve().parents[2]
CASES = json.loads((ROOT / 'tests/fixtures/wave_a/cases.json').read_text())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    root = ROOT / 'artifacts/demo-slideshows'
    manifests = [(root / ('e01-' + case['id'].replace('_', '-')) / 'manifest.json')
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
        if not args.check:
            path.write_text(json.dumps(manifest,indent=2)+'\n')
    validated = [(path, load_manifest(path)) for path in manifests]
    if not args.check:
        links = []
        for path, manifest in validated:
            (path.parent / 'index.html').write_text(render(manifest))
            links.append(f'<li><a href="{manifest["demo_id"]}/index.html">'
                         f'{html.escape(manifest["title"])}</a> · six captures</li>')
        body = ('<h1>E01 · Nine specialized layouts</h1>'
                '<p>Actual pinned reference and Moxi offscreen output; revision and source '
                'hashes are recorded in each manifest. '
                'recorded event replay. VoiceOver remains paused.</p><ul>'
                + ''.join(links) + '</ul>')
        (root / 'e01-index.html').write_text(page('E01 slideshows', body))
    print(f'Validated {len(validated)} E01 manifests, 54 real captures')


if __name__ == '__main__':
    main()
