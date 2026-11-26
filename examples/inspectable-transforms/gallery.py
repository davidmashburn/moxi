#!/usr/bin/env python3
"""Build, exercise and capture only the two native I19 consumers, offline."""
import argparse
from enum import Enum
import hashlib
import json
from pathlib import Path
import platform
import struct
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
DEST = HERE / "evidence/i19-transforms"
sys.path.insert(0, str(ROOT / "scripts"))
from demo_slideshows import load_manifest, render


class Phase(str, Enum):
    INITIAL = "initial"
    INTERACTION = "interaction"
    RESULT = "result"
    RECOVERY = "recovery"


STATES = [
    ("01-initial", Phase.INITIAL, "Independent public Moxi documents",
     "Launch the canvas or spatial entry mode in a fresh process",
     "Both panes have the same X and initial revision, with undo depth zero"),
    ("02-numeric-preview", Phase.INTERACTION, "Exact entry previews without committing",
     "Replace Exact X with 230 (canvas) or 700 (spatial)",
     "Only the native preview changes; committed X, revision and undo stay unchanged"),
    ("03-held-pointer-cancel", Phase.RECOVERY, "Escape cancels during native pointer capture",
     "Escape the numeric preview; drag the card or red X handle; press Escape while held, then move and release",
     "The original committed value and empty undo history survive the late move and release"),
    ("04-pointer-preview", Phase.INTERACTION, "Release keeps an inspectable pointer preview",
     "Drag the card or red X handle again and release",
     "Native preview persists after release; revision and undo remain unchanged"),
    ("05-committed-command", Phase.RESULT, "One native undo unit and a world-value command",
     "Refine Exact X to 230 or 700, then click Commit",
     "X commits once; revision advances once; JSON identifies operation, target, expected revision and world before/after"),
    ("06-source-undo", Phase.RECOVERY, "Undo restores X without rewinding revision",
     "Press Cmd-Z",
     "X returns to 80 (canvas) or 0 (spatial), undo becomes zero and revision advances again"),
    ("07-reprojected-replay", Phase.RESULT, "Replay survives different geometry and real resize",
     "Click Reproject / resize, widen the actual window, then Replay command",
     "Canvas camera zoom/pan or spatial orthographic camera changes; copy commits the same semantic X with one undo unit"),
    ("08-stale-after-undo", Phase.RECOVERY, "Returning to the original X does not revive a command",
     "Replay again (stale); Undo copy; Replay command again",
     "Stale rejection preserves restored X, advanced revision and zero undo depth"),
    ("09-numeric-grab", Phase.INTERACTION, "A grab keeps the displayed numeric draft",
     "Enter X 300 (canvas) or 700 (spatial), miss the target once, then grab the displayed card or red handle",
     "The miss preserves the draft; the visible grab starts at that same X with the committed baseline untouched"),
    ("10-numeric-grab-moved", Phase.INTERACTION, "Pointer movement refines exact entry",
     "Move the grabbed numeric preview 20 points right and release",
     "The native projected delta is added to the pending X; release retains one uncommitted draft"),
    ("11-before-regrab", Phase.INTERACTION, "A released draft can be grabbed again",
     "Commit and undo the mixed edit; make a fresh native pointer preview and release",
     "The pointer preview remains visible with the original committed baseline and unchanged history"),
    ("12-regrab-moved", Phase.INTERACTION, "A second grab refines the same edit",
     "Grab the displayed pointer preview, move 10 points right and release",
     "The second grab adds motion to the displayed X and creates no intermediate commit"),
    ("13-held-arrow", Phase.INTERACTION, "An arrow preserves held pointer ownership",
     "Commit and undo the two-grab edit; drag again and press Right while held",
     "The pending X increases by 10 canvas points or 50 milliworld units while the drag stays live"),
    ("14-held-arrow-moved", Phase.INTERACTION, "Pointer motion retains the arrow step",
     "Move the held pointer another 20 points right after the arrow",
     "Preview equals the independently measured native pointer result plus the arrow step; history is unchanged"),
    ("15-held-mixed-commit", Phase.RESULT, "Commit ends one shared mixed session",
     "Press Enter while the pointer is held; send late motion/release and repeat Enter",
     "The final mixed preview commits once and late events cannot revive it"),
    ("16-mixed-cancel", Phase.RECOVERY, "One undo and Escape preserve the baseline",
     "Undo the mixed commit; start another held drag and arrow; Escape, then move and release",
     "One undo restores the original X; Escape discards the next mixed draft without changing revision or history"),
]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def sources():
    paths = {ROOT / name for name in ("pixi.toml", "pixi.lock", "scripts/demo_slideshows.py",
             "native/macos_window.m", "native/macos_text.m")}
    for directory in (HERE, ROOT / "src/moxi", ROOT / "src/moxi_canvas", ROOT / "src/moxi_spatial", ROOT / "native"):
        paths.update(p for p in directory.rglob("*") if p.is_file() and "evidence" not in p.parts
                     and p.suffix in {".mojo", ".m", ".cpp", ".h", ".hpp", ".inc", ".sh", ".py"})
    return {str(p.relative_to(ROOT)): sha(p) for p in sorted(paths)}


