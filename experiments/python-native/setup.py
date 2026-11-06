"""Package an already compiled Mojo object; never compile on import/install."""
from pathlib import Path
from setuptools import Extension, setup

here = Path(__file__).parent
obj = here / "dist" / "render.o"
if not obj.exists():
    raise RuntimeError("Run build.sh first; source installation requires a build-time Mojo compiler")
setup(ext_modules=[Extension("moxi_native._core", ["native/module.c"],
                            extra_objects=[str(obj)],
                            libraries=["KGENCompilerRTShared"],
                            library_dirs=[str(here / "moxi_native/.libs")],
                            extra_compile_args=["-std=c11", "-Wall", "-Wextra", "-Werror"],
                            extra_link_args=["-Wl,-rpath,@loader_path/.libs"])])
