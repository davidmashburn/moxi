#!/usr/bin/env python3
"""Provenance for the real D04 replay; never manufactures a screenshot."""
import hashlib
import json
import platform
import struct
import subprocess
import sys
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / 'artifacts/demo-slideshows/mindmap'

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def source_paths():
    sources = set()
    for directory in ('src/moxi', 'src/moxi_canvas', 'src/moxi_mindmap', 'native', 'scripts/mindmap', 'tests/mindmap'):
        for p in (ROOT / directory).rglob('*'):
            if p.suffix in {'.mojo', '.m', '.h', '.py', '.sh', '.mm', '.json'} and '__pycache__' not in p.parts:
                sources.add(p)
    sources.update(ROOT / p for p in ['examples/mindmap_native_app.mojo', 'scripts/demo_slideshows.py', 'pixi.toml', 'pixi.lock'])
    sources = sorted(p for p in sources if p.exists())
    return sources

def snapshot():
    return dict(revision=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(), source_sha256={str(p.relative_to(ROOT)): sha(p) for p in source_paths()})

def main(record):
    assert snapshot() == record, "Source changed during native build/replay; recapture required"
    records = [
        ('01-initial', 'initial', 'Ordered local map', 'Open the six-topic synthetic map.', 'Two root sides, ordinary editable topic controls and an independent crosslink.'),
        ('02-mixed-edit', 'interaction', 'Mixed-script ordinary editor', 'Deliver F2 through AppKit NSEvent/native queue; insert text through the public event API.', 'Ordinary editor receives Unicode. This is not physical IME evidence.'),
        ('03-fold-search', 'interaction', 'Fold and search', 'Space folds Research; Find receives an Arabic query.', 'A hidden topic remains discoverable without changing stored folds.'),
        ('04-reparent-preview', 'interaction', 'Keyboard semantic destination', 'Use F6, Enter, type Move branch, Enter, type Research, Enter through public key/text events.', 'Published proposed geometry and rerouted tree edge; committed tree unchanged.'),
        ('05-cancel', 'recovery', 'Cancel destination', 'Escape cancels the semantic transaction.', 'Document encoding equals its pre-preview encoding; no history entry.'),
        ('06a-reflow-start', 'interaction', 'Neighbor reflow starts', 'Commit the semantic move once.', 'Moved branch is at its destination; neighbors start from prior displayed bounds.'),
        ('06b-reflow-middle', 'interaction', 'Neighbor reflow midpoint', 'Advance the public frame clock by 90 ms.', 'Shared canvas geometry interpolates; semantic content and history are unchanged.'),
        ('06-reparent-result', 'result', 'One branch move', 'Advance the remaining 90 ms after the single semantic commit.', 'Neighbor bounds reach the exact destination; one semantic commit changes parent and sibling order.'),
        ('07-undo', 'recovery', 'Undo branch move', 'Invoke the actual Undo command.', 'Stable topic IDs, prior parent/order and links restored.'),
        ('07b-reduced-motion', 'result', 'Reduced motion', 'Repeat the same move with the explicit reduced-motion policy.', 'The same final layout appears immediately, without animation.'),
        ('08a-pointer-preview', 'interaction', 'Pointer branch preview', 'Public pointer-down on a displayed topic header, then pointer-move onto Share findings.', 'Shared canvas capture and semantic destination proposal use actual geometry.'),
        ('08a-pointer-cancel', 'recovery', 'Pointer capture cancellation', 'Deliver pointer-cancel to the active session, then repeat the drag for the next slide.', 'Original document encoding is retained without a history commit.'),
        ('08b-pointer-result', 'result', 'Pointer drop', 'Deliver pointer-up to the same session.', 'The target becomes the parent in one history step.'),
        ('08c-pointer-undo', 'recovery', 'Undo pointer drop', 'Invoke Undo.', 'The prior hierarchy returns.'),
        ('08-side-spacing', 'result', 'Root side and spacing', 'Change Draft side, increase spacing, then Fit.', 'Deterministic layout reflows with stable identities.'),
        ('09-crosslink-outline', 'interaction', 'Crosslink and outline', 'Select two topics, add a connector, then open Outline.', 'Outline and graph share one document; links do not change ancestry.'),
        ('10-save-recovery', 'recovery', 'Local save and recovery', 'Atomically save, edit, write recovery, and load the recovery envelope.', 'Recovered content appears; original saved file is retained.'),
        ('11-import-loss', 'result', 'Bounded import loss report', 'Parse the synthetic loss.mm fixture and display the paged report.', 'Unsupported data is visible; XML source remains untouched and inert.'),
        ('12-large-folded', 'result', '1,000 topics, folded root', 'Open the large fixture with its root folded.', 'One visible topic; this does not establish expanded native capacity.'),
        ('13-large-expanded', 'result', '1,000 topics, culled viewport', 'Open the expanded 1,000-topic fixture with the public canvas camera.', 'Only the viewport is presented; native ordinary command capacity remains 1024.'),
    ]
    sources = source_paths()
    slides = []
    for stem, phase, caption, action, expected in records:
        path = DEST / (stem + '.png')
        data = path.read_bytes()
        assert data[:8] == b'\x89PNG\r\n\x1a\n'
        slides.append(dict(image=path.name, phase=phase, capture_kind='offscreen-render', dimensions=list(struct.unpack('>II', data[16:24])), sha256=sha(path), caption=caption, action=action, expected=expected))
    dirty = subprocess.check_output(['git', 'status', '--porcelain', '--untracked-files=all'], cwd=ROOT, text=True).splitlines()
    source_names = {str(p.relative_to(ROOT)) for p in sources}
    manifest = dict(version=1, demo_id='mindmap', title='Native mind map — public canvas consumer', revision=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(), host=f'macOS {platform.mac_ver()[0]} {platform.machine()}', backend='AppKit contentView cacheDisplay; shared moxi_canvas native presenter', scale=2, fixture='Original synthetic six-topic, import-loss and 1,000-topic fixtures', reproduce='pixi run d04-mindmap-replay', scenario='Real executable and public input/command replay. Only F2 traverses AppKit NSEvent dispatch; remaining inputs are deterministic public Event/command calls. Content-view offscreen renders, not desktop/window captures, physical input or independent acceptance.', source_state='scoped dirty implementation' if any(line[3:] in source_names for line in dirty) else 'clean committed implementation', scoped_dirty_source=[line for line in dirty if line[3:] in source_names], source_sha256=record['source_sha256'], slides=slides)
    DEST.mkdir(parents=True, exist_ok=True)
    (DEST / 'manifest.json').write_text(json.dumps(manifest, indent=2, ensure_ascii=False)+'\n')
    print(f'Wrote {len(slides)} genuine captures; {len(sources)} source hashes including native .m/.h')
if __name__ == '__main__':
    if len(sys.argv) == 3 and sys.argv[1] == '--snapshot':
        Path(sys.argv[2]).write_text(json.dumps(snapshot(), indent=2)+'\n')
    elif len(sys.argv) == 3 and sys.argv[1] == '--from-snapshot':
        main(json.loads(Path(sys.argv[2]).read_text()))
    else:
        raise SystemExit('Use --snapshot PATH before build and --from-snapshot PATH after replay')
