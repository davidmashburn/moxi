"""Loopback-only, stateless Moxi rendering service for the matrix instrument."""
import argparse
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit

from matrix import Matrix

ROOT = Path(__file__).resolve().parent
MAX_BODY = 1024
ASSETS = {"/": ("index.html", "text/html"), "/instrument.js": ("instrument.js", "text/javascript"),
          "/style.css": ("style.css", "text/css")}


class Handler(BaseHTTPRequestHandler):
    def respond(self, status, mime, body):
        self.send_response(status)
        self.send_header("Content-Type", mime + "; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        try:
            self.wfile.write(body)
        except (BrokenPipeError, ConnectionResetError):
            pass  # Newer matrix revisions may abort the previous render request.

    def do_GET(self):
        asset = ASSETS.get(urlsplit(self.path).path)
        if asset:
            name, mime = asset
            self.respond(200, mime, (ROOT / name).read_bytes())
        elif self.path == "/favicon.ico":
            self.respond(204, "image/x-icon", b"")
        else:
            self.send_error(404)

    def do_POST(self):
        if self.path != "/render":
            self.send_error(404)
            return
        try:
            size = int(self.headers.get("Content-Length", "0"))
            if not 0 < size <= MAX_BODY:
                raise ValueError("Expected a small JSON matrix request.")
            payload = json.loads(self.rfile.read(size))
            if not isinstance(payload, dict) or not isinstance(payload.get("matrix"), list):
                raise ValueError("Expected a matrix array.")
            result = Matrix(tuple(payload["matrix"])).render()
            self.respond(200, "application/json", json.dumps(result).encode())
        except (ValueError, TypeError) as exc:
            self.respond(400, "application/json", json.dumps(dict(error=str(exc))).encode())


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=0)
    server = ThreadingHTTPServer(("127.0.0.1", parser.parse_args().port), Handler)
    print(f"Matrix instrument: http://127.0.0.1:{server.server_port}/", flush=True)
    server.serve_forever()
