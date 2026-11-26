"""The original-pin status producer must fail closed and omit host paths."""
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('wave_c_upstream', ROOT / 'scripts/wave_c/upstream.py')
upstream = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(upstream)


class ReferenceStatusTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.checkout = Path(self.directory.name)
        (self.checkout / 'dataviz').mkdir()
        (self.checkout / 'dataviz/__init__.mojo').write_text('from .bar import mark_bar\n')
        (self.checkout / 'dataviz/bar.mojo').write_text('def mark_bar(): pass\n')
        (self.checkout / 'pixi.lock').write_text(upstream.CANVAS_PIN + '\n')
        self.git('init', '-q')
        self.commit()
        revision = self.git('rev-parse', 'HEAD').strip()
        pin = patch.object(upstream, 'PIN', revision)
        pin.start()
        self.addCleanup(pin.stop)

    def git(self, *args):
        return subprocess.check_output(['git', '-C', str(self.checkout), *args], text=True, stderr=subprocess.DEVNULL)

    def commit(self):
        self.git('add', '.')
        self.git('-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.test',
                 'commit', '-qm', 'test: create synthetic inventory')

    def test_inventory_hashes_actual_relative_sources(self):
        record = upstream.pinned_inventory(self.checkout)
        self.assertEqual(record['mojo_files'], 2)
        self.assertFalse(record['tricontour_available'])
        self.assertEqual(record['matching_files'], [])
        self.assertEqual(record['inventory']['dataviz/bar.mojo'],
                         hashlib.sha256((self.checkout / 'dataviz/bar.mojo').read_bytes()).hexdigest())
        canonical = json.dumps(record['inventory'], sort_keys=True, separators=(',', ':')).encode()
        self.assertEqual(record['inventory_sha256'], hashlib.sha256(canonical).hexdigest())
        page = upstream.reference_status_page(dict(generated_at='2026-11-26T00:00:00+00:00', upstream=record))
        self.assertNotIn(str(self.checkout), json.dumps(record) + page)
        self.assertIn('No upstream plot was generated', page)

    def test_rejects_wrong_revision(self):
        with patch.object(upstream, 'PIN', '0' * 40), self.assertRaisesRegex(ValueError, 'pin mismatch'):
            upstream.pinned_inventory(self.checkout)

    def test_rejects_dirty_checkout(self):
        (self.checkout / 'dataviz/bar.mojo').write_text('changed\n')
        with self.assertRaisesRegex(ValueError, 'must be clean'):
            upstream.pinned_inventory(self.checkout)

    def test_rejects_changed_canvas_pin(self):
        (self.checkout / 'pixi.lock').write_text('different dependency\n')
        self.commit()
        with patch.object(upstream, 'PIN', self.git('rev-parse', 'HEAD').strip()), self.assertRaisesRegex(ValueError, 'Canvas pin mismatch'):
            upstream.pinned_inventory(self.checkout)

    def test_rejects_tricontour_symbol(self):
        (self.checkout / 'dataviz/bar.mojo').write_text('def mark_TRIContour(): pass\n')
        self.commit()
        with patch.object(upstream, 'PIN', self.git('rev-parse', 'HEAD').strip()), self.assertRaisesRegex(ValueError, 'availability changed'):
            upstream.pinned_inventory(self.checkout)

    def test_rejects_empty_inventory(self):
        self.git('rm', '-qr', 'dataviz')
        self.commit()
        with patch.object(upstream, 'PIN', self.git('rev-parse', 'HEAD').strip()), self.assertRaisesRegex(ValueError, 'inventory is empty'):
            upstream.pinned_inventory(self.checkout)


if __name__ == '__main__':
    unittest.main()
