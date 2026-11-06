"""Python state for the actual Mojo/Moxi window, using the tested controller."""
from enum import IntEnum
import json
import hashlib
import platform
import os
from pathlib import Path
import statistics
import subprocess
import time
from .controller import Controller, Document
from .corpus import Fixture, fixtures, slow_request
from .model import Backend, Kind, Domain, Request, Status, integer, node, to_text, from_text

class Action(IntEnum):
    NEXT = 10
    RUN = 11
    APPLY = 12
    EDIT = 13
    SLOW = 14
    CANCEL = 15
    SWITCH = 16
    TEXT_EDIT = 17


def display(n):
    k, v, c = n.kind, n.values, n.children
    if k == Kind.INTEGER:
        return v[0]
    if k == Kind.RATIONAL:
        return v[0] + "/" + v[1]
    if k == Kind.SYMBOL:
        return v[1] + (":" + v[2] if v[2] != Domain.COMPLEX else "")
    if k in (Kind.ADD, Kind.MUL, Kind.POW, Kind.MATMUL):
        separator = {Kind.ADD: " + ", Kind.MUL: " * ", Kind.POW: " ^ ", Kind.MATMUL: " @ "}[k]
        return "(" + separator.join(display(x) for x in c) + ")"
    return k.value + (":" + ",".join(v) if v else "") + "(" + ", ".join(display(x) for x in c) + ")"


