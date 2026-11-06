#!/usr/bin/env python3
"""D08 native offscreen evidence; fail if build/replay changes scoped source."""
from enum import Enum
from pathlib import Path
import hashlib
import importlib.util
import json
import math
import platform
import struct
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / 'artifacts/demo-slideshows/spatial-world-panel'
SCOPES = ('examples/spatial-world-panel', 'examples/spatial-explorer',
          'examples/spatial-assembly', 'native', 'src/moxi', 'src/moxi_spatial',
          'tests/spatial', 'pixi.toml', 'pixi.lock', 'scripts/demo_slideshows.py')

class Phase(str, Enum):
    INITIAL = 'initial'
    INTERACTION = 'interaction'
    RESULT = 'result'
    RECOVERY = 'recovery'

STATES = [
 ('01-oblique', Phase.INITIAL, 'Ordinary text, button and slider on a real oblique plane', 'Launch native probe', 'Perspective-correct texture in the existing depth pass'),
 ('02-capture-outside', Phase.INTERACTION, 'Ray slider drag retains capture outside the panel', 'Drag local x=100 to x=500 on a 400-point panel', 'Slider reaches 100; capture remains active until release'),
 ('03-text-focus-failure', Phase.RESULT, 'Focus survives; native world text geometry fails', 'Click button and text; compare actual caret with its world projection', 'One click and stable focus; source-local IME coordinates explicitly unsupported'),
 ('04-hidden-click', Phase.INTERACTION, 'Clipping and real scene occlusion reject input', 'Clip x<0; add foreground geometry; attempt both hidden targets', 'Clipped and depth-occluded clicks return HIDDEN'),
 ('05-screen-editor', Phase.RESULT, 'Equivalent screen editor controls the same model', 'Switch mode; replay native text protocols, selection, clipboard and keyboard', 'Same text/count/level; actual native roles and coherent screen caret'),
 ('06-cancel-recovery', Phase.RECOVERY, 'Cancellation restores state; world promotion rejected', 'Return to world; drag slider then Escape', 'Level restored to 99; explicit supported geometry and failed world IME/AX cases'),
]

def sha(data):
    return hashlib.sha256(data).hexdigest()

def sources():
    paths = set()
    for scope in SCOPES:
        p = ROOT / scope
        if p.is_file():
            paths.add(p)
        else:
            paths.update(f for f in p.rglob('*') if f.is_file() and f.suffix in {'.mojo','.m','.h','.inc','.hpp','.cpp','.sh','.py','.md'})
    return {str(p.relative_to(ROOT)): sha(p.read_bytes()) for p in sorted(paths)}

def fingerprint(files):
    return sha(json.dumps(files, sort_keys=True).encode())

def output(command):
    return subprocess.check_output(command, cwd=ROOT, text=True).strip()

def run(command, log):
    start = time.perf_counter()
    with open(log, 'w') as stream:
        subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT, check=True, timeout=240)
    return time.perf_counter() - start

def distribution(values):
    assert values and all(math.isfinite(v) for v in values)
    ordered = sorted(values)
    return {'samples': len(values), **{key: ordered[math.ceil(len(values)*q)-1] for key,q in (('p50',.5),('p95',.95),('p99',.99),('worst',1))}}

