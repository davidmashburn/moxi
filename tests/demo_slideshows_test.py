"""Evidence validation and offline artifact regression checks (synthetic unit fixture)."""

import base64
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import zlib

sys.path.insert(0, str(Path(__file__).parents[1] / "scripts"))
import audit_demo_manifests as auditor
import demo_gallery as catalog

spec = importlib.util.spec_from_file_location("slideshows", Path(__file__).parents[1] / "scripts/demo_slideshows.py")
slideshows = importlib.util.module_from_spec(spec)
spec.loader.exec_module(slideshows)

def png_chunk(kind, data):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))


def synthetic_png(pixels, width=1, height=1, depth=8, color=2,
                  compression=0, filtering=0, interlace=0, palette=None):
    return (slideshows.PNG_SIGNATURE
            + png_chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, depth, color,
                                             compression, filtering, interlace))
            + (png_chunk(b"PLTE", palette) if palette is not None else b"")
            + png_chunk(b"IDAT", zlib.compress(pixels)) + png_chunk(b"IEND", b""))


# A valid synthetic 1-pixel unit fixture, never used as gallery evidence.
PNG = (slideshows.PNG_SIGNATURE + png_chunk(b"IHDR", struct.pack(">IIBBBBB", 1, 1, 8, 2, 0, 0, 0))
       + png_chunk(b"IDAT", zlib.compress(b"\x00\xff\x00\x00")) + png_chunk(b"IEND", b""))


class SlideshowTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.demo = self.root / "unit-fixture"
        self.demo.mkdir()
        (self.demo / "unit.png").write_bytes(PNG)
        self.path = self.demo / "manifest.json"
        self.manifest = dict(version=1, demo_id="unit-fixture", title="<script>alert(1)</script>",
                             scenario="unit fixture only", host="unit", backend="unit", fixture="unit",
                             reproduce="unit-test", revision="abcdef0", scale=1,
                             slides=[dict(phase=phase, capture_kind="offscreen-render", image="unit.png",
                                          dimensions=[1, 1], caption="a 'quote' & <markup>",
                                          action="unit action", expected="unit result")
                                     for phase in ("initial", "interaction", "result", "recovery")])

    def load(self, manifest=None):
        self.path.write_text(json.dumps(manifest or self.manifest))
        return slideshows.load_manifest(self.path)

    def test_portable_html_escapes_metadata_and_parses_domains(self):
        loaded = self.load()
        self.assertIs(loaded["slides"][0]["phase"], slideshows.Phase.INITIAL)
        self.assertIs(loaded["slides"][0]["capture_kind"], slideshows.CaptureKind.OFFSCREEN)
        self.assertEqual(slideshows.build(self.root), 1)
        output = (self.demo / "index.html").read_text()
        self.assertIn("data:image/png;base64,", output)
        self.assertIn("&lt;script&gt;", output)
        self.assertNotIn("<script>alert(1)</script>", output)
        self.assertIn("ArrowRight", output)
        self.assertIn("unit-fixture/index.html", (self.root / "index.html").read_text())

    def test_relative_image_cli_uses_original_files_and_preserves_existing_deck(self):
        name = "capture ' & #?.png"
        (self.demo / name).write_bytes(PNG)
        for slide in self.manifest["slides"]:
            slide["image"] = name
        self.load()
        result = subprocess.run(
            [sys.executable, str(Path(__file__).parents[1] / "scripts/demo_slideshows.py"),
             str(self.root), "--relative-images"], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        deck = self.demo / "index.html"
        output = deck.read_text()
        self.assertIn("src='capture%20%27%20%26%20%23%3F.png'", output)
        self.assertNotIn("data:image", output)
        self.assertIn("ArrowRight", output)
        entry = catalog.discover(self.root)[0]
        catalog.validate_deck(entry, self.manifest["slides"])
        self.assertEqual(slideshows.build(self.root, check_only=True), 1)
        slideshows.build(self.root)  # The default remains embedded for new decks.
        self.assertEqual(deck.read_text(), output)

    def test_comparison_sequence_uses_recorded_families_and_keeps_evidence_only_cases(self):
        root = self.root / "artifacts/demo-slideshows"
        demo = root / "e03-flow-calendar-followup"
        demo.mkdir(parents=True)
        data = {family: {"labels": index + 1} for index, family in
                enumerate(("chord", "calendar_heatmap", "sankey"))}
        (demo / "results.json").write_text(json.dumps(data))
        (demo / "README.md").write_text("Synthetic comparison reproduction")
        for family in data:
            (demo / f"{family}.png").write_bytes(PNG)
        single = root / "e01-category-labels"
        single.mkdir()
        (single / "comparison.png").write_bytes(PNG)
        review = root / "plot-wave-b-c-review"
        review.mkdir()
        (review / "review.json").write_text("{}")
        with patch.object(catalog, "ROOT", self.root.resolve()):
            entries = catalog.discover(root)
            entry = next(e for e in entries if e.demo_id == demo.name)
            self.assertIs(entry.format, catalog.GalleryFormat.COMPARISONS)
            _, frames = catalog.validate(entry)
            portable = catalog.render_comparisons(entry, data, frames)
            self.assertIn("data:image/png;base64,", portable)
            self.assertEqual(slideshows.build(root, relative_images=True), 3)
            deck = (demo / "index.html").read_text()
            self.assertEqual(deck.count("<figure data-slide="), 3)
            self.assertIn("calendar heatmap comparison", deck)
            self.assertIn("Recorded measurements", deck)
            self.assertNotIn("data:image", deck)
            catalog.validate_deck(entry, frames)
            self.assertFalse((single / "index.html").exists())
            self.assertFalse((review / "index.html").exists())
            self.assertEqual(slideshows.build(root, check_only=True), 3)
            del data["chord"]
            (demo / "results.json").write_text(json.dumps(data))
            with self.assertRaisesRegex(ValueError, "recorded chord measurements"):
                catalog.validate(entry)
            slideshows.build(root, relative_images=True)
            self.assertNotIn("e03-flow-calendar-followup/index.html", (root / "index.html").read_text())
            self.assertEqual((demo / "index.html").read_text(), deck)

    def test_missing_recovery_cannot_be_called_complete(self):
        self.manifest["slides"].pop()
        with self.assertRaisesRegex(ValueError, "recovery"):
            self.load()

    def test_reject_outside_image_even_if_it_exists(self):
        (self.root / "outside.png").write_bytes(PNG)
        self.manifest["slides"][0]["image"] = "../outside.png"
        with self.assertRaisesRegex(ValueError, "inside"):
            self.load()

    def test_reject_dimensions_missing_image_and_unknown_capture_kind(self):
        for field, value in (("dimensions", [2, 1]), ("image", "missing.png"),
                             ("capture_kind", "mockup"), ("phase", "almost-done")):
            with self.subTest(field=field):
                manifest = copy.deepcopy(self.manifest)
                manifest["slides"][0][field] = value
                with self.assertRaises((ValueError, FileNotFoundError)):
                    self.load(manifest)

    def test_reject_checksum_mismatch_and_truncated_or_corrupt_png(self):
        self.manifest["slides"][0]["sha256"] = "0" * 64
        with self.assertRaisesRegex(ValueError, "SHA-256"):
            self.load()
        for data in (PNG[:33], PNG[:-4], PNG[:45] + b"broken" + PNG[51:]):
            with self.subTest(size=len(data)):
                (self.demo / "unit.png").write_bytes(data)
                with self.assertRaises(ValueError):
                    self.load()

    def test_reject_crc_valid_png_with_invalid_encoding_or_scanlines(self):
        for options, pixels in (
                ({"depth": 3}, b"\x00\xff\x00\x00"),
                ({"color": 1}, b"\x00\xff\x00\x00"),
                ({"compression": 1}, b"\x00\xff\x00\x00"),
                ({"filtering": 1}, b"\x00\xff\x00\x00"),
                ({"interlace": 2}, b"\x00\xff\x00\x00"),
                ({"color": 3, "depth": 1}, b"\x00\x00"),
                ({}, b"\x00\xff\x00"),
                ({}, b"\x00\xff\x00\x00\x00"),
                ({}, b"\x05\xff\x00\x00"),
                ({"width": 3, "height": 3, "interlace": 1}, b"\x00" * 30)):
            with self.subTest(options=options, pixels=pixels):
                (self.demo / "unit.png").write_bytes(synthetic_png(pixels, **options))
                with self.assertRaises(ValueError):
                    slideshows.read_png(self.demo / "unit.png")

    def test_accept_packed_16bit_and_adam7_png_scanlines(self):
        for options, pixels in (
                ({"color": 0, "depth": 1}, b"\x00\x80"),
                ({"color": 3, "depth": 1, "palette": b"\x00\x00\x00"}, b"\x00\x00"),
                ({"depth": 16}, b"\x00\xff\xff\x00\x00\x00\x00"),
                # 3x3 RGB Adam7 has six scanlines in passes 1, 4, 5, 6, 7.
                ({"width": 3, "height": 3, "interlace": 1}, b"\x00" * 33)):
            with self.subTest(options=options):
                data = synthetic_png(pixels, **options)
                (self.demo / "unit.png").write_bytes(data)
                self.assertEqual(slideshows.read_png(self.demo / "unit.png"), data)

    def test_undecodable_png_is_not_certified_by_audit_generation_or_strict_cli(self):
        self.path.write_text(json.dumps(self.manifest))
        (self.demo / "unit.png").write_bytes(
            synthetic_png(b"\x00\xff\x00\x00", depth=3))
        row = auditor.audit(self.root)["demos"][0]
        self.assertEqual(row["schema_and_images"], "fail")
        self.assertTrue(row["capture_errors"])
        self.assertEqual(slideshows.build(self.root), 1)
        self.assertFalse((self.demo / "index.html").exists())
        self.assertNotIn("Open recorded deck", (self.root / "index.html").read_text())
        cli = [sys.executable, str(Path(__file__).parents[1] / "scripts/demo_slideshows.py"),
               str(self.root)]
        generated = subprocess.run(cli, capture_output=True, text=True)
        self.assertEqual(generated.returncode, 0, generated.stderr)
        self.assertFalse((self.demo / "index.html").exists())
        self.assertNotIn("Open recorded deck", (self.root / "index.html").read_text())
        checked = subprocess.run(cli + ["--check"], capture_output=True, text=True)
        self.assertNotEqual(checked.returncode, 0)
        self.assertIn("1 galleries lack valid capture evidence", checked.stderr)

    def test_audit_distinguishes_missing_stale_current_and_unknown(self):
        source = "scripts/demo_gallery.py"
        digest = hashlib.sha256((catalog.ROOT / source).read_bytes()).hexdigest()
        self.manifest["source_sha256"] = {source: digest}
        self.load()
        current = auditor.audit(self.root)["demos"][0]
        self.assertEqual(current["source_status"], "recorded-files-match")
        self.assertEqual(current["captured_revision"], "abcdef0")  # Old revision alone is not stale.
        self.manifest["source_sha256"][source] = "0" * 64
        self.load()
        stale = auditor.audit(self.root)["demos"][0]
        self.assertEqual(stale["source_status"], "recorded-source-differs")
        self.assertEqual(stale["changed_source_files"], [source])
        self.manifest["source_sha256"] = {"src/unit-fixture-missing.mojo": "0" * 64}
        self.load()
        missing = auditor.audit(self.root)["demos"][0]
        self.assertEqual(missing["source_status"], "recorded-source-differs")
        self.assertEqual(missing["missing_source_files"], ["src/unit-fixture-missing.mojo"])
        self.manifest.pop("source_sha256")
        self.load()
        (self.demo / "unit.png").unlink()
        unknown = auditor.audit(self.root)["demos"][0]
        self.assertEqual(unknown["source_status"], "no-per-file-source-hashes")
        self.assertEqual(unknown["missing_images"], ["unit.png"] * 4)
        self.assertEqual(unknown["schema_and_images"], "fail")

    def test_master_keeps_missing_and_unknown_entries_without_deck_links(self):
        self.load()
        (self.demo / "unit.png").unlink()
        other = self.root / "future"
        other.mkdir()
        (other / "manifest.json").write_text(json.dumps({"version": 9, "slides": [["x.png"]]}))
        self.assertEqual(slideshows.build(self.root), 2)
        output = (self.root / "index.html").read_text()
        self.assertIn("id='unit-fixture'", output)
        self.assertIn("id='future'", output)
        self.assertIn("unit-fixture/manifest.json", output)
        self.assertIn("unit-test", output)
        self.assertNotIn("Open recorded deck", output)
        self.assertFalse((self.demo / "index.html").exists())
        with self.assertRaisesRegex(ValueError, "2 galleries"):
            slideshows.build(self.root, check_only=True)
        rows = auditor.audit(self.root)["demos"]
        self.assertEqual(rows[0]["format"], "unsupported")
        self.assertIn("unsupported", rows[0]["capture_errors"][0])

    def test_malformed_evidence_is_reported_without_aborting_other_entries(self):
        self.load()
        for content in ("{bad", "[]", '{"version":1,"slides":[[]]}'):
            with self.subTest(content=content):
                other = self.root / "malformed"
                other.mkdir(exist_ok=True)
                (other / "manifest.json").write_text(content)
                report = auditor.audit(self.root)
                self.assertEqual(report["gallery_count"], 2)
                self.assertEqual(report["schema_pass_count"], 1)

    def test_list_capture_kind_retains_failed_entry_and_valid_neighbor(self):
        self.load()
        other = self.root / "malformed"
        other.mkdir()
        (other / "unit.png").write_bytes(PNG)
        manifest = copy.deepcopy(self.manifest)
        manifest["demo_id"] = other.name
        manifest["slides"][0]["capture_kind"] = []
        (other / "manifest.json").write_text(json.dumps(manifest))
        report = auditor.audit(self.root)
        self.assertEqual(report["gallery_count"], 2)
        self.assertEqual(report["schema_pass_count"], 1)
        failed = next(row for row in report["demos"] if row["demo_id"] == other.name)
        self.assertEqual(failed["schema_and_images"], "fail")
        self.assertIn("CaptureKind", failed["capture_errors"][0])
        self.assertEqual(failed["frames"], 4)
        self.assertEqual(failed["capture_kinds"], {"offscreen-render": 3})
        self.assertEqual(slideshows.build(self.root), 2)
        master = (self.root / "index.html").read_text()
        self.assertIn("id='malformed'", master)
        self.assertIn("unit-fixture/index.html", master)
        self.assertNotIn("malformed/index.html", master)
        self.assertFalse((other / "index.html").exists())
        with self.assertRaisesRegex(ValueError, "1 galleries lack valid capture evidence"):
            slideshows.build(self.root, check_only=True)

    def test_existing_deck_is_preserved_and_checked_against_images(self):
        loaded = self.load()
        original = slideshows.render(loaded) + "<!-- historical deck -->"
        deck = self.demo / "index.html"
        deck.write_text(original)
        slideshows.build(self.root)
        self.assertEqual(deck.read_text(), original)
        deck.write_text("<html>wrong deck</html>")
        slideshows.build(self.root)
        self.assertNotIn("Open recorded deck", (self.root / "index.html").read_text())
        self.assertEqual(deck.read_text(), "<html>wrong deck</html>")

    def test_index_only_links_evidence_without_materializing_deck(self):
        self.load()
        slideshows.build(self.root, index_only=True)
        self.assertFalse((self.demo / "index.html").exists())
        self.assertNotIn("Open recorded deck", (self.root / "index.html").read_text())

    def test_oscillator_list_adapter_and_broken_custom_captures(self):
        self.load()
        other = self.root / "oscillator"
        other.mkdir()
        (other / "actual.png").write_bytes(PNG)
        (other / "manifest.json").write_text(json.dumps({
            "slides": [["actual.png", "Title", "Observation"]], "pageErrors": [],
            "sources": {"lesson.py": "0" * 64}}))
        (other / "index.html").write_text('<img src="actual.png">')
        entry = next(e for e in catalog.discover(self.root) if e.demo_id == "oscillator")
        self.assertIs(entry.format, catalog.GalleryFormat.OSCILLATOR)
        report = auditor.audit(self.root)
        self.assertEqual(report["gallery_count"], 2)
        self.assertEqual(report["schema_pass_count"], 2)
        row = next(r for r in report["demos"] if r["demo_id"] == "oscillator")
        self.assertIn("examples/oscillator/lesson.py", row["changed_source_files"])
        self.assertEqual(row["frames"], 1)
        slideshows.build(self.root)
        self.assertIn("oscillator/index.html", (self.root / "index.html").read_text())
        (other / "actual.png").write_bytes(PNG[:40])
        slideshows.build(self.root)
        self.assertNotIn("oscillator/index.html", (self.root / "index.html").read_text())

    def test_outside_root_links_are_discovered_once_and_geometry_overview_is_not_duplicated(self):
        self.load()
        outside = self.root / "examples/outside"
        outside.mkdir(parents=True)
        manifest = copy.deepcopy(self.manifest)
        manifest["demo_id"] = "outside"
        (outside / "manifest.json").write_text(json.dumps(manifest))
        (self.root / "index.md").write_text(
            "[one](examples/outside/index.html) [again](examples/outside/index.html) "
            "[local](unit-fixture/index.html) [remote](https://example.test/index.html)")
        overview = self.root / "e06"
        overview.mkdir()
        (overview / "index.html").write_text("family links only")
        with patch.object(catalog, "ROOT", self.root.resolve()):
            entries = catalog.discover(self.root)
        self.assertEqual([e.demo_id for e in entries], ["outside", "unit-fixture"])

    def test_matrix_adapter_preserves_deck_and_audits_example_relative_hashes(self):
        demo = self.root / "matrix-instrument"
        demo.mkdir()
        (demo / "unit.png").write_bytes(PNG)
        (demo / "README.md").write_text("Synthetic capture instructions")
        source = self.root / "examples/matrix-instrument/instrument.js"
        source.parent.mkdir(parents=True)
        source.write_text("synthetic unit fixture")
        manifest = dict(revision="abcdef0", sources={
            "instrument.js": hashlib.sha256(source.read_bytes()).hexdigest()},
            slides=[dict(image="unit.png", title="Synthetic matrix",
                         sha256=hashlib.sha256(PNG).hexdigest())])
        (demo / "manifest.json").write_text(json.dumps(manifest))
        deck = '<img src="unit.png"><!-- delivered matrix deck -->'
        (demo / "index.html").write_text(deck)
        with patch.object(auditor, "ROOT", self.root.resolve()), \
                patch.object(auditor.subprocess, "check_output", return_value=""):
            entry = catalog.discover(self.root)[0]
            self.assertIs(entry.format, catalog.GalleryFormat.MATRIX)
            row = auditor.audit(self.root)["demos"][0]
            self.assertEqual(row["source_status"], auditor.SourceStatus.MATCH.value)
            self.assertEqual(row["recorded_source_files"], 1)
            self.assertEqual(row["image_hashes_verified"], 1)
            slideshows.build(self.root, index_only=True)
            self.assertIn("matrix-instrument/index.html", (self.root / "index.html").read_text())
            self.assertEqual((demo / "index.html").read_text(), deck)
            manifest["slides"][0]["sha256"] = "0" * 64
            (demo / "manifest.json").write_text(json.dumps(manifest))
            self.assertEqual(auditor.audit(self.root)["demos"][0]["schema_and_images"], "fail")

    def test_equation_scenarios_deduplicate_aliases_and_keep_document_filename_case(self):
        demo = self.root / "i21-equation-linkage"
        demo.mkdir()
        (demo / "unit.png").write_bytes(PNG)
        (demo / "verification.md").write_text("Synthetic capture limits")
        source = self.root / "examples/equation-linkage/model.mjs"
        source.parent.mkdir(parents=True)
        source.write_text("synthetic unit fixture")
        manifest = dict(sourceHashes={"model.mjs": hashlib.sha256(source.read_bytes()).hexdigest()},
                        scenarios=[dict(name="No screenshot"), dict(name="Synthetic equation",
                                   screenshots=["unit.png"], screenshot="unit.png")])
        (demo / "manifest.json").write_text(json.dumps(manifest))
        (demo / "index.html").write_text('<img src="unit.png">')
        with patch.object(auditor, "ROOT", self.root.resolve()), \
                patch.object(auditor.subprocess, "check_output", return_value=""):
            entry = catalog.discover(self.root)[0]
            self.assertIs(entry.format, catalog.GalleryFormat.EQUATION)
            self.assertEqual(entry.documentation.name, "verification.md")
            row = auditor.audit(self.root)["demos"][0]
            self.assertEqual(row["frames"], 1)
            self.assertEqual(row["source_status"], auditor.SourceStatus.MATCH.value)
            self.assertEqual(row["recorded_source_files"], 1)
            slideshows.build(self.root, index_only=True)
            master = (self.root / "index.html").read_text()
            self.assertIn("i21-equation-linkage/index.html", master)
            self.assertIn("i21-equation-linkage/verification.md", master)
            self.assertNotIn("i21-equation-linkage/VERIFICATION.md", master)
            source.write_text("changed synthetic fixture")
            self.assertEqual(auditor.audit(self.root)["demos"][0]["source_status"], auditor.SourceStatus.STALE.value)
            manifest["scenarios"][1]["screenshots"] = "unit.png"
            (demo / "manifest.json").write_text(json.dumps(manifest))
            self.assertEqual(auditor.audit(self.root)["demos"][0]["schema_and_images"], "fail")

    def test_native_transform_deck_discovery_and_provenance_link(self):
        galleries = self.root / "artifacts/demo-slideshows"
        galleries.mkdir(parents=True)
        demo = self.root / "examples/inspectable-transforms/evidence/i19-transforms"
        demo.mkdir(parents=True)
        (demo / "canvas").mkdir()
        (demo / "canvas/unit.png").write_bytes(PNG)
        manifest = copy.deepcopy(self.manifest)
        manifest["demo_id"] = demo.name
        for slide in manifest["slides"]:
            slide["image"] = "canvas/unit.png"
        (demo / "manifest.json").write_text(json.dumps(manifest))
        (demo / "index.html").write_text('<img src="canvas/unit.png">')
        (demo / "VERIFICATION.md").write_text("Synthetic native capture instructions")
        source = self.root / "examples/inspectable-transforms/main.mojo"
        source.write_text("synthetic unit fixture")
        (demo / "provenance.json").write_text(json.dumps(dict(sources={
            "examples/inspectable-transforms/main.mojo": hashlib.sha256(source.read_bytes()).hexdigest()})))
        (galleries / "index.md").write_text(
            "[native](../../examples/inspectable-transforms/evidence/i19-transforms/index.html)")
        with patch.object(catalog, "ROOT", self.root.resolve()), \
                patch.object(auditor, "ROOT", self.root.resolve()), \
                patch.object(auditor.subprocess, "check_output", return_value=""):
            entries = catalog.discover(galleries)
            self.assertEqual(len(entries), 1)
            self.assertIs(entries[0].format, catalog.GalleryFormat.STANDARD)
            row = auditor.audit(galleries)["demos"][0]
            self.assertEqual(row["source_status"], auditor.SourceStatus.MATCH.value)
            self.assertEqual(row["schema_and_images"], "pass")
            with patch.object(auditor, "COMMITTED_PATHS", {str((demo / "index.html").relative_to(self.root))}):
                slideshows.build(galleries, index_only=True)
            master = (galleries / "index.html").read_text()
            self.assertIn("i19-transforms/index.html", master)
            self.assertIn("i19-transforms/VERIFICATION.md", master)
            self.assertIn("i19-transforms/provenance.json", master)


if __name__ == "__main__":
    unittest.main()
