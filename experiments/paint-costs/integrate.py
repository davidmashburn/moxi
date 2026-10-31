"""Verify the integrated runtime against the frozen pre-optimization source.

Historical ablation reports remain unchanged. This records a fresh production
check, including a native Metal/software parity run and the same frame probe.
"""
from datetime import datetime, timezone
import json
from pathlib import Path
import platform
import shutil
import subprocess
import tempfile

from run import HERE, ROOT, parse, run, sha, summarize

BASELINE = '247cad2e313db492ded80b17e56478dcdcaab7ab'


def main():
    logs = Path(tempfile.mkdtemp(prefix='moxi-paint-integration-'))
    candidate = logs / 'candidate'
    baseline = logs / 'baseline'
    shutil.copytree(ROOT / 'src', candidate)
    original = subprocess.check_output(
        ['git', 'show', BASELINE + ':src/moxi/column_runtime.mojo'], cwd=ROOT)
    (candidate / 'moxi/baseline_runtime.mojo').write_bytes(original)
    shutil.copytree(ROOT / 'src', baseline)
    (baseline / 'moxi/column_runtime.mojo').write_bytes(original)
    checks = []
    for name, source, includes in (
        ('paint-parity', HERE / 'parity.mojo', candidate),
        ('baseline-regression', ROOT / 'tests/paint_index.mojo', baseline),
        ('production-regression', ROOT / 'tests/paint_index.mojo', ROOT / 'src'),
    ):
        cmd = ['pixi', 'run', '--locked', 'mojo', 'run', '-I', str(includes), str(source)]
        output = run(cmd, logs / (name + '.log'))
        checks.append(dict(name=name, command=cmd, output=output))
    cmd = ['pixi', 'run', '--locked', 'native-scene-parity']
    output = run(cmd, logs / 'native-scene-parity.log')
    assert 'Moxi native scene parity passed' in output
    checks.append(dict(name='native-scene-parity', command=cmd,
                       output='\n'.join(line for line in output.splitlines()
                                        if not line.startswith('P') and ('passed' in line or 'NATIVE_' in line))))
    includes = [ROOT / 'experiments' / name for name in
                ('state-access', 'method-binding', 'selective-updates', 'selective-costs')]
    binary = logs / 'frame'
    cmd = ['pixi', 'run', '--locked', 'mojo', 'build', '-O3', '-I', str(ROOT / 'src')]
    cmd += [arg for p in includes for arg in ('-I', str(p))]
    cmd += [str(HERE / 'frame.mojo'), '-o', str(binary)]
    run(cmd, logs / 'frame-build.log')
    output = run([str(binary)], logs / 'frame.log')
    samples = parse(output)
    paths = [ROOT/'pixi.toml', ROOT/'pixi.lock', ROOT/'tests/paint_index.mojo',
             *ROOT.glob('src/**/*.mojo'), *HERE.glob('*.py'), *HERE.glob('*.mojo')]
    for directory in includes:
        paths += list(directory.glob('*.mojo'))
    report = dict(timestamp=datetime.now(timezone.utc).isoformat(), baseline=BASELINE,
                  compiler=subprocess.check_output(['pixi','run','--locked','mojo','--version'],cwd=ROOT,text=True).strip(),
                  machine=platform.platform(), logs=str(logs), checks=checks,
                  protocol='Same frame.mojo as ablation: O3; two warmups/five samples; alternating cached/forced order; headless CPU update + paint. Unisolated machine; no baseline timing rerun.',
                  source_hashes={str(p.relative_to(ROOT)): sha(p) for p in sorted(set(paths))},
                  raw_stdout=output, samples=samples, summaries=summarize(samples))
    (HERE / 'integration.json').write_text(json.dumps(report, indent=2)+'\n')
    print('PASS production integration:', len(checks), 'checks; 30 paired frames; logs:', logs)


if __name__ == '__main__':
    main()
