"""Serve the local instrument and its bounded response-calculation builder."""
import argparse
import csv
from http.server import BaseHTTPRequestHandler, HTTPServer
import json
from pathlib import Path

import moxi

HERE = Path(__file__).resolve().parent
CALCULATION_VERSION = 1
MAX_BUILD_BYTES = 2048


def build_curve(calculation):
    """Compile a versioned, two-segment response. No executable input is accepted."""
    if not isinstance(calculation, dict) or type(calculation.get("version")) is not int \
            or calculation["version"] != CALCULATION_VERSION:
        raise ValueError("Unsupported response calculation version.")
    midpoint = calculation.get("midpoint")
    if type(midpoint) is not int or not 0 <= midpoint <= 100:
        raise ValueError("Output at half input must be a whole number from 0 to 100.")
    values = [round(midpoint * x / 50 if x <= 50 else
                    midpoint + (100 - midpoint) * (x - 50) / 50) for x in range(101)]
    spec = moxi.PlotSpec("Response")
    spec.add_line("Output (%)", "input", "output", (0.12, 0.45, 0.42, 1))
    svg = moxi.plot({"input": list(range(101)), "output": values}, spec,
                    width=420, height=155).to_svg().decode()
    return {"values": values, "svg": svg}


def make_page():
    # Sonify the first eight observations as a pitch contour around middle C.
    with (HERE.parent / "data/workbench-tail.csv").open() as source:
        pitches = [60 + round(float(row["value"])) for row in list(csv.DictReader(source))[:8]]
    curves = {}
    for midpoint in (25, 50, 75):
        curves[midpoint] = build_curve({"version": CALCULATION_VERSION, "midpoint": midpoint})
    return (HERE / "index.html").read_text().replace("__INSTRUMENT__", json.dumps(
        {"pitches": pitches, "curves": curves})).encode()


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=8182)
    port = parser.parse_args().port
    page = make_page()

    class Handler(BaseHTTPRequestHandler):
        def do_POST(self):
            if self.path != "/build":
                return self.send_error(404)
            try:
                size = int(self.headers.get("Content-Length", "0"))
                if not 0 < size <= MAX_BUILD_BYTES:
                    raise ValueError("Response build request is too large or empty.")
                calculations = json.loads(self.rfile.read(size))
                if not isinstance(calculations, list) or not 1 <= len(calculations) <= 2:
                    raise ValueError("Build one or two supported response calculations.")
                result = {"curves": [build_curve(c) for c in calculations]}
                status = 200
            except (ValueError, UnicodeDecodeError) as error:
                result, status = {"error": str(error)}, 400
            except Exception:
                result, status = {"error": "Response renderer could not build this calculation."}, 500
            body = json.dumps(result).encode()
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

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
