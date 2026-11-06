"""Build a local platform wheel from the already-built FDG executable.

No compiler/runtime download at install/import time. No source checkout required
by a consumer. The platform tag prevents installing the wrong native binary.
"""
from pathlib import Path
import shutil
import importlib.util
import platform as host_platform
import subprocess
import re
from setuptools import setup
from setuptools.command.build_py import build_py
from wheel.bdist_wheel import bdist_wheel

ROOT = Path(__file__).parent.resolve()

class BuildFDG(build_py):
    def run(self):
        binary = ROOT / "dist/moxi-fdg"
        if not binary.is_file():
            raise RuntimeError("Build FDG with scripts/build.sh or scripts/build-linux.sh before building its local wheel")
        super().run()
        data = Path(self.build_lib) / "_moxi_fdg_data"
        data.mkdir(exist_ok=True, parents=True)
        shutil.copy2(binary, data / "moxi-fdg")
        shutil.copy2(ROOT / "examples/triangle.json", data / "triangle.json")
        shutil.copy2(ROOT / "../../LICENSE", data / "LICENSE")
        spec = importlib.util.spec_from_file_location("bundle_runtime", ROOT / "scripts/bundle_runtime.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        module.bundle(data, ROOT)

class PlatformWheel(bdist_wheel):
    def finalize_options(self):
        super().finalize_options()
        self.root_is_pure = False

    def get_tag(self):
        _, _, platform = super().get_tag()
        if host_platform.system() == "Darwin":
            info = subprocess.check_output(["otool", "-l", str(ROOT / "dist/moxi-fdg")], text=True)
            minimum = re.search(r"minos (\d+)\.(\d+)", info)
            if not minimum:
                raise RuntimeError("Cannot determine native binary's macOS deployment target")
            platform = f"macosx_{minimum[1]}_{minimum[2]}_{host_platform.machine()}"
        return "py3", "none", platform

setup(cmdclass={"build_py": BuildFDG, "bdist_wheel": PlatformWheel})
