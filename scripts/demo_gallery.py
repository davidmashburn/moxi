"""Catalog adapters and master navigation; historical captures are never modified."""

import base64
from dataclasses import dataclass
from enum import Enum
import html
from html.parser import HTMLParser
import json
import os
from pathlib import Path
import re
from urllib.parse import unquote, urlsplit

from demo_slideshows import capture_path, load_manifest, page, read_png, render

ROOT = Path(__file__).resolve().parents[1]


class GalleryFormat(str, Enum):
    STANDARD = "version-1"
    OSCILLATOR = "oscillator-list"
    MATRIX = "matrix-instrument"
    EQUATION = "equation-linkage-scenarios"
    GEOMETRY = "geometry-comparison"
    SWS4D = "sws4d-native"
    IMAGES = "image-comparison"
    EVIDENCE = "evidence-bundle"
    UNKNOWN = "unsupported"


@dataclass(frozen=True)
class Gallery:
    directory: Path
    format: GalleryFormat
    evidence: Path
    title: str = ""
    documentation: Path | None = None
    source_prefix: str | None = None
    images: tuple[str, ...] = ()
    deck_name: str = "index.html"
    catalog_id: str | None = None

    @property
    def demo_id(self):
        return self.catalog_id or self.directory.name


def discover(root):
    """One entry per resolved directory, including galleries linked by index.md."""
    root = root.resolve()
    entries = {}
    paths = set(root.glob("*/manifest.json"))
    markdown = root / "index.md"
    if markdown.is_file():
        for link in re.findall(r"\]\(([^)]+)\)", markdown.read_text()):
            if urlsplit(link).scheme:
                continue
            target = (root / unquote(urlsplit(link).path)).resolve()
            if target.is_relative_to(ROOT) and target.suffix == ".html":
                manifest = target.parent / "manifest.json"
                if manifest.is_file():
                    paths.add(manifest)
    for path in sorted(paths):
        # Classification is deliberately narrow: unknown formats remain visible failures.
        try:
            data = json.loads(path.read_text())
        except (ValueError, OSError):
            data = None
        kind = (GalleryFormat.STANDARD if isinstance(data, dict) and data.get("version") == 1
                else GalleryFormat.UNKNOWN)
        prefix, doc, title = None, None, ""
        if path == root / "oscillator/manifest.json" and isinstance(data, dict) and "version" not in data:
            kind, prefix = GalleryFormat.OSCILLATOR, "examples/oscillator"
            doc = ROOT / "examples/oscillator/README.md"
        if isinstance(data, dict) and "version" not in data:
            if path == root / "matrix-instrument/manifest.json":
                kind, prefix = GalleryFormat.MATRIX, "examples/matrix-instrument"
                title = "I02 matrix instrument"
            elif path == root / "i21-equation-linkage/manifest.json":
                kind, prefix = GalleryFormat.EQUATION, "examples/equation-linkage"
                title = "I21 equation and geometry linkage"
        if doc is None:
            # Return the actual filename: is_file() alone accepts wrong case on macOS.
            files = {child.name.casefold(): child for child in path.parent.iterdir() if child.is_file()}
            doc = next((files[name] for name in ("reproduce.md", "readme.md", "verification.md", "evidence.md", "review.md")
                        if name in files), None)
        if doc is None and path.parent.name.startswith("e01-"):
            doc = ROOT / "docs/plot-specialized-wave-a.md"
        if doc is None and path.parent.name.startswith(("e02-", "e03-")):
            doc = root / "plot-wave-b-c-review/REPRODUCE.md"
        if doc is None and isinstance(data, dict):
            references = re.findall(r"(?:docs|examples|experiments)/[\w./-]+\.md", str(data.get("reproduce", "")))
            doc = next((ROOT / name for name in references if (ROOT / name).is_file()), None)
        entries[path.parent] = Gallery(path.parent, kind, path, title, documentation=doc, source_prefix=prefix)
    # These producers publish evidence without a version-1 manifest. E06's overview
    # is navigation to its three families, not a fourth copy of their captures.
    custom = [
        ("e01-category-labels", GalleryFormat.IMAGES, "comparison.png", "E01 category labels and legends",
         "docs/plot-specialized-wave-a.md", None, ("comparison.png",)),
        ("e03-flow-calendar-followup", GalleryFormat.IMAGES, "results.json", "E03 chord, calendar and Sankey labels",
         "artifacts/demo-slideshows/e03-flow-calendar-followup/README.md", None,
         ("chord.png", "calendar_heatmap.png", "sankey.png")),
        ("sws4d-native", GalleryFormat.SWS4D, "native-replay.json", "P08 linked 4D native replay",
         "artifacts/demo-slideshows/sws4d-native/README.md", None, ()),
        ("plot-wave-b-c-review", GalleryFormat.EVIDENCE, "review.json", "E02/E03 historical comparison review",
         "artifacts/demo-slideshows/plot-wave-b-c-review/REPRODUCE.md", None, ()),
    ]
    for name in ("parallel", "bump", "arc-diagram"):
        custom.append((f"e06-{name}", GalleryFormat.GEOMETRY, "capture.json", f"E06 {name.replace('-', ' ')}",
                       "examples/catalog-remainder/README.md", None, ()))
    for name, kind, evidence, title, doc, prefix, images in custom:
        directory = root / name
        if directory.is_dir() and directory not in entries:
            entries[directory] = Gallery(directory, kind, directory / evidence, title,
                                         ROOT / doc, prefix, images)
    # The funnel comparison is linked by the existing master but has no manifest.
    funnel = ROOT / "examples/funnel/evidence"
    if markdown.is_file() and "examples/funnel/evidence/comparison.html" in markdown.read_text():
        entries.setdefault(funnel, Gallery(funnel, GalleryFormat.IMAGES, funnel / "comparison.html",
                           "E06 funnel", ROOT / "examples/funnel/README.md",
                           images=("inspector.png",), deck_name="comparison.html", catalog_id="funnel"))
    return sorted(entries.values(), key=lambda entry: entry.demo_id)


