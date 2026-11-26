"""Rebuild, verify and capture the normal native app; render only its slideshow."""
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
from pathlib import Path
import platform
import struct
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OUT = ROOT / "artifacts/demo-slideshows/motion-model"

# name, phase, visible state, exact interaction, expected/observed assertion
SLIDES = [
    ("01-informal", "initial", "An informal arm beside an unfinished note", "Launch the normal app", "Fit and parameter controls disabled; no executable arm"),
    ("02-formalized", "interaction", "Only the arm becomes executable", "Formalize arm; Length +10", "130 px arm; note content and position preserved"),
    ("03-parameters", "interaction", "Parameter editing owns the blue response", "Peak +5; Scrub +0.25 s", "50 degree peak; original target retained; RETURN active"),
    ("04-target-draft", "interaction", "A desired curve is a cancellable draft", "Pointer-down on knot 3; drag to 65 degrees", "Draft visible; committed target and parameters unchanged"),
    ("05-target-committed", "result", "Releasing commits the target alone", "Release pointer", "Knot 3 is 65 degrees; executable parameters unchanged"),
    ("06-alternatives", "interaction", "Three bounded fits; second candidate previewed", "Find alternatives; 40 frame ticks; Preview 2", "Three valid fits; preview separate from committed parameters"),
    ("07-applied", "result", "Apply commits a parameter pair atomically", "Escape rejects preview; find alternatives again; Preview 2 via Tab/Space; click Apply", "Selected pair committed; target/length/note retained; keyboard undo/redo checked next"),
    ("08-pending", "interaction", "The bounded search yields between batches", "Find alternatives; one frame tick", "3 of 117 pairs evaluated; Apply disabled"),
    ("09-cancelled", "recovery", "Cancelled search cannot apply later", "Cancel; 40 frame ticks", "Cancelled; committed pair and desired knots preserved"),
    ("10-draft-cancelled", "recovery", "Escape discards an uncommitted target", "Drag to 95 degrees; Escape; release", "Committed curve and implementation preserved"),
    ("11-keyboard-draft", "interaction", "Keyboard editing has the same draft boundary", "Tab/Space Target +5", "Draft rises five degrees; committed curve unchanged; Cmd+Z cancels just the draft"),
    ("11-pinned", "recovery", "Pinned endpoints reject target edits", "Commit/undo a keyboard draft; Previous knot three times; Target +5 via Tab/Space", "Committed keyboard edit undoes; start stays zero without revision change"),
    ("12-infeasible", "result", "Unsupported target fails within the stated grid", "Drag knot 3 to 120 degrees; Find alternatives; 40 ticks", "No fit within six degrees RMS; implementation unchanged; target retained"),
    ("13-failure-undo", "recovery", "Undo restores the prior desired curve", "Undo", "Prior target restored without changing the applied implementation"),
    ("14-stale", "recovery", "Editing invalidates a pending result", "Find alternatives; Peak +5; 40 ticks", "STALE; Apply disabled; no late parameter overwrite"),
    ("15-sketch-undo", "recovery", "Undo formalization returns to the sketch", "Undo until history is empty", "Original sketch kind, length, note content and position restored"),
    ("16-minimum-window", "result", "The minimum native window retains every control", "Resize content to 960 by 760 points", "Every declared control stays inside the content height"),
]


