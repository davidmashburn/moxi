"""Validate and rebuild only the I19 offline slideshow."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
from demo_slideshows import load_manifest, render

directory = ROOT / "artifacts/demo-slideshows/i19-inspectable-interactions"
(directory / "index.html").write_text(render(load_manifest(directory / "manifest.json")))
