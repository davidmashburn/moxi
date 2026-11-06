#!/usr/bin/env python3
"""Execute the P03 notebook in a real local kernel, including native lifecycle.

Requires the optional requirements.txt environment, a compiled FDG binary,
macOS ARM64 and a graphical session. Leaves only local artifacts in dist/ and
artifacts/demo-slideshows/fdg-notebook/; the tracked notebook stays output-free.
"""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import platform
import subprocess
import time
import tempfile

import nbformat
from nbclient import NotebookClient
from jupyter_client import KernelManager

EXAMPLE = Path(__file__).resolve().parents[1]
ROOT = EXAMPLE.parents[1]
DESTINATION = ROOT / "artifacts/demo-slideshows/fdg-notebook"
DIST = EXAMPLE / "dist/notebook"


def command(directory, pid, **request):
    path = directory / f"{pid}.json"
    temporary = path.with_suffix(".tmp")
    temporary.write_text(json.dumps(request))
    temporary.replace(path)
    deadline = time.monotonic() + 15
    while path.exists():
        if time.monotonic() > deadline:
            raise TimeoutError(f"Native probe did not acknowledge PID {pid}")
        time.sleep(0.05)


def extra(client, source):
    cell = nbformat.v4.new_code_cell(source)
    index = len(client.nb.cells)
    client.nb.cells.append(cell)
    try:
        result = client.execute_cell(cell, index)
        return "".join(o.get("text", "") for o in result.outputs)
    finally:
        client.nb.cells.pop()


def source_paths():
    return sorted({*ROOT.joinpath("src").rglob("*.mojo"),
                    *ROOT.joinpath("native").glob("*.m"),
                    *ROOT.joinpath("native").glob("*.h"),
                    *EXAMPLE.joinpath("src").glob("*.mojo"),
                    *EXAMPLE.joinpath("native").glob("*.m"),
                    EXAMPLE / "moxi_fdg.py", EXAMPLE / "entrypoints.ipynb",
                    *EXAMPLE.joinpath("notebook").glob("*.py"),
                    *EXAMPLE.joinpath("notebook").glob("requirements*.txt"),
                    EXAMPLE / "notebook/native_probe.m",
                    EXAMPLE / "scripts/build.sh", ROOT / "pixi.toml", ROOT / "pixi.lock"})


def source_fingerprint():
    digest = hashlib.sha256()
    for path in source_paths():
        digest.update(str(path.relative_to(ROOT)).encode() + b"\0" + path.read_bytes())
    return digest.hexdigest()


