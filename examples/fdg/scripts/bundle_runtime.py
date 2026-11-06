"""Bundle the installed Mojo runtime for a LOCAL wheel, retaining its notices."""
from pathlib import Path
import json
import os
import platform
import shutil
import subprocess


def bundle(data, root):
    prefix = Path(os.environ.get("MOXI_FDG_TOOLCHAIN", root / "../../.pixi/envs/default")).resolve()
    records = list((prefix / "conda-meta").glob("mojo-compiler-*.json"))
    if len(records) != 1:
        raise RuntimeError("Set MOXI_FDG_TOOLCHAIN to the locked Mojo 1.1.0 conda environment")
    record = json.loads(records[0].read_text())
    source = Path(record["link"]["source"])
    licenses = source / "info/licenses"
    if not licenses.is_dir():
        raise RuntimeError("Compiler package license files missing; refusing an incomplete wheel")
    shutil.copytree(licenses, data / "runtime-notices", dirs_exist_ok=True)
    darwin = platform.system() == "Darwin"
    suffix = "dylib" if darwin else "so"
    runtime = data / "lib"
    runtime.mkdir(exist_ok=True)
    libraries = ["libKGENCompilerRTShared", "libMSupportGlobals", "libAsyncRTRuntimeGlobals"]
    for name in libraries:
        shutil.copy2(prefix / "lib" / f"{name}.{suffix}", runtime)
    binary = data / "moxi-fdg"
    if darwin:
        # Remove all build-host RPATHs, including from runtime libraries. Resolve
        # runtime-to-runtime references locally, never from the source checkout.
        for target in [binary, *runtime.glob("*.dylib")]:
            load = subprocess.check_output(["otool", "-l", str(target)], text=True).splitlines()
            paths = [load[i+2].strip().split(" (offset", 1)[0][5:] for i, line in enumerate(load) if line.strip() == "cmd LC_RPATH"]
            for path in paths:
                subprocess.run(["install_name_tool", "-delete_rpath", path, str(target)], check=True)
            subprocess.run(["install_name_tool", "-add_rpath", "@loader_path/lib" if target == binary else "@loader_path", str(target)], check=True)
            subprocess.run(["codesign", "--force", "--sign", "-", str(target)], check=True)
    else:
        for target in [binary, *runtime.glob("*.so")]:
            subprocess.run(["patchelf", "--set-rpath", "$ORIGIN/lib" if target == binary else "$ORIGIN", str(target)], check=True)
    (data / "LOCAL-WHEEL-NOTICE.txt").write_text(
        "Local-use artifact from the installed Mojo toolchain. Moxi source is MIT.\n"
        "Bundled runtime binaries (loader paths adjusted) retain the compiler package's own\n"
        "license and Third-Party-Notices in runtime-notices/. No publication or\n"
        "redistribution approval is implied by this local packaging check.\n"
        "GTK/system libraries and optional LGPL-2.1 librsvg are not bundled.\n")
