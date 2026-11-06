#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../.." && pwd)"
python="${MOXI_E04_PYTHON:-python3}"
consumer="$(mktemp -d /tmp/moxi-e04-consumer.XXXXXX)"
artifacts="$root/artifacts/demo-slideshows/e04-python-native"
mkdir -p "$artifacts" "$consumer/tests" "$consumer/home"
"$python" -m venv "$consumer/venv"
"$consumer/venv/bin/python" -m pip install "$here"/dist/wheels/*.whl pytest pillow pypdf
"$consumer/venv/bin/python" -m pip check
cp "$here"/tests/*.py "$consumer/tests/"
"$python" "$here/inspect_wheel.py" "$here"/dist/wheels/moxi_native*.whl > "$artifacts/packaging.json"
# Isolated mode omits the repo and user-site. pytest loads only copied test files.
(cd "$consumer" && env -i HOME="$consumer/home" PATH=/usr/bin:/bin PYTHONMALLOC=debug \
  "$consumer/venv/bin/python" -I -m pytest tests -q) > /tmp/moxi-e04-native-tests.log 2>&1
cat /tmp/moxi-e04-native-tests.log
# run_path permits only this copied fixture directory, never a repository import.
(cd "$consumer" && env -i HOME="$consumer/home" PATH=/usr/bin:/bin PYTHONMALLOC=debug \
  "$consumer/venv/bin/python" -I -c 'import runpy,sys; sys.path.insert(0,"tests"); sys.argv=["tests/probe.py",sys.argv[1]]; runpy.run_path("tests/probe.py",run_name="__main__")' "$artifacts")
cp /tmp/moxi-e04-native-tests.log "$artifacts/native-tests.log"
# The existing suite stays authoritative for the unchanged facade.
cp -R "$root/tests/python" "$consumer/facade-tests"
mkdir -p "$consumer/fixtures"
cp -R "$root/tests/fixtures/wave_a" "$consumer/fixtures/"
(cd "$consumer" && env -i HOME="$consumer/home" PATH=/usr/bin:/bin \
  "$consumer/venv/bin/python" -I -m pytest facade-tests -q) > /tmp/moxi-e04-facade-tests.log 2>&1
cat /tmp/moxi-e04-facade-tests.log
cp /tmp/moxi-e04-facade-tests.log "$artifacts/facade-tests.log"
printf 'Clean installed consumer retained at %s\n' "$consumer"
