#!/usr/bin/env python3
"""Build, replay and publish only this native demo's local evidence folder."""
from enum import Enum
from pathlib import Path
import hashlib
import importlib.util
import json
import math
import platform
import struct
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / "artifacts/demo-slideshows/spatial-explorer"


class Phase(str, Enum):
    INITIAL = "initial"
    INTERACTION = "interaction"
    RESULT = "result"
    RECOVERY = "recovery"


STATES = [
    ("01-initial", Phase.INITIAL, "Generated geometry through public Mojo", "Launch native explorer", "Three generated surfaces, stable IDs, world anchor, outline and inspector"),
    ("02-parameter", Phase.RESULT, "Asynchronous parameter result", "Activate Parameter +0.12; await current completion", "Actual vertices change; requested and displayed parameters agree"),
    ("03-camera", Phase.INTERACTION, "Orbit with retained geometry", "Drag Orbit from (600,350) to (660,375)", "Camera changes; zero mesh uploads or control rebuilds during drag"),
    ("04-pick-annotation", Phase.RESULT, "Ray selection and projected annotation", "Select; click the projected center of object 202", "Nearest triangle selects a stable ID; inspector and bounding outline agree"),
    ("05-orthographic", Phase.RESULT, "Orthographic projection", "Toggle projection", "Shared projection changes rendering, rays, handles and anchor positions"),
    ("06-slow-responsive", Phase.INTERACTION, "Navigate while geometry is pending", "Request a 700ms update, supersede it, then press Right in viewport", "Camera advances using the last accepted mesh; requested and displayed values differ"),
    ("07-stale-rejected", Phase.RECOVERY, "Stale completion rejected", "Poll until first old revision completes while newer work is pending", "Rejected count increases without publishing old geometry"),
    ("08-axis-preview", Phase.INTERACTION, "X axis preview", "Fit, select 101, drag projected X handle 50 points", "Inspector and bounds show preview; committed history unchanged until pointer up"),
    ("09-plane-preview", Phase.INTERACTION, "XY plane preview", "Drag plane handle (+25,-20) points", "Two world components change through the same operation validator"),
    ("10-rotation-preview", Phase.INTERACTION, "Z rotation preview", "Drag rotation ring (-25,-35) points", "Preview rotates geometry and bounds around selected pivot"),
    ("11-scale-preview", Phase.INTERACTION, "Uniform scale preview", "Drag scale handle (+15,-15) points", "Uniform scale preview; one commit on pointer up"),
    ("12-snap-preview", Phase.INTERACTION, "Grid snapping", "Enable snap; drag Y handle -37 points", "Translation delta quantized to 0.25 world units; rotation uses 15 degrees"),
    ("13-cancel", Phase.RECOVERY, "Cancel restores committed document", "Escape during snapped preview", "Preview disappears without a history entry"),
    ("14-numeric-keyboard", Phase.RESULT, "Native numeric field and keyboard operation", "Enter 0.75 through native text callback, Enter, Escape, Up", "Numeric and key routes use the same validated operation and shared history"),
    ("15-undo", Phase.RECOVERY, "Shared undo", "Undo last keyboard operation", "Prior committed transform restored; parameter edits share this history"),
    ("16-disposed", Phase.RECOVERY, "Explicitly disposed viewport", "Dispose resources", "Unavailable message; geometry image removed and input capture retired"),
    ("17-recreated", Phase.RECOVERY, "Recreate under a new generation", "Recreate and wait for accepted generation", "Retained document and camera render again; old work cannot resurrect resources"),
]


def run(command, log):
    started = time.perf_counter()
    with open(log, "w") as stream:
        subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT,
                       check=True, timeout=180)
    return time.perf_counter() - started


