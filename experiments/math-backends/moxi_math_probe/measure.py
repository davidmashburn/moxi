"""Measure real process/application boundaries, not an engine-only microbenchmark."""
import argparse
from datetime import datetime, timezone
import json
import math
import os
import platform
import statistics
import subprocess
import sys
import time
from pathlib import Path
from .controller import Controller
from .corpus import fixtures, canonical, X, Y
from .model import Backend, Status, Request, Operation, Kind, node, integer

def wait(controller):
    while True:
        result = controller.poll()
        if result is not None:
            return result
        time.sleep(0.0005)

def summarize(samples):
    values = sorted(samples)
    return {"n": len(values), "median": statistics.median(values),
            "p95": values[math.ceil(.95 * len(values)) - 1],
            "p99": values[math.ceil(.99 * len(values)) - 1], "max": max(values)}

def rss(controller):
    if controller.process is None:
        return None
    return int(subprocess.check_output(["ps", "-o", "rss=", "-p", str(controller.process.pid)], text=True).strip()) * 1024

def run(samples):
    report = {"timestamp": datetime.now(timezone.utc).isoformat(), "host": platform.platform(),
              "python": sys.version, "samples": samples,
              "timing_units": "nanoseconds; RSS bytes (ps resident pages, not allocator/leak proof)",
              "backends": {}}
    for backend in Backend:
        with Controller(backend, timeout=15) as controller:
            cold_started = time.perf_counter_ns()
            controller.submit(fixtures()[0].request, 0)
            cold = wait(controller)
            cold_app_ns = time.perf_counter_ns() - cold_started
            if cold.status != Status.OK:
                raise RuntimeError(cold)
            evidence = {"startup": controller.startups[0], "cold_first": {**cold.timings, "app_observed_ns": cold_app_ns}, "corpus": [], "sizes": {}}
            for fixture in fixtures():
                controller.submit(fixture.request, 0)
                completion = wait(controller)
                if completion.status != fixture.status(backend):
                    raise AssertionError((fixture.name, completion))
                if completion.result and canonical(completion.result) != canonical(fixture.expected):
                    raise AssertionError((fixture.name, completion))
                evidence["corpus"].append({"case": fixture.name, "status": completion.status.value,
                                           "message": completion.message, "timings": completion.timings})
            evidence["rss_before"] = rss(controller)
            for power in (2, 8, 24):
                request = Request(node(Kind.POW, node(Kind.ADD, X, Y), integer(power)), Operation.EXPAND)
                observations = []
                for _ in range(samples):
                    app_started = time.perf_counter_ns()
                    controller.submit(request, 0)
                    result = wait(controller)
                    app_observed_ns = time.perf_counter_ns() - app_started
                    if result.status != Status.OK:
                        raise RuntimeError(result)
                    observations.append({**result.timings, "app_observed_ns": app_observed_ns})
                evidence["sizes"][str(power)] = {key: summarize([r[key] for r in observations]) for key in observations[0] if key != "handles"}
            evidence["rss_after"] = rss(controller)
            evidence["persistent_processes_started"] = len(controller.startups)
            report["backends"][backend.value] = evidence
    return report

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--samples", type=int, default=30)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.samples < 1:
        parser.error("samples must be positive")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(run(args.samples), indent=2) + "\n")

if __name__ == "__main__":
    main()
