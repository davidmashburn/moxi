"""Capture a real Moxi figure inspector and verify the offline gallery in Chrome."""
import argparse
import base64
import html
import json
import hashlib
import subprocess
import platform
from datetime import datetime, timezone
import re
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from threading import Thread
from urllib.parse import urlparse, parse_qs
from xml.etree import ElementTree as ET

from moxi import PlotSpec, plot
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[2]
PIN = "3fd5a7e7c622d6130c99a290b88c4fee039deab2"
WIDTH, HEIGHT = 640, 420


def fixture(family):
    if family == "arc_diagram":
        data = {"source": ["A","B","C"], "target": ["C","A","B"], "weight": [3,9,6]}
        spec = PlotSpec()
        spec.specialize(spec.add_catalog_mark(family, "Edges", "source", "weight", x2_field="target"))
        return plot(data,spec,width=WIDTH,height=HEIGHT)
    data = {"team": ["East", "West"], "A": [3, 8], "B": [9, 4], "C": [6, 7]}
    spec = PlotSpec()
    spec.specialize(spec.add_catalog_mark(family, "Teams", "team", "A"),
                    series_fields=["B", "C"])
    return plot(data, spec, width=WIDTH, height=HEIGHT)


def compare(family, reference, python_svg, native_svg):
    """Compare ordered segment endpoints after mapping each drawing to its extent."""
    reference_paths = ET.fromstring(reference).findall(".//{*}path")
    if family == "arc_diagram":
        compare_arcs(reference_paths, python_svg, native_svg)
        return
    expected = []
    for path in reference_paths:
        coords = list(map(float, re.findall(r"-?[\d.]+", path.attrib["d"])))
        expected.append(list(zip(coords[::2], coords[1::2])))
    segments = [(start, end) for path in expected for start, end in zip(path, path[1:])]

    def normalize(lines):
        points = [point for line in lines for point in line]
        xs, ys = zip(*points)
        return sorted(tuple(round((v - lo) / (hi - lo), 4)
                            for point in line for v, lo, hi in zip(point, map(min, (xs, ys)), map(max, (xs, ys))))
                      for line in lines)

    for svg in [python_svg, native_svg]:
        lines = []
        for item in ET.fromstring(svg).findall(".//{*}line"):
            a = item.attrib
            if a["x1"] != a["x2"] and a["y1"] != a["y2"]:
                lines.append(tuple((float(a["x"+i]), float(a["y"+i])) for i in ["1", "2"]))
        assert normalize(lines) == normalize(segments), lines


def compare_arcs(reference_paths, python_svg, native_svg):
    """Check radii, endpoints and stroke widths against upstream's SVG arcs."""
    def numbers(path):
        return list(map(float, re.findall(r"-?[0-9]+(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?", path)))

    targets = []
    for arc in reference_paths:
        x,y,r,ry,_,_,_,end,baseline = numbers(arc.attrib["d"])
        assert r == ry and y == baseline and end-x == 2*r
        targets.append((x,end,float(arc.attrib["stroke-width"])))
    root = ET.fromstring(python_svg)
    groups = []
    for group in root.findall(".//{*}g"):
        lines = group.findall("{*}line")
        if not lines: continue
        pts = [(float(line.attrib["x1"]),float(line.attrib["y1"])) for line in lines]
        pts.append((float(lines[-1].attrib["x2"]),float(lines[-1].attrib["y2"])))
        groups.append((pts, float(lines[0].attrib["stroke-width"])))
    native = []
    for path in ET.fromstring(native_svg).findall(".//{*}path"):
        coords = numbers(path.attrib["d"])
        native.append((list(zip(coords[::2], coords[1::2])),float(path.attrib["stroke-width"])))
    for drawing in (groups,native):
        assert len(drawing) == len(targets)
        left = min(points[0][0] for points,_ in drawing)
        right = max(points[-1][0] for points,_ in drawing)
        for (points, stroke), (start,end,width) in zip(drawing,targets):
            assert abs(stroke-width)<.001
            assert abs((points[0][0]-left)/(right-left)-(start-60)/560)<.0001
            assert abs((points[-1][0]-left)/(right-left)-(end-60)/560)<.0001
            cx = (points[0][0]+points[-1][0])/2
            cy = points[0][1]
            radius = cx-points[0][0]
            assert len(points) == 49
            for x,y in points:
                assert y <= cy+.002 and abs(((x-cx)**2+(y-cy)**2)**.5-radius)<.002


