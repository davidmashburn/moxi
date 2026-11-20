#!/usr/bin/env python3
"""Run the published D08 gallery with a longer build bound and portable logs."""
from pathlib import Path
import hashlib
import importlib.util
import json
import shutil
import subprocess
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
COMMAND_TIMEOUT_SECONDS = 900


def main():
    spec = importlib.util.spec_from_file_location(
        "d08_published_capture", ROOT / "examples/spatial-world-panel/gallery.py")
    gallery = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(gallery)

    def run(command, log):
        start = time.perf_counter()
        with open(log, "w") as stream:
            subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT,
                           check=True, timeout=COMMAND_TIMEOUT_SECONDS)
        return time.perf_counter() - start

    # Only replace the subprocess time bound; retain all source/replay assertions.
    gallery.run = run
    gallery.main()
    logs = HERE / "review-logs"
    logs.mkdir(exist_ok=True)
    shutil.copyfile("/tmp/moxi-d08-gallery-build.log", logs / "build.log")
    shutil.copyfile("/tmp/moxi-d08-source-before.json", logs / "source-before.json")
    provenance = json.loads((HERE / "provenance.json").read_text())
    for index, evidence in enumerate(provenance["evidence"]):
        relative = f"review-logs/replay-{index}.log"
        shutil.copyfile(evidence["log"], HERE / relative)
        evidence["log"] = relative
    provenance["capture_tool"] = {
        "path": str(Path(__file__).resolve().relative_to(ROOT)),
        "sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        "command_timeout_seconds": COMMAND_TIMEOUT_SECONDS,
        "override": "Published run() timeout 240 -> 900 seconds; copy logs and normalize their paths",
    }
    (HERE / "provenance.json").write_text(json.dumps(provenance, indent=2) + "\n")
    manifest = json.loads((HERE / "manifest.json").read_text())
    manifest["reproduce"] = (
        "pixi install --locked && python3 artifacts/demo-slideshows/spatial-world-panel/capture.py")
    (HERE / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    spec = importlib.util.spec_from_file_location("d08_slideshow", ROOT / "scripts/demo_slideshows.py")
    slideshow = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(slideshow)
    (HERE / "index.html").write_text(slideshow.render(slideshow.load_manifest(HERE / "manifest.json")))


if __name__ == "__main__":
    main()