def evidence(entry):
    """Read each supported producer's own format without inventing slide semantics."""
    if entry.format is GalleryFormat.UNKNOWN:
        raise ValueError("unsupported manifest format; no deck certified")
    data = json.loads(entry.evidence.read_text()) if entry.evidence.suffix == ".json" else {}
    if not isinstance(data, dict):
        raise ValueError("evidence must be an object")
    if entry.format in (GalleryFormat.STANDARD, GalleryFormat.MATRIX):
        frames = data.get("slides")
    elif entry.format is GalleryFormat.EQUATION:
        scenarios = data.get("scenarios")
        if not isinstance(scenarios, list) or any(not isinstance(scenario, dict) for scenario in scenarios):
            raise ValueError("equation linkage requires scenario objects")
        frames = []
        for scenario in scenarios:
            names = scenario.get("screenshots", [])
            if not isinstance(names, list) or any(not isinstance(name, str) or not name for name in names):
                raise ValueError("scenario screenshots must be image paths")
            if "screenshot" in scenario:
                names = [*names, scenario["screenshot"]]
            if any(not isinstance(name, str) or not name for name in names):
                raise ValueError("scenario screenshot must be an image path")
            frames.extend(dict(image=name, caption=scenario.get("name", "")) for name in dict.fromkeys(names))
    elif entry.format is GalleryFormat.OSCILLATOR:
        slides = data.get("slides")
        if not isinstance(slides, list) or not slides or data.get("pageErrors") != []:
            raise ValueError("oscillator requires slides and an empty pageErrors list")
        frames = []
        for slide in slides:
            if not isinstance(slide, list) or len(slide) != 3 or not all(isinstance(v, str) and v for v in slide):
                raise ValueError("oscillator slides must contain image, title, description")
            frames.append(dict(image=slide[0], caption=slide[1]))
    elif entry.format is GalleryFormat.GEOMETRY:
        frames = [dict(image=slide["file"], caption=slide["observation"])
                  for slide in data["screenshots"]]
    elif entry.format is GalleryFormat.SWS4D:
        frames = [dict(image=slide["file"], dimensions=slide["pixels"], sha256=slide["sha256"])
                  for slide in data["slides"]]
    else:
        frames = [dict(image=name) for name in entry.images]
    if not isinstance(frames, list) or (not frames and entry.format is not GalleryFormat.EVIDENCE):
        raise ValueError("evidence must contain captured frames")
    if any(not isinstance(frame, dict) or not isinstance(frame.get("image"), str) or not frame["image"]
           for frame in frames):
        raise ValueError("capture records must contain image paths")
    for frame in frames:
        capture_path(entry.directory, frame["image"])
    return data, frames


