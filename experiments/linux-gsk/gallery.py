"""Package reviewed X11 captures with the repository's offline slideshow builder."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
from demo_slideshows import load_manifest, render


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("run", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--revision", default=None, help="commit containing the tested renderer")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    slides = []
    for mode, state, phase, caption, action, expected in [
        ("oracle", "initial", "initial", "GTK Cairo reference", "Open the canonical workbench.",
         "The results pane contains the clipped teal chart above the data grid."),
        ("ngl", "initial", "initial", "The same scene through OpenGL ES", "Select the GSK adapter and open the workbench.",
         "The same chart, text and table appear at the same logical coordinates."),
        ("ngl", "collection", "interaction", "Edit a collection cell", "Click a visible value and type q.",
         "The cell gains focus and its published value includes q."),
        ("ngl", "unicode", "result", "Commit Unicode input", "Focus Dataset and enter U+3042 with GTK simple input.",
         "The editor commits あ and ends preedit."),
        ("ngl", "popup", "interaction", "Open the modal", "Click the chooser.",
         "Modal controls appear over the workbench and the background editor leaves the active semantic tree."),
        ("ngl", "narrow", "recovery", "Dismiss and resize", "Press Escape and narrow the window to 540 pixels.",
         "Focus returns to Dataset and the results pane moves below the form."),
        ("scale2", "initial", "result", "Double the device scale", "Open a fresh window with GDK_SCALE=2.",
         "The initial composition covers twice the device pixels on each axis."),
        ("fallback", "initial", "recovery", "Recover with graphics APIs disabled",
         "Disable GL and Vulkan at process startup while requesting the GL renderer.",
         "GTK falls back to Cairo and presents the chart from the same GSK node stream."),
    ]:
        states = json.loads((args.run / mode / "states.json").read_text())
        record = next(row for row in states if row["state"] == state)
        image = f"{mode}-{state}.png"
        shutil.copyfile(args.run / mode / f"{state}.png", args.output / image)
        with Image.open(args.output / image) as capture:
            dims = list(capture.size)
        slides.append({"image": image, "dimensions": dims, "phase": phase, "caption": caption,
                       "action": action, "expected": expected, "capture_kind": "native-window",
                       **record})
    manifest = dict(version=1, demo_id="linux-gsk", title="Linux workbench scene parity",
                    scenario="P09 · chart, collection editing, Unicode, modal, responsive layout and recovery",
                    revision=args.revision or subprocess.check_output(["git","rev-parse","HEAD"],text=True).strip(),
                    host="Ubuntu 24.04 x86-64 · Xvfb / Openbox",
                    backend="GTK 4.14 · Cairo and GSK NGL on Mesa llvmpipe",
                    fixture="Canonical layout_workbench_linux, deterministic synthetic X11 input",
                    scale=1, reproduce="See experiments/linux-gsk/README.md for build, capture and measurement commands.",
                    slides=slides)
    path = args.output / "manifest.json"
    path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")
    (args.output / "index.html").write_text(render(load_manifest(path)))


if __name__ == "__main__":
    main()
