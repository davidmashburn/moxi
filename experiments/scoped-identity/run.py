"""Verify scoped identity and preserve known lifetime counterexamples."""
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
from pathlib import Path
import platform
import subprocess
import tempfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
EVALUATION = ROOT / 'experiments/composition-evaluation'
spec = importlib.util.spec_from_file_location('replacement_expectations', EVALUATION / 'run_replacement.py')
replacement = importlib.util.module_from_spec(spec)
spec.loader.exec_module(replacement)
spec = importlib.util.spec_from_file_location('author_counts', EVALUATION / 'run_author.py')
author = importlib.util.module_from_spec(spec)
spec.loader.exec_module(author)


def main():
    logs = Path(tempfile.mkdtemp(prefix='moxi-scoped-identity-'))
    checks = []
    sources = [('ordinary', HERE / 'check.mojo'),
               ('held-out-collision', EVALUATION / 'author_collision.mojo'),
               ('editing-churn', HERE / 'stress.mojo'),
               ('nested', HERE / 'nested.mojo'),
               ('legacy-field', ROOT / 'experiments/state-access/probe.mojo'),
               ('legacy-behavior', ROOT / 'experiments/state-access/behavior.mojo'),
               ('replacement-characterization', EVALUATION / 'replacement.mojo')]
    for name, source in sources:
        command = ['pixi', 'run', '--locked', 'mojo', 'run']
        for folder in [HERE, ROOT / 'src', ROOT / 'experiments/typed-boundaries', ROOT / 'experiments/state-access', ROOT / 'experiments/method-binding', ROOT / 'experiments/composition-gate']:
            command += ['-I', str(folder.relative_to(ROOT))]
        command += [str(source.relative_to(ROOT))]
        run = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=240)
        output = run.stdout + run.stderr
        (logs / (name + '.log')).write_text(output)
        assert run.returncode == 0, name + '\n' + output[-4000:]
        if name == 'legacy-field':
            assert output.strip() == '1', output
        elif name == 'replacement-characterization':
            observed = {}
            for line in output.splitlines():
                if line.startswith('CASE '):
                    _, case, cb_label, cb, ev_label, ev = line.split()
                    assert cb_label == 'callback_rejected' and ev_label == 'event_rejected'
                    assert cb in ('True', 'False') and ev in ('True', 'False')
                    assert case not in observed
                    observed[case] = (cb == 'True', ev == 'True')
            assert observed == {case: values[:2] for case, values in replacement.EXPECTED.items()}
        else:
            assert 'PASS' in output, name + '\n' + output
        checks.append(dict(name=name, command=command, exit_code=run.returncode, output=output))
        print('PASS', name, flush=True)
    paths = [*HERE.glob('*.mojo'), Path(__file__).resolve(), EVALUATION / 'author_collision.mojo',
             EVALUATION / 'replacement.mojo', EVALUATION / 'run_replacement.py', EVALUATION / 'run_author.py',
             EVALUATION / 'author/screen.mojo', ROOT / 'pixi.toml', ROOT / 'pixi.lock', *ROOT.glob('src/**/*.mojo')]
    for folder in ('state-access', 'typed-boundaries', 'method-binding', 'composition-gate'):
        paths += list((ROOT / 'experiments' / folder).glob('*.mojo'))
    report = dict(timestamp=datetime.now(timezone.utc).isoformat(),
                  baseline=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
                  compiler=subprocess.check_output(['pixi', 'run', '--locked', 'mojo', '--version'], cwd=ROOT, text=True).strip(),
                  platform=platform.platform(), logs=str(logs), checks=checks,
                  line_counts={str(p.relative_to(ROOT)): author.code_lines(p) for p in [EVALUATION / 'author/screen.mojo', HERE / 'screen.mojo']},
                  source_hashes={str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(set(paths))},
                  limits='Experimental typed keys only. Explicit uniqueness and generation guards remain. Three replacement counterexamples persist. No native event queue, human study, production suite, CI or combined retention measurement.')
    (HERE / 'results.json').write_text(json.dumps(report, indent=2) + '\n')


if __name__ == '__main__':
    main()