def validate(entry):
    data, frames = evidence(entry)
    if entry.format is GalleryFormat.STANDARD:
        load_manifest(entry.evidence)
    else:
        for frame in frames:
            read_png(capture_path(entry.directory, frame["image"]), frame.get("dimensions"),
                     frame.get("sha256", frame.get("png_sha256")))
    return data, frames


class Resources(HTMLParser):
    def __init__(self):
        super().__init__()
        self.urls = []

    def handle_starttag(self, tag, attrs):
        for key, value in attrs:
            if key == "src" or (tag == "link" and key == "href"):
                self.urls.append(value)


def validate_deck(entry, frames):
    """Check local dependencies and bind delivered HTML to the actual PNG bytes."""
    path = entry.directory / entry.deck_name
    text = path.read_text()
    resources = Resources()
    resources.feed(text)
    local_images = set()
    for url in resources.urls:
        if not url:
            continue
        parts = urlsplit(url)
        if parts.scheme == "data":
            continue
        if parts.scheme or parts.netloc or parts.path.startswith("/"):
            raise ValueError("deck requires a nonportable resource")
        resource = (path.parent / unquote(parts.path)).resolve()
        if (not resource.is_relative_to(entry.directory.resolve()) and not resource.is_relative_to(ROOT)) or not resource.is_file():
            raise ValueError(f"deck resource missing or outside gallery: {url}")
        if resource.suffix == ".png":
            read_png(resource)
            local_images.add(resource)
    for frame in frames:
        image = capture_path(entry.directory, frame["image"])
        encoded = base64.b64encode(image.read_bytes()).decode()
        if encoded not in text and image not in local_images:
            raise ValueError(f"deck does not contain recorded capture: {frame['image']}")
    return path


def relative_link(root, path, label):
    url = Path(os.path.relpath(path, root)).as_posix()
    return f"<a href='{html.escape(url, quote=True)}'>{html.escape(label)}</a>"


