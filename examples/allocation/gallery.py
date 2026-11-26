"""Replay the native controls and build only the V10 slideshow."""
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import platform
import struct
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
DEST = ROOT / "artifacts/demo-slideshows/allocation"
sys.path.insert(0, str(ROOT / "scripts"))
from demo_slideshows import load_manifest, render

STEPS = [
    ("01-baseline", "initial", "Open a fresh session", "Compare three 12-plot branches against the three owners' minimums."),
    ("02-preference", "interaction", "Relax Fern's minimum to five", "Plot counts stay fixed. Fern's shortfall in Commons falls to one."),
    ("03-shared", "result", "Raise shared supply to 13", "Every branch gains one garden. Commons meets Fern and Pip's requests."),
    ("04-override", "interaction", "Transfer a Commons play plot to grove", "Only Commons changes. Ash gains a grove plot and Pip loses a play plot."),
    ("05-promoted", "result", "Select Commons, enter a reason and promote", "The decision records five gardens, five grove and three play plots. Pip remains one short."),
    ("06-retained", "result", "Restore the Commons play plot", "Pip's current request is met. The promoted allocation retains the earlier shortfall and reason."),
    ("07-undo", "recovery", "Undo promotion", "The decision clears while the edited working branches and owned minimums remain."),
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
    manifest = dict(version=1, demo_id=DEST.name, title="Orchard Commons allocation",
                    scenario="V10 and I04 • Compare allocations with three owned minimums and retain the decision through later edits.",
                    revision=subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
                    captured_at=datetime.now(timezone.utc).isoformat(),
                    host="macOS " + platform.mac_ver()[0], backend="Moxi AppKit content-view capture",
                    scale=slides[0]["dimensions"][0] / 760,
                    fixture="12 plots; minimum gardens/grove/play 6/5/4; three fixed branch seeds.",
                    reproduce="pixi run --offline --locked python examples/allocation/gallery.py",
                    slides=slides)
    path = DEST / "manifest.json"
    path.write_text(json.dumps(manifest, indent=2) + "\n")
    (DEST / "index.html").write_text(render(load_manifest(path)))
    print("Verified native allocation captures:", DEST / "index.html")


if __name__ == "__main__":
    main()
