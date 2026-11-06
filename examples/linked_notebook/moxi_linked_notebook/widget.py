"""Bounded notebook snapshot transport; Mojo owns plot projection and selection."""
from __future__ import annotations

from enum import StrEnum
from html import escape
import json
import math
import os
import re
from pathlib import Path
import subprocess
import time
import uuid
import weakref

import anywidget
from IPython.display import HTML, display
import traitlets as t

VERSION = 1
MAX_ROWS = 64
MAX_MESSAGE = 4096
MAX_FRAME = 131072
TIMEOUT = 2
HERE = Path(__file__).resolve().parent


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


_slots: dict[str, weakref.ReferenceType] = {}
_generation = 0  # Monotonic process-wide counter; no per-slot tombstone leak.


def sample_rows():
    return [{"label": f"Sample {i + 1:02}", "x": 8 + i * 7,
             "y": [22, 38, 31, 57, 45, 71, 63, 84, 76, 93, 87, 97][i]}
            for i in range(12)]


def validate_rows(rows):
    if not isinstance(rows, list) or not 1 <= len(rows) <= MAX_ROWS:
        raise ValueError("rows must contain 1–64 records")
    for row in rows:
        if not isinstance(row, dict) or set(row) != {"label", "x", "y"}:
            raise ValueError("each record needs exactly label, x, y")
        if not isinstance(row["label"], str) or not 1 <= len(row["label"]) <= 80 or not row["label"].isprintable():
            raise ValueError("label must contain 1–80 printable characters")
        for key in ("x", "y"):
            value = row[key]
            if type(value) not in (int, float) or not math.isfinite(value) or not 0 <= value <= 100:
                raise ValueError("coordinates must be finite numbers in [0,100]")
    return json.loads(json.dumps(rows, allow_nan=False))


def scope_svg(svg):
    """SVG fragment IDs are document-global, including collapsed saved output."""
    prefix = "linked-" + uuid.uuid4().hex + "-"
    ids = re.findall(r'\bid="([^"]+)"', svg)
    if len(ids) != len(set(ids)):
        raise ValueError("duplicate SVG IDs")
    for old in ids:
        svg = svg.replace(f'id="{old}"', f'id="{prefix}{old}"')
        svg = svg.replace(f'url(#{old})', f'url(#{prefix}{old})')
    return svg


def render(binary, rows, selected=-1, minimum=0, data_version=1):
    """Run one bounded child; subprocess.run kills and reaps on timeout."""
    args = [str(binary), str(VERSION), str(selected), str(minimum)]
    args.extend(str(row[key]) for row in rows for key in ("x", "y"))
    start = time.perf_counter()
    result = subprocess.run(args, capture_output=True, text=True, timeout=TIMEOUT, check=True)
    if len(result.stdout.encode()) > MAX_FRAME:
        raise ValueError("Mojo frame exceeds capacity")
    header, svg = result.stdout.split("\n", 1)
    frame = json.loads(header)
    if type(frame["schema"]) is not int or frame["schema"] != VERSION or not svg.strip().startswith("<svg"):
        raise ValueError("unsupported Mojo output schema")
    frame.update(svg=scope_svg(svg.strip()), dataVersion=data_version,
                 processMs=(time.perf_counter() - start) * 1000, minimum=minimum)
    points = frame["points"]
    if not isinstance(points, list) or len(points) > len(rows):
        raise ValueError("unsupported Mojo points")
    visible = set()
    for point in points:
        key = point["key"]
        if type(key) is not int or not 0 <= key < len(rows) or key in visible:
            raise ValueError("unsupported Mojo point key")
        for axis in ("x", "y"):
            value = point[axis]
            if type(value) not in (int, float) or not math.isfinite(value):
                raise ValueError("unsupported Mojo point coordinate")
        visible.add(key)
    selected_key = frame["selected"]
    if type(selected_key) is not int or (selected_key != -1 and selected_key not in visible):
        raise ValueError("unsupported Mojo selection key")
    frame["rows"] = [dict(key=i, **row) for i, row in enumerate(rows) if i in visible]
    frame["detail"] = dict(key=frame["selected"], **rows[frame["selected"]]) if frame["selected"] >= 0 else None
    if len(json.dumps(frame, allow_nan=False).encode()) > MAX_FRAME:
        raise ValueError("frame exceeds capacity")
    return frame


def static_html(frame):
    rows = "".join(f'<tr><td>{escape(r["label"])}</td><td>{r["x"]:g}</td><td>{r["y"]:g}</td></tr>' for r in frame["rows"])
    return ('<section><h3>Saved Moxi linked plot</h3><p>Static initial snapshot; no live kernel required. '
            'Dose (x) and response (y), both 0–100.</p>' + scope_svg(frame["svg"]) +
            '<table><caption>Visible records</caption><thead><tr><th>Sample</th><th>Dose</th><th>Response</th></tr></thead>'
            '<tbody>' + rows + '</tbody></table></section>')


