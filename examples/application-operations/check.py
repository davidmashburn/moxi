"""Build this checkout, exercise both CLI callers and capture the AppKit replay."""
import datetime
import json
import os
from pathlib import Path
import platform
import struct
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
DEST = HERE / "i20-application-operations"
sys.path.insert(0, str(ROOT / "scripts"))
from demo_slideshows import load_manifest, render


SLIDES = [
    ("01-ready", "initial", "An empty cohort", "Open the notebook.", "Three observations and no members."),
    ("02-pressed", "interaction", "Button held", "Send mouseDown to the center of the mounted button.", "Pressed control and empty cohort before release."),
    ("03-button", "result", "Mouse selection", "Release, then click the replacement button.", "Both IDs produce the same cohort of observations 104 and 318."),
    ("04-shortcut", "result", "Keyboard selection", "Start fresh and send F2 to the canvas.", "Keyboard status and the same two members without a click."),
    ("05-script", "result", "Script selection", "Invoke the trusted script adapter on a fresh notebook.", "Script status and the same two stable IDs."),
    ("06-denied", "recovery", "Read-only caller", "Submit the operation on the populated notebook as an agent.", "Rejection leaves cohort membership and write count intact."),
]


def main():
    subprocess.run(["bash", HERE / "build.sh"], check=True)
    binary = ROOT / "dist/application-operations/notebook"
    for flag, code, output in [
        ("--script", 0, "[104,318]"),
        ("--agent", 1, "Caller has read-only access"),
    ]:
        result = subprocess.run([binary, flag], text=True, capture_output=True)
        if (result.returncode, result.stdout.strip()) != (code, output):
            raise RuntimeError(f"{flag}: {result!r}")
    DEST.mkdir(exist_ok=True)
    subprocess.run([binary, "--replay"], env=dict(os.environ, MOXI_COHORT_CAPTURE=str(DEST)), check=True)
    slides = []
    for name, phase, caption, action, expected in SLIDES:
        image = DEST / (name + ".png")
        dimensions = struct.unpack(">II", image.read_bytes()[16:24])
        slides.append(dict(image=image.name, phase=phase, caption=caption, action=action,
                           expected=expected, dimensions=dimensions, capture_kind="native-window"))
    manifest = dict(version=1, demo_id=DEST.name, title="One operation for a high-reading cohort",
                    scenario="I20 • Local application operations", slides=slides,
                    revision=subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
                    captured_at=datetime.datetime.now(datetime.timezone.utc).isoformat(),
                    host="macOS " + platform.mac_ver()[0], backend="AppKit live NSWindow content-view capture",
                    scale=slides[0]["dimensions"][0] / 460, fixture="Three synthetic sensor observations",
                    reproduce="python3 examples/application-operations/check.py")
    path = DEST / "manifest.json"
    path.write_text(json.dumps(manifest, indent=2) + "\n")
    (DEST / "index.html").write_text(render(load_manifest(path)))
    print("PASS CLI output and exit codes, six validated native PNGs and slideshow")


if __name__ == "__main__":
    main()
