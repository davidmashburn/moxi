"""Build an offline I21 consumer using Moxi's public trajectory projection."""
import argparse
import json
import math
from pathlib import Path
import xml.etree.ElementTree as ET

from moxi import PlotSpec, plot

HERE = Path(__file__).resolve().parent


def build(destination):
    # Adapt the public spring-linkage consumer's common-scale anchors. Moxi
    # projects every trace sample; the browser only scales that rigid arm.
    angles = range(91)
    spec = PlotSpec("Linkage endpoint (mm)")
    spec.add_line("Quarter-circle trace", "x", "y")
    figure = plot({
        "x": [0, *[140 * math.cos(math.radians(a)) for a in angles], 140],
        "y": [0, *[140 * math.sin(math.radians(a)) for a in angles], 140],
    }, spec, width=384, height=360)
    svg = ET.fromstring(figure.to_svg())
    points = [[float(v) for v in p.split(',')]
              for p in svg.find('.//{*}polyline').attrib['points'].split()]
    projection = dict(origin=points[0], maximum=points[-1], trace=points[1:-1])
    app = (HERE / 'app.mjs').read_text()
    app = '\n'.join(line for line in app.splitlines() if not line.startswith('import '))
    script = (HERE / 'model.mjs').read_text() + '\n' + app
    page = (HERE / 'editor.html').read_text().replace('/* PROJECTION */null', json.dumps(projection))
    destination.write_text(page.replace('/* APP */', script))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path)
    build(parser.parse_args().output)
