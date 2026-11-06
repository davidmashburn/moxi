#!/usr/bin/env python3
"""Compile a locally instrumented P01 ABI, without modifying its source."""
import hashlib
import json
import os
from pathlib import Path
import subprocess

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
DIST = HERE.parent / "dist/interactive"
P01 = ROOT / "experiments/browser-moxi"


def replace_once(text, old, new):
    assert text.count(old) == 1, f"P01 source changed: {old}"
    return text.replace(old, new)


def main():
    DIST.mkdir(parents=True, exist_ok=True)
    source = (P01 / "browser.mojo").read_text()
    # Measure real scene construction separately from SVG serialization. The
    # event timer includes actual solver/layout dispatch and Moxi invalidation.
    for old, new in (
        ('    _ = dispatch_graph_event(ptr[].app, event)', '    if kind == FRAME_TICK_KIND:\n        external_call["moxi_phase", NoneType](Int32(3))\n    _ = dispatch_graph_event(ptr[].app, event)\n    if kind == FRAME_TICK_KIND:\n        external_call["moxi_phase", NoneType](Int32(4))'),
        ('        var controls = scene_from_paint', '        external_call["moxi_phase", NoneType](Int32(0))\n        var controls = scene_from_paint'),
        ('        var renderer = SvgSceneRenderer', '        external_call["moxi_phase", NoneType](Int32(1))\n        var renderer = SvgSceneRenderer'),
        ('        var markup = ptr[].svg.as_c_string_span()', '        external_call["moxi_phase", NoneType](Int32(2))\n        var markup = ptr[].svg.as_c_string_span()'),
    ):
        source = replace_once(source, old, new)
    (DIST / "browser.mojo").write_text(source)
    runtime = (P01 / "runtime.mjs").read_text()
    runtime = replace_once(runtime, '{heapLimit = Limits.memory, memory64 = supportsMemory64()}', '{heapLimit = Limits.memory, memory64 = supportsMemory64(), observe = () => {}}')
    runtime = replace_once(runtime, '  const env = {', '  const env = {\n    moxi_phase: observe,')
    (DIST / "runtime.mjs").write_text(runtime)
    adapter = (HERE / "interactive.mjs").read_text()
    (DIST / "widget.mjs").write_text(runtime + '\n' + adapter.replace('import {instantiateMoxi, EventKind, Control, AppField, NodeField} from "./runtime.mjs";', ''))
    manifest = Path(os.environ.get("MOXI_PIXI_MANIFEST", ROOT / "pixi.toml"))
    versions = {
        "mojo": subprocess.check_output(["pixi", "run", "--manifest-path", str(manifest), "mojo", "--version"], text=True).strip(),
        "clang": subprocess.check_output(["clang", "--version"], text=True).splitlines()[0],
        "lld": subprocess.check_output([str(manifest.parent / ".pixi/envs/default/bin/lld"), "-flavor", "wasm", "--version"], text=True).strip(),
    }
    required = {"mojo": "Mojo 1.1.0 (8189361e)", "clang": "Apple clang version 21.0.0 (clang-2100.3.34.2)", "lld": "LLD 24.0.0"}
    for tool, expected in required.items():
        if expected not in versions[tool]:
            raise RuntimeError(f"Unvalidated {tool}: {versions[tool]}")
    def run(*args):
        subprocess.run(list(map(str, args)), check=True, cwd=ROOT)
    run("pixi", "run", "--manifest-path", manifest, "mojo", "build", DIST / "browser.mojo", "-I", ROOT / "src", "-I", HERE.parent / "src", "--emit", "llvm", "-o", DIST / "browser.ll")
    run("python3", P01 / "retarget.py", DIST / "browser.ll")
    run("clang", "-target", "wasm64-unknown-unknown", "-c", "-O2", DIST / "browser.portable.ll", "-o", DIST / "browser.o")
    exports = ["moxi_create", "moxi_destroy", "moxi_event", "moxi_resize", "moxi_render", "moxi_inspect", "__heap_base"]
    run(manifest.parent / ".pixi/envs/default/bin/lld", "-flavor", "wasm", "-mwasm64", "--no-entry", *[f"--export={x}" for x in exports], "--allow-undefined", "--max-memory=67108864", DIST / "browser.o", "-o", DIST / "browser.wasm")
    sources = [*sorted((ROOT / "src").rglob("*.mojo")), *sorted((HERE.parent / "src").glob("*.mojo")), P01 / "browser.mojo", P01 / "runtime.mjs", P01 / "retarget.py", Path(__file__), HERE / "interactive.mjs"]
    hashes = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sources}
    (DIST / "build.json").write_text(json.dumps(dict(versions=versions, source_hashes=hashes, wasm_sha256=hashlib.sha256((DIST / "browser.wasm").read_bytes()).hexdigest()), indent=2) + '\n')
    print("Built instrumented real Moxi widget", flush=True)


if __name__ == "__main__":
    main()
