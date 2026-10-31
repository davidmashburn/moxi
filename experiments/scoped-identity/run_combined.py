"""Compose the two isolated candidates in a temporary directory for compatibility.

This does not modify either candidate or production. Runtime composition is an
exact RetainedUI replacement; the public typed child API comes from this folder.
"""
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
RETENTION = ROOT / 'experiments/bounded-retention'
START = 'struct RetainedUI['
END = '\n\ntrait Screen('


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    folder = Path(tempfile.mkdtemp(prefix='moxi-combined-identity-'))
    scoped = (HERE / 'runtime.mojo').read_text()
    bounded = (RETENTION / 'runtime.mojo').read_text()
    for source in HERE.glob('*.mojo'):
        (folder / source.name).write_bytes(source.read_bytes())
    combined = scoped[:scoped.index(START)] + bounded[bounded.index(START):bounded.index(END)] + scoped[scoped.index(END):]
    combined = combined.replace('from std.collections import List\n', 'from std.collections import List, Dict\n')
    (folder / 'runtime.mojo').write_text(combined)
    stress = (folder / 'stress.mojo').read_text()
    stress = stress.replace('    for _ in range(110):', '    var initial_slots = len(app.component.ui.controls)\n    for _ in range(110):')
    stress = stress.replace('        require(app.focus_id() == input,', '        require(len(app.component.ui.controls) == initial_slots, "combined storage stays bounded")\n        require(app.focus_id() == input,')
    (folder / 'stress.mojo').write_text(stress)
    heldout = ROOT / 'experiments/composition-evaluation/author_collision.mojo'
    (folder / heldout.name).write_bytes(heldout.read_bytes())
    checks = []
    for name in ['check.mojo', heldout.name, 'nested.mojo', 'stress.mojo', 'retention_edges.mojo']:
        command = ['pixi', 'run', '--locked', 'mojo', 'run', '-I', str(folder)]
        for include in ['src', 'experiments/typed-boundaries', 'experiments/state-access']:
            command += ['-I', include]
        command += [str(folder / name)]
        result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=240)
        output = result.stdout + result.stderr
        (folder / (name + '.log')).write_text(output)
        assert result.returncode == 0 and 'PASS' in output, name + '\n' + output[-4000:]
        checks.append(dict(source=name, command=command, exit_code=result.returncode, output=output))
        print('PASS combined', name, flush=True)
    paths = [*HERE.glob('*.mojo'), Path(__file__).resolve(), RETENTION / 'runtime.mojo', heldout,
             ROOT / 'pixi.toml', ROOT / 'pixi.lock', *ROOT.glob('src/**/*.mojo')]
    for include in ['typed-boundaries', 'state-access']:
        paths += list((ROOT / 'experiments' / include).glob('*.mojo'))
    report = dict(timestamp=datetime.now(timezone.utc).isoformat(), temporary_directory=str(folder),
                  baseline=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
                  compiler=subprocess.check_output(['pixi', 'run', '--locked', 'mojo', '--version'], cwd=ROOT, text=True).strip(),
                  source_hashes={str(p.relative_to(ROOT)): digest(p) for p in sorted(set(paths))},
                  generated_hashes={p.name: digest(p) for p in sorted(folder.glob('*.mojo'))}, checks=checks,
                  limits='Compatibility checks only; combined performance, full production suite, native queues and human comfort not measured.')
    (HERE / 'combined-results.json').write_text(json.dumps(report, indent=2) + '\n')


if __name__ == '__main__':
    main()
