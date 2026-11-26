"""Regression at the real HTTP -> Mojo -> Moxi Scene/SVG boundary."""
import hashlib
import json
import shutil
import subprocess
import tempfile
import threading
import unittest
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path

from serve import BINARY, RENDERER, make_server


class ConsumerTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = make_server(0)
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()
        cls.url = f"http://127.0.0.1:{cls.server.server_port}"

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join()

    def request(self, path="/scene", payload=b'{"widths":[24,18.25]}', **headers):
        request = urllib.request.Request(self.url + path, data=payload, headers=headers)
        try:
            return urllib.request.urlopen(request)
        except urllib.error.HTTPError as error:
            return error

    def test_real_render(self):
        with self.request(Origin=f"http://localhost:{self.server.server_port}") as response:
            self.assertEqual(response.status, 200)
            data = json.load(response)
        self.assertEqual(data["renderer"], RENDERER)
        self.assertEqual(data["binary_sha256"], hashlib.sha256(BINARY.read_bytes()).hexdigest())
        for svg, width in zip(data["svgs"], (24, 18.25)):
            scene = ET.fromstring(svg)
            paths = scene.findall("{http://www.w3.org/2000/svg}path")
            self.assertEqual(len(paths), 1)
            self.assertEqual(float(paths[0].attrib["stroke-width"]), width)
            self.assertIn("Q", paths[0].attrib["d"])
        # The identical Moxi bytes are delivered to the browser, without a JS path renderer.
        direct = subprocess.check_output([str(BINARY), "24", "18.25"], text=True).splitlines()
        self.assertEqual(data["svgs"], direct)

    def test_rejected_requests(self):
        for payload in [b"{", b"[]", b'{"widths":[true,12]}', b'{"widths":[4,29]}',
                        b'{"widths":["12",12]}', b'{"widths":[NaN,12]}', b'{"widths":[12]}',
                        b'{"widths":[12,12],"extra":1}', b" " * 257]:
            with self.subTest(payload=payload), self.request(payload=payload) as response:
                self.assertEqual(response.status, 400)
                self.assertNotIn("svgs", json.load(response))
        with self.request(Origin="https://example.invalid") as response:
            self.assertEqual(response.status, 403)
        with self.request(path="/unknown") as response:
            self.assertEqual(response.status, 404)
        with self.request(path="/scene.mojo", payload=None) as response:
            self.assertEqual(response.status, 404)

    def test_binary_rejects_invalid_widths(self):
        for value in ("nan", "inf", "3", "29", "not-a-number"):
            result = subprocess.run([str(BINARY), value, "12"], capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertNotIn(b"<svg", result.stdout)

    def test_missing_renderer_has_no_fallback(self):
        with tempfile.TemporaryDirectory() as temp:
            executable = Path(temp) / "scene"
            shutil.copy2(BINARY, executable)
            with make_server(0, executable) as server:
                executable.unlink()
                thread = threading.Thread(target=server.serve_forever, daemon=True)
                thread.start()
                request = urllib.request.Request(f"http://127.0.0.1:{server.server_port}/scene",
                                                 data=b'{"widths":[12,12]}')
                try:
                    with self.assertRaises(urllib.error.HTTPError) as error:
                        urllib.request.urlopen(request)
                    self.assertEqual(error.exception.code, 503)
                    self.assertNotIn("svgs", json.load(error.exception))
                    error.exception.close()
                finally:
                    server.shutdown()
                    thread.join()


if __name__ == "__main__":
    unittest.main()
