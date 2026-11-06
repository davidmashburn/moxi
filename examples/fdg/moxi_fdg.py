"""Send Python graph data to the built Moxi viewer (standard library only)."""

from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess
import tempfile
import sys
from enum import Enum
from importlib import resources


class ExportFormat(str, Enum):
    SVG = "svg"
    PNG = "png"
    PDF = "pdf"


def _default_executable():
    try:
        packaged = resources.files("_moxi_fdg_data") / "moxi-fdg"
        if packaged.is_file():
            return packaged
    except ModuleNotFoundError:
        pass
    return Path(__file__).resolve().parent / "dist" / "moxi-fdg"


def _executable(executable):
    path = Path(
        executable
        or os.environ.get("MOXI_FDG_EXECUTABLE")
        or _default_executable()
    ).expanduser().resolve()
    if not path.is_file():
        raise FileNotFoundError(
            f"Viewer not found: {path}. Install a local moxi-fdg platform wheel, build examples/fdg/scripts/build.sh, or set "
            "MOXI_FDG_EXECUTABLE to the built executable."
        )
    if not os.access(path, os.X_OK):
        raise PermissionError(f"Viewer is not executable: {path}")
    return str(path)


def _payload(graph):
    text = json.dumps(graph, ensure_ascii=False, allow_nan=False, separators=(",", ":"))
    data = text.encode("utf-8")
    if len(text) > 262144 or len(data) > 1048576:
        raise ValueError("Graph exceeds the viewer's 256K-character / 1 MiB input limit")
    return data


def view_graph(graph, *, executable=None, wait=False):
    """Open a native window for a nodes/links dictionary and return its Popen.

    By default the caller continues once JSON has been sent. Use wait=True to
    wait until the window closes and raise CalledProcessError on a nonzero exit.
    Viewer diagnostics inherit the caller's stdout/stderr. In nonblocking mode,
    inspect the returned process's poll()/wait() for validation/startup failures.
    Each call opens an independent viewer; subsequent graph mutations are not
    sent. The window opens on the Python process's machine (macOS ARM64 or the Linux GTK lane).
    """
    data = _payload(graph)
    process = subprocess.Popen([_executable(executable), "/dev/stdin"], stdin=subprocess.PIPE)
    try:
        process.stdin.write(data)
        process.stdin.close()
        process.stdin = None
        if wait:
            returncode = process.wait()
            if returncode:
                raise subprocess.CalledProcessError(returncode, process.args)
        return process
    except BaseException:
        if process.poll() is None:
            process.terminate()
        process.wait()
        if process.stdin is not None:
            try:
                process.stdin.close()
            except BrokenPipeError:
                pass
        raise


def fdg(nodes, links, *, executable=None, wait=False):
    """Original-style tuples: nodes=(id, group), links=(source, target, value).

    Template/JavaScript styling options from render_d3_fdg are not supported.
    """
    return view_graph(
        {
            "nodes": [{"id": id_, "group": group} for id_, group in nodes],
            "links": [
                {"source": source, "target": target, "value": value}
                for source, target, value in links
            ],
        },
        executable=executable,
        wait=wait,
    )


def render_svg(graph, *, executable=None, timeout=30):
    """Return a settled SVG snapshot, without opening a window.

    In Jupyter: display(IPython.display.SVG(render_svg(graph))). This is a static
    graph snapshot, not the live viewer. Invalid graphs raise CalledProcessError
    with the viewer's diagnostic in stderr. Temporary output is removed.
    """
    data = _payload(graph)
    with tempfile.TemporaryDirectory(prefix="moxi-fdg-") as directory:
        output = Path(directory) / "graph.svg"
        subprocess.run(
            [_executable(executable), "/dev/stdin", "--export", str(output)],
            input=data,
            capture_output=True,
            check=True,
            timeout=timeout,
        )
        return output.read_text(encoding="utf-8")


def render_graph(graph, *, format=ExportFormat.PNG, executable=None, timeout=30):
    """Return settled PNG/PDF bytes or SVG text. PNG/PDF need rsvg-convert.

    This is a new deterministic snapshot; use the native Export command for the
    live application's current selection, viewport and simulation positions.
    """
    format = ExportFormat(format)
    data = _payload(graph)
    with tempfile.TemporaryDirectory(prefix="moxi-fdg-") as directory:
        output = Path(directory) / ("graph." + format.value)
        subprocess.run([_executable(executable), "/dev/stdin", "--export", str(output)],
                       input=data, capture_output=True, check=True, timeout=timeout)
        return output.read_text(encoding="utf-8") if format is ExportFormat.SVG else output.read_bytes()


def sample_graph():
    """Read the packaged fixture (or the same fixture in a source checkout)."""
    try:
        fixture = resources.files("_moxi_fdg_data") / "triangle.json"
        return json.loads(fixture.read_text(encoding="utf-8"))
    except (ModuleNotFoundError, FileNotFoundError):
        fixture = Path(__file__).resolve().parent / "examples/triangle.json"
        return json.loads(fixture.read_text(encoding="utf-8"))


def main():
    """Console entrypoint forwarding arguments to the packaged native viewer."""
    raise SystemExit(subprocess.call([_executable(None), *sys.argv[1:]]))


if __name__ == "__main__":
    main()