class LinkedPlot(anywidget.AnyWidget):
    session = t.Unicode().tag(sync=True)
    generation = t.Int().tag(sync=True)
    initial = t.Dict().tag(sync=True)
    title = t.Unicode().tag(sync=True)
    _esm = (HERE / "widget.mjs").read_text()

    def __init__(self, *, slot, rows=None, binary=None, title="Linked assay explorer"):
        global _generation
        if not isinstance(slot, str) or not 1 <= len(slot) <= 80:
            raise ValueError("slot must be a stable name of 1–80 characters")
        if not isinstance(title, str) or not 1 <= len(title) <= 100:
            raise ValueError("title must contain 1–100 characters")
        self.rows = validate_rows(sample_rows() if rows is None else rows)
        supplied = binary or os.environ.get("MOXI_LINKED_BINARY")
        if not supplied:
            raise ValueError("Pass binary=path to the built moxi-linked executable; see examples/linked_notebook/README.md")
        self.binary = Path(supplied).resolve(strict=True)
        frame = render(self.binary, self.rows)
        self.slot, self.view, self.sequence = slot, None, 0
        self.backend = Backend.AVAILABLE
        self.received = self.rejected = self.finals = 0
        self.frame = frame
        self.data_version = 1
        _generation += 1
        super().__init__(session=uuid.uuid4().hex, generation=_generation, initial=frame, title=title)
        prior = _slots.get(slot, lambda: None)()
        if prior is not None:
            prior.close()
        _slots[slot] = weakref.ref(self, lambda ref: _slots.pop(slot, None) if _slots.get(slot) is ref else None)
        self.on_msg(self._receive)

    def _reply(self, message, kind, **payload):
        self.send(dict(v=VERSION, session=self.session, generation=self.generation,
                       view=message["view"], seq=message["seq"], kind=kind, **payload))

    def _receive(self, widget, message, buffers):
        try:
            if buffers or not isinstance(message, dict) or len(json.dumps(message, allow_nan=False).encode()) > MAX_MESSAGE:
                raise ValueError("message capacity")
            kind = Kind(message["kind"])
            fields = {"v", "session", "generation", "view", "seq", "kind"}
            if kind == Kind.STATE:
                fields.add("state")
            if set(message) != fields or kind not in (Kind.HELLO, Kind.STATE, Kind.PING, Kind.DISPOSE):
                raise ValueError("message schema")
            if type(message["v"]) is not int or message["v"] != VERSION or message["session"] != self.session or type(message["generation"]) is not int or message["generation"] != self.generation:
                raise ValueError("stale identity/version")
            if self.backend == Backend.CLOSED or _slots.get(self.slot, lambda: None)() is not self:
                raise ValueError("replaced output")
            view, seq = message["view"], message["seq"]
            if not isinstance(view, str) or str(uuid.UUID(view)) != view or type(seq) is not int or not 0 < seq < 2**53 or seq <= self.sequence:
                raise ValueError("sequence/view")
            if self.view is None and kind != Kind.HELLO or self.view is not None and view != self.view:
                raise ValueError("hello required; one display per widget")
            state = None
            if kind == Kind.STATE:
                state = message["state"]
                if not isinstance(state, dict) or set(state) != {"selected", "minimum", "finals", "dataVersion"}:
                    raise ValueError("state schema")
                if type(state["selected"]) is not int or not -1 <= state["selected"] < len(self.rows):
                    raise ValueError("selected key")
                if type(state["minimum"]) is not int or not 0 <= state["minimum"] <= 100:
                    raise ValueError("minimum range")
                if type(state["finals"]) is not int or not self.finals <= state["finals"] < 2**53:
                    raise ValueError("final counter")
                if type(state["dataVersion"]) is not int or state["dataVersion"] != self.data_version:
                    raise ValueError("stale data")
            self.view, self.sequence = view, seq
            self.received += 1
            if kind == Kind.DISPOSE:
                self.close()
                return
            if self.backend == Backend.FAILED:
                self._reply(message, Kind.ERROR, detail="Backend unavailable. Restore backend and Retry, or rerun after restart.")
                return
            if state is not None:
                try:
                    frame = render(self.binary, self.rows, state["selected"], state["minimum"], self.data_version)
                except (OSError, subprocess.SubprocessError, ValueError, KeyError, TypeError):
                    self._reply(message, Kind.ERROR, detail="Mojo process failed, returned an unsupported frame, or exceeded its 2-second deadline. Repair binary and Retry.")
                    return
                self.frame, self.finals = frame, state["finals"]
            self._reply(message, Kind.ACK, finals=self.finals, dataVersion=self.data_version,
                        **({"frame": self.frame} if kind in (Kind.HELLO, Kind.STATE) else {}))
        except (KeyError, TypeError, ValueError, OverflowError):
            self.rejected += 1
        except (OSError, subprocess.SubprocessError):
            self._reply(message, Kind.ERROR, detail="Mojo process failed or exceeded its 2-second deadline. Repair binary and Retry.")

    def update(self, rows):
        """Atomic data replacement: failure preserves prior output; keys reset."""
        if self.backend == Backend.CLOSED:
            raise RuntimeError("output is closed")
        rows = validate_rows(rows)
        frame = render(self.binary, rows, data_version=self.data_version + 1)
        self.rows, self.frame = rows, frame
        self.data_version += 1
        self.initial = frame

    def set_backend_available(self, available: bool):
        if type(available) is not bool:
            raise ValueError("available must be boolean")
        if self.backend != Backend.CLOSED:
            self.backend = Backend.AVAILABLE if available else Backend.FAILED

    def close(self):
        if getattr(self, "backend", Backend.CLOSED) == Backend.CLOSED:
            return
        self.backend = Backend.CLOSED
        self.on_msg(self._receive, remove=True)
        if _slots.get(self.slot, lambda: None)() is self:
            del _slots[self.slot]
        super().close()

    def show(self):
        display(HTML('<details class="moxi-linked-static"><summary>Saved plot and table — available without the adapter</summary>' + static_html(self.frame) + '</details>'))
        display(self)
