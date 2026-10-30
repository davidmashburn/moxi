"""Ablate paint scans in disposable source trees; preserve source and evidence."""
from datetime import datetime, timezone
import difflib
import hashlib
import json
from pathlib import Path
import platform
import shutil
import statistics
import subprocess
import tempfile

from variants import Variant, transform

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(cmd, logfile, timeout=240):
    with logfile.open("w") as output:
        result = subprocess.run(cmd, cwd=ROOT, stdout=output,
                                stderr=subprocess.STDOUT, timeout=timeout)
    assert result.returncode == 0, str(logfile) + "\n" + logfile.read_text()[-4000:]
    return logfile.read_text()


def parse(raw):
    rows = []
    for line in raw.splitlines():
        if not line.startswith("FRAME "):
            continue
        tag, count, shared, sample, cu, cp, fu, fp, commands, cr, fr = line.split()
        assert shared in ("True", "False")
        row = dict(count=int(count), shared=shared == "True", sample=int(sample),
                   cached_update_ns=int(cu), cached_paint_ns=int(cp),
                   forced_update_ns=int(fu), forced_paint_ns=int(fp),
                   commands=int(commands), cached_renders=int(cr), forced_renders=int(fr))
        row["cached_frame_ns"] = row["cached_update_ns"] + row["cached_paint_ns"]
        row["forced_frame_ns"] = row["forced_update_ns"] + row["forced_paint_ns"]
        rows.append(row)
    assert len(rows) == 30
    expected = {(n, shared, i) for n in (2, 100, 300) for shared in (False, True) for i in range(5)}
    assert {(r['count'], r['shared'], r['sample']) for r in rows} == expected
    for r in rows:
        assert r['cached_renders'] == (r['count'] if r['shared'] else 1)
        assert r['forced_renders'] == r['count']
        assert all(r[k] > 0 for k in ('cached_update_ns', 'cached_paint_ns', 'forced_update_ns', 'forced_paint_ns'))
    assert "PASS equivalent trees" in raw
    return rows


def summarize(rows):
    out = []
    for n in (2, 100, 300):
        for shared in (False, True):
            samples = [r for r in rows if r['count'] == n and r['shared'] == shared]
            stats = {}
            for mode in ('cached', 'forced'):
                for stage in ('update', 'paint', 'frame'):
                    key = f'{mode}_{stage}_ns'
                    values = [r[key] for r in samples]
                    stats[key] = dict(median=statistics.median(values), min=min(values), max=max(values))
            out.append(dict(count=n, shared=shared, stats=stats))
    return out


def main():
    logs = Path(tempfile.mkdtemp(prefix="moxi-paint-costs-"))
    paths = [ROOT/'pixi.toml', ROOT/'pixi.lock', *ROOT.glob('src/**/*.mojo')]
    for name in ('state-access', 'method-binding', 'selective-updates', 'selective-costs', 'typed-boundaries', 'paint-costs'):
        paths += list((ROOT/'experiments'/name).glob('*.mojo'))
    paths += list(HERE.glob('*.py'))
    hashes = {str(p.relative_to(ROOT)): sha(p) for p in sorted(paths)}
    original = (ROOT/'src/moxi/column_runtime.mojo').read_text()
    includes = [ROOT/'experiments'/n for n in ('state-access','method-binding','selective-updates','selective-costs')]
    report = dict(timestamp=datetime.now(timezone.utc).isoformat(),
                  implementation_head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
                  compiler=subprocess.check_output(['pixi','run','--locked','mojo','--version'],cwd=ROOT,text=True).strip(),
                  machine=platform.platform(), logs=str(logs), source_hashes=hashes,
                  protocol="Mojo -O3; equivalent retained trees; local text and shared action events; two warmups/five samples; alternating cached/forced order; update/paint split in one frame; validation/setup/destruction outside timer; variants executed in enum order; headless CPU work, unisolated machine",
                  variants=[])
    for variant in Variant:
        directory = logs/variant.value
        directory.mkdir()
        shutil.copytree(ROOT/'src', directory/'src')
        module = directory/'src/moxi/column_runtime.mojo'
        (module.parent/'baseline_runtime.mojo').write_text(original)
        modified = transform(original, variant)
        module.write_text(modified)
        patch = ''.join(difflib.unified_diff(original.splitlines(True),modified.splitlines(True),fromfile='baseline',tofile=variant.value))
        (directory/'runtime.patch').write_text(patch)
        flags = ['pixi','run','--locked','mojo','build','-O3','-I',str(directory/'src')]
        flags += [arg for p in includes for arg in ('-I',str(p))]
        build = flags + [str(HERE/'frame.mojo'),'-o',str(directory/'frame')]
        run(build, directory/'build.log')
        raw = run([str(directory/'frame')],directory/'frame.log')
        rows = parse(raw)
        result = dict(variant=variant.value, build_command=build, patch=patch,
                      runtime_sha256=sha(module), raw_stdout=raw, samples=rows, summaries=summarize(rows))
        report['variants'].append(result)
        for s in result['summaries']:
            print(variant.value,s['count'],'shared' if s['shared'] else 'local',
                  'cached/forced ms',round(s['stats']['cached_frame_ns']['median']/1e6,3),
                  round(s['stats']['forced_frame_ns']['median']/1e6,3),flush=True)
    assert hashes == {name: sha(ROOT/name) for name in hashes}, "Inputs changed while measuring"
    (HERE/'results.json').write_text(json.dumps(report,indent=2)+'\n')
    print('PASS 120 paired samples; logs:', logs)


if __name__ == '__main__':
    main()
