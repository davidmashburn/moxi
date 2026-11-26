"""Run with PYTHONPATH=python python3 examples/flight-recorder/app.py."""
import argparse
import asyncio
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path

from recorder import CaptureMode, MAX_BYTES, capture, inspect_episode


class Handler(BaseHTTPRequestHandler):
    def respond(self, status, mime, body):
        self.send_response(status)
        self.send_header("Content-Type", mime)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path != "/":
            return self.send_error(404)
        self.respond(200, "text/html; charset=utf-8", Path(__file__).with_name("index.html").read_bytes())

    def do_POST(self):
        try:
            size = int(self.headers.get("Content-Length", -1))
            if not 0 <= size <= MAX_BYTES:
                return self.send_error(413)
            data = json.loads(self.rfile.read(size))
            if self.path == "/capture":
                data = asyncio.run(capture(CaptureMode(data)))
            elif self.path != "/open":
                return self.send_error(404)
            body = inspect_episode(data)
        except (ValueError, RecursionError) as exc:
            return self.respond(400, "text/plain", str(exc).encode())
        self.respond(200, "application/json", json.dumps(body).encode())


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=8175)
    args = parser.parse_args()
    with ThreadingHTTPServer(("127.0.0.1", args.port), Handler) as server:
        print(f"Flight recorder at http://127.0.0.1:{server.server_port}/", flush=True)
        server.serve_forever()
