"""Single active + single replacing pending request; one process per controller.

A daemon IO thread owns serialization and reads. The UI never waits for an engine.
Cancellation is logical unless terminate=True; deadlines always kill and reap.
Closing the document synchronously tears down its child and joins the IO thread.
"""
from dataclasses import dataclass
import os
import selectors
import subprocess
import sys
import threading
import time
from .model import Backend, BoundaryError, Node, Request, Status, VERSION
from .protocol import HEADER, MAX_FRAME, pack
import json

@dataclass(frozen=True)
class Completion:
    generation: int
    revision: int
    status: Status
    result: Node | None = None
    message: str = ""
    node_id: str = ""
    timings: dict | None = None

@dataclass(frozen=True)
class Work:
    generation: int
    revision: int
    request: Request

class Controller:
    def __init__(self, backend=Backend.SYMPY, *, command=None, timeout=5.0, env=None):
        self.backend = backend
        if command is None:
            if backend == Backend.SYMPY:
                command = [os.environ.get("MOXI_SYMPY_PYTHON", sys.executable), "-m", "moxi_math_probe.sympy_worker"]
            else:
                binary = os.environ.get("MOXI_SYMENGINE_WORKER")
                command = [binary] if binary else ["moxi-symengine-worker"]
        self.command, self.timeout = command, timeout
        self.env = dict(os.environ if env is None else env)
        if backend == Backend.SYMPY:
            # Mojo embeds CPython and may export its Python home. Do not let
            # that override the explicitly selected worker virtualenv.
            self.env.pop("PYTHONHOME", None)
            self.env.pop("PYTHONEXECUTABLE", None)
            self.env.pop("__PYVENV_LAUNCHER__", None)
        self.generation = 0
        self.closed = False
        self.pending = None
        self.active = None
        self.latest = None
        self.process = None
        self.startups = []
        self.lock = threading.Condition()
        self.thread = threading.Thread(target=self._loop, name="moxi-math-io", daemon=True)
        self.thread.start()

    def submit(self, request, revision, *, replace_active=True):
        # Local validation takes place before a process exists or a frame is sent.
        request.validate()
        pack({"version": VERSION, "generation": 0, "revision": revision, "request": request.wire()})
        with self.lock:
            if self.closed:
                raise BoundaryError("Document is closed", status=Status.CLOSED)
            self.generation += 1
            self.latest = None
            self.pending = Work(self.generation, revision, request)
            if replace_active and self.active is not None:
                self._stop_locked()
            self.lock.notify_all()
            return self.generation

    def cancel(self, *, terminate=False):
        with self.lock:
            self.generation += 1
            self.pending = None
            self.latest = None
            if terminate:
                self._stop_locked()
            self.lock.notify_all()
            return self.generation

    def poll(self):
        with self.lock:
            result, self.latest = self.latest, None
            return result

    def _stop_locked(self):
        # Kill, rather than cooperative terminate: native algorithms need not
        # implement signal interruption. Process owns all native allocations.
        if self.process is not None and self.process.poll() is None:
            self.process.kill()

    def close(self):
        with self.lock:
            if self.closed:
                return
            self.closed = True
            self.pending = None
            self._stop_locked()
            self.lock.notify_all()
        self.thread.join(timeout=max(2.0, self.timeout + 1))
        if self.thread.is_alive():
            raise RuntimeError("Worker IO did not close")
        self.latest = None

    def _dispose(self, process):
        if process.poll() is None:
            process.kill()
        process.wait(timeout=2)
        process.stdin.close()
        process.stdout.close()
        with self.lock:
            if self.process is process:
                self.process = None

    def _read(self, process, deadline):
        def exact(length):
            result = bytearray()
            with selectors.DefaultSelector() as ready:
                ready.register(process.stdout, selectors.EVENT_READ)
                while len(result) < length:
                    remaining = deadline - time.monotonic()
                    if remaining <= 0 or not ready.select(remaining):
                        raise TimeoutError("Symbolic worker deadline exceeded")
                    chunk = os.read(process.stdout.fileno(), length - len(result))
                    if not chunk:
                        raise EOFError("Worker exited or truncated response")
                    result.extend(chunk)
            return bytes(result)
        length = HEADER.unpack(exact(HEADER.size))[0]
        if not 0 < length <= MAX_FRAME:
            raise BoundaryError("Invalid/oversized response")
        value = json.loads(exact(length))
        if not isinstance(value, dict) or value.get("version") != VERSION:
            raise BoundaryError("Malformed/version-mismatched response")
        return value

    def _ensure(self, work):
        with self.lock:
            if self.closed or work.generation != self.generation:
                raise InterruptedError("Request superseded before launch")
            if self.process is not None and self.process.poll() is None:
                return self.process
            if self.process is not None:
                self._dispose(self.process)
            start = time.perf_counter_ns()
            # stderr inherits the caller's log, never an undrained PIPE.
            self.process = subprocess.Popen(self.command, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                            bufsize=0, env=self.env)
            process = self.process
        ready = self._read(process, time.monotonic() + self.timeout)
        if ready.get("ready") is not True or ready.get("engine") != self.backend.value:
            raise BoundaryError("Invalid worker handshake")
        self.startups.append({"startup_ns": time.perf_counter_ns() - start, **ready})
        return process

    def _loop(self):
        try:
            while True:
                with self.lock:
                    self.lock.wait_for(lambda: self.closed or self.pending is not None)
                    if self.closed:
                        return
                    work, self.pending = self.pending, None
                    self.active = work
                started = time.perf_counter_ns()
                try:
                    process = self._ensure(work)
                    wire_start = time.perf_counter_ns()
                    frame = pack({"version": VERSION, "generation": work.generation, "revision": work.revision,
                                  "request": work.request.wire()})
                    exported = time.perf_counter_ns()
                    deadline = time.monotonic() + self.timeout
                    # A bounded nonblocking write also handles a worker which stops reading.
                    with selectors.DefaultSelector() as writable:
                        os.set_blocking(process.stdin.fileno(), False)
                        writable.register(process.stdin, selectors.EVENT_WRITE)
                        offset = 0
                        while offset < len(frame):
                            remaining = deadline - time.monotonic()
                            if remaining <= 0 or not writable.select(remaining):
                                raise TimeoutError("Worker input deadline exceeded")
                            try:
                                offset += os.write(process.stdin.fileno(), frame[offset:])
                            except BlockingIOError:
                                continue
                    response = self._read(process, deadline)
                    received = time.perf_counter_ns()
                    if response.get("generation") != work.generation or response.get("revision") != work.revision:
                        raise BoundaryError("Response identity mismatch")
                    status = Status(response["status"])
                    result = Node.read(response["result"]) if status == Status.OK else None
                    if result:
                        symbols = work.request.validate()
                        returned = result.validate()
                        if any(identity not in symbols or symbols[identity] != metadata for identity, metadata in returned.items()):
                            raise BoundaryError("Worker changed symbol identity or assumptions")
                    done = time.perf_counter_ns()
                    timings = {**response.get("timings", {}), "export_ns": exported - wire_start,
                               "roundtrip_ns": received - exported,
                               "transport_ns": max(0, received - exported - response.get("worker_ns", 0)),
                               "import_ns": done - received, "total_ns": done - started,
                               "handles": response.get("handles")}
                    completion = Completion(work.generation, work.revision, status, result,
                                            response.get("message", ""), response.get("node_id", ""), timings)
                except Exception as exc:
                    completion = Completion(work.generation, work.revision,
                                            Status.TIMEOUT if isinstance(exc, TimeoutError) else Status.ERROR,
                                            message=type(exc).__name__ + ": " + str(exc))
                    with self.lock:
                        process = self.process
                    if process is not None:
                        self._dispose(process)
                with self.lock:
                    self.active = None
                    if not self.closed and work.generation == self.generation:
                        self.latest = completion
        finally:
            with self.lock:
                process = self.process
            if process is not None:
                self._dispose(process)

    def __enter__(self):
        return self

    def __exit__(self, *_):
        self.close()

@dataclass
class Document:
    root: Node
    revision: int = 0
    generation: int = 0
    closed: bool = False
    selection: tuple[int, ...] = ()

    def edit(self, root):
        self.root = root
        self.revision += 1

    def submit(self, controller, request):
        if self.closed or request.root != self.root:
            raise BoundaryError("Request is not for the current open document")
        self.generation = controller.submit(request, self.revision)
        self.selection = request.selection

    def cancel(self, controller, *, terminate=False):
        self.generation = controller.cancel(terminate=terminate)

    def apply(self, completion):
        if self.closed:
            return Status.CLOSED
        if completion.generation != self.generation or completion.revision != self.revision:
            return Status.STALE
        if completion.status != Status.OK:
            return completion.status
        self.edit(self.root.replace_at(self.selection, completion.result))
        return Status.OK

    def close(self, controller):
        self.closed = True
        controller.close()
