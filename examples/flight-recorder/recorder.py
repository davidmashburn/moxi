"""The bounded I15 episode format and synthetic instrument."""

import asyncio
from collections import deque
from enum import Enum

import moxi

FORMAT = "moxi.synthetic-episode/1"
SOURCE = "bench-probe/1"
CLOCK = "logical ticks, 10 ms per tick"
REQUEST = "probe-peak/16"
CAPACITY = 12
TICKS = 24
REQUEST_TICK = 16
SEED = 37
MAX_BYTES = 8192


class CaptureMode(Enum):
    COMPLETE = "complete"
    OMIT_RESULT = "omit-result"


async def peak_reading(samples):
    """A separate result producer, operating on the request-time snapshot."""
    return await asyncio.to_thread(max, samples)


async def capture(mode):
    records = deque(maxlen=CAPACITY)
    value = SEED
    for tick in range(TICKS):
        value = (17 * value + 11) % 101
        records.append([tick, value])
        if tick == REQUEST_TICK:
            pending = asyncio.create_task(peak_reading([v for _, v in records]))
        await asyncio.sleep(0)
    peak = await pending
    return {
        "format": FORMAT, "source": SOURCE, "clock": CLOCK, "seed": SEED,
        "capacity": CAPACITY, "emitted": TICKS, "dropped": TICKS - len(records),
        "samples": list(records), "request": REQUEST,
        "result": {"request": REQUEST, "peak": peak} if mode is CaptureMode.COMPLETE else None,
    }


def integer(value, low, high):
    return type(value) is int and low <= value <= high


def inspect_episode(episode):
    """Validate the v1 instrument contract before plotting recorded values."""
    if not isinstance(episode, dict) or any(episode.get(k) != v for k, v in (
        ("format", FORMAT), ("source", SOURCE), ("clock", CLOCK), ("request", REQUEST)
    )):
        raise ValueError("Unsupported instrument, clock, request or episode version.")
    for key, expected in (("seed", SEED), ("capacity", CAPACITY), ("emitted", TICKS),
                          ("dropped", TICKS - CAPACITY)):
        if not integer(episode.get(key), expected, expected):
            raise ValueError(f"Invalid {key} for this instrument.")
    rows = episode.get("samples")
    if not isinstance(rows, list) or len(rows) > CAPACITY:
        raise ValueError("Invalid sample window.")
    ticks, values = [], []
    for row in rows:
        if not isinstance(row, list) or len(row) != 2:
            raise ValueError("Expected a tick and a reading.")
        tick, value = row
        if not integer(tick, TICKS - CAPACITY, TICKS - 1) or (ticks and tick <= ticks[-1]):
            raise ValueError("Sample ticks must increase inside the retained window.")
        if not integer(value, 0, 100):
            raise ValueError("Invalid sample reading.")
        ticks.append(tick)
        values.append(value)
    result = episode.get("result")
    if result is not None and (not isinstance(result, dict) or result.get("request") != REQUEST
                               or not integer(result.get("peak"), 0, 100)):
        raise ValueError("Invalid or uncorrelated async result.")
    missing = sorted(set(range(TICKS - CAPACITY, TICKS)) - set(ticks))
    spec = moxi.PlotSpec("Retained observations")
    spec.add_scatter("reading", "tick", "reading", (0.15, 0.47, 0.55, 1))
    svg = moxi.plot({"tick": ticks, "reading": values}, spec, width=590, height=210).to_svg() if ticks else b""
    return {"svg": svg.decode(), "missing": missing, "episode": episode}
