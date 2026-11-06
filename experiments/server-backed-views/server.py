"""Loopback-only P02 transport; stdlib, synthetic data, no remote service API."""
from array import array
from enum import Enum
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from threading import Event, Lock
import argparse
import hashlib
import json
import sys
import time
import uuid
from urllib.parse import urlsplit
from probe import generate_points, validate_viewport, validate_grid_dimensions

GRID = 32
MAX_DETAILS = 32
MAX_RESPONSE = 65536
MAX_JOBS = 8
MAX_REQUEST = 4096
STATIC_FILES = {
    '/experiments/server-backed-views/' + name
    for name in ('index.html', 'demo.mjs', 'adapter.mjs', 'local.mjs',
                 'local-worker.mjs', 'dist/density.wasm')
} | {'/experiments/browser-moxi/runtime.mjs', '/native/hosts/moxi_web_host.mjs'}

class Kind(str, Enum):
    GRID = 'grid'
    DETAILS = 'details'

class Cancelled(Exception):
    pass

def wire_bytes(points):
    # Fixed little endian SoA: Float64 x[N], Float64 y[N], UInt32 stable IDs[N].
    parts = []
    for a in (points.x, points.y, points.source_ids):
        copy = array(a.typecode, a)
        if sys.byteorder != 'little':
            copy.byteswap()
        parts.append(copy.tobytes())
    return b''.join(parts)

def validate_request(data):
    if not isinstance(data, dict):
        raise ValueError('object required')
    for key in ('session', 'revision', 'query'):
        if not isinstance(data.get(key), str) or not 1 <= len(data[key]) <= 80:
            raise ValueError('invalid identity')
    if type(data.get('generation')) is not int or not 1 <= data['generation'] <= 2**31-1:
        raise ValueError('invalid generation')
    if type(data.get('delay')) is not int or not 0 <= data['delay'] <= 3000:
        raise ValueError('delay must be 0..3000ms')
    kind = Kind(data.get('kind'))
    viewport = validate_viewport(data.get('viewport'))
    if any(abs(x) > 10 for x in viewport) or min(viewport[2]-viewport[0], viewport[3]-viewport[1]) < .000001:
        raise ValueError('outside experimental camera range')
    if kind == Kind.GRID:
        validate_grid_dimensions(data.get('width'), data.get('height'))
        if data['width'] != GRID or data['height'] != GRID:
            raise ValueError('this view requires a 32 x 32 grid')
    elif type(data.get('cap')) is not int or not 1 <= data['cap'] <= MAX_DETAILS:
        raise ValueError('details cap must be 1..32')
    return kind, viewport

def reduce(points, request, cancelled):
    kind, (xmin, ymin, xmax, ymax) = validate_request(request)
    start = time.perf_counter()
    counts = [0] * (GRID * GRID)
    records = []
    total = 0
    for i, (x, y) in enumerate(zip(points.x, points.y)):
        if i % 4096 == 0 and cancelled.is_set():
            raise Cancelled()
        if xmin <= x < xmax and ymin <= y < ymax:
            total += 1
            if kind == Kind.GRID:
                c = min(GRID - 1, int((x-xmin)/(xmax-xmin)*GRID))
                r = min(GRID - 1, int((y-ymin)/(ymax-ymin)*GRID))
                counts[r*GRID+c] += 1
            elif len(records) < request['cap']:
                records.append({'id': points.source_ids[i], 'x': x, 'y': y})
    result = {key: request[key] for key in ('session', 'revision', 'query', 'generation', 'kind', 'viewport')}
    result.update(total=total, reducer_ms=(time.perf_counter()-start)*1000)
    if kind == Kind.GRID:
        result.update(width=GRID, height=GRID, counts=counts,
                      x_edges=[xmin+(xmax-xmin)*i/GRID for i in range(GRID+1)],
                      y_edges=[ymin+(ymax-ymin)*i/GRID for i in range(GRID+1)])
    else:
        result.update(records=records, truncated=total > len(records))
    return result

