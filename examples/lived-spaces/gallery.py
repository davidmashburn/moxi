"""Replay the native controls and render this example's offline gallery."""
import json
import hashlib
from datetime import datetime, timezone
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
     "North's eye view is occluded. South's exhibit marker brightens to 100% at the same 7 s cursor."),
    ("09-south", "interaction", "Compare from the other route", "Switch to South at 7 s.",
     "South becomes selected and stays clear; North stays occluded. Score and two history entries are shared."),
    ("10-undo-light", "recovery", "First undo: timing", "Undo once while South is selected.",
     "The cue returns to 75%, North stays occluded and one spatial edit remains."),
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
    ("11-ended", "result", "One cursor, different route durations", "Switch to North and scrub to 12 s.",
     "North is at 12 s; South's eye stays at its 10 s endpoint. The shared cue is now 0%."),
    ("performance/01-authored", "interaction", "Record five actions", "Record route, time, partition, cue and time actions; finish.",
     "The native transcript lists five accepted actions and both eye views follow the resulting session."),
    ("performance/02-exploring", "interaction", "Explore after step three", "Play the sequence, explore at step three, then edit route, time and score.",
     "The eye views follow the exploration while the authored transcript retains its third-step position."),
    ("performance/03-returned", "recovery", "Return to the recorded prefix", "Return from exploration.",
     "South at 4 s, partition −1 m, prior cue and complete history return at step three."),
    ("performance/04-resumed", "result", "Resume the last two actions", "Step twice.",
     "The cue and cursor reach the recorded endpoint at South 5 s without changing the five-action sequence."),
    ("performance/05-undo-light", "recovery", "Undo the recorded cue", "Undo once.",
     "Cue timing returns to the prefix; South stays occluded and prior history is preserved."),
    ("performance/06-undo-partition", "recovery", "Undo the recorded partition", "Undo again.",
     "The original partition returns and South's marker reappears, retaining pre-recording history."),
]


def main():
    def git(*args):
        return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()

    sources = ["examples/lived-spaces", "native/spatial", "scripts/demo_slideshows.py"]
    if git("status", "--porcelain", "--", *sources):
        raise SystemExit("Commit the tested sources before labeling captures with a revision.")
    revision = git("log", "-1", "--format=%H", "--", *sources)
    DEST.mkdir(parents=True, exist_ok=True)
    (DEST / "performance").mkdir(exist_ok=True)
    commands = [
        ["examples/lived-spaces/run.sh", "--check-model"],
        ["examples/lived-spaces/run.sh", "--check", str(DEST.relative_to(ROOT))],
        ["examples/lived-spaces/run.sh", "--check-performance", str((DEST / "performance").relative_to(ROOT))],
    ]
    checks = []
    for command in commands:
        result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, check=True)
        checks.append(dict(command=command, exit_code=result.returncode, stdout=result.stdout,
                           stderr=result.stderr))
        print(result.stdout.strip())
    inventory = {
        path: hashlib.sha256((ROOT / path).read_bytes()).hexdigest()
        for path in git("ls-files", "--", *sources).splitlines()
    }
    slides = []
    for name, phase, caption, action, expected in STATES:
        path = DEST / (name + ".png")
        width, height = struct.unpack(">II", path.read_bytes()[16:24])
        slides.append(dict(image=name + ".png", phase=phase, caption=caption, action=action,
                           expected=expected, dimensions=[width, height], capture_kind="native-window"))
    manifest = dict(version=1, demo_id=DEST.name, title="Compose a timed exhibit reveal",
                    scenario="V09 partition and cue authoring, I06 term inspection and I07 checkpoint replay",
                    host=f"macOS {platform.mac_ver()[0]} {platform.machine()}",
                    backend="AppKit content capture; Moxi floor projection and triangle picking; stylized perspective visitor-eye ray casting",
                    fixture="Two parallel 7 m paths, one exhibit, one partition and one cue",
                    reproduce="python3 examples/lived-spaces/gallery.py", revision=revision,
                    captured_at=datetime.now(timezone.utc).isoformat(),
                    base_revision="aedd058d1ac9605d25a4b0660c93c9220901362f",
                    source_sha256=inventory,
                    scale=slides[0]["dimensions"][0] / 1260, slides=slides)
    path = DEST / "manifest.json"
    path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")
    (DEST / "checks.json").write_text(json.dumps(dict(revision=revision, checks=checks), indent=2) + "\n")
    (DEST / "index.html").write_text(render(load_manifest(path)))
    print(f"Validated {len(slides)} native captures and wrote {DEST.name}/index.html")


if __name__ == "__main__":
    main()
