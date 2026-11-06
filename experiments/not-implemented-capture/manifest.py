"""Record provenance for actual AppKit render captures; never synthesize images."""
import hashlib
import json
from pathlib import Path
import platform
import subprocess
import sys

repo = Path(__file__).resolve().parents[2]
output = Path(sys.argv[1])
sources = sorted([*repo.glob("src/**/*.mojo"), repo / "native/macos_window.m",
                  *Path(__file__).parent.glob("capture.*"), Path(__file__),
                  Path(__file__).with_name("run.sh")])
fingerprint = hashlib.sha256(b"".join(
    str(p.relative_to(repo)).encode() + p.read_bytes() for p in sources)).hexdigest()
states = [
    ("initial", "initial", "Default and explanatory variants", "Launch the real NotImplementedDemo", "Both instances show Not implemented yet; Host clicks is 0"),
    ("interaction", "interaction", "Working surrounding controls", "Dispatch Enter to the initially focused host button", "Host clicks is 1; both informational components are unchanged"),
    ("result", "result", "Replace with implemented content", "Activate replacement and the real counter increment action", "Counter is 1 beside the unchanged Report export component"),
    ("recovery", "recovery", "Restore unfinished content", "Activate Restore unfinished counter", "Both informational components return; Host clicks remains 1"),
    ("narrow", "interaction", "Narrow wrapped content", "Resize the App to 280 by 620 points", "Explanation wraps; overflow is scrollable"),
    ("narrow-bottom", "recovery", "Reach the recovery control", "Dispatch a scroll to the bottom", "The replacement button remains reachable"),
    ("playground", "result", "Playground integration", "Select Not implemented pattern and its Demo tab", "The same real component is mounted inside Playground"),
]
slides = []
for name, phase, caption, action, expected in states:
    png = (output / (name + ".png")).read_bytes()
    if png[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("Invalid capture: " + name)
    slides.append(dict(phase=phase, capture_kind="offscreen-render", image=name + ".png",
                       dimensions=[int.from_bytes(png[16:20], "big"), int.from_bytes(png[20:24], "big")],
                       caption=caption, action=action, expected=expected))
manifest = dict(version=1, demo_id="not-implemented", title="Moxi unfinished-feature pattern",
    scenario="N01: actual Moxi App event replay and AppKit drawing. Offscreen renders do not verify live desktop input, the compositor, or VoiceOver.",
    revision=subprocess.check_output(["git", "-C", str(repo), "rev-parse", "HEAD"], text=True).strip(),
    host=platform.platform(), backend="AppKit offscreen bitmap, actual Moxi draw commands", scale=1,
    fixture="NotImplementedDemo and DemoBrowserState; working-source SHA256 " + fingerprint,
    reproduce="bash experiments/not-implemented-capture/run.sh; python3 scripts/demo_slideshows.py",
    slides=slides)
(output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
print("Recorded seven actual captures; source SHA256", fingerprint)