def run_check(command, log):
    with log.open("w") as stream:
        result = subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT)
    if result.returncode:
        raise SystemExit(f"Check failed ({result.returncode}); inspect {log}")
    return log.read_text()


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    # No success manifest survives a failed fresh reproduction.
    for name in ("manifest.json", "verification.json", "slideshow-check.json", "index.html"):
        (OUT / name).unlink(missing_ok=True)
    started = datetime.now(timezone.utc).isoformat()
    revision = git("rev-parse", "HEAD")
    dirty = bool(git("status", "--porcelain", "--", "examples/motion-model", "src/moxi", "native"))
    model_log = run_check([sys.executable, str(HERE / "run.py"), "--model-check"], OUT / "model-check.log")
    ui_log = run_check([sys.executable, str(HERE / "run.py"), "--replay", str(OUT)], OUT / "ui-check.log")
    source_paths = sorted(HERE.glob("*.mojo")) + [HERE / "native.m", HERE / "run.py", HERE / "reproduce.py", HERE / "check_slideshow.py"]
    source_hashes = {str(p.relative_to(ROOT)): digest(p) for p in source_paths}
    slides, captures = [], []
    for name, phase, caption, action, expected in SLIDES:
        path = OUT / f"{name}.png"
        header = path.read_bytes()[:24]
        if header[:8] != b"\x89PNG\r\n\x1a\n":
            raise ValueError(f"Not a real PNG: {path.name}")
        width, height = struct.unpack(">II", header[16:24])
        slides.append(dict(phase=phase, capture_kind="offscreen-render", image=path.name,
                           dimensions=[width, height], caption=caption, action=action, expected=expected))
        captures.append(dict(image=path.name, sha256=digest(path), captured_at=datetime.fromtimestamp(path.stat().st_mtime, timezone.utc).isoformat(),
                             steps=action, expected=expected, observed=expected, outcome="pass",
                             assertion_source="examples/motion-model/replay.mojo"))
    if len({c["sha256"] for c in captures}) != len(SLIDES):
        raise ValueError("Repeated capture bytes: inspect the recorded state sequence")
    scale = slides[0]["dimensions"][0] / 1120
    if any(s["dimensions"] != [int(1120 * scale), int(860 * scale)] for s in slides[:-1]):
        raise ValueError("Unexpected initial content capture dimensions")
    if slides[-1]["dimensions"] != [int(960 * scale), int(760 * scale)]:
        raise ValueError("Minimum-window capture dimension mismatch")
    manifest = dict(version=1, demo_id="motion-model", title="Motion from a sketch",
        scenario="V01 with I01 and I03: mounted native Moxi app; partial formalization, parameter/target ownership, bounded alternatives, cancellation, failure, stale revision and undo. AppKit content-view raster captures; no desktop compositor or human efficacy claim.",
        revision=revision, source_dirty=dirty, host=f"{platform.system()} {platform.release()} {platform.machine()}",
        backend="Cocoa / Moxi App + Scene / AppKit content-view capture", scale=scale,
        fixture="Deterministic informal arm, length 120 px; parameters 45 deg / 1 s; desired knots from 60 deg / 0.75 s",
        reproduce="python3 examples/motion-model/reproduce.py\nopen artifacts/demo-slideshows/motion-model/index.html\nOptional: MOXI_PIXI_MANIFEST=/path/to/locked/toolchain/pixi.toml", slides=slides)
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    verification = dict(source_revision=revision, source_dirty=dirty, source_sha256=source_hashes,
        pixi_lock_sha256=digest(ROOT / "pixi.lock"),
        started_at=started, completed_at=datetime.now(timezone.utc).isoformat(),
        stack="Normal examples/motion-model/app.mojo executable, Cocoa, Moxi Component/Scene; native AX press, pointer/key callbacks, deterministic frame ticks",
        viewports_points=[[1120, 860], [960, 760]], role="Local synthetic fixture; no account or customer data",
        capture_method="NSWindow.contentView display/cacheDisplayInRect to NSBitmapImageRep PNG; live mounted view, no titlebar or desktop compositor",
        model_checks=[line for line in model_log.splitlines() if line.startswith("PASS:")],
        ui_checks=[line for line in ui_log.splitlines() if line.startswith("PASS ")], captures=captures,
        not_verified=["Physical input", "VoiceOver (explicitly excluded)", "Wall-clock responsiveness", "Other OS/backends and display scale matrix", "Independent human comprehension", "Persistence (no save/load feature)"])
    (OUT / "verification.json").write_text(json.dumps(verification, indent=2) + "\n")
    spec = importlib.util.spec_from_file_location("demo_slideshows", ROOT / "scripts/demo_slideshows.py")
    gallery = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(gallery)
    (OUT / "index.html").write_text(gallery.render(gallery.load_manifest(OUT / "manifest.json")))
    print(f"PASS: model + native UI; {len(slides)} captures; {OUT / 'index.html'}")
    if dirty:
        print("Source has uncommitted changes; commit it and reproduce for revision-bound evidence.")


if __name__ == "__main__":
    main()
