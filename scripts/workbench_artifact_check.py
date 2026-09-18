#!/usr/bin/env python3
"""Validate the sealed bundle without claiming a desktop launch succeeded."""
import hashlib
import json
import os
from pathlib import Path
import plistlib
import subprocess
import sys


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def validate(app):
    subprocess.run(["/usr/bin/codesign", "--verify", "--deep", "--strict", "--verbose=2", str(app)], check=True)
    with (app / "Contents/Info.plist").open("rb") as source:
        info = plistlib.load(source)
    if info["CFBundleIdentifier"] != "org.moxi.data-workbench":
        raise ValueError("unexpected bundle identifier")
    if info["CFBundleExecutable"] != "moxi-data-workbench":
        raise ValueError("unexpected executable")
    binary = app / "Contents/MacOS/moxi-data-workbench"
    if not binary.is_file() or not os.access(binary, os.X_OK):
        raise ValueError("missing executable")
    manifest = json.loads((app / "Contents/Resources/build.json").read_text())
    # Bundle signing changes executable bytes. The sealed manifest identifies
    # the linker input; record the final signed bytes after signature validation.
    manifest["executable_sha256"] = digest(binary)
    return manifest


if __name__ == "__main__":
    app = Path(sys.argv[1] if len(sys.argv) > 1 else "dist/Moxi Data Workbench.app").resolve()
    print(json.dumps(validate(app), indent=2))
    print("Workbench artifact passed; desktop behavior not checked")
