#!/usr/bin/env python3
"""Package captured P03 UI using the repository's slideshow contract."""
import hashlib
import json
from pathlib import Path
import struct
import subprocess
import sys

from verify import source_fingerprint, source_paths

ROOT = Path(__file__).resolve().parents[3]
DESTINATION = ROOT / "artifacts/demo-slideshows/fdg-notebook"
DIST = ROOT / "examples/fdg/dist/notebook"
sys.path.insert(0, str(ROOT))
from scripts.demo_slideshows import CaptureKind, Phase, load_manifest, render

STATES = (
    ("00-graph.png", Phase.INITIAL, CaptureKind.BROWSER, "One graph defined in JupyterLab", "Run all cells in a fresh local Python kernel", "Five synthetic nodes and five links feed both helpers"),
    ("01-svg.png", Phase.INITIAL, CaptureKind.BROWSER, "Actual JupyterLab static SVG output", "Render the graph with render_svg and IPython.display.SVG", "All five labels are readable, including SVG & μ"),
    ("02-native.png", Phase.INTERACTION, CaptureKind.NATIVE, "Live native content view; excludes window chrome", "Launch twice; execute the computation cell while both viewers remain open", "The same five-node graph renders in the compiled AppKit viewer"),
    ("03-error.png", Phase.RECOVERY, CaptureKind.BROWSER, "Compiled diagnostic with an actionable repair", "Try a link whose target is missing", "Unknown link endpoint: Data -> missing; replace it with an existing ID"),
    ("04-reopen-native.png", Phase.RESULT, CaptureKind.NATIVE, "Reopened native content view", "Close both viewers through performClose, verify exit 0, then reopen", "The original valid graph renders again in a fresh process"),
    ("05-restart-native.png", Phase.RECOVERY, CaptureKind.NATIVE, "Native content view after kernel restart", "Restart the test kernel, verify old globals are absent, and rerun every cell", "A new viewer renders the reconstructed graph; final cleanup reaps it"),
    ("06-restart.png", Phase.RESULT, CaptureKind.BROWSER, "JupyterLab restart and Run All completed", "Use Kernel → Restart Kernel and Run All Cells and confirm Restart", "Eight code cells finish in a new kernel PID, including reopen and final cleanup"),
)


def main():
    native = json.loads((DIST / "evidence.json").read_text())
    frontend = json.loads((DIST / "frontend-evidence.json").read_text())
    assert native["source_sha256"] == source_fingerprint(), "Source changed: rerun verify.py"
    for key, path in (
        ("notebook_sha256", ROOT / "examples/fdg/entrypoints.ipynb"),
        ("capture_script_sha256", Path(__file__).with_name("capture_frontend.py")),
    ):
        assert frontend[key] == hashlib.sha256(path.read_bytes()).hexdigest(), "Frontend source changed: rerun capture_frontend.py"
    assert native["binary_sha256"] == hashlib.sha256((ROOT / "examples/fdg/dist/moxi-fdg").read_bytes()).hexdigest(), "Binary changed: rerun verify.py"
    slides = []
    for name, phase, kind, caption, action, expected in STATES:
        png = (DESTINATION / name).read_bytes()
        dimensions = list(struct.unpack(">II", png[16:24]))
        slides.append(dict(image=name, phase=phase, capture_kind=kind, dimensions=dimensions,
                           scale=2 if kind == CaptureKind.NATIVE else 1,
                           caption=caption, action=action, expected=expected,
                           sha256=hashlib.sha256(png).hexdigest()))
    revision = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    dirty = bool(subprocess.check_output(["git", "status", "--porcelain", "--", *[str(p.relative_to(ROOT)) for p in source_paths()]], cwd=ROOT, text=True))
    provenance = dict(base_revision=revision, uncommitted_changes=dirty,
                      source_sha256=native["source_sha256"], binary_sha256=native["binary_sha256"],
                      note="Source inputs include native implementation, notebook, capture/check scripts and pinned dependencies; generated evidence and documentation are excluded from the dirty check.")
    manifest = dict(version=1, demo_id="fdg-notebook", title="One graph in Jupyter and native Moxi",
        scenario="P03 local Python notebook: graph/SVG, nonblocking native viewer, actionable error, close/reopen and kernel restart. Native frames are live content-view captures with test-only injection, not desktop/compositor or physical-input acceptance.",
        revision=revision, host=native["versions"]["platform"],
        backend=f"JupyterLab {native['versions']['JupyterLab']} / Chrome {frontend['browser']}; AppKit cacheDisplay content view",
        scale=1, fixture="Five nodes: Data, Python, Mojo, Moxi, SVG & μ; five links; source SHA-256 " + native["source_sha256"],
        reproduce="From repository root: bash examples/fdg/scripts/build.sh; install optional notebook/requirements-capture.txt; run examples/fdg/.venv-notebook/bin/python examples/fdg/notebook/verify.py, capture_frontend.py, then gallery.py (each at that same notebook/ path). See README.md for exact commands.",
        source_provenance=provenance, versions=native["versions"],
        verification=dict(kernel_rounds=[{k: v for k, v in r.items() if k != "kernel_pid"} for r in native["rounds"]],
                          frontend={k: v for k, v in frontend.items() if k != "kernel_pids"},
                          kernel_restart_changed_pid=True,
                          skipped=["actual remote kernel", "VoiceOver (paused)", "physical input", "independent human usability", "desktop compositor/window chrome", "other platforms/frontends"]),
        slides=slides)
    path = DESTINATION / "manifest.json"
    path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    validated = load_manifest(path)
    (DESTINATION / "index.html").write_text(render(validated))
    print(f"Validated {len(slides)} real UI captures; generated {DESTINATION / 'index.html'}")


if __name__ == "__main__":
    main()
