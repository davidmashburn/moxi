"""Serve immutable local views. Each URL is a replayable synthetic snapshot."""
import argparse
from dataclasses import replace
from html import escape
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlencode, urlsplit
from xml.etree import ElementTree as ET

from moxi import Figure, PlotSpec
from model import COLLECTIONS, Domain, View

SVG = "{http://www.w3.org/2000/svg}"
ET.register_namespace("", SVG[1:-1])
STYLE = Path(__file__).with_name("style.css").read_text()


def url(view, **changes):
    state = replace(view, **changes)
    return "?" + urlencode(dict(domain=state.domain.value, selected=state.selected,
                                deleted=state.deleted, filtered=int(state.filtered),
                                grouped=int(state.grouped)), doseq=True)


def plot(view):
    marks = view.marks()
    if not marks:
        return "<p>No visible marks.</p>"
    spec = PlotSpec()
    spec.add_scatter("Visible sources", color=(0.03, 0.42, 0.43, 1))
    figure = Figure([dict(x=m.x, y=m.y) for m in marks], spec, width=360, height=220)
    tree = ET.fromstring(figure.to_svg())
    for group in tree.iter(SVG + "g"):
        for circle in group.findall(SVG + "circle"):
            hit = figure.hit_test(float(circle.get("cx")), float(circle.get("cy")))
            mark = marks[hit["row_index"]]
            label = "Select " + ", ".join(mark.members)
            link = ET.SubElement(group, SVG + "a", href=url(view, selected=mark.members),
                                 attrib={"aria-label": label})
            ET.SubElement(link, SVG + "title").text = label
            group.remove(circle)
            link.append(circle)
            circle.set("r", "9")
            if set(view.selected).intersection(mark.members):
                circle.set("class", "picked")
    return ET.tostring(tree, encoding="unicode")


def render(view, message=""):
    data = view.collection
    def action(label, href, active=False, style=""):
        return (f'<a class="button {"picked" if active else ""}" style="{style}" '
                f'href="{escape(href, quote=True)}">{escape(label)}</a>')
    rows, cards = [], []
    for row in view.visible():
        def pick(style=""):
            return action(row.key, url(view, selected=(row.key,)), row.key in view.selected, style)
        rows.append(f"<tr><td>{pick()}</td><td>{row.group}</td><td>{row.x}</td><td>{row.y}</td></tr>")
        cards.append(pick(f"left:{row.left}%;top:{row.top}%"))
    refs = " · ".join(f"{r.key} ({view.visibility(r).value})" for r in data.sources
                      if r.key in view.selected) or "No source selected"
    other = next(d for d in Domain if d != view.domain)
    mode = "Group means" if view.grouped else "Individual readings"
    controls = [
        action("Show all values" if view.filtered else f"{data.measure} ≥ {data.threshold}",
               url(view, filtered=not view.filtered), view.filtered),
        action("Individual marks" if view.grouped else "Group means", url(view, grouped=not view.grouped)),
        action("Delete selection", url(view) + "&delete=1"),
        action("Reset collection", url(View(view.domain))),
    ]
    return f"""<!doctype html><html lang="en"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>{data.title} · Source atlas</title><style>{STYLE}</style>
<main><header><div>Source atlas</div>{action(COLLECTIONS[other].title, url(View(other)))}</header>
<h1>{data.title}</h1><nav aria-label="View controls">{' '.join(controls)}</nav>
<p class="status"><b>Selected sources</b>　{refs}</p>
{f'<p role="alert">{escape(message)}</p>' if message else ''}
<div class="panels"><section><h2>Source table</h2><table><thead><tr>
<th>ID</th><th>Group</th><th>{data.axes.split(' × ')[0]}</th><th>{data.measure}</th></tr></thead>
<tbody>{''.join(rows)}</tbody></table></section>
<section><h2>{mode}</h2><div id="plot">{plot(view)}</div><p>{data.axes}</p></section>
<section><h2>{data.canvas}</h2><div class="canvas">{''.join(cards)}</div></section></div>
<footer>Synthetic collection · Select a row, mark or location. Group marks select all contributing sources.</footer></main></html>"""


def snapshot(query):
    params = parse_qs(query)
    view = View(Domain(params.get("domain", [Domain.SPECIMEN.value])[0]),
                tuple(params.get("selected", [])), tuple(params.get("deleted", [])),
                params.get("filtered") == ["1"], params.get("grouped") == ["1"])
    if params.get("delete") == ["1"]:
        try:
            return 303, url(view.delete())
        except ValueError as error:
            return 200, render(view, str(error))
    return 200, render(view)


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        parts = urlsplit(self.path)
        if parts.path != "/":
            self.send_error(404)
            return
        try:
            status, body = snapshot(parts.query)
        except ValueError:
            self.send_error(400, "Unknown collection or invalid source reference")
            return
        self.send_response(status)
        if status == 303:
            self.send_header("Location", body)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.end_headers()
        if status == 200:
            self.wfile.write(body.encode())


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=8118)
    server = ThreadingHTTPServer(("127.0.0.1", parser.parse_args().port), Handler)
    print(f"http://127.0.0.1:{server.server_port}/", flush=True)
    server.serve_forever()
