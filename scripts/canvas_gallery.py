#!/usr/bin/env python3
"""Stamp D03 real captures and render using the shared version-1 gallery contract."""
import hashlib
import json
from pathlib import Path
import platform
import struct
import subprocess

from demo_slideshows import load_manifest, render

ROOT = Path(__file__).resolve().parents[1]
paths = sorted([*ROOT.glob('src/moxi_canvas/*.mojo'), *ROOT.glob('examples/canvas_demo/*.mojo'),
                ROOT / 'examples/canvas_probe.mojo', ROOT / 'examples/canvas_graph.mojo',
                ROOT / 'src/moxi/column_view.mojo', ROOT / 'native/macos_window.m',
                ROOT / 'tests/canvas/capture.m', ROOT / 'tests/canvas/native_layers.m', ROOT / 'native/macos_window_state.h',
                ROOT / 'native/macos_paragraph.h', ROOT / 'src/moxi/native_window.mojo',
                ROOT / 'scripts/canvas_checks.sh', ROOT / 'scripts/canvas_gallery.py',
                ROOT / 'scripts/demo_slideshows.py'])
digest = hashlib.sha256()
source_files = {}
for path in paths:
    digest.update(str(path.relative_to(ROOT)).encode())
    digest.update(path.read_bytes())
    source_files[str(path.relative_to(ROOT))] = hashlib.sha256(path.read_bytes()).hexdigest()
revision = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
dirty = bool(subprocess.check_output(['git', 'status', '--porcelain', '--',
                                    *[str(p.relative_to(ROOT)) for p in paths]], cwd=ROOT))
source = f"{'Uncommitted D03 checkout based on' if dirty else 'Committed checkout'} {revision}; source SHA-256 {digest.hexdigest()}"
sequence = [
    ('01-initial.png', 'initial', 'Ordinary components in a real Moxi window', 'Launch the native demo.', 'Editable text, button, slider, fractional ports, edges and minimap appear.'),
    ('10-control-ownership.png', 'interaction', 'Button and slider own their input', 'Click Apply/Stage enabled, then drag the ordinary slider to 80%.', 'Controls change state without moving the node; rich probe content growth republishes ports.'),
    ('05-native-editor.png', 'interaction', 'Live AppKit editor in the transformed node', 'Enter the first node controls and insert text.', 'An actual NSTextField owns editing; this is not a drawn input mock.'),
    ('06-zoom-clip.png', 'interaction', 'Zoomed editor in a scrolled parent', 'Zoom to 80% and scroll the parent by 90 points.', 'The same native editor survives; frame, clip and font agree with published geometry and clipped semantics.'),
    ('02-preview.png', 'interaction', 'Keyboard move preview', 'Leave controls, press M, then Shift+Right seven times and Shift+Down once.', 'The preview moves the selected node and its connection without committing.'),
    ('11-cancel.png', 'recovery', 'Escape discards the move preview', 'Press Escape.', 'The committed position returns without adding a history entry.'),
    ('03-result.png', 'result', 'Committed move and resized ports', 'Repeat and commit the move; press R, Shift+Right five times, Enter.', 'The node is wider and the output port/edge follow its published extent.'),
    ('04-recovery.png', 'recovery', 'Undo restores size and position', 'Undo resize, then undo move.', 'Placement and connection anchors return; earlier control edits remain.'),
    ('07-invalid-edge.png', 'interaction', 'Invalid connection stays a preview', 'Attempt a duplicate source-to-target connection.', 'A rejection reason is visible and the existing graph remains intact.'),
    ('08-reconnected.png', 'result', 'Reconnect retains the old edge until success', 'Choose the existing edge and reconnect to an available input.', 'The rich probe uses the second node’s alternate input; the graph frees the fourth input then reconnects edge 1.'),
    ('09-group-fit.png', 'result', 'Group move, fit and minimap', 'Group nodes 1 and 2, move the group down once, commit, fit all.', 'Children move once with their group; ports, edges and minimap use the same world bounds.'),
]
for demo, title in [('canvas-rich-node', 'Moxi rich-node composition probe'), ('canvas-graph', 'Moxi freeform graph — public second consumer')]:
    folder = ROOT / 'artifacts/demo-slideshows' / demo
    slides = []
    for filename, phase, caption, action, expected in sequence:
        image = folder / filename
        data = image.read_bytes()
        dimensions = list(struct.unpack('>II', data[16:24]))
        slides.append(dict(image=filename, phase=phase, capture_kind='offscreen-render', sha256=hashlib.sha256(data).hexdigest(), dimensions=dimensions,
                           caption=caption, action=action, expected=expected))
    manifest = dict(version=1, demo_id=demo, title=title,
                    scenario='Real transformed ordinary controls, transactional manipulation, connections and groups.',
                    revision=revision, host=f'{platform.system()} {platform.release()} {platform.machine()}',
                    backend='Moxi AppKit ordered controls + Scene slider presenter; NSView bitmap capture',
                    scale=dimensions[0] / 1060, fixture=source,
                    source_state=dict(dirty=dirty, sha256=digest.hexdigest(), files=source_files),
                    reproduce='pixi run canvas-native-check && pixi run canvas-gallery; see docs/canvas-interaction.md',
                    slides=slides)
    path = folder / 'manifest.json'
    path.write_text(json.dumps(manifest, indent=2) + '\n')
    checked = load_manifest(path)
    (folder / 'index.html').write_text(render(checked))
    print(f'{demo}: validated {len(slides)} actual native captures; {source}')
