"""Build-time only compiler/runtime bundling for a local experimental wheel."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
RUNTIMES = ('libKGENCompilerRTShared.dylib', 'libMSupportGlobals.dylib', 'libAsyncRTRuntimeGlobals.dylib')
RUNTIME_NOTICE_FILES = ('LICENSE', 'Third-Party-Notices')

def run(*args):
    return subprocess.check_output(args, text=True).strip()

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def copy_runtime_notices(prefix, destination):
    """Retain the exact installed compiler package terms, never substitute web terms."""
    records = list((prefix / 'conda-meta').glob('mojo-compiler-*.json'))
    if len(records) != 1:
        raise RuntimeError('Expected one installed mojo-compiler package record')
    record = json.loads(records[0].read_text())
    source = Path(record['link']['source']) / 'info/licenses'
    for name in RUNTIME_NOTICE_FILES:
        if not (source / name).is_file() or not (source / name).stat().st_size:
            raise RuntimeError(f'Installed runtime notice missing: {name}; refusing incomplete wheel')
    if destination.exists():
        shutil.rmtree(destination)
    shutil.copytree(source, destination)
    return record['license'], {str(p.relative_to(destination)): sha(p)
                               for p in sorted(destination.rglob('*')) if p.is_file()}

def main():
    if sys.platform != 'darwin' or run('uname', '-m') != 'arm64':
        raise SystemExit('This experimental packaging recipe supports macOS arm64 only')
    prefix = Path(os.environ['CONDA_PREFIX'])
    compiler = shutil.which('mojo')
    version = run(compiler, '--version')
    if not version.startswith('Mojo 1.1.0 '):
        raise SystemExit(f'Unverified compiler ABI: {version}; expected Mojo 1.1.0')
    runtime_license, notices = copy_runtime_notices(prefix, HERE / 'moxi_native/runtime-notices')
    output = HERE / 'dist'
    output.mkdir(exist_ok=True)
    obj = output / 'render.o'
    subprocess.run([compiler, 'build', '--emit', 'object', '-I', str(ROOT / 'src'),
                    str(HERE / 'native/render.mojo'), '-o', str(obj)], check=True)
    libs = HERE / 'moxi_native/.libs'
    libs.mkdir(exist_ok=True)
    runtimes = {}
    for name in RUNTIMES:
        original = prefix / 'lib' / name
        target = libs / name
        shutil.copy2(original, target)
        target.chmod(0o755)
        # Remove build-machine search paths; internal runtime edges are siblings.
        commands = run('otool', '-l', str(target)).splitlines()
        for i, line in enumerate(commands):
            if line.strip() == 'cmd LC_RPATH':
                path = commands[i + 2].strip().split(' (offset')[0].removeprefix('path ')
                subprocess.run(['install_name_tool', '-delete_rpath', path, str(target)], check=True)
        for dependency in run('otool', '-L', str(target)).splitlines()[2:]:
            old = dependency.strip().split(' (compatibility')[0]
            if Path(old).name in RUNTIMES:
                subprocess.run(['install_name_tool', '-change', old, '@loader_path/' + Path(old).name, str(target)], check=True)
        subprocess.run(['install_name_tool', '-id', '@rpath/' + name, str(target)], check=True)
        subprocess.run(['codesign', '--force', '--sign', '-', str(target)], check=True)
        runtimes[name] = {'original_sha256': sha(original), 'bundled_sha256': sha(target)}
    files = []
    for base in (ROOT / 'src/moxi', ROOT / 'src/moxi_plot', HERE / 'native', HERE / 'moxi_native'):
        files.extend(p for p in base.rglob('*') if p.is_file() and p.suffix in ('.mojo', '.c', '.py')
                     and p.name != '_build.py' and '__pycache__' not in p.parts)
    files += [HERE / 'build_native.py', HERE / 'setup.py', HERE / 'pyproject.toml']
    sources = {str(p.relative_to(ROOT)): sha(p) for p in sorted(files)}
    build = dict(compiler=version, compiler_sha256=sha(Path(compiler)),
                 revision=run('git', '-C', str(ROOT), 'rev-parse', 'HEAD'),
                 dirty=bool(run('git', '-C', str(ROOT), 'status', '--porcelain')),
                 sources_sha256=hashlib.sha256(json.dumps(sources, sort_keys=True).encode()).hexdigest(),
                 object_sha256=sha(obj), sources=sources, runtimes=runtimes,
                 runtime_license=runtime_license, runtime_notices=notices,
                 redistribution_review='not performed; local proof only')
    (HERE / 'moxi_native/_build.py').write_text('BUILD = ' + repr(build) + '\n')
    (output / 'build.json').write_text(json.dumps(build, indent=2) + '\n')
    print(json.dumps({k: v for k, v in build.items() if k not in ('sources', 'runtimes')}, indent=2))

if __name__ == '__main__':
    main()
