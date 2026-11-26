"""Local I13 consumer. Start with `pixi run execution-debugger`."""

import argparse
from enum import Enum
import hashlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import shutil
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(ROOT / "python"))
sys.path.insert(0, str(HERE.parent / "flight-recorder"))
from recorder import MAX_BYTES, inspect_episode  # Reuse I15's boundary contract.

BINARY = ROOT / "dist/execution-debugger/runner"
FIXTURE = HERE.parent / "flight-recorder/evidence/episode.json"
MISSING_FIXTURE = HERE.parent / "flight-recorder/evidence/missing.json"
MAX_REQUEST = MAX_BYTES + 1024


class ReplayMode(str, Enum):
    LOCALIZED = "localized"
    BROAD = "broad"


def build():
    """Always compile this checkout, rather than silently reuse a stale binary."""
    mojo = shutil.which("mojo")
    if not mojo:
        raise RuntimeError("Mojo is missing. Start in the repository's pixi environment.")
    BINARY.parent.mkdir(parents=True, exist_ok=True)
    clock = BINARY.parent / "clock.o"
    subprocess.run(["cc", "-O2", "-c", str(ROOT / "native/benchmark_clock.c"),
                    "-o", str(clock)], check=True)
    subprocess.run([mojo, "build", "-I", str(ROOT / "src"), "-Xlinker", str(clock),
                    str(HERE / "runner.mojo"), "-o", str(BINARY)], check=True)


def replay(episode, mode, capacity):
    if not isinstance(mode, ReplayMode):
        raise ValueError("Expected a parsed ReplayMode.")
    if type(capacity) is not int or not 1 <= capacity <= 32:
        raise ValueError("Trace capacity must be an integer from 1 to 32.")
    if len(json.dumps(episode).encode()) > MAX_BYTES:
        raise ValueError("Episode exceeds I15's 8192-byte limit.")
    inspected = inspect_episode(episode)
    peak = episode.get("result")
    args = [str(BINARY), str(int(mode is ReplayMode.BROAD)), str(capacity),
            str(peak["peak"] if peak else -1)]
    args.extend(str(value) for row in episode["samples"] for value in row)
    output = subprocess.run(args, check=True, capture_output=True, text=True, timeout=15)
    summary, *records = [json.loads(line) for line in output.stdout.splitlines()]
    # A disabled-trace control executes identical dispatch/build work. This is a
    # short diagnostic measurement, not a stable latency or overhead benchmark.
    args[2] = "0"
    control = json.loads(subprocess.run(args, check=True, capture_output=True,
                                       text=True, timeout=15).stdout)
    if (summary["final"], summary["builds"]) != (control["final"], control["builds"]):
        raise RuntimeError("Tracing changed the replay's state or build counts.")
    return {
        "mode": mode.value, "capacity": capacity, "summary": summary, "records": records,
        "control_dispatch_ns": control["dispatch_ns"],
        "source_dropped": episode["dropped"], "missing_ticks": inspected["missing"],
        "missing_result": peak is None,
        "episode_id": hashlib.sha256(json.dumps(episode, sort_keys=True).encode()).hexdigest(),
        "episode": episode,
    }


class Handler(BaseHTTPRequestHandler):
    def respond(self, status, mime, body):
        self.send_response(status)
        self.send_header("Content-Type", mime)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        routes = {
            "/": (HERE / "index.html", "text/html; charset=utf-8"),
            "/ui-tests.js": (HERE / "ui-tests.js", "text/javascript; charset=utf-8"),
            "/fixture": (FIXTURE, "application/json"),
            "/missing-fixture": (MISSING_FIXTURE, "application/json"),
        }
        route = routes.get(self.path)
        if route is None:
            return self.send_error(404)
        path, mime = route
        self.respond(200, mime, path.read_bytes())

    def do_POST(self):
        if self.path != "/replay":
            return self.send_error(404)
        try:
            size = int(self.headers.get("Content-Length", -1))
            if not 0 <= size <= MAX_REQUEST:
                return self.respond(413, "text/plain", b"Replay input exceeds the bounded limit.")
            data = json.loads(self.rfile.read(size))
            if not isinstance(data, dict):
                raise ValueError("Expected a replay request.")
            body = replay(data.get("episode"), ReplayMode(data.get("mode")), data.get("capacity"))
        except (ValueError, TypeError, RecursionError) as exc:
            return self.respond(400, "text/plain", str(exc).encode())
        except (subprocess.SubprocessError, OSError, RuntimeError):
            return self.respond(500, "text/plain", b"Moxi replay failed. Check the local runner/toolchain.")
        self.respond(200, "application/json", json.dumps(body).encode())


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=8173)
    args = parser.parse_args()
    build()
    with ThreadingHTTPServer(("127.0.0.1", args.port), Handler) as server:
        print(f"Moxi execution debugger at http://127.0.0.1:{server.server_port}/", flush=True)
        server.serve_forever()