def main():
    if platform.system() != "Darwin" or platform.machine() != "arm64":
        raise SystemExit("This native notebook check requires macOS ARM64")
    DIST.mkdir(parents=True, exist_ok=True)
    DESTINATION.mkdir(parents=True, exist_ok=True)
    probe = DIST / "native_probe.dylib"
    subprocess.run(["clang", "-Wall", "-Wextra", "-Werror", "-fobjc-arc",
                    "-dynamiclib", str(EXAMPLE / "notebook/native_probe.m"),
                    "-framework", "Cocoa", "-o", str(probe)], check=True)
    bounds = DIST / "window-bounds"
    subprocess.run(["clang", str(ROOT / "native/macos_window_bounds.c"),
                    "-framework", "CoreGraphics", "-framework", "CoreFoundation",
                    "-o", str(bounds)], check=True)
    commands = tempfile.TemporaryDirectory(prefix="moxi-p03-native-")
    command_directory = Path(commands.name)
    notebook = nbformat.read(EXAMPLE / "entrypoints.ipynb", as_version=4)
    assert all(c.execution_count is None and not c.outputs
               for c in notebook.cells if c.cell_type == "code")
    km = KernelManager(kernel_name="python3")
    client = NotebookClient(notebook, km=km, timeout=30,
                            resources={"metadata": {"path": str(EXAMPLE)}})
    environment = dict(os.environ, DYLD_INSERT_LIBRARIES=str(probe),
                       MOXI_NOTEBOOK_PROBE_DIR=str(command_directory))
    evidence = {"rounds": [], "source_sha256": source_fingerprint()}
    child_pids = set()
    try:
        with client.setup_kernel(cwd=str(EXAMPLE), env=environment):
            for round_number in range(2):
                if round_number:
                    km.restart_kernel(now=True)
                    client.kc.wait_for_ready(timeout=30)
                    client.reset_execution_trackers()
                kernel_pid = int(extra(client, "import os; print(os.getpid())").strip())
                if round_number:
                    assert kernel_pid != evidence["rounds"][0]["kernel_pid"]
                    extra(client, "assert 'graph' not in globals() and 'viewers' not in globals()")
                result = {"kernel_pid": kernel_pid, "code_cells": 0}
                for index, cell in enumerate(notebook.cells):
                    cell_start = time.monotonic()
                    client.execute_cell(cell, index)
                    if cell.cell_type == "code":
                        result["code_cells"] += 1
                    if index == 6:  # Repeat the actual launch cell, preserving both handles.
                        client.execute_cell(cell, index)
                        pids = json.loads(extra(client, "print(json.dumps([p.pid for p in viewers]))"))
                        assert len(pids) == 2 and len(set(pids)) == 2
                        child_pids.update(pids)
                        # Acknowledgement requires both actual NSWindows to be visible.
                        for pid in pids:
                            command(command_directory, pid)
                    if index == 7:
                        extra(client, "assert len(viewers) == 2 and all(p.poll() is None for p in viewers); assert answer == 333328333350000")
                        result["responsive_cell_seconds"] = round(time.monotonic() - cell_start, 4)
                        if not round_number:
                            desktop = subprocess.run([str(bounds), "--pid", str(pids[0]),
                                                      "--title", "Moxi Force Graph"],
                                                     capture_output=True, text=True)
                            result["desktop_window_lookup_exit"] = desktop.returncode
                            result["desktop_window_lookup_output"] = desktop.stdout.strip()
                            command(command_directory, pids[0], capture=str(DESTINATION / "02-native.png"))
                        # Real AppKit window-close callback, not SIGTERM.
                        for pid in pids:
                            command(command_directory, pid, close=True)
                        extra(client, "assert all(p.wait(timeout=10) == 0 for p in viewers)")
                        result["normal_close_codes"] = [0, 0]
                    if index == 11:
                        pid = int(extra(client, "print(viewer.pid)"))
                        child_pids.add(pid)
                        if round_number:
                            command(command_directory, pid, capture=str(DESTINATION / "05-restart-native.png"))
                        else:
                            command(command_directory, pid, capture=str(DESTINATION / "04-reopen-native.png"))
                        extra(client, "assert viewer.poll() is None")
                extra(client, "assert viewers == [] and viewer.poll() is not None")
                extra(client, '''
try:
    render_svg(graph, executable=example / 'dist' / 'missing-p03-binary')
except FileNotFoundError as error:
    assert 'Build with scripts/build.sh' in str(error)
    assert 'MOXI_FDG_EXECUTABLE' in str(error)
else:
    raise AssertionError('Missing executable accepted')
failed = view_graph(invalid_graph)
assert failed.wait(timeout=10) != 0
''')
                result["missing_binary_and_async_invalid_graph"] = "passed"
                evidence["rounds"].append(result)
                nbformat.write(notebook, DIST / ("executed.ipynb" if not round_number else "restarted.ipynb"))
        for pid in child_pids:
            try:
                os.kill(pid, 0)
            except ProcessLookupError:
                continue
            raise AssertionError(f"Viewer PID {pid} survived cleanup")
    finally:
        # Bound failure cleanup to children this harness observed.
        for pid in child_pids:
            try:
                os.kill(pid, 15)
            except ProcessLookupError:
                pass
        if km.has_kernel:
            km.shutdown_kernel(now=True)
        commands.cleanup()
    evidence["versions"] = json.loads(next(o.text for o in notebook.cells[1].outputs if o.output_type == "stream"))
    evidence["versions"]["Mojo"] = subprocess.check_output(
        ["pixi", "run", "mojo", "--version"], cwd=ROOT, text=True).strip()
    evidence["binary_sha256"] = hashlib.sha256((EXAMPLE / "dist/moxi-fdg").read_bytes()).hexdigest()
    evidence["source_revision"] = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    evidence["source_status"] = subprocess.check_output(["git", "status", "--short"], cwd=ROOT, text=True).splitlines()
    evidence["native_capture"] = "Live NSWindow content view via cacheDisplay; injected test probe; excludes desktop compositor and window chrome"
    evidence["remote_kernel"] = "Not tested"
    evidence["physical_input_and_voiceover"] = "Not tested; VoiceOver remains paused"
    (DIST / "evidence.json").write_text(json.dumps(evidence, indent=2) + "\n")
    print(json.dumps(evidence, indent=2))


if __name__ == "__main__":
    main()
