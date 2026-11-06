#!/usr/bin/env python3
"""Reproduce only D07's real native captures, source hashes and timing evidence."""
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
DEST = ROOT / "artifacts/demo-slideshows/spatial-assembly"
LOG = Path("/tmp/moxi-d07-gallery-replay.log")


class Phase(str, Enum):
    INITIAL = "initial"
    INTERACTION = "interaction"
    RESULT = "result"
    RECOVERY = "recovery"


STATES = [
    ("01-initial", Phase.INITIAL, "One assembly, two public views", "Launch the assembly inspector", "Four stable IDs, a three-level hierarchy, perspective and orthographic targets sharing one geometry buffer"),
    ("02-linked-views", Phase.INTERACTION, "Independent camera, shared document", "Orbit only the perspective view", "Right camera revision remains unchanged; both views retain the same document and geometry"),
    ("03-hierarchy-preview", Phase.INTERACTION, "Parent transform preview", "Select Arm in the hierarchy; drag its X handle in the right view", "Arm and Joint move together in both views; history remains unchanged"),
    ("04-transform-commit", Phase.RESULT, "Commit hierarchy transform", "Release the Arm drag", "One history entry; child local coordinates account for parent scale and Joint follows the composed transform"),
    ("05-measurement", Phase.RESULT, "Shared surface measurement", "Pick Carrier in perspective and Arm in orthographic", "Two local surface anchors produce the same world distance and cyan segment in both views"),
    ("06-clipping", Phase.RESULT, "Shared clipping plane", "Enable the X >= 0 plane", "Both targets omit the same half-space; clipped triangles also drive picking; no cap surface"),
    ("07-plane-moved", Phase.INTERACTION, "Move the clipping plane", "Advance the plane offset by 0.25", "Both views update from one derived geometry rebuild/upload"),
    ("08-clip-undo", Phase.RECOVERY, "Shared clipping undo", "Undo both the offset edit and enabling the plane", "Unclipped geometry returns in both views"),
    ("09-cancel-preview", Phase.INTERACTION, "Uncommitted transform", "Drag the Arm X handle again", "Both views display a shared preview before commit"),
    ("10-cancelled", Phase.RECOVERY, "Cancel without history", "Send Escape through the native event queue", "Committed transforms and history are restored in both views"),
    ("11-numeric", Phase.RESULT, "Native numeric input", "Enter 0.25 via the native text callback, press Enter then Escape", "Same public operation validator and shared history as pointer manipulation"),
    ("12-stale-rejected", Phase.RECOVERY, "Stale worker result rejected", "Undo numeric edit; request a delayed mesh, supersede it and poll its old completion", "Old completion is rejected; both views retain the last accepted mesh while the latest work remains pending"),
    ("13-right-disposed", Phase.RECOVERY, "Independent view disposal", "Dispose the right view", "Right image is removed; left target, document and GPU geometry remain usable"),
    ("14-recovered", Phase.RECOVERY, "Recreate the right view", "Recreate under its existing owner", "New right target consumes the surviving GPU geometry without another upload"),
]


def sha(data):
    return hashlib.sha256(data).hexdigest()


def run(command, log):
    started = time.perf_counter()
    with open(log, "w") as output:
        subprocess.run(command, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT,
                       check=True, timeout=240)
    return time.perf_counter() - started


def distribution(rows):
    result = {}
    for column, name in enumerate(("process_cpu", "encode_wall", "command_wait_wall", "gpu_command", "readback_wall", "publication_wall", "frame_to_host_image_wall")):
        values = sorted(row[column] for row in rows)
        if not values or not all(math.isfinite(v) and v >= 0 for v in values):
            raise ValueError("Missing or invalid timing samples")
        result[name] = dict(samples=len(values), **{key: values[math.ceil(len(values)*q)-1] for key, q in (("p50", .5), ("p95", .95), ("p99", .99), ("worst", 1))})
    return result


def source_snapshot():
    paths = set()
    for directory in ("examples/spatial-assembly", "examples/spatial-explorer", "native/spatial", "src/moxi_spatial", "src/moxi", "tests/spatial"):
        paths.update(p for p in (ROOT / directory).rglob("*") if p.suffix in {".m", ".h", ".hpp", ".cpp", ".mojo", ".sh", ".py", ".md"})
    for name in ("native/macos_window.m", "native/macos_window_state.h", "native/macos_composition.h", "native/macos_composition.inc", "native/macos_metal.m", "native/macos_text.m", "native/macos_paragraph.h", "scripts/demo_slideshows.py", "pixi.lock", "pixi.toml"):
        paths.add(ROOT / name)
    files = {str(p.relative_to(ROOT)): sha(p.read_bytes()) for p in sorted(paths)}
    revision = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    return revision, files


