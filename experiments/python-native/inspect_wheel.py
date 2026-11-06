"""Independent stdlib/Mach-O inspection; does not import the extension."""
import hashlib
import ast
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import zipfile


def command(*args):
    return subprocess.check_output(args, text=True)


def inspect(wheel: Path) -> dict:
    with tempfile.TemporaryDirectory(prefix='moxi-e04-inspect-') as temporary:
        root = Path(temporary)
        with zipfile.ZipFile(wheel) as archive:
            names = archive.namelist()
            assert not any(n.endswith(('.mojo', '.o', '.a')) or '/bin/' in n for n in names)
            archive.extractall(root)
            metadata = archive.read(next(n for n in names if n.endswith('.dist-info/METADATA'))).decode()
            tags = archive.read(next(n for n in names if n.endswith('.dist-info/WHEEL'))).decode()
            build_module = ast.parse(archive.read('moxi_native/_build.py').decode())
            build = ast.literal_eval(build_module.body[0].value)
            notices = build['runtime_notices']
            assert {'LICENSE', 'Third-Party-Notices'} <= notices.keys(), 'Missing installed runtime notices'
            for name, digest in notices.items():
                data = archive.read('moxi_native/runtime-notices/' + name)
                assert data and hashlib.sha256(data).hexdigest() == digest, 'Runtime notice changed: ' + name
        binaries = {}
        core = list(root.rglob('_core*.so'))
        assert len(core) == 1
        libs = list((core[0].parent / '.libs').glob('*.dylib'))
        assert len(libs) == 3
        for path in core + libs:
            linked = command('otool', '-L', str(path))
            loads = command('otool', '-l', str(path))
            dependencies = [line.strip().split(' (compatibility')[0] for line in linked.splitlines()[1:]]
            rpaths = []
            lines = loads.splitlines()
            for index, line in enumerate(lines):
                if line.strip() == 'cmd LC_RPATH':
                    rpaths.append(lines[index + 2].strip().split(' (offset')[0].removeprefix('path '))
            for dependency in dependencies:
                if dependency.startswith(('/usr/lib/', '/System/Library/')):
                    continue
                if dependency.startswith('@loader_path/'):
                    resolved = path.parent / dependency.removeprefix('@loader_path/')
                elif dependency.startswith('@rpath/'):
                    # Dylib's first entry is its install ID, not a dependency.
                    resolved = core[0].parent / '.libs' / dependency.removeprefix('@rpath/')
                else:
                    raise AssertionError(f'external non-system dependency: {dependency}')
                assert resolved.is_file(), dependency
            assert all(rpath == '@loader_path/.libs' for rpath in rpaths), rpaths
            subprocess.run(['codesign', '--verify', str(path)], check=True, capture_output=True)
            binaries[str(path.relative_to(root))] = dict(
                sha256=hashlib.sha256(path.read_bytes()).hexdigest(), dependencies=dependencies,
                rpaths=rpaths, file=command('file', str(path)).strip().replace(str(path), path.name),
                build_version=command('vtool', '-show-build', str(path)).replace(str(path), path.name))
        return dict(wheel=wheel.name, sha256=hashlib.sha256(wheel.read_bytes()).hexdigest(),
                    bytes=wheel.stat().st_size, members=names, metadata=metadata, tags=tags,
                    binaries=binaries, dependency_check='PASS: bundled or system only',
                    runtime_license=build['runtime_license'], runtime_notices=notices,
                    compiler_in_wheel=False, abi3=False,
                    production_gate='OPEN: proprietary runtime redistribution unreviewed; one CPython/macOS/arm64 host only; bounded render coverage')

if __name__ == '__main__':
    print(json.dumps(inspect(Path(sys.argv[1])), indent=2))
