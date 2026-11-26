"""Replay the native controls and build only the I11 slideshow."""
import json
import os
from pathlib import Path
import platform
import struct
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
DEST = ROOT / "artifacts/demo-slideshows/visible-proposals"
sys.path.insert(0, str(ROOT / "scripts"))
from demo_slideshows import load_manifest, render

STEPS = [
    ("01-initial", "initial", "Open the calibration sample", "Gain 1 and offset 0 at revision 0. Apply is disabled."),
    ("02-inspect", "interaction", "Request a fit proposal", "Inspect gain 1 to 3 and offset 0 to 4 alongside the unchanged live values."),
    ("03-reject", "result", "Reject the proposal", "The preview clears. Both values and the revision stay unchanged."),
    ("04-edited", "interaction", "Request again and increase live gain", "Revision 1 has gain 2. The preview still describes revision 0."),
    ("05-stale", "recovery", "Apply the outdated proposal", "Stale rejection preserves gain 2 and offset 0 at revision 1."),
    ("06-applied", "result", "Request a fresh proposal and apply it", "Both changes land together at revision 2. The preview clears."),
]


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    subprocess.run([HERE / "run.sh", "check"], check=True,
                   env=dict(os.environ, MOXI_LIFECYCLE_CAPTURE_DIR=str(DEST)))
    slides = []
    for name, phase, action, expected in STEPS:
        image = DEST / (name + ".png")
        width, height = struct.unpack(">II", image.read_bytes()[16:24])
        slides.append(dict(image=image.name, phase=phase, dimensions=[width, height],
                           capture_kind="native-window", caption=action, action=action, expected=expected))
    manifest = dict(version=1, demo_id=DEST.name, title="Visible fit proposals",
                    scenario="I11 • Inspect a deterministic two-parameter fit in the live workspace.",
                    revision=subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
                    host="macOS " + platform.mac_ver()[0], backend="Moxi AppKit content-view capture",
                    scale=slides[0]["dimensions"][0] / 480,
                    fixture="Fixed measurements (0, 4), (1, 7); initial gain 1, offset 0.",
                    reproduce="pixi run --locked python examples/visible-proposals/gallery.py",
                    slides=slides)
    path = DEST / "manifest.json"
    path.write_text(json.dumps(manifest, indent=2) + "\n")
    (DEST / "index.html").write_text(render(load_manifest(path)))
    print("Verified six native captures:", DEST / "index.html")


if __name__ == "__main__":
    main()
