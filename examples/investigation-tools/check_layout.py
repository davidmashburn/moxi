"""Regress full coefficients and maximum-length metadata in the native app."""
import argparse
import datetime
import json
import os
from pathlib import Path
import platform
import struct
import subprocess

from check import ROOT, HERE, digest, run


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dest", type=Path, default=Path("/tmp/moxi-i10-layout"))
    parser.add_argument("--skip-build", action="store_true",
                        help="Reuse this checkout's just-built executables; records their hashes.")
    args = parser.parse_args()
    dest = args.dest.resolve()
    dest.mkdir(parents=True, exist_ok=True)
    logs = dest / "logs"
    logs.mkdir(exist_ok=True)
    work = dest / "work"
    work.mkdir(exist_ok=True)
    if not args.skip_build:
        run(["bash", HERE / "build.sh"], log=logs / "build.log", timeout=900)
    binary = ROOT / "dist/investigation-tools/investigation"
    tests = ROOT / "dist/investigation-tools/model-tests"
    run([tests], log=logs / "domain.log")
    env = dict(os.environ, MOXI_COHORT_CAPTURE=str(dest), MOXI_I10_LAYOUT_CHECK="1")
    run([binary], cwd=work, env=dict(env, MOXI_I10_REPLAY="create"), log=logs / "create.log")
    saved = work / "panel.json"
    document = json.loads(saved.read_text())
    # Independent wire literals detect rounding or changed serialization.
    assert document["coefficients"] == [-33.333333333333336, 16.123456789012344,
                                         -1.2345678901234567e-123]
    assert document["model"] == "quadratic"
    assert document["members"] == [318, 429, 530, 641, 752, 863]
    assert document["cohort_name"] == "W" * 64
    assert document["hypothesis"] == "W" * 140
    assert document["membership"] == "live"
    (dest / "saved-panel.json").write_bytes(saved.read_bytes())
    run([binary], cwd=work, env=dict(env, MOXI_I10_REPLAY="reopen"), log=logs / "reopen.log")
    assert saved.read_bytes() == (dest / "saved-panel.json").read_bytes()
    sources = sorted([*HERE.glob("*.mojo"), *HERE.glob("*.py"), HERE / "host.m", HERE / "build.sh",
                      ROOT / "examples/application-operations/cohort.mojo",
                      ROOT / "examples/application-operations/host.m",
                      ROOT / "native/macos_window.m", ROOT / "pixi.lock"])
    captures = {}
    for prefix in ("linear", "edited", "saved-frozen", "saved-live", "reopened"):
        for size in ("min", "large"):
            path = dest / f"{prefix}-{size}.png"
            dimensions = struct.unpack(">II", path.read_bytes()[16:24])
            points = [980, 800] if size == "min" else [1140, 860]
            assert dimensions[0] / points[0] == dimensions[1] / points[1]
            captures[path.name] = dict(sha256=digest(path), pixels=list(dimensions),
                                       content_points=points)
    manifest = dict(
        captured_at=datetime.datetime.now(datetime.timezone.utc).isoformat(),
        revision=subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        source_status=subprocess.check_output(["git", "status", "--short", "--", "examples/investigation-tools"], cwd=ROOT, text=True).strip(),
        source_sha256={str(path.relative_to(ROOT)): digest(path) for path in sources},
        binary_sha256=digest(binary), domain_binary_sha256=digest(tests),
        environment=f"macOS {platform.mac_ver()[0]} / {platform.machine()} / AppKit NSWindow",
        fixture="sensor-curve-v1, eight synthetic observations, local files only",
        reproduce="python3 examples/investigation-tools/check_layout.py --dest /tmp/moxi-i10-layout",
        captures=captures,
        verification={path.name: path.read_text().strip() for path in sorted(logs.glob("*.log"))
                      if path.name != "build.log"},
        skipped=["Physical mouse/keyboard use", "VoiceOver", "Other OS hosts", "Full repository suite"])
    (dest / "manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")
    print("PASS native layout: 2 processes, 2 sizes, 10 captures; exact JSON coefficients and maximum metadata verified")
    print(dest / "manifest.json")


if __name__ == "__main__":
    main()
