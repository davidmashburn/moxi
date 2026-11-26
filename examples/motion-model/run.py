"""Build this checkout with the locked toolchain, then run the actual Moxi app."""
import argparse
import os
from pathlib import Path
import plistlib
import subprocess

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OUT = ROOT / "dist/motion-model"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model-check", action="store_true")
    parser.add_argument("--build-only", action="store_true")
    parser.add_argument("--replay", type=Path, help="Capture and verify the normal entry point")
    args = parser.parse_args()
    manifest = Path(os.environ.get("MOXI_PIXI_MANIFEST", ROOT / "pixi.toml")).resolve()
    if manifest != ROOT / "pixi.toml":
        if manifest.with_name("pixi.lock").read_bytes() != (ROOT / "pixi.lock").read_bytes():
            raise RuntimeError("Reused toolchain must have the same pixi.lock as this checkout")
    mojo = ["pixi", "run", "--locked", "--manifest-path", str(manifest), "mojo"]
    if args.model_check:
        subprocess.run([*mojo, "run", str(HERE / "model_check.mojo")], cwd=ROOT, check=True)
        return
    OUT.mkdir(parents=True, exist_ok=True)
    obj = OUT / "native.o"
    subprocess.run(["clang", "-O2", "-fobjc-arc", "-fmodules", "-c", str(HERE / "native.m"),
                    "-o", str(obj)], cwd=ROOT, check=True)
    bundle = OUT / "Motion Model.app"
    app = bundle / "Contents/MacOS/motion-model"
    app.parent.mkdir(parents=True, exist_ok=True)
    with (bundle / "Contents/Info.plist").open("wb") as stream:
        plistlib.dump(dict(CFBundleIdentifier="org.moxi.motion-model",
                          CFBundleName="Moxi Motion Model", CFBundleExecutable="motion-model",
                          CFBundlePackageType="APPL", CFBundleShortVersionString="0.1.0",
                          NSHighResolutionCapable=True), stream)
    subprocess.run([*mojo, "build", "-I", str(ROOT / "src"), "-Xlinker", str(obj),
                    "-Xlinker", "-framework", "-Xlinker", "Cocoa", str(HERE / "app.mojo"),
                    "-o", str(app)], cwd=ROOT, check=True)
    if args.build_only:
        print(app)
        return
    command = [str(app)]
    if args.replay:
        args.replay.mkdir(parents=True, exist_ok=True)
        command += ["--replay", str(args.replay.resolve())]
    subprocess.run(command, cwd=ROOT, check=True)


if __name__ == "__main__":
    main()
