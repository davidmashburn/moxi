"""Example-local browser-owned FDG; kernel owns the bounded comm lease only."""
from __future__ import annotations

import base64
from enum import StrEnum
import json
import math
from pathlib import Path
import subprocess
import uuid
import weakref

import anywidget
from IPython.display import HTML, display
import traitlets as t

HERE = Path(__file__).resolve().parent
DIST = HERE.parent / "dist/interactive"
VERSION = 1
MAX_MESSAGE = 4096
MAX_ASSET = 2_000_000


class Kind(StrEnum):
    HELLO = "hello"
    STATE = "state"
    PING = "ping"
    DISPOSE = "dispose"
    ACK = "ack"
    ERROR = "error"


class Backend(StrEnum):
    AVAILABLE = "available"
    FAILED = "failed"
    CLOSED = "closed"


_slots: dict[str, tuple[int, weakref.ReferenceType]] = {}


def validate_graph(graph):
    if graph is None:
        return workload(77, 254)
    if not isinstance(graph, dict) or set(graph) != {"groups", "links"}:
        raise ValueError("graph needs groups and links")
    groups, links = graph["groups"], graph["links"]
    if not isinstance(groups, list) or not 1 <= len(groups) <= 256 or not isinstance(links, list) or len(links) > 1024:
        raise ValueError("graph capacity is 1–256 nodes and 0–1024 links")
    if any(type(g) is not int or not 0 <= g <= 1_000_000 for g in groups):
        raise ValueError("invalid group")
    for edge in links:
        if not isinstance(edge, list) or len(edge) != 3:
            raise ValueError("edge needs source, target, weight")
        a, b, weight = edge
        if any(type(i) is not int or not 0 <= i < len(groups) for i in (a, b)) or type(weight) not in (int, float) or not math.isfinite(weight) or not 0 <= weight <= 1e6:
            raise ValueError("invalid edge")
    return json.loads(json.dumps(graph, allow_nan=False))


def workload(count, edges):
    # Same synthetic topology as examples/fdg/tests/benchmark.mojo.
    return {"groups": [i % 6 for i in range(count)],
            "links": [[i % count, (i * 7 + 1) % count, 1] for i in range(edges)]}


def workload_256():
    return workload(256, 1024)


def static_svg(graph=None):
    graph = validate_graph(graph)
    if not (DIST / "browser.wasm").exists():
        raise RuntimeError("Run examples/fdg/notebook/prepare_interactive.py first; see INTERACTIVE.md")
    result = subprocess.run(["node", str(HERE / "static_interactive.mjs")], input=json.dumps(graph), text=True, capture_output=True, timeout=30, check=True)
    if len(result.stdout.encode()) > MAX_ASSET:
        raise ValueError("SVG capacity exceeded")
    return result.stdout


