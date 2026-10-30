"""Verify generated runtimes against the original and focused existing checks."""
from datetime import datetime, timezone
import json
from pathlib import Path
import subprocess

from run import HERE, ROOT, parse, run, sha, summarize
from variants import Variant, transform


def main():
    report = json.loads((HERE/'results.json').read_text())
    for name, digest in report['source_hashes'].items():
        assert sha(ROOT/name) == digest, name
    original = (ROOT/'src/moxi/column_runtime.mojo').read_text()
    checks = []
    logs = Path(report['logs'])
    includes = [ROOT/'experiments'/n for n in ('state-access','method-binding','selective-updates','typed-boundaries')]
    def check(variant, source):
        directory = logs/variant.value
        name = variant.value + '-' + source.parent.name + '-' + source.stem
        cmd = ['pixi','run','--locked','mojo','run','-I',str(directory/'src')]
        cmd += [arg for p in includes for arg in ('-I',str(p))] + [str(source)]
        output = run(cmd,logs/(name+'.log'))
        checks.append(dict(name=name, command=cmd, output=output, source_sha256=sha(source)))
        print('PASS',name,flush=True)
    for result in report['variants']:
        variant = Variant(result['variant'])
        module = logs/variant.value/'src/moxi/column_runtime.mojo'
        assert module.read_text() == transform(original, variant)
        assert sha(module) == result['runtime_sha256']
        assert parse(result['raw_stdout']) == result['samples']
        assert summarize(result['samples']) == result['summaries']
        if variant is not Variant.BASELINE:
            check(variant,HERE/'parity.mojo')
    for name in ('animation','clipping','scroll_app','widget_catalog','component'):
        check(Variant.COMBINED,ROOT/'tests'/f'{name}.mojo')
    check(Variant.COMBINED,ROOT/'experiments/typed-boundaries/check.mojo')
    check(Variant.BASELINE,HERE/'value_equality.mojo')
    verification = dict(timestamp=datetime.now(timezone.utc).isoformat(), checks=checks,
                        timing_report_sha256=sha(HERE/'results.json'),
                        verifier_sha256=sha(HERE/'verify.py'))
    (HERE/'verification.json').write_text(json.dumps(verification,indent=2)+'\n')
    print('PASS',len(checks),'programs and all timing provenance; logs:', logs)


if __name__ == '__main__':
    main()
