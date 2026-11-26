"""A finite, block-clocked instrument over an existing Signal Playground capture."""
from dataclasses import dataclass
from enum import Enum
from math import sqrt
from pathlib import Path
from struct import unpack
import wave

import moxi

SOURCE = Path(__file__).resolve().parents[2] / "artifacts/signal-playground/04-pulse.wav"
BLOCK = 32
BLOCKS = 32
RATE = 44100


class Node(str, Enum):
    SOURCE = "WAV source"
    FILTER = "Low-pass"
    FEATURE = "Block RMS"
    PLOT = "Trace"
    RECORDER = "Recorder"


class Port(Enum):
    PCM = "PCM samples"
    RMS = "block RMS"


OUTPUT = {Node.SOURCE: Port.PCM, Node.FILTER: Port.PCM, Node.FEATURE: Port.RMS}
INPUT = {Node.FILTER: Port.PCM, Node.FEATURE: Port.PCM, Node.PLOT: Port.RMS, Node.RECORDER: Port.RMS}
PATCH = {Node.FILTER: Node.SOURCE, Node.FEATURE: Node.FILTER,
         Node.PLOT: Node.FEATURE, Node.RECORDER: Node.FEATURE}


class Action(str, Enum):
    PATCH = "patch"
    WIRE = "wire"
    PREVIEW = "preview"
    RECORD = "record"
    CANCEL = "cancel"
    UNDO = "undo"


class Caller(Enum):
    PANEL = "panel"
    SCRIPT = "script"


@dataclass
class Run:
    alpha: float
    rows: list
    wires: dict

    def document(self):
        return dict(source=SOURCE.name, rate_hz=RATE, block_samples=BLOCK,
                    alpha=self.alpha, wires=self.wires, rows=self.rows)


def execute(wires, alpha, rate, fail):
    if set(wires) != set(INPUT):
        raise ValueError("Incomplete graph. Connect all four inputs.")
    if rate != RATE:
        raise ValueError(f"Rate mismatch. WAV supplies {RATE} Hz and Low-pass expects {rate} Hz.")
    rows = []
    memory = 0.0
    with wave.open(str(SOURCE), "rb") as stream:
        if (stream.getframerate(), stream.getnchannels(), stream.getsampwidth()) != (RATE, 1, 2):
            raise ValueError("Unsupported recording format.")
        for tick in range(BLOCKS):
            block = stream.readframes(BLOCK)
            if len(block) != 2 * BLOCK:
                raise ValueError(f"Source ended during block {tick}.")
            raw = [n / 32768 for n in unpack(f"<{BLOCK}h", block)]
            filtered = []
            for sample in raw:
                memory += alpha * (sample - memory)
                filtered.append(memory)
            if fail and tick == 7:
                raise ValueError("Block RMS failed at block 7 (injected fault). Clear fault and retry.")
            signal = filtered if wires[Node.FEATURE] == Node.FILTER else raw
            rms = sqrt(sum(s * s for s in signal) / BLOCK)
            rows.append(dict(block=tick, end_ms=1000 * (tick + 1) * BLOCK / RATE,
                             source_last=raw[-1], filter_memory=memory, rms=rms))
    return Run(alpha, rows, dict(wires))


class Instrument:
    def __init__(self):
        self.wires = {}
        self.recorded = self.preview = self.previous = None

    def apply(self, action, args, caller=Caller.PANEL):
        if caller is Caller.SCRIPT and action is not Action.PREVIEW:
            raise ValueError("Script callers may preview only.")
        if action is Action.PATCH:
            self.wires = PATCH.copy()
            self.preview = None
            return "Connected the five-node pipeline."
        if action is Action.WIRE:
            src, dst = Node(args["from"]), Node(args["to"])
            if src == dst or src not in OUTPUT or dst not in INPUT or OUTPUT[src] != INPUT[dst]:
                raise ValueError(f"Invalid wire from {src.value} to {dst.value}.")
            self.wires[dst] = src
            self.preview = None
            return f"Connected {src.value} to {dst.value}."
        if action is Action.CANCEL:
            self.preview = None
            return "Preview cancelled. Restored recorded trace and controls."
        if action is Action.UNDO:
            if self.previous is None:
                raise ValueError("No earlier recording to restore.")
            self.recorded, self.previous = self.previous, None
            self.wires = self.recorded.wires.copy()
            self.preview = None
            return "Restored previous recording and patch."
        alpha = float(args["alpha"])
        if not 0.01 <= alpha <= 1:
            raise ValueError("Low-pass coefficient must be between 0.01 and 1.")
        result = execute(self.wires, alpha, int(args["rate"]), args.get("fault") is True)
        if action is Action.PREVIEW:
            self.preview = result
            return "Preview complete. Inspect the filter or compare with the recording."
        self.previous, self.recorded, self.preview = self.recorded, result, None
        return "Recorded 32 blocks."

    def view(self):
        displayed = self.preview or self.recorded
        spec = moxi.PlotSpec("Block RMS")
        data = {}
        for label, run, color in (("Recorded", self.recorded, (.11, .43, .45, 1)),
                                  ("Preview", self.preview, (.86, .34, .14, 1))):
            if run:
                data["ms"] = [r["end_ms"] for r in run.rows]
                data[label] = [r["rms"] for r in run.rows]
                spec.add_line(label, "ms", label, color)
        return dict(wires=self.wires, recorded_alpha=self.recorded.alpha if self.recorded else .25,
                    recorded=bool(self.recorded), rows=displayed.rows if displayed else [],
                    preview=bool(self.preview), preview_alpha=self.preview.alpha if self.preview else None, displayed_wires=displayed.wires if displayed else {},
                    svg=moxi.plot(data, spec, width=640, height=235).to_svg().decode() if data else "")
