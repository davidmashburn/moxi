#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

fail() {
  echo "Moxi Linux VM check: $*" >&2
  exit 1
}

[[ "$(uname -s)" == Linux ]] || fail "run this script inside a Linux VM"
[[ "$(uname -m)" == x86_64 ]] || fail "the locked guest lane requires x86_64 (linux-64)"

for tool in cc g++ ar git tar node pixi systemd-detect-virt; do
  command -v "$tool" >/dev/null 2>&1 || fail "missing prerequisite: $tool"
done
if container_kind="$(systemd-detect-virt --container 2>/dev/null)"; then
  fail "container detected: $container_kind; run directly in the guest OS"
fi
if ! vm_kind="$(systemd-detect-virt --vm 2>/dev/null)"; then
  fail "no virtual machine detected; containers and the host are outside this lane"
fi
node -e 'if (Number(process.versions.node.split(".")[0]) < 18) {
  console.error("Moxi Linux VM check: Node.js 18 or newer is required");
  process.exit(1);
}'

[[ ! -e .pixi ]] || fail "transfer a fresh source snapshot without .pixi"
[[ ! -e dist ]] || fail "transfer a fresh source snapshot without dist"
native_artifact="$(find native experiments -type f \( \
  -name '*.o' -o -name '*.a' -o -name '*.so' -o -name '*.dylib' \
  -o -name '*.mojoc' \) -print -quit)"
[[ -z "$native_artifact" ]] || fail "remove reused native build artifact: $native_artifact"

# Linux calls SSE3 "pni" and commonly exposes LZCNT as "abm".
cpu_flags="$(awk '/^flags[[:space:]]*:/ { $1=""; $2=""; print; exit }' /proc/cpuinfo)"
has_flag() {
  [[ " $cpu_flags " == *" $1 "* ]]
}
for flag in cx16 lahf_lm popcnt ssse3 sse4_1 sse4_2 avx avx2 bmi1 bmi2 f16c fma movbe xsave; do
  has_flag "$flag" || fail "guest CPU lacks x86-64-v3 flag: $flag"
done
has_flag pni || has_flag sse3 || fail "guest CPU lacks SSE3 (pni)"
has_flag abm || has_flag lzcnt || fail "guest CPU lacks LZCNT (abm)"

echo "Moxi real Linux VM portable checks"
date -u '+Date: %Y-%m-%dT%H:%M:%SZ'
uname -srvm
sed -n '/^PRETTY_NAME=/p' /etc/os-release
echo "Virtual machine: $vm_kind"
awk '/^model name[[:space:]]*:/ { print; exit }' /proc/cpuinfo
sed -n '/^MemTotal:/p' /proc/meminfo
echo "CPU: x86-64-v3 flags verified"
cc --version | sed -n '1p'
g++ --version | sed -n '1p'
node --version
pixi --version
sha256sum pixi.toml pixi.lock

echo "==> Install the locked Linux environment"
pixi install --locked
pixi run --locked mojo --version

echo "==> Portable software plot and Mojo source precompilation"
pixi run --locked headless-check
echo "==> Mojo retained engine and box publication contracts"
pixi run --locked retained-engine-test
pixi run --locked box-layout-test
echo "==> Kiwi C++ bridge and Mojo constraint publication contracts"
CXX=g++ pixi run --locked constraint-layout-check

for test_file in \
  tests/collection_layout.mojo \
  tests/overlay_layout.mojo \
  tests/request_adapter.mojo \
  tests/reactivity_tasks.mojo \
  tests/plot_view.mojo \
  tests/execution.mojo; do
  echo "==> $test_file"
  pixi run --locked mojo run -I src "$test_file"
done

echo "==> Web host contracts and HTTP harness (fake DOM/surface; no browser launched)"
node tests/web_host.mjs
node tests/web_browser_harness.mjs

echo "Moxi Linux VM portable checks passed"
echo "Native window/text/accessibility, real-browser interaction, mobile and benchmarks were not checked"
