#!/usr/bin/env python3
"""Check regenerated D04/D07 evidence; never creates captures or promotes a gate."""

import argparse
import hashlib
import importlib.util
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GALLERIES = ROOT / "artifacts/demo-slideshows"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_module(name, relative):
    spec = importlib.util.spec_from_file_location(name, ROOT / relative)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def require(condition, message):
    if not condition:
        raise ValueError(message)


def check(revision):
    expected = subprocess.check_output(
        ["git", "rev-parse", revision], cwd=ROOT, text=True
    ).strip()
    head = subprocess.check_output(
        ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True
    ).strip()
    require(head == expected, "Checkout does not match the requested review revision")
    gallery = load_module("demo_slideshows", "scripts/demo_slideshows.py")
    mindmap = load_module("mindmap_manifest", "scripts/mindmap/manifest.py")
    assembly = load_module("assembly_gallery", "examples/spatial-assembly/gallery.py")
    includes = {
        str(p.relative_to(ROOT)): sha(p)
        for p in sorted((ROOT / "native").rglob("*.inc"))
    }
    result = {"revision": head, "demos": {}}
    for demo, source_now, count, executable in (
        ("mindmap", mindmap.snapshot()["source_sha256"], 20, "dist/moxi-mindmap"),
        ("spatial-assembly", assembly.source_snapshot()[1], 14,
         "dist/spatial-assembly/assembly"),
    ):
        folder = GALLERIES / demo
        # Existing schema tooling checks containment, PNG signature/dimensions,
        # required metadata and all four scenario phases.
        manifest = gallery.load_manifest(folder / "manifest.json")
        captured = manifest["revision"]
        require(re.fullmatch(r"[0-9a-f]{40}", captured),
                f"{demo}: capture revision must be an immutable Git commit")
        require(len(manifest["slides"]) == count, f"{demo}: incomplete sequence")
        if demo == "mindmap":
            recorded = manifest["source_sha256"]
            require(not manifest["scoped_dirty_source"], f"{demo}: dirty capture source")
        else:
            provenance = json.loads((folder / "provenance.json").read_text())
            require(provenance["base_revision"] == captured, "D07 provenance revision mismatch")
            require(not provenance["uncommitted_source"], "Dirty D07 capture source")
            recorded = provenance["files"]
            fingerprint = hashlib.sha256(json.dumps(recorded, sort_keys=True).encode()).hexdigest()
            require(fingerprint == provenance["source_sha256"], "D07 aggregate hash mismatch")
            require(sha(ROOT / executable) == provenance["executable_sha256"],
                    "D07 executable changed after capture")
        require(recorded == source_now, f"{demo}: capture source inventory/hash mismatch")
        supplemental = {p: h for p, h in includes.items() if p not in recorded}
        sources = recorded | supplemental
        # A gallery may retain an earlier capture when all its recorded inputs
        # still match this checkout. Verify each capture against its own commit,
        # including native .inc files omitted by older capture recipes.
        for name, digest in sources.items():
            committed = subprocess.check_output(["git", "show", f"{captured}:{name}"], cwd=ROOT)
            require(hashlib.sha256(committed).hexdigest() == digest,
                    f"{demo}: source differs from reviewed Git blob: {name}")
        images = []
        for slide in manifest["slides"]:
            require(slide["capture_kind"] == gallery.CaptureKind.OFFSCREEN,
                    f"{demo}: unexpected capture kind")
            digest = sha(folder / slide["image"])
            recorded_digest = slide.get("sha256", slide.get("png_sha256"))
            require(digest == recorded_digest, f"{demo}: PNG SHA-256 mismatch: {slide['image']}")
            images.append(slide["image"])
        require(len(set(images)) == count, f"{demo}: duplicate frame references")
        result["demos"][demo] = {
            "capture_revision": captured,
            "resolved_frames": len(images), "images": images,
            "unreferenced_pngs": sorted(p.name for p in folder.glob("*.png")
                                       if p.name not in images),
            "recorded_source_files": len(recorded),
            "supplemental_source_sha256": supplemental,
            "sources_equal_reviewed_git_blobs": len(sources),
            "executable_sha256": sha(ROOT / executable),
        }
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--revision", default="HEAD", help="Expected review checkout revision; each capture retains its own immutable source revision")
    args = parser.parse_args()
    print(json.dumps(check(args.revision), indent=2))