def main():
    revision, files = source_snapshot()
    DEST.mkdir(parents=True, exist_ok=True)
    build_command = ["bash", "examples/spatial-assembly/build.sh"]
    replay_command = [str(ROOT / "dist/spatial-assembly/assembly"), "--replay", str(DEST)]
    build_seconds = run(build_command, "/tmp/moxi-d07-gallery-build.log")
    replay_seconds = run(replay_command, LOG)
    lines = LOG.read_text().splitlines()
    samples = [list(map(float, line.split()[1:])) for line in lines if line.startswith("TIMING ")]
    if len(samples) != 120 or not any(line.startswith("PASS assembly native public replay") for line in lines):
        raise ValueError("Incomplete native replay")
    if [row[0] for row in samples] != [0, 1] * 60:
        raise ValueError("Unexpected view timing order")
    reuse = next(list(map(int, line.split()[2:])) for line in lines if line.startswith("REUSE initial "))
    vertices, gpu_bytes, left_geometry, right_geometry, left_target, right_target = reuse
    if left_geometry != right_geometry or left_target == right_target or gpu_bytes != vertices * 32:
        raise ValueError("Geometry reuse contract failed")
    if source_snapshot() != (revision, files):
        raise ValueError("Source changed during native build/replay; recapture required")
    fingerprint = sha(json.dumps(files, sort_keys=True).encode())
    dirty = subprocess.check_output(["git", "status", "--porcelain", "--untracked-files=all", "--", *files], cwd=ROOT, text=True).splitlines()
    slides = []
    for name, phase, caption, action, expected in STATES:
        data = (DEST / f"{name}.png").read_bytes()
        if data[:8] != b"\x89PNG\r\n\x1a\n":
            raise ValueError(f"Invalid native PNG: {name}")
        slides.append(dict(scenario_id=name, phase=phase.value, capture_kind="offscreen-render",
                           image=f"{name}.png", dimensions=list(struct.unpack(">II", data[16:24])),
                           caption=caption, action=action, expected=expected, png_sha256=sha(data)))
    manifest = dict(version=1, demo_id="spatial-assembly", title="D07 — native assembly inspector / S3",
                    scenario="Real AppKit+Metal app content, cacheDisplay offscreen-render captures. Synthetic native event queue and native text callback replay; no physical input, human, IME, VoiceOver or compositor evidence. D05 performance/production gate remains OPEN.",
                    revision=revision, host=f"macOS {platform.mac_ver()[0]} / {platform.machine()}",
                    backend="Moxi AppKit + shared bounded Metal geometry + public owner-scoped copied-image composition",
                    scale=slides[0]["dimensions"][0] / 1200,
                    fixture=f"4 objects; 3 hierarchy levels; {vertices:,} shared expanded vertices; {gpu_bytes:,} GPU geometry bytes; source SHA-256 {fingerprint}; uncommitted scoped source: {bool(dirty)}",
                    reproduce="python3 examples/spatial-assembly/gallery.py", slides=slides)
    (DEST / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    executable = ROOT / "dist/spatial-assembly/assembly"
    provenance = dict(base_revision=revision, uncommitted_source=bool(dirty), scoped_git_status=dirty,
                      source_sha256=fingerprint, files=files,
                      captured_at=time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                      compiler=subprocess.check_output(["clang", "--version"], text=True).splitlines()[0],
                      mojo=subprocess.check_output(["pixi", "run", "mojo", "--version"], cwd=ROOT, text=True).strip(),
                      sdk=subprocess.check_output(["xcrun", "--show-sdk-version"], text=True).strip(),
                      executable_sha256=sha(executable.read_bytes()), executable_bytes=executable.stat().st_size,
                      build_command=build_command, replay_command=replay_command,
                      build_wall_seconds=build_seconds, replay_wall_seconds=replay_seconds,
                      logs=["/tmp/moxi-d07-gallery-build.log", str(LOG)], replay_log_sha256=sha(LOG.read_bytes()))
    (DEST / "provenance.json").write_text(json.dumps(provenance, indent=2) + "\n")
    per_view = {str(view): distribution([row[1:] for row in samples if row[0] == view]) for view in (0, 1)}
    paired = [[a+b for a, b in zip(samples[i][1:], samples[i+1][1:])] for i in range(0, 120, 2)]
    timing = dict(units="milliseconds", fixture="60 consecutive iterations, both cameras changed and both targets rendered synchronously; no sustained rate/thermal or input-to-photon measurement",
                  viewport_points=[440,390], viewport_pixels=[round(440*manifest["scale"]),round(390*manifest["scale"])],
                  initial_reuse=dict(expanded_vertices=vertices, gpu_geometry_bytes=gpu_bytes, left_geometry_id=left_geometry, right_geometry_id=right_geometry, left_target_id=left_target, right_target_id=right_target),
                  quantile="nearest rank; 60 samples per view/pair; p99 equals maximum", per_view=per_view, sequential_pair=distribution(paired),
                  camera_mesh_uploads=0, camera_derived_mesh_builds=0, camera_control_builds=0, idle_submissions=0, idle_seconds=.3,
                  samples=samples,
                  limits="CPU is process user+system time and can include worker activity. GPU uses command-buffer timestamps; wait includes queue/synchronization. Publication copies RGBA to owner-scoped NSImage and composes a draw slot. Total ends before AppKit end-frame/compositor/scanout. Sequential pair sums matching phases across two view calls, excluding inter-call/app overhead; it is not end-to-end frame time. Phases overlap; do not sum CPU/GPU/wait. Shared GPU bytes exclude two targets, depth textures, images and pipelines. D05 production/performance gate remains OPEN.")
    (DEST / "timing.json").write_text(json.dumps(timing, indent=2, allow_nan=False) + "\n")
    spec = importlib.util.spec_from_file_location("demo_slideshows", ROOT / "scripts/demo_slideshows.py")
    gallery = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(gallery)
    (DEST / "index.html").write_text(gallery.render(gallery.load_manifest(DEST / "manifest.json")))
    print(f"PASS: {len(slides)} native offscreen captures; source {fingerprint}; one geometry / two targets; 60 timing pairs")


if __name__ == "__main__":
    main()
