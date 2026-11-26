"""Loopback-only, synthetic pose consumer. No camera or third-party server."""
import argparse
import hashlib
import json
import math
import subprocess
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
BINARY = ROOT / "dist/moxi-pose-scene"
RENDERER = "Moxi Scene / SvgSceneRenderer"
ASSETS = {"/": ("index.html", "text/html; charset=utf-8"),
          "/model.js": ("model.js", "text/javascript; charset=utf-8"),
          "/replay.js": ("replay.js", "text/javascript; charset=utf-8")}


def render(binary, widths):
    if not isinstance(widths, list) or len(widths) != 2 or any(
        type(v) not in (int, float) or not math.isfinite(v) or not 4 <= v <= 28 for v in widths
    ):
        raise ValueError("expected two finite widths in [4,28] px")
    result = subprocess.run([str(binary), *(str(v) for v in widths)],
                            capture_output=True, text=True, timeout=10, check=True)
    svgs = result.stdout.splitlines()
    if len(svgs) != 2 or not all(s.startswith("<svg ") and s.endswith("</svg>") for s in svgs):
        raise RuntimeError("Moxi returned an invalid scene response")
    return svgs


def make_server(port=8765, binary=BINARY):
    binary = Path(binary).resolve()
    if not binary.is_file():
        raise FileNotFoundError("Build dist/moxi-pose-scene first (see the example README).")
    identity = {"renderer": RENDERER, "binary_sha256": hashlib.sha256(binary.read_bytes()).hexdigest()}

    class Handler(BaseHTTPRequestHandler):
        def reply(self, status, payload, content_type="application/json"):
            self.send_response(status)
            self.send_header("Content-Type", content_type)
            self.send_header("Content-Length", str(len(payload)))
            self.send_header("Cache-Control", "no-store")
            self.send_header("X-Content-Type-Options", "nosniff")
            self.end_headers()
            self.wfile.write(payload)

        def do_GET(self):
            if self.path == "/favicon.ico":
                self.reply(HTTPStatus.NO_CONTENT, b"")
            elif self.path in ASSETS:
                filename, content_type = ASSETS[self.path]
                self.reply(HTTPStatus.OK, (HERE / filename).read_bytes(), content_type)
            else:
                self.reply(HTTPStatus.NOT_FOUND, b'{"error":"Unknown asset"}')

        def do_POST(self):
            if self.path != "/scene":
                self.reply(HTTPStatus.NOT_FOUND, b'{"error":"Unknown operation"}')
                return
            origins = (None, f"http://127.0.0.1:{self.server.server_port}",
                       f"http://localhost:{self.server.server_port}")
            if self.headers.get("Origin") not in origins:
                self.reply(HTTPStatus.FORBIDDEN, b'{"error":"Use the loopback consumer"}')
                return
            try:
                size = int(self.headers.get("Content-Length", "0"))
                if not 0 < size <= 256:
                    raise ValueError("invalid scene request length")
                data = json.loads(self.rfile.read(size))
                if not isinstance(data, dict) or set(data) != {"widths"}:
                    raise ValueError("expected widths only")
                svgs = render(binary, data["widths"])
            except (ValueError, OverflowError) as error:
                self.reply(HTTPStatus.BAD_REQUEST, json.dumps({"error": str(error)}).encode())
                return
            except (OSError, subprocess.SubprocessError, RuntimeError):
                self.reply(HTTPStatus.SERVICE_UNAVAILABLE, b'{"error":"Moxi render failed; rebuild or restart the local host"}')
                return
            self.reply(HTTPStatus.OK, json.dumps({**identity, "svgs": svgs}).encode())

        def log_message(self, *_):
            pass

    return ThreadingHTTPServer(("127.0.0.1", port), Handler)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=8765)
    args = parser.parse_args()
    with make_server(args.port) as server:
        print(f"Pose consumer: http://127.0.0.1:{server.server_port}", flush=True)
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            pass
