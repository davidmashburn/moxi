#!/usr/bin/env python3
"""Cache the native math build, including configurable paths and toolchains."""

import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def fingerprint(repo, hb):
    inputs = {repo / "pixi.toml", repo / "pixi.lock"}
    for pattern in (
        "src/**/*.mojo", "examples/math/*.mojo", "scripts/math/*.sh",
        "scripts/math/*.py", "native/*.h", "native/*.inc",
        "native/macos_window.m", "native/math/*.m",
    ):
        inputs.update(repo.glob(pattern))
    inputs.update((hb / "include/harfbuzz").rglob("*.h"))
    inputs.add(hb / "lib/libharfbuzz.dylib")
    tools = {}
    for command in (
        ["clang", "--version"], ["pixi", "run", "--frozen", "mojo", "--version"],
        ["xcrun", "--show-sdk-path"], ["xcrun", "--show-sdk-version"],
    ):
        tools[" ".join(command)] = subprocess.check_output(command, cwd=repo, text=True)
    return {
        "repo": str(repo),
        "inputs": {str(p): digest(p) for p in sorted(inputs)},
        "tools": tools,
        "clang": shutil.which("clang"),
        "environment": {name: os.environ.get(name) for name in (
            "SDKROOT", "MACOSX_DEPLOYMENT_TARGET", "DEVELOPER_DIR",
        )},
    }


def output_hashes(work):
    paths = [work / name for name in ("window.o", "font.o", "workbench", "consumer")]
    if not all(p.is_file() for p in paths):
        return None
    if not all(os.access(work / name, os.X_OK) for name in ("workbench", "consumer")):
        return None
    return {p.name: digest(p) for p in paths}


def main(force=False):
    repo = Path(__file__).resolve().parents[2]
    work = Path(os.environ.get("MOXI_D02_BUILD_DIR", "/tmp/moxi-d02"))
    hb = Path(os.environ.get("MOXI_HARFBUZZ_PREFIX", "/opt/homebrew/opt/harfbuzz"))
    # The shell build interprets relative overrides from the repository root.
    os.chdir(repo)
    work.mkdir(parents=True, exist_ok=True)
    stamp = work / ".build-cache.json"
    # The default output directory can be shared by multiple repo checkouts.
    with (work / ".build-cache.lock").open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        inputs = fingerprint(repo, hb)
        try:
            previous = json.loads(stamp.read_text())
        except (OSError, ValueError):
            previous = None
        outputs = output_hashes(work)
        if not force and outputs is not None and previous == {"inputs": inputs, "outputs": outputs}:
            print(f"Native math build cache hit: {work}")
            return
        stamp.unlink(missing_ok=True)
        subprocess.run(["bash", "scripts/math/build.sh", "--uncached"], check=True)
        outputs = output_hashes(work)
        if outputs is None:
            raise RuntimeError("native math build did not produce all executable outputs")
        if fingerprint(repo, hb) == inputs:
            temporary = stamp.with_suffix(".tmp")
            temporary.write_text(json.dumps({"inputs": inputs, "outputs": outputs}))
            temporary.replace(stamp)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--force", action="store_true", help="rebuild even when inputs are unchanged")
    main(force=parser.parse_args().force)
