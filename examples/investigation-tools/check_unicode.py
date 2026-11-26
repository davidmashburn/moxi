"""Compare native label paint with an unconstrained raster and reopen exact panels."""
import argparse
import datetime
import json
import os
from pathlib import Path
import platform
import re
import struct
import subprocess

from check import ROOT, HERE, digest, run


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dest", type=Path, default=Path("/tmp/moxi-i10-unicode"))
    parser.add_argument("--skip-build", action="store_true",
                        help="Reuse this checkout's just-built executable and record its hash.")
    args = parser.parse_args()
    dest = args.dest.resolve()
    dest.mkdir(parents=True, exist_ok=True)
    if not args.skip_build:
        run(["bash", HERE / "build.sh"], log=dest / "build.log", timeout=900)
    binary = ROOT / "dist/investigation-tools/investigation"
    failures = []
    processes = {}
    for mode in ("frozen", "live"):
        case = dest / mode
        work = case / "work"
        work.mkdir(parents=True, exist_ok=True)
        env = dict(os.environ, MOXI_COHORT_CAPTURE=str(case), MOXI_I10_UNICODE_CHECK=mode)
        saved = work / "panel.json"
        for action in ("create", "reopen"):
            log = case / f"{action}.log"
            try:
                run([binary], cwd=work, env=dict(env, MOXI_I10_REPLAY=action), log=log)
            except RuntimeError:
                failures.append(f"{mode}/{action}")
            output = log.read_text().strip()
            processes[f"{mode}/{action}"] = output
            if action == "create":
                # Paint checks also cover the active native field editor, where
                # End/delete/reinsert previously left a blank viewport.
                ink = re.findall(r"PADDED (active|edited|applied|saved) ink (980|1140) (\d+)", output)
                if len(ink) != 7 or any(int(count) <= 100 for _, _, count in ink):
                    failures.append(f"{mode}/padded-foreground")
            document = json.loads(saved.read_text())
            # Independent wire values verify the sentinel, complete configuration
            # and numeric identity, rather than trusting app-side string equality.
            assert document == {
                "version": 1, "fixture": "sensor-curve-v1",
                "fixture_state": "baseline", "target": "sensor.reading.by.sample-index.v1", "cohort_name": "😀" * 63 + "Z",
                "hypothesis": "😀" * 139 + "Z", "membership": mode, "rule": "reading>=70",
                "members": [318, 429, 530, 641, 752, 863], "model": "quadratic",
                "coefficients": [67.99999999999994, 1.2345678901234566e-7, 1.9999999999999976],
                "controls": ["refit", "coefficients"],
            }
            if action == "create":
                (case / "saved-panel.json").write_bytes(saved.read_bytes())
            else:
                assert saved.read_bytes() == (case / "saved-panel.json").read_bytes()
    sources = sorted([*HERE.glob("*.mojo"), *HERE.glob("*.py"), HERE / "host.m", HERE / "build.sh",
                      ROOT / "examples/application-operations/host.m", ROOT / "native/macos_window.m",
                      ROOT / "pixi.lock"])
    captures = {}
    for path in sorted(dest.glob("*/*.png")):
        dimensions = struct.unpack(">II", path.read_bytes()[16:24])
        points = [980, 800] if path.stem.endswith("980") else [1140, 860]
        assert dimensions[0] / points[0] == dimensions[1] / points[1]
        captures[str(path.relative_to(dest))] = dict(sha256=digest(path), pixels=list(dimensions),
                                                    content_points=points)
    for mode in ("frozen", "live"):
        for prefix in ("case0-saved", "case0-reopened", "case7-saved", "case7-reopened", "fresh-emoji"):
            for width in (980, 1140):
                assert f"{mode}/{prefix}-{width}.png" in captures
    manifest = dict(
        captured_at=datetime.datetime.now(datetime.timezone.utc).isoformat(),
        revision=subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        source_status=subprocess.check_output(["git", "status", "--short", "--", "examples/investigation-tools"], cwd=ROOT, text=True).strip(),
        source_sha256={str(path.relative_to(ROOT)): digest(path) for path in sources},
        binary_sha256=digest(binary),
        environment=f"macOS {platform.mac_ver()[0]} / {platform.machine()} / AppKit NSWindow",
        fixture="sensor-curve-v1, eight synthetic observations, local files only",
        oracle="Real native drawOrderedSlot label paint at allocated height vs tall reference; shortened-frame negative control",
        reproduce="python3 examples/investigation-tools/check_unicode.py --dest /tmp/moxi-i10-unicode",
        captures=captures, verification=processes, failures=failures,
        skipped=["Physical mouse/keyboard use", "VoiceOver", "Other OS hosts and fonts/scales", "Full repository suite"])
    (dest / "manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")
    assert not failures, f"Native paint/entry-point failures: {failures}; see {dest / 'manifest.json'}"
    print(f"PASS native Unicode: 4 processes, frozen/live, 2 sizes, {len(captures)} captures; full paint and exact JSON")
    print(dest / "manifest.json")


if __name__ == "__main__":
    main()
