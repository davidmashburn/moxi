"""Package an already compiled Mojo object; never compile on import/install."""
import os
from pathlib import Path
import subprocess

# Python.org's macOS interpreter is universal2, while this experiment's Mojo
# object and bundled runtimes are arm64 only. Apply this before setuptools reads
# Python's compiler configuration. The wheel tag is selected separately below.
os.environ["ARCHFLAGS"] = "-arch arm64"
from setuptools import Extension, setup
from setuptools.command.build_ext import build_ext
from wheel.bdist_wheel import bdist_wheel


class NativeBuildExt(build_ext):
    def run(self):
        super().run()
        for extension in self.extensions:
            path = self.get_ext_fullpath(extension.name)
            architectures = subprocess.check_output(["lipo", "-archs", path], text=True).split()
            if architectures != ["arm64"]:
                raise RuntimeError("Native extension must contain only arm64: " + repr(architectures))
            # Sign the final linked bytes explicitly; do not rely on a linker or
            # universal-interpreter default to produce a valid ad hoc signature.
            subprocess.run(["codesign", "--force", "--sign", "-", path], check=True)
            subprocess.run(["codesign", "--verify", path], check=True)


class NativeWheel(bdist_wheel):
    def get_tag(self):
        python, abi, platform = super().get_tag()
        if not platform.startswith("macosx_"):
            raise RuntimeError("Native wheel requires macOS: " + platform)
        # sysconfig retains the interpreter's original universal2 CFLAGS for
        # platform tags even when ARCHFLAGS selects a thin extension.
        return python, abi, platform.rsplit("_", 1)[0] + "_arm64"

here = Path(__file__).parent
obj = here / "dist" / "render.o"
if not obj.exists():
    raise RuntimeError("Run build.sh first; source installation requires a build-time Mojo compiler")
setup(cmdclass={"build_ext": NativeBuildExt, "bdist_wheel": NativeWheel},
      ext_modules=[Extension("moxi_native._core", ["native/module.c", "native/graphics.c"],
                            depends=["native/graphics.h", str(obj)],
                            extra_objects=[str(obj)],
                            libraries=["KGENCompilerRTShared"],
                            library_dirs=[str(here / "moxi_native/.libs")],
                            extra_compile_args=["-std=c11", "-Wall", "-Wextra", "-Werror"],
                            extra_link_args=["-Wl,-rpath,@loader_path/.libs", "-framework", "CoreGraphics",
                                             "-framework", "CoreText", "-framework", "CoreFoundation"])])
