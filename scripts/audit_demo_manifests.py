#!/usr/bin/env python3
"""Audit every catalog manifest without treating old captures as current proof."""

import argparse
from collections import Counter
from datetime import datetime, timezone
from enum import Enum
import hashlib
import json
from pathlib import Path
import re
import subprocess

from demo_gallery import GalleryFormat, discover, evidence, validate
from demo_slideshows import capture_path

ROOT = Path(__file__).resolve().parents[1]
GALLERIES = ROOT / "artifacts/demo-slideshows"
TRACKED_PATHS = set(subprocess.check_output(["git", "ls-files"], cwd=ROOT, text=True).splitlines())
AUDIT_REVISION = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
COMMITTED_PATHS = set(subprocess.check_output(
    ["git", "ls-tree", "-r", "--name-only", AUDIT_REVISION], cwd=ROOT, text=True).splitlines())
SOURCE_ROOTS = {"src", "native", "python", "examples", "scripts", "tests", "experiments", "packages", "docs", "assets", "web"}


class SourceStatus(str, Enum):
    MATCH = "recorded-files-match"
    STALE = "recorded-source-differs"
    UNVERIFIABLE = "no-per-file-source-hashes"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def source_maps(value):
    """Extract explicit repository source-file maps, not artifact/binary hashes."""
    if isinstance(value, dict):
        for name, digest in value.items():
            if (isinstance(digest, str) and re.fullmatch(r"[a-f0-9]{64}", digest)
                    and not Path(name).is_absolute() and ".." not in Path(name).parts
                    and (name in TRACKED_PATHS or name.split("/")[0] in SOURCE_ROOTS)
                    and not name.startswith(("artifacts/", "dist/"))):
                yield name, digest
            elif isinstance(digest, (dict, list)):
                yield from source_maps(digest)
    elif isinstance(value, list):
        for item in value:
            yield from source_maps(item)


