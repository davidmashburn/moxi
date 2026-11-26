"""Loopback-only, single-instrument demo."""
import argparse
from http.server import BaseHTTPRequestHandler, HTTPServer
import json
from pathlib import Path

from instrument import Action, Caller, Instrument


class Handler(BaseHTTPRequestHandler):
    def send(self, code, mime, body):
        self.send_response(code)
        self.send_header("Content-Type", mime)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        instrument = self.server.instrument
        if self.path == "/":
            self.send(200, "text/html; charset=utf-8", Path(__file__).with_name("index.html").read_bytes())
        elif self.path == "/view":
            self.send(200, "application/json", json.dumps(instrument.view()).encode())
        elif self.path == "/recording.json" and instrument.recorded:
            self.send(200, "application/json", json.dumps(instrument.recorded.document(), indent=2).encode())
        else:
            self.send_error(404)

    def do_POST(self):
        if self.path not in ("/panel", "/script"):
            return self.send_error(404)
        if self.headers.get_content_type() != "application/json":
            return self.send_error(415)
        try:
            size = int(self.headers.get("Content-Length", 0))
            if not 0 < size <= 1024:
                return self.send_error(413)
            data = json.loads(self.rfile.read(size))
            caller = Caller.PANEL if self.path == "/panel" else Caller.SCRIPT
            message = self.server.instrument.apply(Action(data["action"]), data, caller)
            status = 200
        except (TypeError, KeyError, ValueError, OverflowError) as exc:
            message, status = str(exc), 400
        self.send(status, "application/json", json.dumps(dict(message=message)).encode())


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=8183)
    with HTTPServer(("127.0.0.1", parser.parse_args().port), Handler) as server:
        server.instrument = Instrument()
        print(f"Instrument at http://127.0.0.1:{server.server_port}/", flush=True)
        server.serve_forever()
