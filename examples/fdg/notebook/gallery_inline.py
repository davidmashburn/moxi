#!/usr/bin/env python3
"""Validate real P04 captures and publish local slideshow plus compact evidence."""
import hashlib
import json
from pathlib import Path
import statistics
import struct
import sys

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
DIST=HERE.parent/'dist/interactive'
DEST=ROOT/'artifacts/demo-slideshows/fdg-inline-notebook'
sys.path.insert(0,str(ROOT))
from scripts.demo_slideshows import CaptureKind, Phase, load_manifest, render

STATES=[
 ('01-initial.png',Phase.INITIAL,'Inline 77-node graph','Run all cells in a fresh Python kernel','Real Mojo state reports 77 nodes and 254 links; kernel roundtrip acknowledged'),
 ('02-drag.png',Phase.INTERACTION,'Drag held before release','Press a real graph node and move the mouse while held','Selection changes and the actual Mojo node is pinned at the dragged location'),
 ('03-pan-pause.png',Phase.RESULT,'Pan, zoom and pause','Release, pan blank canvas, wheel, Resume then Pause','Actual Moxi pan and zoom changed; solver is paused; output B remains independent'),
 ('04-two-outputs.png',Phase.RESULT,'Two independent notebook outputs','Use a taller viewport to inspect both cells','77/254 and 256/1024 graph states coexist'),
 ('05-resize.png',Phase.INTERACTION,'Narrow layout and hit testing','Resize to 860 CSS pixels and select a known node','Selection agrees with the actual resized Mojo scene'),
 ('06-scale2.png',Phase.RESULT,'Device scale 2','Set Chromium DPR 2 and select another node','Physical screenshot dimensions double; CSS hit testing still selects the intended node'),
 ('07-failure.png',Phase.RECOVERY,'Actual kernel backend rejection','Set a.set_backend_available(False)','A shows a visible error and releases runtime resources; B remains live'),
 ('08-recovery.png',Phase.RESULT,'Backend restored','Restore backend availability and click Retry','A confirms a new roundtrip and recreates a settled real graph'),
 ('09-restart-stopped.png',Phase.RECOVERY,'Kernel restart stops old outputs','Restart the actual kernel without rerunning cells','Old outputs stop and release runtime resources; PID changes'),
 ('10-restart-recovered.png',Phase.RESULT,'Rerun in the new kernel','Run all cells after restart','Both outputs reconstruct and acknowledge new sessions'),
 ('11-saved-fallback.png',Phase.RECOVERY,'Saved notebook without adapter/network','Export the executed notebook normally; open offline and expand saved SVG','Real saved SVG displays without live widget elements'),
]


def distribution(values):
    if not values:return None
    values=sorted(values)
    return dict(samples=len(values),median_ms=round(statistics.median(values),4),p95_ms=round(values[min(len(values)-1,int(len(values)*.95))],4),max_ms=round(max(values),4))


def main():
    evidence=json.loads((DIST/'evidence.json').read_text())
    for path,digest in {**evidence['source_hashes'],**evidence['build']['source_hashes']}.items():
        assert hashlib.sha256((ROOT/path).read_bytes()).hexdigest()==digest,f'Source changed: {path}; rebuild/recapture'
    assert hashlib.sha256((DIST/'browser.wasm').read_bytes()).hexdigest()==evidence['build']['wasm_sha256']
    summary={key:value for key,value in evidence.items() if key not in ('measurements','build')}
    summary['build']=evidence['build']
    summary['measurements']=[]
    for m in evidence['measurements']:
        values={**m['measures'],**m['input'],'paintMs':m['paintMs'],'commRoundtripMs':m['comm']['roundtripMs'],'commSerializeMs':m['comm']['serializeMs']}
        summary['measurements'].append(dict(nodes=m['nodes'],links=m['links'],metrics={k:distribution(v) for k,v in values.items() if v},
            runtime=m['runtime'],comm=dict(sent=m['comm']['sent'],coalesced=m['comm']['coalesced'],maxQueued=m['comm']['maxQueued'],max_bytes=max(m['comm']['bytes']))))
    (DEST/'evidence.json').write_text(json.dumps(summary,indent=2)+'\n')
    slides=[]
    for name,phase,caption,action,expected in STATES:
        data=(DEST/name).read_bytes()
        slides.append(dict(image=name,phase=phase,capture_kind=CaptureKind.BROWSER,dimensions=list(struct.unpack('>II',data[16:24])),scale=2 if name=='06-scale2.png' else 1,
            caption=caption,action=action,expected=expected,sha256=hashlib.sha256(data).hexdigest()))
    preview=DIST/'preview-evidence.json'
    if preview.exists():
        p=json.loads(preview.read_text())
        assert p['wasm_sha256']==evidence['build']['wasm_sha256']
        for name,caption in [('00-preview.png','T3 collaborative preview: real Jupyter output'),('00-preview-selection.png','T3 collaborative preview: real node selection')]:
            data=(DEST/name).read_bytes()
            slides.append(dict(image=name,phase=Phase.INITIAL if name=='00-preview.png' else Phase.INTERACTION,capture_kind=CaptureKind.BROWSER,dimensions=list(struct.unpack('>II',data[16:24])),scale=p['scale'],caption=caption,action=p['action'],expected=p['expected'],sha256=hashlib.sha256(data).hexdigest()))
        summary['collaborative_preview']=p
        (DEST/'evidence.json').write_text(json.dumps(summary,indent=2)+'\n')
    manifest=dict(version=1,demo_id='fdg-inline-notebook',title='Inline Mojo / Moxi in Jupyter',
        scenario='P04 local browser-owned actual Moxi graph with kernel comms, drag/pan/pause, isolated outputs, resize/DPR, failure/recovery, kernel restart and saved fallback. Remote gate remains unverified.',
        revision=evidence['base_revision'],host=evidence['platform'],backend=f"JupyterLab {evidence['versions']['jupyterlab']} / Chrome {evidence['browser']} / Mojo Wasm64",scale=1,
        fixture='Deterministic FDG benchmark topologies: 77/254 and 256/1024; groups i%6, edge i%n→(7*i+1)%n; 100 solver steps, Fit, Pause',
        reproduce='Follow examples/fdg/notebook/INTERACTIVE.md: build P01, prepare_interactive.py, run check_interactive.py and check_channel.mjs, capture_interactive.py, then gallery_inline.py. Optional dependencies isolated. See evidence.json for exact versions and source hashes.',
        source_provenance=dict(base_revision=evidence['base_revision'],uncommitted_changes=evidence['uncommitted'],wasm_sha256=evidence['build']['wasm_sha256'],source_hashes_file='evidence.json',note='Exact source content hashes recorded; uncommitted_changes describes the captured source scope.'),
        verification=dict(checks=evidence['checks'],skipped=evidence['skipped']),slides=slides)
    path=DEST/'manifest.json';path.write_text(json.dumps(manifest,indent=2)+'\n')
    (DEST/'index.html').write_text(render(load_manifest(path)))
    print(f'Validated {len(slides)} real captures; local slideshow generated')


if __name__=='__main__':main()