class Session:
    def __init__(self):
        self.backend = Backend.SYMPY
        self.controller = Controller(self.backend, timeout=8)
        self.cases = fixtures()
        self.slow_index = len(self.cases)
        self.cases.append(Fixture("slow-expansion", slow_request(), None))
        self.index = 0
        self.document = Document(self.cases[0].request.root)
        self.completion = None
        self.status = "Ready. No computation has run."
        self.frames = 0
        self.last_frame = time.perf_counter()
        self.slow_intervals = []
        self.slow_by_backend = {b.value: [] for b in Backend}
        root = Path(__file__).resolve().parent.parent
        sources = sorted([*root.glob("moxi_math_probe/*.py"), *root.glob("native/*"), *root.glob("*.sh"), root / "pyproject.toml"])
        self.source_sha256 = hashlib.sha256(b"".join(str(p.relative_to(root)).encode() + p.read_bytes() for p in sources)).hexdigest()
        self.capture_pending = ""
        self.capture_entry = None
        self.capture_error = None
        self.window_id = 0
        self.capture_root = Path(os.environ["MOXI_MATH_CAPTURE_DIR"]) if os.environ.get("MOXI_MATH_CAPTURE_DIR") else None
        self.scripted = self.capture_root is not None
        self.stage = -1
        self.stage_start = time.monotonic()
        self.previous_capture = False
        self.manifest = []
        self.capturing = False
        self.finished = False
        self.dirty = True
        self.last_refresh = 0.0
        self.started_slow = False
        self.decision_lines = None

    def choose(self, name):
        self.index = next(i for i, f in enumerate(self.cases) if f.name == name)
        self.document.edit(self.cases[self.index].request.root)
        self.completion = None
        self.status = "Fixture: " + name
        self.dirty = True

    def action(self, action):
        action = Action(action)
        self.dirty = True
        match action:
            case Action.NEXT:
                self.index = (self.index + 1) % len(self.cases)
                self.document.edit(self.cases[self.index].request.root)
                self.completion = None
                self.status = "Fixture loaded; source revision advanced."
            case Action.RUN:
                fixture = self.cases[self.index]
                request = Request(self.document.root, fixture.request.operation, fixture.request.selection,
                                  fixture.request.variable, fixture.request.replacement)
                self.document.submit(self.controller, request)
                self.completion = None
                self.started_slow = self.index == self.slow_index
                self.status = "Pending: source stays editable."
            case Action.APPLY:
                if self.completion:
                    applied = self.document.apply(self.completion)
                    self.status = "Apply: " + applied.value
            case Action.EDIT:
                self.document.edit(node(Kind.ADD, self.document.root, integer(1)))
                self.status = "Structured edit: wrapped source + 1; older result is stale."
            case Action.TEXT_EDIT:
                # A text edit of the lossless notation, parsed back into a tree.
                text = to_text(self.document.root)
                edited = from_text(text.replace('"values":["1","2"]', '"values":["3","4"]', 1))
                if edited == self.document.root:
                    self.status = "Text edit demo applies to the exact-half result; use that fixture first."
                else:
                    self.document.edit(edited)
                    self.status = "Text edit: rational payload 1/2 -> 3/4; still typed and computable."
            case Action.SLOW:
                self.index = self.slow_index
                request = self.cases[self.index].request
                self.document.edit(request.root)
                self.document.submit(self.controller, request)
                self.completion = None
                self.started_slow = True
                self.status = "Real expansion (x+y+z)^1200 running; edit, cancel or supersede."
            case Action.CANCEL:
                self.document.cancel(self.controller, terminate=True)
                self.completion = None
                self.started_slow = False
                self.status = "Cancelled: native/Python process killed; next request restarts."
            case Action.SWITCH:
                self.controller.close()
                self.backend = Backend.SYMENGINE if self.backend == Backend.SYMPY else Backend.SYMPY
                self.controller = Controller(self.backend, timeout=8)
                self.completion = None
                self.started_slow = False
                self.status = "Switched backend; prior worker reaped."

    def tick(self):
        now = time.perf_counter()
        if self.started_slow and self.controller.active is not None and not self.capturing:
            self.slow_intervals.append((now-self.last_frame)*1000)
            self.slow_by_backend[self.backend.value].append((now-self.last_frame)*1000)
        self.last_frame = now
        self.frames += 1
        completion = self.controller.poll()
        if completion:
            self.completion = completion
            self.started_slow = False
            eligible = completion.generation == self.document.generation and completion.revision == self.document.revision
            self.status = completion.status.value + (("; eligible for explicit apply" if completion.status == Status.OK else "; source retained") if eligible else "; stale revision/generation")
            if completion.message:
                self.status += ": " + completion.message
            self.dirty = True
        if self.scripted and not self.finished and not self.capturing:
            self.script()
        if now - self.last_refresh >= .25:
            self.dirty = True
            self.last_refresh = now
        changed, self.dirty = self.dirty, False
        return changed

    def lines(self):
        if self.decision_lines:
            return self.decision_lines
        fixture = self.cases[self.index]
        result = display(self.completion.result) if self.completion and self.completion.result else "No imported result"
        timings = self.completion.timings if self.completion and self.completion.timings else {}
        return ["Moxi / D01 symbolic backend comparison",
                self.backend.value + " | " + fixture.name + " | " + fixture.request.operation.value,
                "Source: " + display(self.document.root), "Result: " + result,
                self.status,
                f"Revision {self.document.revision} | generation {self.document.generation} | frame ticks {self.frames} | active {self.controller.active is not None}",
                "Application request: " + (f"{timings['total_ns']/1e6:.3f} ms" if 'total_ns' in timings else "not measured yet"),
                "Lossless text preview: " + to_text(self.document.root)[:95] + " ...",
                "Use Run, inspect the result, then Apply. Edits advance the revision and prevent stale application."]

    def capture(self, caption):
        if not self.capture_root:
            return
        self.capturing = True
        self.capture_root.mkdir(parents=True, exist_ok=True)
        index = len(self.manifest)
        filename = f"{index:02d}-{self.backend.value}.png"
        entry = {"demo": "D01", "caption": caption, "backend": self.backend.value,
                 "fixture": self.cases[self.index].name, "source_revision": os.environ.get("MOXI_SOURCE_REVISION", "unrecorded"),
                 "source_sha256": self.source_sha256, "host": platform.platform(),
                 "document_revision": self.document.revision, "generation": self.document.generation,
                 "window_points": [1100, 760], "scale": "see PNG pixel dimensions", "image": filename,
                 "capture": "AppKit cacheDisplay of the live Moxi NSWindow contentView; OS screen capture unavailable",
                 "reproduction": "bash experiments/math-backends/run-demo.sh --capture <output-directory>",
                 "status": self.status, "source": self.document.root.wire(),
                 "result": self.completion.result.wire() if self.completion and self.completion.result else None}
        self.capture_pending = str(self.capture_root / filename)
        self.capture_entry = entry

    def captured(self, success):
        if success:
            self.manifest.append(self.capture_entry)
        else:
            self.capture_error = "AppKit live-view capture failed"
        self.capture_pending = ""
        self.capture_entry = None
        self.last_frame = time.perf_counter()
        self.capturing = False

    def script(self):
        if self.capture_error:
            self.finished = True
            raise RuntimeError(self.capture_error)
        elapsed = time.monotonic() - self.stage_start
        # Each backend performs identical real interactions. A failed worker is
        # captured as failure; the script never supplies fabricated results.
        if self.stage == -1 and elapsed > .5:
            self.capture("Initial exact arithmetic fixture")
            self.stage = 0
        elif self.stage == 0 and self.completion is None and self.controller.active is None and self.controller.pending is None:
            self.action(Action.RUN)
        elif self.stage == 0 and self.completion:
            self.capture("One third + one sixth: exact result")
            self.stage = 1
        elif self.stage == 1:
            self.action(Action.APPLY)
            self.action(Action.TEXT_EDIT)
            self.capture("Applied result, then edited its exact JSON rational payload")
            self.stage = 2
        elif self.stage in (2, 4, 6, 8, 10):
            names = {2: "expand-square", 4: "differentiate-sine-product", 6: "substitute-compound", 8: "complex-root-square", 10: "real-root-unsupported-abs"}
            self.choose(names[self.stage])
            self.action(Action.RUN)
            self.stage += 1
        elif self.stage in (3, 5, 7, 9, 11) and self.completion:
            self.capture(self.cases[self.index].name + ": " + self.completion.status.value)
            self.stage += 1
        elif self.stage == 12:
            self.action(Action.SLOW)
            self.stage = 120
            self.stage_start = time.monotonic()
        elif self.stage == 120 and elapsed > .5:
            self.capture("Real slow expansion pending; native frame ticks continue")
            self.stage = 13
        elif self.stage == 13:
            self.action(Action.EDIT)
            self.capture("Source edited while expansion runs; old revision cannot apply")
            self.stage = 14
        elif self.stage == 14:
            self.choose("exact-half")
            self.action(Action.RUN)
            self.stage = 141
        elif self.stage == 141 and self.completion:
            self.capture("Slow request superseded by exact arithmetic; only the new generation returns")
            self.stage = 142
        elif self.stage == 142:
            self.action(Action.SLOW)
            self.stage_start = time.monotonic()
            self.stage = 143
        elif self.stage == 143 and elapsed > .3:
            self.action(Action.CANCEL)
            self.capture("Cancellation terminates the worker process")
            self.stage = 15
        elif self.stage == 15:
            self.choose("exact-half")
            self.action(Action.RUN)
            self.stage = 16
        elif self.stage == 16 and self.completion:
            self.action(Action.APPLY)
            self.capture("Worker restarted; editable result applied")
            self.stage = 17
        elif self.stage == 17:
            if self.backend == Backend.SYMPY:
                self.action(Action.SWITCH)
                self.choose("exact-half")
                self.stage = -1
                self.stage_start = time.monotonic()
            else:
                report_path = os.environ.get("MOXI_MATH_MEASUREMENTS")
                if report_path:
                    measurements = json.loads(Path(report_path).read_text())
                    sp, se = (measurements["backends"][b.value] for b in Backend)
                    self.decision_lines = ["Moxi / D01 measured decision", "Initial adapter: persistent SymPy worker",
                        f"Warm repeated request, IO boundary: median / p95 / p99 / max ({measurements['samples']} samples per size)"]
                    for size in ("2", "8", "24"):
                        line = "(x+y)^" + size + "  "
                        for name, data in (("SymPy", sp), ("SymEngine", se)):
                            stats = data["sizes"][size]["total_ns"]
                            line += name + ": " + "/".join(f"{stats[k]/1e6:.2f}" for k in ("median", "p95", "p99", "max")) + " ms   "
                        self.decision_lines.append(line)
                    self.decision_lines += ["SymEngine has lower cold startup and RSS; this Mojo/Python bridge costs more per warm request.",
                                            "Both processes can be killed/restarted; exact scalar results remain typed and editable.",
                                            "SymPy supports more corpus structure. D02 integration and signed packaging remain open."]
                    self.dirty = True
                    self.capture("Measured decision at the application boundary; choose SymPy")
                self.stage = 18
        elif self.stage == 18:
            self.finished = True

    def close(self):
        self.document.close(self.controller)
        if self.capture_root:
            self.capture_root.mkdir(parents=True, exist_ok=True)
            (self.capture_root / "captures.json").write_text(json.dumps(self.manifest, indent=2) + "\n")
            metrics = {"frame_ticks": self.frames, "slow_frame_intervals_ms": self.slow_intervals,
                       "slow_frame_intervals_ms_by_backend": self.slow_by_backend,
                       "capture_error": self.capture_error, "capture_pauses_excluded": True,
                       "note": "App frame-tick intervals, not GPU presentation timestamps"}
            (self.capture_root / "frames.json").write_text(json.dumps(metrics, indent=2) + "\n")
        if self.capture_error:
            raise RuntimeError(self.capture_error)
