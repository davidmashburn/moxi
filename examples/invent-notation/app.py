"""Local V03 browser host and Moxi reference plot endpoint."""
import argparse
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

from moxi import PlotSpec, plot

ROOT = Path(__file__).resolve().parent
ASSETS = {"index.html": "text/html", "score.mjs": "text/javascript",
          "persistence.mjs": "text/javascript", "studio.mjs": "text/javascript", "studio.css": "text/css"}


class Handler(BaseHTTPRequestHandler):
    def reply(self, status, mime, body):
        self.send_response(status)
        self.send_header("Content-Type", mime)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        name = self.path.removeprefix("/") or "index.html"
        if name in ASSETS:
            self.reply(200, ASSETS[name], (ROOT / name).read_bytes())
        else:
            self.send_error(404)

    def do_POST(self):
        if self.path != "/curve":
            return self.send_error(404)
        try:
            size = int(self.headers.get("Content-Length", 0))
            if not 1 <= size <= 16000:
                raise ValueError()
            values = json.loads(self.rfile.read(size))
            if not isinstance(values, list) or not 2 <= len(values) <= 513 or not all(
                type(v) in (float, int) and 0 <= v <= 4000 for v in values
            ):
                raise ValueError()
        except (TypeError, ValueError):
            return self.send_error(400, "Invalid angle samples")
        spec = PlotSpec("Score angle")
        spec.add_line("Joint rotation", "sample", "angle")
        figure = plot({"sample": list(range(len(values))), "angle": values}, spec, width=470, height=100)
        self.reply(200, "image/svg+xml", figure.to_svg())


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=8763)
    server = ThreadingHTTPServer(("127.0.0.1", parser.parse_args().port), Handler)
    print(f"http://127.0.0.1:{server.server_port}", flush=True)
    server.serve_forever()