def sha(data):
    return hashlib.sha256(data).hexdigest()


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    build_seconds = run(["bash", "examples/spatial-explorer/build.sh"], "/tmp/moxi-d06-gallery-build.log")
    run([str(ROOT / "dist/spatial-explorer/explorer"), "--replay", str(DEST)], "/tmp/moxi-d06-replay.log")
    # Include direct/transitive native and Mojo source dependencies plus this
    # recipe. Hashes complement HEAD: all implementation is intentionally local.
    paths = set()
    for directory in ("examples/spatial-explorer", "native/spatial", "src/moxi_spatial", "src/moxi", "tests/spatial"):
        paths.update(p for p in (ROOT / directory).rglob("*") if p.suffix in {".m", ".h", ".hpp", ".cpp", ".mojo", ".sh", ".py", ".md"})
    for name in ("native/macos_window.m", "native/macos_window_state.h", "native/macos_composition.h", "native/macos_composition.inc", "native/macos_metal.m", "native/macos_text.m", "native/macos_paragraph.h", "scripts/demo_slideshows.py", "pixi.lock", "pixi.toml"):
        paths.add(ROOT / name)
    files = {str(p.relative_to(ROOT)): sha(p.read_bytes()) for p in sorted(paths)}
    fingerprint = sha(json.dumps(files, sort_keys=True).encode())
    slides = []
    for name, phase, caption, action, expected in STATES:
        data = (DEST / f"{name}.png").read_bytes()
        if data[:8] != b"\x89PNG\r\n\x1a\n":
            raise ValueError(f"Invalid native PNG: {name}")
        slides.append(dict(scenario_id=name, phase=phase.value, capture_kind="offscreen-render",
                           image=f"{name}.png", dimensions=list(struct.unpack(">II", data[16:24])),
                           caption=caption, action=action, expected=expected, png_sha256=sha(data)))
    revision = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    dirty = subprocess.check_output(["git", "status", "--porcelain", "--untracked-files=all", "--", *files], cwd=ROOT, text=True).splitlines()
    manifest = dict(version=1, demo_id="spatial-explorer", title="D06 — native geometry explorer / S1 + S2",
                    scenario="Real Moxi AppKit+Metal content captured with cacheDisplay. Synthetic native event-queue replay; offscreen-render, not compositor/native-window or human input evidence. Experimental CPU readback; no production renderer or performance acceptance claim. VoiceOver paused.",
                    revision=revision, host=f"macOS {platform.mac_ver()[0]} / {platform.machine()}",
                    backend="Moxi AppKit + bounded Metal depth bridge + public owner-scoped composition",
                    scale=slides[0]["dimensions"][0]/1100,
                    fixture=f"3 generated surfaces; 13,680 expanded vertices; source SHA-256 {fingerprint}; uncommitted scoped source: {bool(dirty)}",
                    reproduce="python3 examples/spatial-explorer/gallery.py", slides=slides)
    (DEST / "manifest.json").write_text(json.dumps(manifest, indent=2)+"\n")
    executable = ROOT / "dist/spatial-explorer/explorer"
    provenance = dict(base_revision=revision, uncommitted_source=bool(dirty), scoped_git_status=dirty,
                      source_sha256=fingerprint, files=files,
                      captured_at=time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                      compiler=subprocess.check_output(["clang", "--version"], text=True).splitlines()[0],
                      mojo=subprocess.check_output(["pixi", "run", "mojo", "--version"], cwd=ROOT, text=True).strip(),
                      sdk=subprocess.check_output(["xcrun", "--show-sdk-version"], text=True).strip(),
                      executable_sha256=sha(executable.read_bytes()), executable_bytes=executable.stat().st_size,
                      build_wall_seconds=build_seconds)
    (DEST / "provenance.json").write_text(json.dumps(provenance, indent=2)+"\n")
    lines = Path("/tmp/moxi-d06-replay.log").read_text().splitlines()
    samples = [list(map(float, line.split()[1:])) for line in lines if line.startswith("TIMING ")]
    if len(samples) != 60 or not any(line.startswith("PASS native public Mojo replay") for line in lines):
        raise ValueError("Incomplete replay / measurement")
    metrics = {}
    for index, name in enumerate(("process_cpu", "encode_wall", "command_wait_wall", "gpu_command", "readback_wall", "publication_wall", "frame_to_host_image_wall")):
        values = sorted(row[index] for row in samples if math.isfinite(row[index]))
        metrics[name] = {"samples": len(values), **{key: values[max(0, math.ceil(len(values)*q)-1)] if values else None for key,q in (("p50",.5),("p95",.95),("p99",.99),("worst",1))}}
    timing = dict(units="milliseconds", fixture="60 consecutive camera-only frames after replay; no sustained/thermal or input-to-photon measurement",
                  viewport_points=[620,480], viewport_pixels=[round(620*manifest["scale"]),round(480*manifest["scale"])],
                  geometry_vertices=13680, quantile="nearest rank; p99 equals maximum for 60 samples",
                  metrics=metrics, camera_mesh_uploads=0, camera_derived_mesh_builds=0, camera_control_builds=0,
                  idle_submissions=0, idle_seconds=.3, samples=samples,
                  limits="CPU is process user+system time, potentially includes worker activity. GPU is command-buffer timestamps; wait includes queue and synchronization. Publication copies RGBA to owner-scoped NSImage and composes a draw slot. Total ends before AppKit end-frame/compositor/scanout. Metrics overlap; do not sum CPU/GPU/wait. No production/60Hz acceptance conclusion.")
    (DEST / "timing.json").write_text(json.dumps(timing, indent=2, allow_nan=False)+"\n")
    spec = importlib.util.spec_from_file_location("demo_slideshows", ROOT / "scripts/demo_slideshows.py")
    gallery = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(gallery)
    (DEST / "index.html").write_text(gallery.render(gallery.load_manifest(DEST / "manifest.json")))
    print(f"PASS: {len(slides)} native offscreen captures; scoped source {fingerprint}; timing.json / provenance.json / index.html")


if __name__ == "__main__":
    main()