class InlineFDG(anywidget.AnyWidget):
    session = t.Unicode().tag(sync=True)
    generation = t.Int().tag(sync=True)
    graph = t.Any(None, allow_none=True).tag(sync=True)
    wasm = t.Unicode().tag(sync=True)
    fallback = t.Unicode().tag(sync=True)
    title = t.Unicode().tag(sync=True)

    def __init__(self, *, slot: str, graph=None, title="Inline Moxi FDG"):
        if not isinstance(slot, str) or not 1 <= len(slot) <= 80:
            raise ValueError("slot must be a short stable name for this output")
        graph = validate_graph(graph)
        # Build/fallback failure must not destroy the preceding working output.
        fallback = static_svg(graph)
        esm = (DIST / "widget.mjs").read_text()
        wasm = (DIST / "browser.wasm").read_bytes()
        if len(wasm) > MAX_ASSET or len(esm.encode()) > MAX_ASSET:
            raise ValueError("widget asset capacity exceeded")
        prior_generation, prior = _slots.get(slot, (0, lambda: None))
        previous = prior()
        if previous is not None:
            previous.close()
        self._esm = esm
        self.backend = Backend.AVAILABLE
        self.sequence = 0
        self.view = None
        self.received = 0
        self.rejected = 0
        self.snapshot = None
        self.slot = slot
        super().__init__(session=uuid.uuid4().hex, generation=prior_generation + 1, graph=graph,
                         wasm=base64.b64encode(wasm).decode(), fallback=fallback, title=title)
        _slots[slot] = (self.generation, weakref.ref(self))
        self.on_msg(self._receive)

    def _reply(self, message, kind, **payload):
        self.send(dict(v=VERSION, session=self.session, generation=self.generation,
                       view=message["view"], seq=message["seq"], kind=kind, **payload))

    def _receive(self, widget, message, buffers):
        try:
            if buffers or not isinstance(message, dict) or len(json.dumps(message, allow_nan=False).encode()) > MAX_MESSAGE:
                raise ValueError("message capacity")
            if set(message) - {"v", "session", "generation", "view", "seq", "kind", "state"}:
                raise ValueError("unknown field")
            kind = Kind(message["kind"])
            if message["v"] != VERSION or type(message["v"]) is not int or message["session"] != self.session or type(message["generation"]) is not int or message["generation"] != self.generation:
                raise ValueError("stale identity/version")
            if self.backend == Backend.CLOSED or _slots[self.slot][1]() is not self:
                raise ValueError("replaced output")
            view, seq = message["view"], message["seq"]
            if not isinstance(view, str) or len(view) != 36 or type(seq) is not int or not 0 < seq < 2**53 or seq <= self.sequence:
                raise ValueError("sequence/view")
            if self.view is not None and view != self.view:
                raise ValueError("one display per widget; create another slot")
            snapshot = None
            if kind == Kind.STATE:
                snapshot = message["state"]
                if not isinstance(snapshot, dict) or set(snapshot) != {"selected", "paused", "panX", "panY", "zoom", "releases", "dragging"}:
                    raise ValueError("state schema")
                count = 77 if self.graph is None else len(self.graph["groups"])
                if type(snapshot["selected"]) is not int or not -1 <= snapshot["selected"] < count or type(snapshot["paused"]) is not bool or type(snapshot["dragging"]) is not bool:
                    raise ValueError("state type")
                if type(snapshot["releases"]) is not int or not 0 <= snapshot["releases"] < 2**53:
                    raise ValueError("release counter")
                if self.snapshot and snapshot["releases"] < self.snapshot["releases"]:
                    raise ValueError("release counter regressed")
                if any(type(snapshot[k]) not in (int, float) or not math.isfinite(snapshot[k]) or abs(snapshot[k]) > 1e6 for k in ("panX", "panY", "zoom")) or snapshot["zoom"] <= 0:
                    raise ValueError("state range")
            elif kind not in (Kind.HELLO, Kind.PING, Kind.DISPOSE):
                raise ValueError("client operation")
            self.view, self.sequence = view, seq
            self.received += 1
            if kind == Kind.DISPOSE:
                self.view = None
                self.snapshot = None
                return
            if self.backend == Backend.FAILED:
                self._reply(message, Kind.ERROR, detail="Kernel backend unavailable; restore backend then Retry, or rerun the cell.")
                return
            if snapshot is not None:
                self.snapshot = snapshot
            self._reply(message, Kind.ACK, releases=self.snapshot["releases"] if self.snapshot else 0)
        except (KeyError, TypeError, ValueError, OverflowError):
            self.rejected += 1

    def set_backend_available(self, available: bool):
        """Exercise a real backend rejection/recovery, without faking a UI error."""
        if self.backend != Backend.CLOSED:
            self.backend = Backend.AVAILABLE if available else Backend.FAILED

    def close(self):
        if getattr(self, "backend", Backend.CLOSED) == Backend.CLOSED:
            return
        self.backend = Backend.CLOSED
        self.snapshot = None
        super().close()

    def show(self):
        # Separate output: survives missing widget manager, untrusted/reopened
        # notebooks and kernel restart. No executable JS, remote URL or local path.
        display(HTML('<details class="moxi-static"><summary>Saved static SVG — available without the live adapter</summary>' + self.fallback + '</details>'))
        display(self)
        return None
