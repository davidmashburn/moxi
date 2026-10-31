"""Run isolated lifetime and compatibility checks with reproducible evidence."""
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import platform
import subprocess
import tempfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]


def main():
    folder = Path(tempfile.mkdtemp(prefix='moxi-lifetime-contract-'))
    for source in (ROOT / 'experiments/scoped-identity').glob('*.mojo'):
        (folder / source.name).write_bytes(source.read_bytes())
    for source in HERE.glob('*.mojo'):
        (folder / source.name).write_bytes(source.read_bytes())
    checks = ['lifetime_check.mojo', 'copy_divergence.mojo', 'retired_scope.mojo', 'unpublished_reset.mojo', 'structure.mojo', 'check.mojo', 'nested.mojo', 'stress.mojo', 'retention_edges.mojo']
    replacement = ROOT / 'experiments/composition-evaluation/replacement.mojo'
    (folder / replacement.name).write_bytes(replacement.read_bytes())
    checks.append(replacement.name)
    results = []
    for name in checks:
        command = ['pixi', 'run', '--locked', 'mojo', 'run', '-I', str(folder)]
        for include in ['src', 'experiments/typed-boundaries', 'experiments/state-access']:
            command += ['-I', include]
        command.append(str(folder / name))
        result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, timeout=240)
        output = result.stdout + result.stderr
        (folder / (name + '.log')).write_text(output)
        if result.returncode or 'PASS' not in output:
            raise RuntimeError(str(folder / (name + '.log')) + '\n' + output[-5000:])
        if name == replacement.name:
            cases = [line for line in output.splitlines() if line.startswith('CASE ')]
            expected = [(False, False), (True, True), (False, False), (False, False), (True, True), (True, False)]
            assert len(cases) == len(expected)
            for line, (callback, event) in zip(cases, expected):
                assert line.endswith(f'callback_rejected {callback} event_rejected {event}'), line
        results.append(dict(source=name, command=command, exit_code=result.returncode, output=output))
        print('PASS', name, flush=True)
    paths = [*HERE.glob('*.mojo'), Path(__file__).resolve(), replacement, ROOT / 'pixi.toml', ROOT / 'pixi.lock', *ROOT.glob('src/**/*.mojo')]
    for include in ['scoped-identity', 'typed-boundaries', 'state-access']:
        paths += list((ROOT / 'experiments' / include).glob('*.mojo'))
    report = dict(timestamp=datetime.now(timezone.utc).isoformat(), platform=platform.platform(),
                  baseline=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
                  compiler=subprocess.check_output(['pixi', 'run', '--locked', 'mojo', '--version'], cwd=ROOT, text=True).strip(),
                  temporary_directory=str(folder),
                  source_hashes={str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(set(paths))},
                  generated_hashes={p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(folder.glob('*.mojo'))},
                  checks=results,
                  limits='Prototype delivery boundary only; raw events/actions remain unsafe across hosts. No native queue, timing, human trial, production suite or CI.')
    (HERE / 'results.json').write_text(json.dumps(report, indent=2) + '\n')


if __name__ == '__main__':
    main()
