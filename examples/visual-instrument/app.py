"""Loopback-only, single-instrument demo."""
import argparse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
from threading import Lock

from instrument import Action, Caller, Instrument


class InstrumentServer(ThreadingHTTPServer):
    def __init__(self, address):
        super().__init__(address, Handler)
        self.instrument = Instrument()
        self.instrument_lock = Lock()


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
            return
        with self.server.instrument_lock:
            if self.path == "/view":
                body = json.dumps(instrument.view()).encode()
            elif self.path == "/recording.json" and instrument.recorded:
                body = json.dumps(instrument.recorded.document(), indent=2).encode()
            else:
                body = None
        if body is None:
            self.send_error(404)
        else:
            self.send(200, "application/json", body)

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
            with self.server.instrument_lock:
                message = self.server.instrument.apply(Action(data["action"]), data, caller)
            status = 200
        except (TypeError, KeyError, ValueError, OverflowError) as exc:
            message, status = str(exc), 400
        self.send(status, "application/json", json.dumps(dict(message=message)).encode())


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=8183)
    with InstrumentServer(("127.0.0.1", parser.parse_args().port)) as server:
        print(f"Instrument at http://127.0.0.1:{server.server_port}/", flush=True)
        server.serve_forever()
