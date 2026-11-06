"""Packaging boundary checks that do not compile or load any native runtime."""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

from build_native import copy_runtime_notices


class NoticePackagingTests(unittest.TestCase):
    def fixture(self, root):
        prefix = root / 'environment'
        metadata = prefix / 'conda-meta'
        metadata.mkdir(parents=True)
        package = root / 'installed-package'
        licenses = package / 'info/licenses'
        licenses.mkdir(parents=True)
        (licenses / 'LICENSE').write_bytes(b'Exact installed terms\r\n')
        (licenses / 'Third-Party-Notices').write_bytes(b'Exact installed notices\n')
        (metadata / 'mojo-compiler-test.json').write_text(json.dumps({
            'link': {'source': str(package)}, 'license': 'LicenseRef-Test'}))
        return prefix, licenses

    def test_installed_terms_are_preserved_and_stale_files_removed(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            prefix, source = self.fixture(root)
            destination = root / 'bundle'
            destination.mkdir()
            (destination / 'old-license').write_text('stale')
            license_id, hashes = copy_runtime_notices(prefix, destination)
            self.assertEqual(license_id, 'LicenseRef-Test')
            self.assertFalse((destination / 'old-license').exists())
            for name in ('LICENSE', 'Third-Party-Notices'):
                self.assertEqual((destination / name).read_bytes(), (source / name).read_bytes())
                self.assertEqual(hashes[name], hashlib.sha256((source / name).read_bytes()).hexdigest())

    def test_missing_notice_fails_without_replacing_existing_bundle(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            prefix, source = self.fixture(root)
            (source / 'Third-Party-Notices').unlink()
            destination = root / 'bundle'
            destination.mkdir()
            (destination / 'LICENSE').write_text('previous valid bundle')
            with self.assertRaisesRegex(RuntimeError, 'refusing incomplete wheel'):
                copy_runtime_notices(prefix, destination)
            self.assertEqual((destination / 'LICENSE').read_text(), 'previous valid bundle')


if __name__ == '__main__':
    unittest.main()