def main():
    DEST.mkdir(parents=True, exist_ok=True)
    before = sources()
    source_hash = fingerprint(before)
    revision = output(['git','rev-parse','HEAD'])
    dirty = output(['git','status','--short','--untracked-files=all','--',*SCOPES])
    started = time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())
    toolchain = {'mojo': output(['pixi','run','mojo','--version']),
                 'clang': output(['clang','--version']).splitlines()[0],
                 'sdk': output(['xcrun','--show-sdk-version']),
                 'pixi_lock_sha256': before['pixi.lock'], 'host': platform.platform()}
    # The source manifest exists before any build, independently of final output.
    Path('/tmp/moxi-d08-source-before.json').write_text(json.dumps({'revision': revision, 'files': before, 'source_sha256': source_hash, 'scoped_git_status': dirty}, indent=2)+'\n')
    build_seconds = run(['bash','examples/spatial-world-panel/build.sh'], '/tmp/moxi-d08-gallery-build.log')
    executable = ROOT / 'dist/spatial-world-panel/panel'
    cold, warm, bridge, evidence = [], [], [], []
    for index in range(3):
        log = f'/tmp/moxi-d08-gallery-replay-{index}.log'
        run([str(executable),'--replay',str(DEST)],log)
        lines = Path(log).read_text().splitlines()
        c = [float(s.split()[1]) for s in lines if s.startswith('COLD ')]
        w = [list(map(float,s.split()[1:])) for s in lines if s.startswith('WARM ')]
        assert len(c)==1 and len(w)==30 and any(s.startswith('PASS D08 ordinary') for s in lines), log
        assert any(s.startswith('IDLE_REUSE 100 mappings zero submissions') for s in lines), log
        cold.extend(c); warm.extend(row[0] for row in w); bridge.extend(row[1] for row in w)
        assert any(s.startswith('REUSE_PASS 30 draws') for s in lines), log
        evidence.append({'log': log, 'observations': [s for s in lines if s.startswith(('WORLD_IME_FAILED','SCREEN_CARET_PASS','PASS native','IDLE_REUSE','REUSE_PASS'))]})
    after = sources()
    assert before==after, 'Source changed during build/replay; discard these captures'
    assert revision==output(['git','rev-parse','HEAD']), 'Revision changed during replay'
    slides=[]
    for name,phase,caption,action,expected in STATES:
        data=(DEST / (name+'.png')).read_bytes()
        assert data[:8]==b'\x89PNG\r\n\x1a\n'
        slides.append(dict(scenario_id=name, phase=phase.value, capture_kind='offscreen-render', image=name+'.png', dimensions=list(struct.unpack('>II',data[16:24])), caption=caption, action=action, expected=expected, png_sha256=sha(data)))
    manifest=dict(version=1,demo_id='spatial-world-panel',title='Spatial S4 — world panel feasibility',scenario='Ordinary components: real world plane versus native screen editor',revision=revision,host=platform.platform(),backend='Experimental D05 copied-image Metal + actual AppKit ordinary components',scale=slides[0]['dimensions'][0]/1000,fixture=f'400×240 source; 940×420 depth target; source SHA-256 {source_hash}; scoped dirty source: {bool(dirty)}',reproduce='pixi install --locked && python3 examples/spatial-world-panel/gallery.py',slides=slides)
    provenance=dict(base_revision=revision,uncommitted_source=bool(dirty),scoped_git_status_before_build=dirty,captured_before_build_at=started,toolchain=toolchain,source_sha256_before=source_hash,source_sha256_after=fingerprint(after),sources_unchanged=True,files=before,executable_sha256=sha(executable.read_bytes()),executable_bytes=executable.stat().st_size,build_wall_seconds=build_seconds,capture_run=2,evidence=evidence)
    timing=dict(units='milliseconds',quantile='nearest rank',cold_first_draw=distribution(cold),warm_whole_draw=distribution(warm),warm_bridge=distribution(bridge),samples=dict(cold_first_draw=cold,warm_whole_draw=warm,warm_bridge=bridge),idle=dict(mapping_calls_per_process=100,gpu_submissions_during_mappings=0),limits='Three process runs; first draw excludes process/window startup. Whole draw includes ordinary rebuild, source snapshot, GPU, copied-image publication and native frame completion. Bridge timing is narrower and overlapping. No compositor/scanout, physical input, sustained/thermal or memory-pressure acceptance.')
    for name,value in [('manifest',manifest),('provenance',provenance),('timing',timing)]:
        (DEST / (name+'.json')).write_text(json.dumps(value,indent=2,allow_nan=False)+'\n')
    spec=importlib.util.spec_from_file_location('demo_slideshows',ROOT / 'scripts/demo_slideshows.py')
    gallery=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(gallery)
    (DEST / 'index.html').write_text(gallery.render(gallery.load_manifest(DEST / 'manifest.json')))
    print(f'PASS 6 native offscreen captures; 3 cold / 90 warm; unchanged source {source_hash}')

if __name__=='__main__':
    main()