def build_catalog(root, check_only=False, index_only=False):
    from audit_demo_manifests import COMMITTED_PATHS, audit

    root = root.resolve()
    entries = discover(root)
    report = audit(root)
    failures = [row for row in report["demos"] if row["schema_and_images"] != "pass"]
    if check_only:
        if failures:
            raise ValueError(f"{len(failures)} galleries lack valid capture evidence; run audit_demo_manifests.py for details")
        return len(entries)
    items, deck_count = [], 0
    for entry, row in zip(entries, report["demos"]):
        links = []
        if entry.evidence.is_file():
            links.append(relative_link(root, entry.evidence, "Capture evidence"))
        if entry.documentation and entry.documentation.is_file():
            links.append(relative_link(root, entry.documentation, "Reproduction and limits"))
        for inventory in row["source_inventories"]:
            path = ROOT / inventory["path"]
            if path != entry.evidence and path.is_file():
                links.append(relative_link(root, path, f"Source provenance ({path.name})"))
        errors = list(row["capture_errors"])
        data = {}
        if not errors:
            data, frames = evidence(entry)
            if entry.format not in (GalleryFormat.IMAGES, GalleryFormat.EVIDENCE) or entry.deck_name != "index.html":
                try:
                    deck = entry.directory / entry.deck_name
                    if index_only and root == ROOT / "artifacts/demo-slideshows" and str(deck.relative_to(ROOT)) not in COMMITTED_PATHS:
                        raise ValueError("deck is generated locally; use capture evidence and reproduction")
                    if entry.format is GalleryFormat.STANDARD and not deck.exists() and not index_only:
                        deck.write_text(render(load_manifest(entry.evidence)))
                    validate_deck(entry, frames)
                    if entry.evidence == deck:
                        links.remove(relative_link(root, deck, "Capture evidence"))
                    links.insert(0, relative_link(root, deck, "Open recorded deck"))
                    deck_count += 1
                except (ValueError, OSError) as error:
                    errors.append(str(error).replace(str(ROOT) + "/", ""))
        elif entry.evidence.suffix == ".json":
            try:
                data = json.loads(entry.evidence.read_text())
            except (ValueError, OSError):
                pass
        title = entry.title or (data.get("title") if isinstance(data, dict) else None) or entry.demo_id
        recipe = data.get("reproduce", data.get("command", "")) if isinstance(data, dict) else ""
        status = ("Deck unavailable — use capture evidence and reproduction" if errors else
                  "Evidence bundle; no deck certified" if entry.format is GalleryFormat.EVIDENCE else
                  "Recorded capture evidence available")
        issue = f"<p class='meta'>{html.escape(errors[0])}</p>" if errors else ""
        reproduce = (f"<details><summary>Reproduce captures</summary><pre>{html.escape(recipe)}</pre></details>"
                     if isinstance(recipe, str) and recipe else "")
        items.append(f"<li id='{html.escape(entry.demo_id)}' data-gallery='{html.escape(entry.demo_id)}'>"
                     f"<h2>{html.escape(title)}</h2><p>{' · '.join(links)}</p>"
                     f"<p>{status} · {row['frames']} frame references</p>"
                     f"<p class='meta'>{html.escape(entry.demo_id)} · {html.escape(row['format'])} · "
                     f"Sources: {html.escape(row['source_status'])} · "
                     f"revision: {html.escape(str(row['captured_revision'] or 'not recorded'))}</p>"
                     f"{issue}{reproduce}</li>")
    body = ("<h1>Moxi demo slideshows</h1><p>Recorded decks, capture recipes and evidence. "
            "Each gallery appears once; the E06 overview is represented by its three families.</p>"
            f"<p>{len(entries)} galleries · {deck_count} checked deck links · "
            f"{report['frame_count']} frame references (not unique images).</p>"
            f"<p class='meta'>Inventory at {html.escape(report['checkout_revision'])}. "
            f"Audited source worktree changes: {len(report['audited_source_worktree_status'])}. "
            "Rebuild after obtaining or regenerating captures: python3 scripts/demo_slideshows.py</p>"
            "<p>Source status compares only recorded per-file hashes. Older revisions can match; "
            "missing inventories mean unknown. These checks do not certify current behavior, "
            "visual quality, dependency completeness or physical input.</p>"
            "<label>Find a gallery <input id='search' type='search' placeholder='Name, family, source status'></label>"
            "<p id='matches' aria-live='polite'></p><ul id='galleries'>\n" + "\n".join(items) + "</ul>")
    script = """
const entries=[...document.querySelectorAll('[data-gallery]')];
document.getElementById('search').addEventListener('input',event=>{
const query=event.target.value.trim().toLowerCase();let count=0;
entries.forEach(entry=>{entry.hidden=!entry.textContent.toLowerCase().includes(query);if(!entry.hidden)count++;});
document.getElementById('matches').textContent=`${count} galleries shown`;});
"""
    root.mkdir(parents=True, exist_ok=True)
    (root / "index.html").write_text(page("Moxi demo slideshows", body, script))
    print(f"{deck_count} checked deck links; {len(failures)} galleries with unavailable capture evidence")
    return len(entries)
