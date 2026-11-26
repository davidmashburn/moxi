"""Serve a self-contained instrument page on loopback."""
import argparse
import csv
from http.server import BaseHTTPRequestHandler, HTTPServer
import json
from pathlib import Path

import moxi

HERE = Path(__file__).resolve().parent


def make_page():
    # Sonify the first eight observations as a pitch contour around middle C.
    with (HERE.parent / "data/workbench-tail.csv").open() as source:
        pitches = [60 + round(float(row["value"])) for row in list(csv.DictReader(source))[:8]]
    curves = {}
    for midpoint in (25, 50, 75):
        values = [round(midpoint * x / 50 if x <= 50 else
                        midpoint + (100 - midpoint) * (x - 50) / 50) for x in range(101)]
        spec = moxi.PlotSpec("Response")
        spec.add_line("Output (%)", "input", "output", (0.12, 0.45, 0.42, 1))
        svg = moxi.plot({"input": list(range(101)), "output": values}, spec,
                        width=420, height=155).to_svg().decode()
        curves[midpoint] = {"values": values, "svg": svg}
    return (HERE / "index.html").read_text().replace("__INSTRUMENT__", json.dumps(
        {"pitches": pitches, "curves": curves})).encode()


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=8182)
    port = parser.parse_args().port
    page = make_page()

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            if self.path != "/":
                return self.send_error(404)
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(page)))
            self.end_headers()
            self.wfile.write(page)

    with HTTPServer(("127.0.0.1", port), Handler) as server:
        print(f"Phrase desk at http://127.0.0.1:{server.server_port}/", flush=True)
        server.serve_forever()
