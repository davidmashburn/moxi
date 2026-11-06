"""Load shared registry metadata, then the registry-owned column fixtures."""
import hashlib
import json
import subprocess
from pathlib import Path
from moxi import PlotSpec, plot

ROOT = Path(__file__).resolve().parents[2]
REGISTRY_SOURCE = ROOT/'src/moxi/scenarios.mojo'
REGISTRY_PATH = ROOT/'tests/fixtures/wave_b/registry.json'


def refresh_registry():
    result=subprocess.run(['pixi','run','mojo','run','-I','src','scripts/wave_b/registry.mojo'],cwd=ROOT,capture_output=True,text=True)
    Path('/tmp/moxi-e02-registry.log').write_text(result.stdout+result.stderr)
    result.check_returncode()
    cases=[]
    for line in result.stdout.splitlines():
        p=[s.strip() for s in line.split('|')]
        if len(p)!=9:continue
        cases.append(dict(id=p[0],fixture=p[1],rows=int(p[2]),seed=int(p[3]),width=int(p[4]),height=int(p[5]),schema_version=int(p[6]),reference_revision=p[7],reference_available=p[8]=='True'))
    assert len(cases) and len({c['id'] for c in cases})==len(cases)
    REGISTRY_PATH.write_text(json.dumps(dict(source_sha256=hashlib.sha256(REGISTRY_SOURCE.read_bytes()).hexdigest(),cases=cases),indent=2)+'\n')


def load_cases():
    registry=json.loads(REGISTRY_PATH.read_text())
    assert registry['source_sha256']==hashlib.sha256(REGISTRY_SOURCE.read_bytes()).hexdigest(), 'Run fixtures.py to refresh the shared registry export'
    cases=[]
    for entry in registry['cases']:
        case=dict(entry,**json.loads((ROOT/entry['fixture']).read_text()))
        assert all(len(v)==case['rows'] for v in case['columns'].values()),case['id']
        cases.append(case)
    return cases


def figure(case, *, columns=None):
    spec=PlotSpec('Wave B: '+case['id'])
    identity=spec.add_catalog_mark(case['id'],case['id'],case['x'],case['y'],**case.get('channels',{}))
    spec.specialize(identity,**case.get('layout',{}))
    spec.add_hover();spec.add_click_select();spec.add_keyboard()
    return plot(case['columns'] if columns is None else columns,spec,width=case['width'],height=case['height'])

if __name__=='__main__':refresh_registry()
