"""Local consumer, with an ephemeral port by default."""
import argparse
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlsplit

from lesson import BASE, TRANSFER, Spring, comparison

ROOT = Path(__file__).resolve().parent


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        url = urlsplit(self.path)
        if url.path == "/run":
            query = parse_qs(url.query)
            try:
                def number(key):
                    return float(query[key][0])
                result = comparison(Spring(number("m"), number("k"), number("a")), number("t"))
            except (KeyError, ValueError, OverflowError) as exc:
                self.respond(400, "application/json", json.dumps({"error": str(exc)}).encode())
                return
            self.respond(200, "application/json", json.dumps(result).encode())
        elif url.path == "/cases":
            data = {key: vars(value) for key, value in (("reference", BASE), ("transfer", TRANSFER))}
            self.respond(200, "application/json", json.dumps(data).encode())
        elif url.path in ("/", "/lesson.js", "/style.css"):
            file, mime = {"/": ("index.html", "text/html"), "/lesson.js": ("lesson.js", "text/javascript"),
                          "/style.css": ("style.css", "text/css")}[url.path]
            self.respond(200, mime, (ROOT / file).read_bytes())
        else:
            self.send_error(404)

    def respond(self, status, mime, content):
        self.send_response(status)
        self.send_header("Content-Type", mime + "; charset=utf-8")
        self.send_header("Content-Length", str(len(content)))
        self.end_headers()
        self.wfile.write(content)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=0)
    server = ThreadingHTTPServer(("127.0.0.1", parser.parse_args().port), Handler)
    print(f"http://127.0.0.1:{server.server_port}/", flush=True)
    server.serve_forever()