def output(*command):
    return subprocess.check_output(command, cwd=ROOT, text=True).strip()


def run(command, log):
    with open(log, "w") as stream:
        subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT, check=True, timeout=300)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--render-only", action="store_true", help="Verify retained hashes and rebuild only the offline HTML")
    args = parser.parse_args()
    DEST.mkdir(parents=True, exist_ok=True)
    if args.render_only:
        provenance = json.loads((DEST / "provenance.json").read_text())
        if sources() != provenance["sources"]:
            raise RuntimeError("Sources changed; recapture with gallery.py before presenting these frames as current")
        for name, digest in provenance["artifacts"].items():
            if sha(DEST / name) != digest:
                raise RuntimeError(f"Retained evidence hash mismatch: {name}")
    else:
        before = sources()
        revision = output("git", "rev-parse", "HEAD")
        started = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        executable = ROOT / "dist/inspectable-transforms/transforms"
        run(["bash", "examples/inspectable-transforms/build.sh"], "/tmp/moxi-i19-build.log")
        slides = []
        for mode in ("canvas", "spatial"):
            directory = DEST / mode
            directory.mkdir(exist_ok=True)
            run([str(executable), mode, "--replay", str(directory)], f"/tmp/moxi-i19-{mode}.log")
            for stem, phase, caption, action, expected in STATES:
                image = directory / f"{stem}.png"
                observed = json.loads((directory / f"{stem}.json").read_text())
                dimensions = list(struct.unpack(">II", image.read_bytes()[16:24]))
                if dimensions != [round(v * observed["scale"]) for v in observed["window_points"]]:
                    raise RuntimeError(f"Capture dimensions disagree with observed window and scale: {image}")
                slides.append({"image": str(image.relative_to(DEST)), "phase": phase.value,
                    "caption": f"{mode.capitalize()}: {caption}", "action": action, "expected": expected,
                    "observed": observed, "outcome": "pass", "capture_kind": "native-window", "dimensions": dimensions})
        if sources() != before:
            raise RuntimeError("Source changed while building/capturing; evidence is not current")
        manifest = {"version": 1, "demo_id": "i19-transforms", "title": "I19 · Canvas and projected spatial commands",
            "revision": revision, "host": platform.platform(), "scale": slides[0]["observed"]["scale"],
            "backend": "Native Moxi CanvasSnapshot / public SpatialViewport with experimental Metal; AppKit callbacks",
            "fixture": "One synthetic card (ID 1) or one generated surface (ID 101); independent source/copy documents; no external services",
            "scenario": "Numeric and native pointer preview, visible numeric/pointer re-grabs, held arrow followed by live pointer motion, shared commit/cancel/undo, world-value replay after camera/viewport/window change, repeat and undo-ABA stale rejection. Automated native replay through field-editor insertion, AppKit key dispatch and pointer callbacks; no human or hardware input evaluation. VoiceOver remains paused.",
            "reproduce": "bash examples/inspectable-transforms/build.sh\ndist/inspectable-transforms/transforms canvas\ndist/inspectable-transforms/transforms spatial\npython3 examples/inspectable-transforms/gallery.py\npython3 examples/inspectable-transforms/gallery.py --render-only",
            "slides": slides}
        (DEST / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
        artifacts = {str(p.relative_to(DEST)): sha(p) for p in sorted(DEST.rglob("*"))
                     if p.is_file() and p.suffix in {".png", ".json"} and p.name != "provenance.json"}
        provenance = {"capture_started_utc": started, "revision": revision,
            "public_base": "033596ddb576b09b48234733b45a283b4c3fecae",
            "scoped_git_status": output("git", "status", "--short", "--untracked-files=all", "--", str(HERE.relative_to(ROOT))),
            "sources": before, "artifacts": artifacts, "executable_sha256": sha(executable),
            "mojo": output("pixi", "run", "mojo", "--version"), "clang": output("clang", "--version").splitlines()[0],
            "logs": ["/tmp/moxi-i19-build.log", "/tmp/moxi-i19-canvas.log", "/tmp/moxi-i19-spatial.log"],
            "verification": {"canvas": "pass", "spatial": "pass", "method": "Normal executable modes, native pointer callbacks, field-editor insertion and AppKit key dispatch; cancellation fault events through the normal host event queue. Malformed record tests explicitly injected at the semantic boundary."},
            "limits": ["macOS arm64 only", "Experimental spatial renderer; no performance acceptance", "No physical keyboard/mouse or human usability evaluation", "No VoiceOver, other accessibility, IME or other-platform checks", "No persistence/reload or multi-object generalization", "Repository-wide suite skipped; only I19 and scoped native consumers checked"]}
        (DEST / "provenance.json").write_text(json.dumps(provenance, indent=2) + "\n")
    manifest = load_manifest(DEST / "manifest.json")
    (DEST / "index.html").write_text(render(manifest))
    print(f"Validated {len(manifest['slides'])} native frames; offline deck: {DEST.relative_to(ROOT)}/index.html")


if __name__ == "__main__":
    main()
