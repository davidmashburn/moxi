"""Validate and build this gallery without touching the shared slideshow index."""
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[2] / "scripts"))
from demo_slideshows import load_manifest, render

if __name__ == "__main__":
    manifest = load_manifest(HERE / "manifest.json")
    (HERE / "index.html").write_text(render(manifest))
    print(f"Built {len(manifest['slides'])} slides.")
