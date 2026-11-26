"""V08. Run with PYTHONPATH=python python3 examples/probability-instrument/instrument.py."""
import argparse
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from xml.etree import ElementTree as ET

from moxi import Figure, PlotSpec

INITIAL = (0.25, 0.5, 0.25)
EPSILON = 1e-12


def mean(mass):
    return mass[1] + 2 * mass[2]


def redistribute(mass, outcome, target, pinned):
    """Split the residual between the two free outcomes."""
    if len(mass) != 3 or not all(0 <= p <= 1 for p in mass) or abs(sum(mass) - 1) > EPSILON:
        raise ValueError("Invalid starting distribution")
    if type(outcome) is not int or outcome not in range(3) or type(pinned) is not bool:
        raise ValueError("Invalid edit")
    if not 0 <= target <= 1:
        raise ValueError("Enter a probability between 0 and 1.")
    low, high = (i for i in range(3) if i != outcome)
    remaining = 1 - target
    if pinned:
        required = mean(mass) - outcome * target
        if not low * remaining - EPSILON <= required <= high * remaining + EPSILON:
            raise ValueError(
                f"With P({outcome}) = {target:g}, the possible mean is "
                f"{outcome * target + low * remaining:g} to "
                f"{outcome * target + high * remaining:g}. The pinned mean is {mean(mass):g}."
            )
        high_share = (required - low * remaining) / (high - low)
        high_share = min(remaining, max(0, high_share))
    else:
        previous = mass[low] + mass[high]
        high_share = remaining * (mass[high] / previous if previous else 0.5)
    result = list(mass)
    result[outcome], result[low], result[high] = target, remaining - high_share, high_share
    return result


def chart(mass):
    spec = PlotSpec()
    layer = spec.add_stacked_bar(y_field="mass")
    spec.specialize(layer, series_fields=["mass", "room"])
    data = {"x": [0, 1, 2], "mass": mass, "room": [1 - p for p in mass]}
    svg = Figure(data, spec, width=600, height=220).to_svg().decode()
    # Place outcome labels under the rendered marks, independent of margins.
    bars = ET.fromstring(svg).findall(".//{*}rect[@data-mark]")
    labels = []
    for outcome, bar in enumerate(bars[::2]):
        center = float(bar.get("x")) + float(bar.get("width")) / 2
        labels.append(f'<text x="{center:g}" y="213" text-anchor="middle">{outcome}</text>')
    return svg.replace("</svg>", "".join(labels) + "</svg>")


class Handler(BaseHTTPRequestHandler):
    def reply(self, code, mime, data):
        self.send_response(code)
        self.send_header("Content-Type", mime)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path != "/":
            self.send_error(404)
            return
        page = Path(__file__).with_name("instrument.html").read_text()
        basis = Path(__file__).with_name("triangle.json").read_text()
        page = page.replace("<!--chart-->", chart(INITIAL)).replace("/*basis*/", basis)
        self.reply(200, "text/html; charset=utf-8", page.encode())

    def do_POST(self):
        if self.path != "/preview":
            self.send_error(404)
            return
        try:
            size = int(self.headers.get("Content-Length", "0"))
            if not 0 < size <= 2048:
                raise ValueError("Invalid request size")
            mass = redistribute(**json.loads(self.rfile.read(size)))
            payload = {"mass": mass, "svg": chart(mass)}
        except (KeyError, TypeError, ValueError, OverflowError) as error:
            self.reply(400, "application/json", json.dumps({"error": str(error)}).encode())
            return
        self.reply(200, "application/json", json.dumps(payload).encode())


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=8038)
    args = parser.parse_args()
    with ThreadingHTTPServer(("127.0.0.1", args.port), Handler) as server:
        print(f"http://127.0.0.1:{server.server_port}", flush=True)
        server.serve_forever()
