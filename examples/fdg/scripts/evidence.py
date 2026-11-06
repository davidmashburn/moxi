#!/usr/bin/env python3
"""Validate/render ONLY the three P06 sequences using the shared schema v1.

Run after the real replays and verify_artifacts.py. Never fabricates frames.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
from pathlib import Path
import struct
import subprocess

REPO = Path(__file__).resolve().parents[3]
APP = REPO / 'examples/fdg'
BASE = '5db9a010053fd05412ee02d11eed05cce82b2a3c'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def generate(demo, host, backend, scale, binary, wheel=None):
    directory = REPO / 'artifacts/demo-slideshows' / demo
    # Source identity includes the shared library/backend and local application.
    # Record dirty inputs explicitly; never attribute them to a clean revision.
    inputs = [*REPO.glob('src/**/*.mojo'), *REPO.glob('native/*.[cm]'), *REPO.glob('native/*.h'), REPO/'LICENSE',
              *APP.glob('src/*.mojo'), *APP.glob('native/*.[cm]'),
              APP/'moxi_fdg.py', APP/'setup.py', APP/'pyproject.toml',
              *APP.glob('scripts/*.sh'), *APP.glob('scripts/*.py'),
              *APP.glob('tests/*.mojo'), *APP.glob('tests/*.py'),
              *APP.glob('_moxi_fdg_data/*.py'), APP/'examples/triangle.json',
              APP/'Dockerfile.linux', APP/'Dockerfile.linux.dockerignore',
              REPO/'scripts/demo_slideshows.py',
              REPO/'pixi.toml', REPO/'pixi.lock', APP/'tests/fixtures/export.json']
    inputs = sorted(set(inputs))
    sources = {str(path.relative_to(REPO)): sha(path) for path in inputs}
    status = subprocess.check_output(['git','status','--porcelain','--untracked-files=all','--',
                                      'examples/fdg', 'src', 'native', 'pixi.toml', 'pixi.lock'],
                                     cwd=REPO, text=True)
    status = '\n'.join(line for line in status.splitlines() if 'examples/fdg/notebook/' not in line)
    revision = subprocess.check_output(['git','rev-parse','HEAD'],cwd=REPO,text=True).strip()
    scenes = [
        ('phase-0.png','initial','Search selected the Unicode ID; neighborhood enabled',
         'Replay Find and Neighbors through the actual App dispatcher',
         'Selected alpha plus beta/gamma; isolated node absent'),
        ('phase-1.png','interaction','Dragged selected node, cancelled drag, then zoomed',
         'Dispatch pointer down/move/cancel and scroll to the real application',
         'Selection/filter retained; graph geometry and viewport change'),
        ('phase-2.png','result','Current application state exported in three formats',
         'Export the current scene as SVG, PNG and PDF without advancing the solver',
         'Saved status; same selection, neighborhood and camera'),
        ('current.png','result','Reopened PNG export',
         'Read/decode the PNG with Pillow; assert scene geometry against SVG and PDF',
         'Graph canvas only; weighted edges, loop, labels and selected outline preserved'),
        ('reopened-pdf.png','result','PDF independently rasterized with PDFium',
         'Open actual PDF, extract Unicode text and rasterize at 96 DPI',
         'Same page size, labels and node centers as the PNG'),
        ('phase-3.png','recovery','Unsupported extension rejected; SVG succeeds afterward',
         'Attempt .jpg, require failure, then export recovered.svg',
         'Explicit recovery status; application state remains available'),
    ]
    slides=[]
    for image,phase,caption,action,expected in scenes:
        path=directory/image
        raw=path.read_bytes()
        dimensions=list(struct.unpack('>II',raw[16:24]))
        slides.append(dict(image=image,phase=phase,caption=caption,action=action,expected=expected,
                           capture_kind='offscreen-render',dimensions=dimensions,sha256=sha(path),
                           file_modified_utc=datetime.fromtimestamp(path.stat().st_mtime,timezone.utc).isoformat()))
    missing=['native-window compositor screenshots (AppKit cacheDisplay / GTK widget snapshots are offscreen)',
             'human pointer/keyboard and native Save-dialog walkthrough',
             'VoiceOver/screen-reader acceptance (paused)', 'physical Linux hardware / Wayland desktop acceptance',
             'remote CI, public redistribution and older macOS deployment acceptance']
    reproduce=('See examples/fdg/P06.md. Run the appropriate native --replay with tests/fixtures/export.json, '
               'then tests/verify_artifacts.py and scripts/evidence.py; PNG/HTML and export binaries are local ignored artifacts.')
    manifest=dict(version=1,demo_id=demo,title={'fdg-export':'FDG current-state export comparison',
                  'fdg-clean-consumer':'FDG installed-wheel consumer', 'fdg-linux':'FDG Linux GTK / software rendering'}[demo],
                  revision=revision,base_revision=BASE,
                  source_state='dirty integrated sources' if status else 'clean integrated source commit',
                  scoped_source_dirty_status=status,source_sha256=sources,host=host,backend=backend,scale=scale,
                  fixture='examples/fdg/tests/fixtures/export.json',fixture_sha256=sha(APP/'tests/fixtures/export.json'),
                  scenario='Synthetic finite replay in the real native application: search/neighborhood, drag/cancel/zoom, export and recovery. No human interaction claim.',
                  reproduce=reproduce,missing_frames_or_gates=missing,slides=slides,
                  binary_sha256=sha(binary),binary_role='native source build' if demo!='fdg-clean-consumer' else 'installed wheel executable',
                  artifact_sha256={str(p.relative_to(directory)):sha(p) for p in directory.rglob('*') if p.suffix in ('.svg','.png','.pdf')},
                  export_assertions=json.loads((directory/'export-check.json').read_text()))
    manifest['supporting_checks'] = {
        str(p.relative_to(directory)): {'sha256':sha(p)}
        for p in directory.rglob('*.json') if p.name != 'manifest.json'}
    if wheel:
        manifest['wheel']={'filename':wheel.name,'sha256':sha(wheel)}
    path=directory/'manifest.json'
    path.write_text(json.dumps(manifest,indent=2)+'\n')
    spec=importlib.util.spec_from_file_location('demo_slideshows',REPO/'scripts/demo_slideshows.py')
    shared=importlib.util.module_from_spec(spec); spec.loader.exec_module(shared)
    checked=shared.load_manifest(path)
    (directory/'index.html').write_text(shared.render(checked))
    print(f'Validated {demo}: {len(slides)} actual frames, {len(sources)} source hashes')


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('demo',choices=['fdg-export','fdg-clean-consumer','fdg-linux'])
    parser.add_argument('--host',required=True)
    parser.add_argument('--backend',required=True)
    parser.add_argument('--scale',type=float,required=True)
    parser.add_argument('--binary',type=Path,required=True)
    parser.add_argument('--wheel',type=Path)
    generate(**vars(parser.parse_args()))
