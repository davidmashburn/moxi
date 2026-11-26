"""Cancel the real viewer's NSSavePanel in a private child on a logged-in Mac."""
import os
from pathlib import Path
import subprocess
import tempfile

here = Path(__file__).resolve().parent
app = here.parents[1]
root = Path(tempfile.mkdtemp(prefix="fdg-dialog-")).resolve()
print(root, flush=True)
probe = root / "probe.dylib"
output = root / "exports"
output.mkdir()
subprocess.run(["clang", "-dynamiclib", "-Wall", "-Wextra", "-Werror", "-fobjc-arc",
                "-framework", "Cocoa", here / "mac_cancel.m", "-o", probe], check=True)
subprocess.run([app / "dist/moxi-fdg", app / "tests/fixtures/export.json"], cwd=root,
               env=dict(os.environ, DYLD_INSERT_LIBRARIES=str(probe), FDG_DIALOG_DIR=str(output)),
               check=True, timeout=30)
if sorted(p.name for p in output.iterdir()) != ["cancelled.png"]:
    raise RuntimeError("Expected only the post-cancel view capture")
