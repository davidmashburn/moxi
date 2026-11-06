#!/usr/bin/env python3
"""Capture the actual two-window integration replay and write its slideshow."""
from enum import StrEnum
import hashlib
import json
import os
from pathlib import Path
import platform
import struct
import subprocess

ROOT = Path(__file__).resolve().parents[1]
DESTINATION = ROOT / "artifacts/demo-slideshows/native-lifecycle"
NATIVE_WINDOW = "native-window"


class Phase(StrEnum):
    INITIAL = "initial"
    INTERACTION = "interaction"
    RESULT = "result"
    RECOVERY = "recovery"


STATES = [
    ("01-initial-a", Phase.INITIAL, "Independent A", "Open both real Moxi windows", "A shows rows 50001–50006; row 50001 is selected"),
    ("02-initial-b", Phase.INITIAL, "Independent B", "Capture B while A remains alive", "B has its own labels, selection and model"),
    ("03-edited-a", Phase.INTERACTION, "A retains a mixed-script edit", "Use A's native AX text callback while B is selected", "Only A's row 50001 becomes Alpha deep edit 日本語"),
    ("04-edited-b", Phase.INTERACTION, "B retains a different edit", "Select B's row 50003 and use its native AX text callback", "Only B's row 50003 becomes Beta retained edit"),
    ("05-reordered-a", Phase.RESULT, "Stable identity through drag", "Deliver AppKit mouse down/drag/up callbacks to A while B is selected", "A's row 50001 moves to the third slot with its edit and selection"),
    ("06-selected-text", Phase.INTERACTION, "Native editor selection", "Invoke the native menu target and apply the portable selection result", "A's native field editor selects the complete retained text"),
    ("08-cancelled", Phase.RECOVERY, "Cancel preserves the edit", "Open a real NSAlert sheet and resolve Cancel", "A retains its mixed-script edit; B remains independent"),
    ("09-applied", Phase.RESULT, "Apply resets one row", "Open another native sheet and resolve Apply", "A's selected row returns to A observation 50001"),
    ("10-sibling-survives", Phase.RECOVERY, "B survives A's disposal", "Restore A's edit, close A with a sheet open, then invoke its stale callback", "B stays open with Beta retained edit"),
    ("11-reopened-a", Phase.RECOVERY, "Fresh window, retained model", "Request reopening through B's native AX button action", "A has a new handle and retains its edit, row order and selection"),
    ("12-final-b", Phase.RESULT, "Sibling state remains isolated", "Close A after reopening and capture B", "B still shows its independent selected row and edit"),
]


def main():
    if platform.system() != "Darwin":
        raise SystemExit("Native lifecycle capture requires a macOS graphical session")
    DESTINATION.mkdir(parents=True, exist_ok=True)
    environment = dict(os.environ, MOXI_LIFECYCLE_CAPTURE_DIR=str(DESTINATION))
    subprocess.run(["pixi", "run", "native-lifecycle-check"], cwd=ROOT, env=environment, check=True)
    sources = sorted((ROOT / "src/moxi").glob("*.mojo"))
    sources += [ROOT / name for name in (
        "native/macos_window.m", "native/macos_window_state.h", "native/macos_text.m",
        "tests/native_lifecycle.mojo", "tests/native_lifecycle_probe.m",
        "scripts/native_lifecycle_check.sh", "scripts/native_lifecycle_gallery.py")]
    digest = hashlib.sha256()
    for path in sources:
        digest.update(str(path.relative_to(ROOT)).encode() + b"\0" + path.read_bytes())
    slides = []
    for name, phase, caption, action, expected in STATES:
        path = DESTINATION / (name + ".png")
        data = path.read_bytes()
        if data[:8] != b"\x89PNG\r\n\x1a\n":
            raise ValueError(f"Invalid PNG: {path.name}")
        width, height = struct.unpack(">II", data[16:24])
        slides.append(dict(phase=phase, capture_kind=NATIVE_WINDOW, image=path.name,
                           dimensions=[width, height], caption=caption, action=action, expected=expected))
    manifest = dict(version=1, demo_id="native-lifecycle", title="Independent native windows",
        scenario="Two real Moxi/AppKit collection windows: isolated editing, drag, sheet outcomes and retained reopen. Scripted native callbacks; content-view captures exclude window chrome and compositor effects.",
        revision=subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        host="macOS " + platform.mac_ver()[0], backend="AppKit live NSWindow content-view cacheDisplay", scale=slides[0]["dimensions"][0] / 560,
        fixture="100000 stable rows per window; six mounted rows; source SHA-256 " + digest.hexdigest(),
        reproduce="python3 scripts/native_lifecycle_gallery.py && python3 scripts/demo_slideshows.py", slides=slides)
    (DESTINATION / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    print(f"Captured {len(slides)} lifecycle slides; source SHA-256 {digest.hexdigest()}")


if __name__ == "__main__":
    main()
