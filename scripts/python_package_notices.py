"""Check that both Python distributions retain the exact upstream MIT notice."""
from pathlib import Path
import sys
import tarfile
import zipfile


def check(directory):
    expected = (Path(__file__).resolve().parents[1] /
                'tests/fixtures/wave_a/DATAVIZ-LICENSE').read_bytes()
    wheels = list(directory.glob('moxi-*.whl'))
    sources = list(directory.glob('moxi-*.tar.gz'))
    assert wheels and sources, 'Build both wheel and source distribution'
    for wheel in wheels:
        with zipfile.ZipFile(wheel) as archive:
            assert archive.read('moxi/licenses/DATAVIZ-LICENSE.txt') == expected
    for source in sources:
        with tarfile.open(source) as archive:
            members = [m for m in archive.getmembers()
                       if m.name.endswith('/python/moxi/licenses/DATAVIZ-LICENSE.txt')]
            assert len(members) == 1
            assert archive.extractfile(members[0]).read() == expected
    print('Python wheel and sdist retain the exact upstream MIT notice')


if __name__ == '__main__':
    check(Path(sys.argv[1]))
