#!/usr/bin/env python3
"""Build/replay real native candidates, capture provenance, make only D05's gallery."""
from enum import Enum
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import platform
import struct
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / "artifacts/demo-slideshows/spatial-probe"
LOG_PREFIX = os.environ.get("MOXI_SPATIAL_LOG_PREFIX", "/tmp/d05")


class Phase(str, Enum):
    INITIAL = "initial"
    INTERACTION = "interaction"
    RESULT = "result"
    RECOVERY = "recovery"


STATES = [
    ("01-perspective", Phase.INITIAL, "Bridge • perspective", "Open the real Moxi window", "Depth-tested orange and blue cubes beside Moxi controls"),
    ("02-orbit-active", Phase.INTERACTION, "Camera drag in progress", "Deliver native mouse down and drag callbacks", "Changed view while capture remains active; no mesh upload"),
    ("02b-pan-dolly", Phase.RESULT, "Pan and dolly", "Deliver Shift-drag callbacks and a synthetic Moxi wheel packet", "Camera pans and moves closer without a mesh upload; wheel hardware is not tested"),
    ("03-orthographic", Phase.RESULT, "Bridge • orthographic", "Click Use orthographic", "Parallel projection of the same retained geometry"),
    ("04-clip-overlay", Phase.INTERACTION, "Scroll, clip and overlay", "Click Show overlay and Scroll / clip", "Image shifts up 72 logical points and clips; ordinary button remains above it"),
    ("05-control-focus", Phase.RESULT, "Keyboard focus in ordinary controls", "Click overlay reset, then Tab from viewport to camera control", "Button focus ring; arrow input leaves camera unchanged"),
    ("06-resize", Phase.RESULT, "Narrow live window", "Resize NSWindow content to 680 × 480 points", "Target pixel size follows viewport size and backing scale"),
    ("07-disposed", Phase.RECOVERY, "Viewport resources disposed", "Click Dispose resources", "Scene removed; ordinary UI remains available; stale generation rejected"),
    ("08-recreated", Phase.RECOVERY, "New resource generation", "Click Recreate resources", "Scene returns with retained camera and a new generation"),
    ("09-focus-recovery", Phase.RECOVERY, "Cancel capture and restore camera focus", "Open second owner, cancel first owner's drag with Escape, close second, press Right", "First owner camera responds; second owner's image identity was untouched"),
    ("10-bridge-comparison", Phase.RESULT, "Comparison • bridge", "Restore wide layout and reset camera, clip and overlay", "Canonical perspective scene before renderer switch"),
    ("11-adapter-perspective", Phase.RESULT, "Comparison • SceneKit", "Click Switch renderer", "The same fixture through the actual SceneKit renderer"),
    ("12-adapter-orthographic", Phase.RESULT, "Adapter • orthographic", "Click Use orthographic", "SceneKit camera uses shared view parameters"),
    ("13-adapter-clip", Phase.INTERACTION, "Adapter • host composition", "Show overlay and scroll the SceneKit image", "Same host clipping and overlay path as the bridge"),
    ("14-adapter-recreated", Phase.RECOVERY, "Adapter • recreated", "Dispose and recreate the SceneKit adapter", "Scene restored under new resource generation"),
]


def run(command, log):
    start = time.perf_counter()
    with open(log, "w") as stream:
        subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT, check=True, timeout=180)
    return time.perf_counter() - start


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    build_seconds = {}
    for candidate in ("bridge", "comparison"):
        build_seconds[candidate] = run(["bash", "experiments/spatial-probe/build.sh", candidate], f"{LOG_PREFIX}-build-{candidate}.log")
    run([str(ROOT / "dist/spatial-probe/comparison"), "--replay", str(DEST)], f"{LOG_PREFIX}-replay.log")
    source_paths = sorted((ROOT / "experiments/spatial-probe").glob("*"))
    source_paths = [p for p in source_paths if p.suffix in (".m", ".h", ".sh", ".py")]
    source_paths += [ROOT / p for p in ("native/macos_metal.m", "native/macos_window.m", "native/macos_window_state.h", "native/macos_paragraph.h", "scripts/demo_slideshows.py")]
    fingerprint = hashlib.sha256()
    files = {}
    for path in source_paths:
        relative = str(path.relative_to(ROOT))
        data = path.read_bytes()
        fingerprint.update(relative.encode() + b"\0" + data)
        files[relative] = hashlib.sha256(data).hexdigest()
    slides = []
    for name, phase, caption, action, expected in STATES:
        path = DEST / (name + ".png")
        data = path.read_bytes()
        if data[:8] != b"\x89PNG\r\n\x1a\n":
            raise ValueError(f"Invalid capture: {path}")
        dimensions = list(struct.unpack(">II", data[16:24]))
        slides.append(dict(scenario_id=name, backend="SceneKit adapter" if int(name[:2]) >= 11 else "Metal bridge extension", phase=phase.value, capture_kind="offscreen-render", image=path.name,
            dimensions=dimensions, caption=caption, action=action, expected=expected,
            png_sha256=hashlib.sha256(data).hexdigest()))
    revision = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    manifest = dict(version=1, demo_id="spatial-probe", title="Spatial S0 — two executable renderers",
        scenario="Actual NSWindow content-view cacheDisplay captures of the Moxi native host. Native callbacks are scripted; excludes window chrome, compositor, physical input and scanout. Live content rendered offscreen via AppKit cacheDisplay; not a compositor screenshot. VoiceOver remains paused.",
        revision=revision, host="macOS " + platform.mac_ver()[0] + " / " + platform.machine(),
        backend="Moxi AppKit host + Metal bridge depth extension / optional SceneKit",
        scale=slides[0]["dimensions"][0] / 900, fixture="Two cubes, 24 triangles, linear vertex colors; source SHA-256 " + fingerprint.hexdigest(),
        reproduce="python3 experiments/spatial-probe/gallery.py", slides=slides)
    (DEST / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    footprints = {}
    for candidate in ("bridge", "comparison"):
        path = ROOT / "dist/spatial-probe" / candidate
        footprints[candidate] = dict(bytes=path.stat().st_size, sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
            build_wall_seconds=build_seconds[candidate], linked_libraries=subprocess.check_output(["otool", "-L", str(path)], text=True).splitlines()[1:])
    dirty = bool(subprocess.check_output(
        ["git", "status", "--porcelain", "--untracked-files=all", "--", *files],
        cwd=ROOT, text=True).strip())
    provenance = dict(source_sha256=fingerprint.hexdigest(), files=files, base_revision=revision,
        uncommitted_source=dirty, captured_at=time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        sdk=subprocess.check_output(["xcrun", "--show-sdk-version"], text=True).strip(),
        compiler=subprocess.check_output(["clang", "--version"], text=True).splitlines()[0],
        footprints=footprints)
    (DEST / "provenance.json").write_text(json.dumps(provenance, indent=2) + "\n")
    spec = importlib.util.spec_from_file_location("demo_slideshows", ROOT / "scripts/demo_slideshows.py")
    slideshows = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(slideshows)
    # Avoid rewriting another worker's gallery or the shared master index.
    validated = slideshows.load_manifest(DEST / "manifest.json")
    (DEST / "index.html").write_text(slideshows.render(validated))
    print(f"PASS: {len(slides)} genuine native captures; source SHA-256 {fingerprint.hexdigest()}")


if __name__ == "__main__":
    main()
