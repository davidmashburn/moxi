#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../.." && pwd)"
python="${MOXI_E04_PYTHON:-python3}"
consumer="$(mktemp -d /tmp/moxi-e04-consumer.XXXXXX)"
artifacts="${MOXI_E04_ARTIFACTS:-$root/artifacts/demo-slideshows/e04-python-native}"
mkdir -p "$artifacts" "$consumer/tests" "$consumer/home"
"$python" -m venv "$consumer/venv"
tag="$("$consumer/venv/bin/python" -c 'import sys; print(f"cp{sys.version_info.major}{sys.version_info.minor}")')"
native_wheels=("$here"/dist/wheels/moxi_native*-"$tag"-"$tag"-*.whl)
if [ "${#native_wheels[@]}" != 1 ] || [ ! -f "${native_wheels[0]}" ]; then
  printf 'Expected exactly one native wheel for %s\n' "$tag" >&2
  exit 1
fi
"$consumer/venv/bin/python" -m pip install "$here"/dist/wheels/moxi-*.whl "${native_wheels[0]}" pytest pillow pypdf
"$consumer/venv/bin/python" -m pip check
cp "$here"/tests/*.py "$consumer/tests/"
"$python" "$here/inspect_wheel.py" "${native_wheels[0]}" > "$artifacts/packaging.json"
# Isolated mode omits the repo and user-site. pytest loads only copied test files.
native_status=0
(cd "$consumer" && env -i HOME="$consumer/home" PATH=/usr/bin:/bin PYTHONMALLOC=debug \
  "$consumer/venv/bin/python" -I -m pytest tests -q) > "$consumer/native-tests.log" 2>&1 || native_status=$?
cp "$consumer/native-tests.log" "$artifacts/native-tests.log"
cat "$consumer/native-tests.log"
if [ "$native_status" -ne 0 ]; then exit "$native_status"; fi
# run_path permits only this copied fixture directory, never a repository import.
(cd "$consumer" && env -i HOME="$consumer/home" PATH=/usr/bin:/bin PYTHONMALLOC=debug \
  "$consumer/venv/bin/python" -I -c 'import runpy,sys; sys.path.insert(0,"tests"); sys.argv=["tests/probe.py",sys.argv[1]]; runpy.run_path("tests/probe.py",run_name="__main__")' "$artifacts")
# The existing suite stays authoritative for the unchanged facade.
cp -R "$root/tests/python" "$consumer/tests/python"
mkdir -p "$consumer/tests/fixtures" "$consumer/scripts/wave_b" "$consumer/scripts/wave_c" "$consumer/src/moxi" "$consumer/docs"
cp -R "$root/tests/fixtures/wave_a" "$root/tests/fixtures/wave_b" "$root/tests/fixtures/wave_c" "$consumer/tests/fixtures/"
cp "$root/tests/test_specialized_c.py" "$consumer/tests/"
# Copy the fixture loaders and their data dependencies, never the facade source.
for wave in wave_b wave_c; do
  cp "$root/scripts/$wave/fixtures.py" "$root/scripts/$wave/boundaries.py" "$consumer/scripts/$wave/"
done
cp "$root/src/moxi/scenarios.mojo" "$consumer/src/moxi/"
cp "$root/docs/dataviz-capabilities.tsv" "$consumer/docs/"
facade_status=0
(cd "$consumer" && env -i HOME="$consumer/home" PATH=/usr/bin:/bin \
  "$consumer/venv/bin/python" -I -m pytest tests/python tests/test_specialized_c.py -q) > "$consumer/facade-tests.log" 2>&1 || facade_status=$?
cp "$consumer/facade-tests.log" "$artifacts/facade-tests.log"
cat "$consumer/facade-tests.log"
if [ "$facade_status" -ne 0 ]; then exit "$facade_status"; fi
printf 'Clean installed consumer retained at %s\n' "$consumer"
