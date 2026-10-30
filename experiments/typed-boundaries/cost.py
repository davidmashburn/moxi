"""Compile once, warm, then time a local edit with growing shared history."""
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import platform
import statistics
import subprocess
import tempfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]


def main():
    logs = Path(tempfile.mkdtemp(prefix="moxi-typed-cost-"))
    includes = [ROOT / "src", ROOT / "experiments/state-access", ROOT / "experiments/method-binding", ROOT / "experiments/selective-updates"]
    binary = logs / "cost"
    build = ["pixi", "run", "--locked", "mojo", "build", "-O3"] + [arg for path in includes for arg in ("-I", str(path))] + [str(HERE / "cost.mojo"), "-o", str(binary)]
    for name, cmd in (("build", build), ("run", [str(binary)])):
        result = subprocess.run(cmd, cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=240)
        (logs / f"{name}.log").write_text(result.stdout)
        assert result.returncode == 0, result.stdout[-4000:]
    samples = []
    for line in result.stdout.splitlines():
        _, selective, history, index, ns, commands, renders = line.split()
        samples.append({"selective": selective == "True", "history": int(history), "sample": int(index), "ns": int(ns), "paint_commands": int(commands), "renders": int(renders)})
    assert len(samples) == 18
    summaries = []
    for history in (0, 10000, 100000):
        for selective in (True, False):
            rows = [r for r in samples if r["history"] == history and r["selective"] == selective]
            assert len(rows) == 3
            assert all(r["renders"] == (1 if selective else 8) for r in rows)
            values = [r["ns"] for r in rows]
            summaries.append({"selective": selective, "history": history, "median_ns": statistics.median(values), "min_ns": min(values), "max_ns": max(values)})
    paths = [ROOT / "pixi.toml", ROOT / "pixi.lock", *ROOT.glob("src/**/*.mojo"),
             *ROOT.glob("experiments/state-access/*.mojo"), *ROOT.glob("experiments/method-binding/*.mojo"),
             *ROOT.glob("experiments/selective-updates/*.mojo"), *HERE.glob("*.mojo"), HERE / "cost.py"]
    report = {"timestamp": datetime.now(timezone.utc).isoformat(), "implementation_head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
              "compiler": subprocess.check_output(["pixi", "run", "--locked", "mojo", "--version"], cwd=ROOT, text=True).strip(),
              "machine": platform.platform(), "processor": subprocess.check_output(["sysctl", "-n", "machdep.cpu.brand_string"], text=True).strip(),
              "protocol": "Mojo -O3; one warmup and three samples per mode/history; actual App.update plus App.paint; setup/checks/destruction outside timer; backend-neutral paint only; machine-local diagnostic, no native/GPU latency claim",
              "build_command": build, "samples": samples, "summaries": summaries, "logs": str(logs),
              "source_hashes": {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(paths)}}
    (HERE / "cost-results.json").write_text(json.dumps(report, indent=2)+"\n")
    for s in summaries:
        print(s["history"], "cached" if s["selective"] else "full", round(s["median_ns"]/1e6, 3), "ms", "range", round(s["min_ns"]/1e6, 3), round(s["max_ns"]/1e6, 3))
    print("PASS 18 samples; logs:", logs)


if __name__ == "__main__":
    main()
