"""Compare the built wheels' project and dataviz notices with the source bytes."""
from pathlib import Path
import sys
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[2]


def check(wheel, dataviz_member):
    with ZipFile(wheel) as archive:
        metadata, = (n for n in archive.namelist() if n.endswith(".dist-info/METADATA"))
        dist_info = metadata.removesuffix("METADATA")
        # Setuptools used the dist-info root before adopting PEP 639.
        notices = dist_info + "licenses/" if dist_info + "licenses/LICENSE" in archive.namelist() else dist_info
        expected = {
            notices + "LICENSE": ROOT / "LICENSE",
            dataviz_member or notices + "LICENSE.dataviz": ROOT / "tests/fixtures/wave_a/DATAVIZ-LICENSE",
        }
        for member, source in expected.items():
            if member not in archive.namelist() or archive.read(member) != source.read_bytes():
                raise ValueError(f"{wheel.name}: missing or changed {member}")


if __name__ == "__main__":
    facade, native = map(Path, sys.argv[1:])
    check(facade, "moxi/licenses/DATAVIZ-LICENSE.txt")
    check(native, None)
