"""Compare Moxi and the original Canvas 2D renderer on the same generator inputs."""

import argparse
import json
import re
import shutil
import subprocess
import tempfile
from pathlib import Path
from statistics import median

ROOT = Path(__file__).resolve().parents[1]
ORIGINAL = "5f78b3fb3e167365d86dc21b79788bec454c16ec"
CASES = [("Koch", 4096), ("SampleFractal", 65536), ("Peano Serpent", 1000000)]


def line(fields):
    x0, y0, x1, y1 = map(float, fields)
    return {"start": {"x": x0, "y": y0}, "end": {"x": x1, "y": y1}}


def measure(directory, original, chrome):
    bench = directory / "bench"
    subprocess.run(["bash", "scripts/build_native_demo.sh", "-I", "src",
                    "benchmarks/fractal_throughput.mojo", "-o", bench], cwd=ROOT, check=True)
    cases, native = [], []
    for row in subprocess.check_output([bench], text=True).splitlines():
        tag, *fields = row.split()
        if tag == "CASE":
            cases.append({"base": line(fields[2:]), "depth": int(fields[1]), "lines": []})
            native.append([])
        elif tag == "LINE":
            cases[-1]["lines"].append(line(fields))
        elif tag == "TIME":
            native[-1].append({"leaves": int(fields[1]), "ms": float(fields[2])})

    # Read the pinned git objects, even if the supplied checkout has local edits.
    for name in ("constants.js", "drawFractal.js", "generator.js", "helpers.js"):
        (directory / name).write_bytes(subprocess.check_output(
            ["git", "-C", original, "show", f"{ORIGINAL}:{name}"]))
    (directory / "cases.js").write_text("export const cases = " + json.dumps(cases))
    page = directory / "fractal_canvas.html"
    shutil.copyfile(ROOT / "benchmarks" / page.name, page)
    dom = subprocess.check_output([
        chrome, "--headless=new", "--no-first-run", "--disable-extensions",
        "--allow-file-access-from-files", f"--user-data-dir={directory / 'profile'}",
        "--dump-dom", page.as_uri(),
    ], text=True, timeout=300)
    match = re.search(r'<pre id="results">(\[.*?\])</pre>', dom)
    if not match:
        raise RuntimeError("Chrome did not finish the benchmark")
    return native, json.loads(match[1])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("original", help="local clone of davidmashburn/canvas-line-fractal")
    parser.add_argument("--chrome", default="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome")
    args = parser.parse_args()
    with tempfile.TemporaryDirectory() as directory:
        native, browser = measure(Path(directory), args.original, args.chrome)
    for (name, leaves), a, b in zip(CASES, native, browser, strict=True):
        if len(a) != 9 or len(b) != 9 or any(row["leaves"] != leaves for row in a + b):
            raise ValueError(f"Unexpected trial or leaf count for {name}")
        result = {"curve": name, "lines": leaves, "native_ms": [r["ms"] for r in a[2:]],
                  "js_submit_ms": [r["submit"] for r in b[2:]],
                  "js_readback_ms": [r["readback"] for r in b[2:]]}
        result["speedup"] = median(result["js_submit_ms"]) / median(result["native_ms"])
        print(json.dumps(result))


if __name__ == "__main__":
    main()
