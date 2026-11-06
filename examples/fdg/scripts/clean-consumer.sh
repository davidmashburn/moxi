#!/usr/bin/env bash
set -euo pipefail
app_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
wheel="${1:?Usage: clean-consumer.sh /absolute/local.whl /absolute/evidence-directory}"
evidence="${2:?Supply an absolute evidence directory}"
work="$(mktemp -d /tmp/moxi-p06-consumer.XXXXXX)"
# Retain this isolated installation for audit/reopened inspection.
printf '%s\n' "$work" > /tmp/moxi-p06-consumer-path.txt
uv venv "$work/venv"
uv pip install --python "$work/venv/bin/python" --no-deps "$wheel"
mkdir -p "$work/clean" "$evidence"
cp "$app_dir/tests/fixtures/export.json" "$work/clean/fixture.json"
cd "$work/clean"
unset PYTHONPATH MOXI_FDG_EXECUTABLE DYLD_LIBRARY_PATH LD_LIBRARY_PATH
"$work/venv/bin/python" -I - "$evidence" <<'PY'
import json, os, pathlib, subprocess, sys
import moxi_fdg
from importlib import resources
module = pathlib.Path(moxi_fdg.__file__).resolve()
assert module.is_relative_to(pathlib.Path(sys.prefix).resolve()), module
binary = pathlib.Path(moxi_fdg._executable(None))
assert binary.is_relative_to(pathlib.Path(sys.prefix).resolve()), binary
assert len(moxi_fdg.sample_graph()["nodes"]) == 4
assert (resources.files("_moxi_fdg_data") / "runtime-notices/LICENSE").is_file()
graph = json.loads(pathlib.Path("fixture.json").read_text())
assert moxi_fdg.render_graph(graph, format=moxi_fdg.ExportFormat.PNG).startswith(b"\x89PNG")
assert moxi_fdg.render_graph(graph, format=moxi_fdg.ExportFormat.PDF).startswith(b"%PDF")
assert "α" in moxi_fdg.render_svg(graph)
os.environ["MOXI_FDG_RSVG"] = str(pathlib.Path.cwd()/"missing-converter")
try:
    try:
        moxi_fdg.render_graph(graph)
    except subprocess.CalledProcessError as error:
        assert b"requires rsvg-convert" in error.stderr
    else:
        raise AssertionError("Missing optional converter was silently accepted")
    assert "α" in moxi_fdg.render_svg(graph)
finally:
    del os.environ["MOXI_FDG_RSVG"]
# Native installed executable opens, handles real app events, exports and closes.
subprocess.run([binary, "fixture.json", "--replay", sys.argv[1]], check=True, timeout=60)
subprocess.run([str(pathlib.Path(sys.prefix)/"bin/moxi-fdg"), "--smoke"], check=True, timeout=30)
# Missing required runtime must fail, then restore the same local installation.
lib = next((binary.parent / "lib").glob("libKGENCompilerRTShared.*"))
hidden = lib.with_suffix(lib.suffix + ".missing")
lib.rename(hidden)
try:
    result = subprocess.run([binary,"--help"], capture_output=True, timeout=30)
    assert result.returncode != 0
finally:
    hidden.rename(lib)
subprocess.run([binary,"--help"], check=True, capture_output=True, timeout=30)
(pathlib.Path(sys.argv[1])/"consumer-check.json").write_text(json.dumps({
    "module":str(module),"executable":str(binary),"cwd":str(pathlib.Path.cwd()),
    "isolated_python":sys.flags.isolated,"runtime_removal_failed_as_expected":True,
    "fixture_loaded_from_package":True,"optional_converter_rejection":True,"native_replay_exit":0},indent=2)+"\n")
print("PASS: isolated wheel import, packaged fixture/runtime, PNG/PDF/SVG, native replay + console smoke, missing-runtime rejection and recovery")
PY
if [[ "$(uname -s)" == Darwin ]]; then
  DYLD_PRINT_LIBRARIES=1 "$work/venv/bin/moxi-fdg" --help 2> "$evidence/loaded-libraries.log" >/dev/null
  if rg 'KGEN|MSupport|AsyncRT' "$evidence/loaded-libraries.log" | rg -v "$(cd "$work/venv" && pwd -P)/"; then
    echo 'Runtime escaped isolated installation' >&2; exit 1
  fi
fi

if [[ "$(uname -s)" == Linux ]]; then
  "$work/venv/bin/python" -I - "$evidence" <<'PYTHON'
import pathlib, subprocess, sys
import moxi_fdg
binary = pathlib.Path(moxi_fdg._executable(None))
linked = subprocess.check_output(["ldd", str(binary)], text=True)
(pathlib.Path(sys.argv[1])/"loaded-libraries.log").write_text(linked)
assert "not found" not in linked and "/work/" not in linked, linked
for name in ("libKGENCompilerRTShared", "libMSupportGlobals", "libAsyncRTRuntimeGlobals"):
    line = next(line for line in linked.splitlines() if name in line)
    assert str(binary.parent / "lib") in line, line
print("PASS: Linux runtime dependencies resolve inside the installation or system library directories")
PYTHON
fi
