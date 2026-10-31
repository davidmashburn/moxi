"""Exercise real scheduler/native queue boundaries without changing native source."""
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import platform
import subprocess
import tempfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
INCLUDES = ['src', 'experiments/lifetime-contract', 'experiments/scoped-identity',
            'experiments/typed-boundaries', 'experiments/state-access']


def main():
    folder = Path(tempfile.mkdtemp(prefix='moxi-lifetime-integration-'))
    checks = []

    def run(name, command, require_pass=True):
        result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, timeout=300)
        output = result.stdout + result.stderr
        log = folder / (name + '.log')
        log.write_text(output)
        if result.returncode or (require_pass and 'PASS' not in output):
            raise RuntimeError(str(log) + '\n' + output[-5000:])
        checks.append(dict(name=name, command=command, exit_code=result.returncode, output=output))
        print('PASS', name, flush=True)

    mojo = ['pixi', 'run', '--locked', 'mojo']
    includes = [arg for path in INCLUDES for arg in ['-I', path]]
    for name in ['requests', 'scroll_reset', 'author', 'move']:
        run(name, mojo + ['run', *includes, str(HERE / (name + '.mojo'))])
    for name in ['request_scope_retention', 'reactivity_tasks', 'request_adapter',
                 'input_routing', 'action_dispatch', 'scroll_app']:
        # Production programs use assertions and exit status; not all print PASS.
        run(name, mojo + ['run', '-I', 'src', 'tests/' + name + '.mojo'], require_pass=False)

    generated = {}
    skipped = []
    if platform.system() == 'Darwin':
        native = (ROOT / 'native/macos_window.m').read_text()
        patches = {
            '    uint64_t receivedAtNs;\n': '    uint64_t receivedAtNs;\n    uint64_t lifetime;\n',
            'static MoxiQueuedEvent moxi_event_queue[MOXI_EVENT_QUEUE_CAPACITY];':
                'static uint64_t moxi_probe_lifetime = 1;\nstatic MoxiQueuedEvent moxi_event_queue[MOXI_EVENT_QUEUE_CAPACITY];',
            '    queued->kind = kind;': '    queued->lifetime = moxi_probe_lifetime;\n    queued->kind = kind;',
            '    queued->kind = MOXI_EVENT_ACTION;': '    queued->lifetime = moxi_probe_lifetime;\n    queued->kind = MOXI_EVENT_ACTION;',
        }
        for old, new in patches.items():
            assert native.count(old) == 1, 'native anchor changed: ' + old
            native = native.replace(old, new)
        backend = folder / 'native_lifetime_backend.m'
        backend.write_text(native)
        generated[backend.name] = hashlib.sha256(backend.read_bytes()).hexdigest()
        obj = folder / 'probe.o'
        binary = folder / 'probe'
        run('native_compile', ['clang', '-Wall', '-Wextra', '-Werror', '-fobjc-arc', '-fmodules',
                              '-I', str(folder), '-I', 'native', '-c', str(HERE / 'native_probe.m'),
                              '-o', str(obj)], require_pass=False)
        run('native_mojo_build', mojo + ['build', *includes, '-Xlinker', str(obj),
                                        '-Xlinker', '-framework', '-Xlinker', 'Cocoa',
                                        str(HERE / 'native_queue.mojo'), '-o', str(binary)], require_pass=False)
        run('native_queue', [str(binary)])
    else:
        skipped.append('native queue requires macOS/Cocoa')
    paths = [*HERE.glob('*.mojo'), HERE / 'native_probe.m', Path(__file__).resolve(),
             HERE / 'author-first-attempt.mojo.txt', ROOT / 'pixi.toml', ROOT / 'pixi.lock',
             *ROOT.glob('src/**/*.mojo'), *ROOT.glob('native/*')]
    for directory in INCLUDES[1:]:
        paths += list((ROOT / directory).glob('*.mojo'))
    paths += [ROOT / 'tests' / (name + '.mojo') for name in
              ['request_scope_retention', 'reactivity_tasks', 'request_adapter',
               'input_routing', 'action_dispatch', 'scroll_app']]
    report = dict(timestamp=datetime.now(timezone.utc).isoformat(), platform=platform.platform(),
                  baseline=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
                  compiler=subprocess.check_output(mojo + ['--version'], cwd=ROOT, text=True).strip(),
                  temporary_directory=str(folder),
                  source_hashes={str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
                                 for p in sorted(set(paths)) if p.is_file()},
                  generated_hashes=generated, checks=checks, skipped=skipped,
                  limits='Prototype adapters only. No OS-generated input, real window, pixel check, native production integration, timing benchmark, full production suite, CI, or human usability trial.')
    (HERE / 'results.json').write_text(json.dumps(report, indent=2) + '\n')


if __name__ == '__main__':
    main()