def audit(root=GALLERIES):
    rows = []
    audited_sources = set()
    for entry in discover(root):
        path = entry.evidence
        data, frames = {}, []
        errors = []
        try:
            data, frames = evidence(entry)
            validate(entry)
        except (ValueError, KeyError, OSError, TypeError) as error:
            errors.append(str(error).replace(str(ROOT) + "/", ""))
            if path.suffix == ".json":
                try:
                    raw = json.loads(path.read_text())
                    data = raw if isinstance(raw, dict) else {}
                except (ValueError, OSError):
                    pass
        def relative(path):
            return str(path.relative_to(ROOT)) if path.is_relative_to(ROOT) else str(path)
        row = dict(demo_id=entry.demo_id, format=entry.format.value,
                   evidence_path=relative(path), evidence_sha256=sha(path) if path.is_file() else None,
                   captured_revision=data.get("revision", data.get("source_revision", data.get("checkout_base"))),
                   frames=len(frames))
        if path.name == "manifest.json":
            row["manifest_sha256"] = row["evidence_sha256"]
        row["schema_and_images"] = "fail" if errors else "pass"
        row["capture_errors"] = errors
        image_hashes, missing_hashes, mismatches, absent_images = 0, [], [], []
        committed_images, local_uncommitted_images, absent_uncommitted_images = [], [], []
        kinds = Counter()
        for slide in frames:
            kind = slide.get("capture_kind", "missing")
            if isinstance(kind, str):
                kinds[kind] += 1
            image = capture_path(path.parent, slide["image"])
            if relative(image) in COMMITTED_PATHS:
                committed_images.append(slide.get("image"))
            elif image.is_file():
                local_uncommitted_images.append(slide.get("image"))
            else:
                absent_uncommitted_images.append(slide.get("image"))
            digest = slide.get("sha256", slide.get("png_sha256"))
            if not image.is_file():
                absent_images.append(slide.get("image"))
            elif digest is None:
                missing_hashes.append(slide.get("image"))
            elif sha(image) == digest:
                image_hashes += 1
            else:
                mismatches.append(slide.get("image"))
        row.update(capture_kinds=dict(kinds), image_hashes_verified=image_hashes,
                   images_without_recorded_hash=missing_hashes, image_hash_mismatches=mismatches,
                   missing_images=absent_images, committed_images=committed_images,
                   local_uncommitted_images=local_uncommitted_images,
                   absent_uncommitted_images=absent_uncommitted_images)
        documents = [(relative(path), data)]
        candidates = {path.parent / filename for filename in (
            "provenance.json", "source-hashes.json", "evidence.json", "capture-provenance.json",
            "frames.json", "build.json", "capture.json")}
        invalid_inventories = []
        published_hashes = data.get("artifacts_sha256", {})
        if isinstance(published_hashes, dict) and "publication.json" in published_hashes:
            # Installed-wheel proofs retain machine-specific build logs locally.
            # Audit the source inventory that a clean checkout can reproduce.
            candidates.discard(path.parent / "build.json")
            publication = path.parent / "publication.json"
            if publication.is_file() and sha(publication) == published_hashes[publication.name]:
                candidates.add(publication)
            else:
                invalid_inventories.append(str(publication.relative_to(ROOT)))
        for key in ("source_manifest", "source_state_path"):
            if isinstance(data.get(key), str):
                candidates.add((ROOT if key == "source_state_path" else path.parent) / data[key])
        provenance = data.get("source_provenance", {})
        if isinstance(provenance, dict) and isinstance(provenance.get("source_hashes_file"), str):
            candidates.add(path.parent / provenance["source_hashes_file"])
        for sidecar in sorted(candidates):
            if sidecar.is_file():
                try:
                    documents.append((relative(sidecar), json.loads(sidecar.read_text())))
                except (ValueError, OSError) as error:
                    invalid_inventories.append(dict(path=relative(sidecar), reason=str(error)))
        recorded, conflicts, inventories, external = {}, [], [], []
        for name, document in documents:
            if entry.source_prefix and name == relative(path):
                document = dict(document)
                for field in ("sources", "sourceHashes"):
                    if isinstance(document.get(field), dict):
                        document[field] = {
                            f"{entry.source_prefix}/{source}": digest
                            for source, digest in document[field].items()}
            if entry.format is GalleryFormat.SWS4D:
                external.append(dict(path=name, namespace="moxi-sws4d",
                                     recorded_files=len(document.get("source_sha256", {})),
                                     reason="Separate application repository; not checked against Moxi paths."))
            # The SWS consumer records its application and Moxi repositories
            # separately. Application-relative paths do not name this checkout.
            if (isinstance(document, dict) and isinstance(document.get("moxi"), dict)
                    and isinstance(document.get("application"), dict)):
                external.append(dict(path=name, namespace="application",
                                     recorded_files=len(document["application"]),
                                     reason="Separate application repository; not checked against Moxi paths."))
                document = document["moxi"]
            entries = list(source_maps(document))
            if entries:
                inventories.append(dict(path=name, sha256=sha(Path(name) if Path(name).is_absolute() else ROOT / name), entries=len(entries)))
            for source, digest in entries:
                if source in recorded and recorded[source] != digest:
                    conflicts.append(source)
                recorded[source] = digest
        absent = sorted(source for source in recorded if not (ROOT / source).is_file())
        audited_sources.update(recorded)
        changed = sorted(source for source, digest in recorded.items()
                         if (ROOT / source).is_file() and sha(ROOT / source) != digest)
        status = (SourceStatus.STALE if invalid_inventories else
                  SourceStatus.UNVERIFIABLE if not recorded else
                  SourceStatus.STALE if absent or changed or conflicts else SourceStatus.MATCH)
        row.update(source_status=status.value, source_inventories=inventories,
                   external_source_inventories=external,
                   recorded_source_files=len(recorded), changed_source_files=changed,
                   missing_source_files=absent, conflicting_source_hashes=sorted(set(conflicts)))
        if invalid_inventories:
            row["invalid_source_inventories"] = invalid_inventories
        rows.append(row)
    return dict(checked_at=datetime.now(timezone.utc).isoformat(),
                checkout_revision=AUDIT_REVISION,
                audited_source_worktree_status=subprocess.check_output(
                    ["git", "status", "--short", "--", *sorted(audited_sources)],
                    cwd=ROOT, text=True).splitlines(),
                scope="One-level manifests, supported custom evidence, and outside-root galleries linked from index.md; duplicate directories and the E06 family overview are excluded. Schema, PNG structure/presence/dimensions, recorded PNG checksums and recorded per-file source fingerprints. No capture, visual review, dependency-completeness certification, binary verification or acceptance promotion.",
                source_status_meaning="Recorded-files-match verifies only the explicit inventory; omitted dependencies and provenance completeness remain unverified. Old revision equality alone is not current-source evidence.",
                gallery_count=len(rows),
                manifest_count=sum(row["evidence_path"].endswith("/manifest.json") for row in rows),
                format_counts=dict(Counter(row["format"] for row in rows)),
                frame_count=sum(row["frames"] for row in rows),
                image_hashes_verified=sum(row["image_hashes_verified"] for row in rows),
                images_without_recorded_hash=sum(len(row["images_without_recorded_hash"]) for row in rows),
                image_hash_mismatches=sum(len(row["image_hash_mismatches"]) for row in rows),
                missing_images=sum(len(row["missing_images"]) for row in rows),
                committed_image_references=sum(len(row["committed_images"]) for row in rows),
                local_uncommitted_image_references=sum(len(row["local_uncommitted_images"]) for row in rows),
                absent_uncommitted_image_references=sum(len(row["absent_uncommitted_images"]) for row in rows),
                image_availability_basis="Committed PNG paths at checkout_revision count as fresh-clone artifacts. Staged, ignored and other uncommitted local PNGs do not. missing_images is a working-tree absence count, not a fresh-clone absence count.",
                source_status_counts=dict(Counter(row["source_status"] for row in rows)),
                schema_pass_count=sum(row["schema_and_images"] == "pass" for row in rows),
                demos=rows)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, help="Write the complete JSON report")
    args = parser.parse_args()
    result = audit()
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(result, indent=2) + "\n")
        print(json.dumps({key: result[key] for key in ("gallery_count", "manifest_count", "format_counts", "frame_count", "schema_pass_count", "source_status_counts")}))
    else:
        print(json.dumps(result, indent=2))
