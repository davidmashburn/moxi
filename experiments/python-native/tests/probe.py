"""Run outside the repository after wheel install, with an empty environment."""
import ctypes
import hashlib
import importlib.metadata
import json
import os
from pathlib import Path
import shutil
import statistics
import sys
import time

# Install before moxi imports: rendering must not delegate to any process/CLI.
def no_process(event, args):
    if event in ('subprocess.Popen', 'os.system', 'os.posix_spawn', 'os.exec', 'os.fork'):
        raise AssertionError('runtime process invocation forbidden: ' + event)
sys.addaudithook(no_process)

import moxi
import moxi_native as native
from fixture import canonical, WIDTH, HEIGHT

out = Path(sys.argv[1]); out.mkdir(parents=True, exist_ok=True)
assert 'site-packages' in moxi.__file__ and 'site-packages' in native.__file__
assert not shutil.which('mojo')
assert not any(key in os.environ for key in ('PYTHONPATH', 'MOJO_PATH', 'MODULAR_HOME', 'CONDA_PREFIX', 'DYLD_LIBRARY_PATH'))
capabilities = native.capabilities()
# Preserve full hashes in build.json; concise terminal/result evidence here.
build = capabilities['build']
capabilities['build'] = {k: v for k, v in build.items() if k not in ('sources', 'runtimes')}
(out / 'build.json').write_text(json.dumps(build, indent=2) + '\n')
initial = dict(python=sys.version.split()[0], platform='-'.join((os.uname().sysname, os.uname().release, os.uname().machine)),
               moxi_version=moxi.__version__, native_version=native.__version__,
               import_paths=[moxi.__file__, native.__file__, native._core.__file__],
               mojo_on_path=False, isolated=sys.flags.isolated, process_audit='enabled',
               packages={n: importlib.metadata.version(n) for n in ('numpy', 'pillow', 'pypdf', 'pytest')},
               capabilities=capabilities)
(out / '01-import.json').write_text(json.dumps(initial, indent=2) + '\n')
print('CLEAN IMPORT', json.dumps(initial, sort_keys=True))
spec, columns = canonical()
formats = {}
for kind in native.RenderFormat:
    start = time.perf_counter_ns()
    data = native.render(spec.to_json(), columns, WIDTH, HEIGHT, kind)
    elapsed = time.perf_counter_ns() - start
    (out / ('native.' + kind.value)).write_bytes(data)
    reference = moxi.render(spec.to_json(), {k: v.values for k, v in columns.items()}, WIDTH, HEIGHT, kind.value)
    (out / ('facade.' + kind.value)).write_bytes(reference)
    formats[kind.value] = dict(native_bytes=len(data), native_sha256=hashlib.sha256(data).hexdigest(),
                              facade_bytes=len(reference), facade_sha256=hashlib.sha256(reference).hexdigest(),
                              first_call_ms=elapsed / 1e6)
(out / '02-render.json').write_text(json.dumps(formats, indent=2) + '\n')
print('CANONICAL EXPORTS', json.dumps(formats, sort_keys=True))
failures = []
for bad in ('{bad}', '[]', '{"version":1,"layers":[null]}'):
    try: native.render(bad, columns, WIDTH, HEIGHT)
    except native.InputError as exc: failures.append(dict(input=bad, exception=type(exc).__name__, message=str(exc)))
    else: raise AssertionError('malformed spec accepted')
assert native.render(spec.to_json(), columns, WIDTH, HEIGHT) == (out / 'native.rgba').read_bytes()
(out / '04-errors.json').write_text(json.dumps(failures, indent=2) + '\n')
print('ERROR RECOVERY', json.dumps(failures))
measurements = {}
for kind in (native.RenderFormat.RGBA, native.RenderFormat.PNG, native.RenderFormat.SVG, native.RenderFormat.PDF):
    for _ in range(3): native.render(spec.to_json(), columns, WIDTH, HEIGHT, kind)
    samples = []
    for _ in range(30):
        start = time.perf_counter_ns()
        native.render(spec.to_json(), columns, WIDTH, HEIGHT, kind)
        samples.append((time.perf_counter_ns() - start) / 1e6)
    measurements[kind.value] = dict(n=len(samples), warmups=3, mean_ms=statistics.mean(samples),
        median_ms=statistics.median(samples), stdev_ms=statistics.stdev(samples),
        min_ms=min(samples), max_ms=max(samples), p95_ms=sorted(samples)[28], samples_ms=samples)
benchmark = dict(width=WIDTH, height=HEIGHT, rows=6, layers=2,
                 includes='validation, input copies, Mojo parse/table/scene/render, output copies and container encoding',
                 excludes='compiler/build/install/import, first-call initialization, file IO, browser/screenshots; no facade speed comparison',
                 claim='bounded in-process observations only; GIL held, no throughput/zero-copy/production claim',
                 measurements=measurements)
(out / 'benchmark.json').write_text(json.dumps(benchmark, indent=2) + '\n')
print('BOUNDED TIMING', json.dumps({k: {f: v for f, v in row.items() if f != 'samples_ms'} for k, row in measurements.items()}))
# Inspect actually loaded Mach-O images, independently of advertised capabilities.
loader = ctypes.CDLL(None)
loader._dyld_image_count.restype = ctypes.c_uint32
loader._dyld_get_image_name.argtypes = [ctypes.c_uint32]
loader._dyld_get_image_name.restype = ctypes.c_char_p
images = [loader._dyld_get_image_name(i).decode() for i in range(loader._dyld_image_count())]
runtimes = [p for p in images if any(n in p for n in ('KGEN', 'MSupportGlobals', 'AsyncRTRuntimeGlobals'))]
assert len(runtimes) == 3 and all('/site-packages/moxi_native/.libs/' in p for p in runtimes)
assert not any('/.pixi/' in p for p in images)
(out / 'loaded-runtime.json').write_text(json.dumps(runtimes, indent=2) + '\n')
print('LOADED RUNTIME', json.dumps(runtimes))
print('DEPLOYMENT: local experimental wheel works without compiler/import-path setup; production gate OPEN')
