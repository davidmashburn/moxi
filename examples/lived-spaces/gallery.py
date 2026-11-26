"""Replay the native controls and render this example's offline gallery."""
import json
from pathlib import Path
import platform
import struct
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / "artifacts/demo-slideshows/lived-spaces"
sys.path.insert(0, str(ROOT / "scripts"))
from demo_slideshows import load_manifest, render


STATES = [
    ("01-routes", "initial", "Two walks to the exhibit", "Launch at 7 s on North.",
     "Both routes have cleared the partition. The selected visitor sees 75% light."),
    ("02-partition", "interaction", "A spatial edit separates the routes", "Move the partition +1 m.",
     "North loses sight at the cursor. South remains clear."),
    ("03-peak", "result", "A brighter cue behind the wall", "Move the peak one second later.",
     "The exhibit reaches 100% at the cursor while North remains blocked."),
    ("04-undo", "recovery", "Restore both representations", "Undo the cue, then the partition.",
     "The peak returns to 6 s, the sightline clears and history is empty."),
    ("05-rejected", "recovery", "The partition reaches its travel limit",
     "Switch to South, scrub to 5 s, move −1 m and checkpoint. Advance the cue, move −1 m, then try once more.",
     "The final move is rejected at −2 m. Three edits remain in history."),
    ("06-restored", "recovery", "Return to the third action", "Restore the checkpoint.",
     "South at 5 s, partition −1 m, peak 6 s and one history entry return."),
    ("07-definition", "interaction", "Inspect the envelope width", "Press Command-F, then Command-D.",
     "The cue formula gives way to its asymmetric rise and fall durations."),
    ("08-selection", "result", "Return to the selected term", "Press Command-D again.",
     "The formula regains keyboard focus with width selected."),
]


def main():
    def git(*args):
        return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()

    sources = ["examples/lived-spaces", "native/spatial", "scripts/demo_slideshows.py"]
    if git("status", "--porcelain", "--", *sources):
        raise SystemExit("Commit the tested sources before labeling captures with a revision.")
    revision = git("log", "-1", "--format=%H", "--", *sources)
    DEST.mkdir(parents=True, exist_ok=True)
    subprocess.run([ROOT / "examples/lived-spaces/run.sh", "--check", DEST], check=True)
    slides = []
    for name, phase, caption, action, expected in STATES:
        path = DEST / (name + ".png")
        width, height = struct.unpack(">II", path.read_bytes()[16:24])
        slides.append(dict(image=path.name, phase=phase, caption=caption, action=action,
                           expected=expected, dimensions=[width, height], capture_kind="native-window"))
    manifest = dict(version=1, demo_id=DEST.name, title="Compose a timed exhibit reveal",
                    scenario="V09 partition and cue authoring, I06 term inspection and I07 checkpoint replay",
                    host=f"macOS {platform.mac_ver()[0]} {platform.machine()}",
                    backend="AppKit window content capture; Moxi spatial CPU projection and ray picking",
                    fixture="Two parallel 7 m paths, one exhibit, one partition and one cue",
                    reproduce="python3 examples/lived-spaces/gallery.py", revision=revision,
                    scale=slides[0]["dimensions"][0] / 920, slides=slides)
    path = DEST / "manifest.json"
    path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")
    (DEST / "index.html").write_text(render(load_manifest(path)))
    print(f"Validated {len(slides)} native captures and wrote {DEST.name}/index.html")


if __name__ == "__main__":
    main()
