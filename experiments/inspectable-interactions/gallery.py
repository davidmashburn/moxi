"""Validate and rebuild only the I19 offline slideshow."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
from demo_slideshows import load_manifest, render

directory = ROOT / "artifacts/demo-slideshows/i19-inspectable-interactions"
manifest = load_manifest(directory / "manifest.json")
for slide in manifest["slides"]:
    slide["data_url"] = slide["image"]
(directory / "index.html").write_text(render(manifest))