class Data:
    def __init__(self, points=None):
        self.points = generate_points() if points is None else points
        self.binary = wire_bytes(self.points)
        self.revision = hashlib.sha256(self.binary).hexdigest()
        self.epoch = str(uuid.uuid4())
        self.lock = Lock()
        self.jobs = {}
        self.cancelled = {}  # short-lived bounded tombstones cover cancel-before-start
        self.completed = self.cancellations = self.max_active = 0

    def cancel(self, session, query):
        with self.lock:
            now = time.monotonic()
            self.cancelled = {k:v for k,v in self.cancelled.items() if now-v < 30}
            key = (session, query)
            if key not in self.cancelled and len(self.cancelled) >= 256:
                raise ValueError('cancellation capacity; retry after 30 seconds')
            self.cancelled[key] = now
            job = self.jobs.get(session)
            if job and job[0] == query:
                job[1].set()

    def execute(self, request):
        validate_request(request)
        if request['revision'] != self.revision:
            raise ValueError('dataset revision changed; restart the view')
        session, query = request['session'], request['query']
        token = Event()
        with self.lock:
            if session in self.jobs or len(self.jobs) >= MAX_JOBS:
                raise ValueError('active query capacity')
            if (session, query) in self.cancelled:
                token.set()
            self.jobs[session] = (query, token)
            self.max_active = max(self.max_active, len(self.jobs))
        try:
            if token.wait(request['delay']/1000):
                raise Cancelled()
            result = reduce(self.points, request, token)
            if token.is_set():
                raise Cancelled()
            self.completed += 1
            return result
        except Cancelled:
            self.cancellations += 1
            return {key: request[key] for key in ('session', 'revision', 'query', 'generation', 'kind')} | {'cancelled': True}
        finally:
            with self.lock:
                del self.jobs[session]
                self.cancelled.pop((session, query), None)

class Handler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cache-Control', 'no-store')
        super().end_headers()

    def send(self, status, payload, content_type='application/json'):
        body = payload if isinstance(payload, bytes) else json.dumps(payload, separators=(',', ':'), allow_nan=False).encode()
        if content_type == 'application/json' and len(body) > MAX_RESPONSE:
            status, body = 500, b'{"error":"response cap exceeded"}'
        self.send_response(status)
        self.send_header('Content-Type', content_type)
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        try:
            self.wfile.write(body)
        except (BrokenPipeError, ConnectionResetError):
            pass

    def allowed(self):
        # No cross-origin control or DNS rebinding. Deliberately no CORS.
        host = self.headers.get('Host', '')
        expected = f'127.0.0.1:{self.server.server_port}'
        if host != expected or self.headers.get('Origin', f'http://{expected}') != f'http://{expected}':
            self.send(403, {'error':'loopback same-origin requests only'})
            return False
        return True

    def do_GET(self):
        if not self.allowed():
            return
        route = urlsplit(self.path).path
        data = self.server.data
        if route == '/api/meta':
            self.send(200, {'revision':data.revision, 'epoch':data.epoch, 'count':len(data.points), 'source_bytes':len(data.binary), 'grid':GRID, 'details_cap':MAX_DETAILS})
        elif route == '/api/source':
            self.send(200, data.binary, 'application/octet-stream')
        elif route == '/api/stats':
            with data.lock:
                result = {'active':len(data.jobs), 'max_active':data.max_active, 'cancelled':data.cancellations, 'completed':data.completed, 'tombstones':len(data.cancelled)}
            self.send(200, result)
        elif route in STATIC_FILES:
            super().do_GET()
        elif route == '/':
            # Canonical directory is required for relative modules and Wasm.
            query = urlsplit(self.path).query
            self.send_response(302)
            self.send_header('Location', '/experiments/server-backed-views/' + ('?' + query if query else ''))
            self.send_header('Content-Length', '0')
            self.end_headers()
        elif route == '/experiments/server-backed-views/':
            self.path = '/experiments/server-backed-views/index.html'
            super().do_GET()
        else:
            self.send(404, {'error':'outside experiment routes'})

    def do_POST(self):
        if not self.allowed():
            return
        try:
            size = int(self.headers.get('Content-Length', '0'))
            if not 1 <= size <= MAX_REQUEST:
                raise ValueError('request cap')
            data = json.loads(self.rfile.read(size))
            if self.path == '/api/query':
                self.send(200, self.server.data.execute(data))
            elif self.path == '/api/cancel':
                if not isinstance(data, dict) or any(not isinstance(data.get(k), str) or not 1 <= len(data[k]) <= 80 for k in ('session','query')):
                    raise ValueError('invalid cancellation identity')
                self.server.data.cancel(data['session'], data['query'])
                self.send(200, {'cancelled':True})
            else:
                self.send(404, {'error':'unknown operation'})
        except (ValueError, TypeError, KeyError) as error:
            self.send(400, {'error':str(error)})


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--port', type=int, default=8766)
    args = parser.parse_args()
    data = Data()
    server = ThreadingHTTPServer(('127.0.0.1', args.port), partial(Handler, directory=str(Path(__file__).resolve().parents[2])))
    server.data = data
    print(f'P02 ready: http://127.0.0.1:{args.port}/; revision={data.revision}', flush=True)
    server.serve_forever()

if __name__ == '__main__':
    main()