STYLE = """body{font:16px system-ui;color:#13283b;margin:16px;background:#fff}
main{display:flex;align-items:flex-start;gap:16px}table{border-collapse:collapse}
td,th{padding:6px;border-bottom:1px solid #ccd}tr.selected{background:#ffe7ae}
img,svg{max-width:100%}button{font:inherit;margin:4px}h1{font-size:24px}"""


def replay(family, native, output):
    fig = fixture(family)
    svg = fig.to_svg()
    ref = (ROOT / f"tests/fixtures/plot_catalog/{family}.svg").read_bytes()
    compare(family, ref, svg, native)
    rows = fig.table()
    fields = list(rows[0])
    table = "<table><tr>" + "".join(f"<th>{html.escape(f)}</th>" for f in fields) + "</tr>"
    for row in rows:
        table += '<tr data-row="%d">' % row["row_index"] + "".join(
            f"<td>{html.escape(str(row[f]))}</td>" for f in fields) + "</tr>"
    app = f"""<style>{STYLE}</style><h1>{family.replace('_',' ').title()} source inspector</h1>
    <main><section id="chart">{svg.decode()}</section><section>{table}</table>
    <p id="status">Select a record</p><button id="clear">Clear selection</button></section></main>
    <script>function select(row){{document.querySelectorAll('[data-row]').forEach(
    tr=>tr.classList.toggle('selected', Number(tr.dataset.row)===row));
    statusText.textContent=row===null?'Select a record':'Selected source row '+row}}
    const statusText=document.querySelector('#status');
    chart.onclick=async e=>{{const b=chart.getBoundingClientRect();
    const r=await fetch('/hit?x='+(e.clientX-b.left)+'&y='+(e.clientY-b.top));
    select(await r.json())}};clearSelection=()=>select(null);
    document.querySelector('#clear').onclick=clearSelection;
    document.onkeydown=e=>{{if(e.key==='Escape')clearSelection()}}</script>"""

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            req = urlparse(self.path)
            body = app.encode()
            if req.path == "/hit":
                q = parse_qs(req.query)
                hit = fig.hit_test(float(q["x"][0]), float(q["y"][0]))
                body = json.dumps(hit["row_index"] if hit else None).encode()
            self.send_response(200)
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, *args):
            pass

    output.mkdir(parents=True, exist_ok=True)
    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    Thread(target=server.serve_forever, daemon=True).start()
    slides = []

    def capture(page, name, caption):
        path = output / (name + ".png")
        page.screenshot(path=str(path))
        slides.append((caption, path))

    with sync_playwright() as pw:
        browser = pw.chromium.launch(channel="chrome")
        page = browser.new_page(viewport={"width": 1100, "height": 540}, device_scale_factor=1)
        def show(title, content):
            page.set_content(f"<style>{STYLE}</style><h1>{title}</h1>{content}")
        show("Source fixture", table + "</table>")
        capture(page, "source", "Source table in input order")
        show("Pinned upstream reference", ref.decode())
        capture(page, "reference", "dataviz_mojo v0.8.0")
        show("Mojo PlotView", native.decode())
        capture(page, "native", "Native Scene exported through SvgSceneRenderer (offscreen)")
        page.goto(f"http://127.0.0.1:{server.server_port}")
        capture(page, "initial", "Python figure and source inspector")
        picked = set()
        for _, geometry in fig._render_geometries():
            if geometry.interactive and geometry.segments and geometry.source_row not in picked:
                x,y,xx,yy = geometry.segments[len(geometry.segments)//2]
                page.locator("#chart").click(position={"x": .75*x+.25*xx, "y": .75*y+.25*yy})
                page.locator(f'tr.selected[data-row="{geometry.source_row}"]').wait_for(timeout=3000)
                picked.add(geometry.source_row)
        assert picked == set(range(len(rows)))
        capture(page, "selected", "Click a line to select its original source row")
        page.keyboard.press("Escape")
        assert page.locator("tr.selected").count() == 0
        capture(page, "reset", "Escape clears the selection")
        show("Export comparison", '<main>'+''.join('<section>'+title+'<br><img width="490" src="data:image/svg+xml;base64,'+base64.b64encode(blob).decode()+'"></section>' for title,blob in [('Reference',ref),('Moxi SVG',svg)])+'</main>')
        capture(page, "comparison", "Compare normalized geometry across different margins, palettes and legends")
        report = f"<style>{STYLE}#thumbs img{{width:100px}}</style><h1>{family} · E06</h1><img id=frame width=880><p id=caption></p><button id=prev>Previous</button><button id=next>Next</button><div id=thumbs></div>"
        images = ["data:image/png;base64,"+base64.b64encode(p.read_bytes()).decode() for _,p in slides]
        report += "<script>const images="+json.dumps(images)+", captions="+json.dumps([s for s,_ in slides])+""";let i=0;
        function show(n){i=(n+images.length)%images.length;frame.src=images[i];caption.textContent=captions[i]}
        images.forEach((src,n)=>{let b=document.createElement('button'),img=new Image();img.src=src;
        b.append(img);b.onclick=()=>show(n);b.title=captions[n];thumbs.append(b)});
        prev.onclick=()=>show(i-1);next.onclick=()=>show(i+1);
        document.onkeydown=e=>{if(e.key==='ArrowRight')next.click();if(e.key==='ArrowLeft')prev.click()};show(0)</script>"""
        index = output / "index.html"
        index.write_text(report)
        page.context.set_offline(True)
        page.goto(index.resolve().as_uri())
        for caption,_ in slides:
            assert page.locator("#caption").inner_text() == caption
            assert page.locator("#frame").evaluate("img=>img.complete && img.naturalWidth===1100")
            page.keyboard.press("ArrowRight")
        page.locator("#thumbs button").last.click()
        page.locator("#prev").click()
        assert page.locator("#caption").inner_text() == slides[-2][0]
        metadata = {
            "demo": family, "captured_utc": datetime.now(timezone.utc).isoformat(),
            "host": platform.system()+" "+platform.machine(),
            "browser": "Chrome "+browser.version, "viewport": [1100,540], "scale": 1,
            "figure_size": [WIDTH,HEIGHT], "fixture": rows, "reference_revision": PIN,
            "checkout_base": subprocess.check_output(["git","rev-parse","HEAD"],cwd=ROOT,text=True).strip(),
            "source_sha256": {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
                              for path in [Path(__file__).resolve(), ROOT/f"examples/catalog-remainder/{family}/main.mojo",
                                           ROOT/"python/moxi/figure.py", ROOT/"python/moxi/specialized.py",
                                           ROOT/"src/moxi_plot/plot_layout.mojo", ROOT/"src/moxi_plot/plotting.mojo",
                                           ROOT/"src/moxi_plot/plot_point.mojo"]},
            "command": f"PYTHONPATH=python python examples/catalog-remainder/replay.py {family} NATIVE_SVG OUTPUT_DIR",
            "native_backend": "offscreen Mojo PlotView / SvgSceneRenderer",
            "screenshots": [{"file": path.name,"observation": caption} for caption,path in slides],
            "browser_checks": ["source rows selected by chart clicks","Escape clears selection",
                               "offline keyboard next wraps","thumbnail and Previous navigate"],
        }
        (output/"capture.json").write_text(json.dumps(metadata,indent=2)+"\n")
        browser.close()
    server.shutdown()
    for suffix in ("svg","pdf","png"):
        fig.save(output / ("export."+suffix))
    (output / "native.svg").write_bytes(native)
    print(f"{family}: {len(rows)} source picks, reference geometry, exports and offline navigation passed")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("family")
    parser.add_argument("native", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    replay(args.family, args.native.read_bytes(), args.output)
