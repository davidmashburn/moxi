# Cross-platform VM validation

Use real guest operating systems and clean source snapshots to check installation,
execution and host integration. A passing portable test does not certify a native
desktop backend. Keep guest results separate from hosted CI, fake-DOM harnesses,
browser interaction and physical input checks.

## Scope and order

| Guest | Checks | Current boundary |
| --- | --- | --- |
| Ubuntu 24.04 x86-64, first | Exact `pixi.lock`; Mojo retained engine, box/collection/overlay policies, Kiwi constraints, portable plotting and precompilation; rebased request/runtime/plot regressions; Node host contracts | Linux native window, text and accessibility backends are unavailable. Node harnesses do not exercise a browser. |
| Ubuntu desktop, next | Actual guest browser rendering, pointer/key/resize, then a fixture for scroll, composition and ARIA | The current browser demo is a JavaScript host demo, not a compiled Mojo layout app. The pinned compiler has no supported WASM package target. |
| macOS ARM64, next | Clean native-services build, installed consumer and layout workbench in a GUI session | AppKit/CoreText checks apply to macOS. VoiceOver speech, real Japanese composition and physical horizontal input require separate observations. |
| Windows 11 ARM64, later | Actual Edge/browser host and Python wheel consumption | Mojo has no native Windows support; WSL results must be reported as Linux. Moxi's Windows native backend is unavailable. Guest image/license and GUI provisioning are not established yet. |

Do not add a Linux or Windows native backend as part of this validation task.
Android/iOS emulator checks remain separate: their host adapters currently do not
execute the Mojo layout engine.

## First guest

[The Lima configuration](../scripts/vm/ubuntu-24.04-x86_64.yaml) pins Ubuntu's
2026-07-05 cloud image and SHA-256. It reserves 4 CPUs, 8 GiB RAM and a 40 GiB
sparse disk. It disables host mounts, extra host SSH keys, agent forwarding and
container runtimes. On Apple Silicon this is a full x86 guest running under QEMU
TCG, rather than a container or an ARM guest with translated x86 userspace.
Its timings must not be compared with native frame budgets.

Host prerequisites used for the initial setup are Lima 2.2.0, its additional guest
agents and QEMU 11.1.2. Start and stop only this task's guest:

```sh
brew install lima lima-additional-guestagents qemu
limactl validate scripts/vm/ubuntu-24.04-x86_64.yaml
limactl start --yes --name=moxi-linux-x86 --timeout=30m scripts/vm/ubuntu-24.04-x86_64.yaml
limactl shell moxi-linux-x86 uname -a
limactl stop moxi-linux-x86
```

Inside the guest, install build tools and the pinned Pixi executable:

```sh
sudo apt-get update
sudo apt-get install --no-install-recommends -y build-essential nodejs python3-venv ca-certificates curl git
curl -fL https://github.com/prefix-dev/pixi/releases/download/v0.81.0/pixi-x86_64-unknown-linux-musl.tar.gz -o /tmp/moxi-pixi.tar.gz
printf '%s\n' '7aa3ec39aecceff9062fa2ed4d42cbaa0bdc25ddea727d048e061cf188d434f6  /tmp/moxi-pixi.tar.gz' | sha256sum -c -
mkdir -p "$HOME/.local/bin"
tar -xzf /tmp/moxi-pixi.tar.gz -C "$HOME/.local/bin" pixi
export PATH="$HOME/.local/bin:$PATH"
```

The Pixi checksum comes from the official
[v0.81.0 release asset](https://github.com/prefix-dev/pixi/releases/tag/v0.81.0).
From the host, transfer the committed source:

```sh
git rev-parse HEAD
git archive --format=tar HEAD -o /tmp/moxi-vm-source.tar
shasum -a 256 /tmp/moxi-vm-source.tar
limactl copy /tmp/moxi-vm-source.tar moxi-linux-x86:/tmp/
limactl shell moxi-linux-x86 bash -lc 'mkdir -p "$HOME/moxi-vm-source" && tar -xf /tmp/moxi-vm-source.tar -C "$HOME/moxi-vm-source"'
limactl shell moxi-linux-x86 bash -lc 'export PATH="$HOME/.local/bin:$PATH"; cd "$HOME/moxi-vm-source"; bash scripts/vm_linux_check.sh'
```

Use a new empty snapshot directory for each run. The
[guest runner](../scripts/vm_linux_check.sh) rejects reused environments/build
objects, checks guest prerequisites, installs with `--locked`, and stops on the
first failed product check. Record the commit and archive checksum with its log.

Mojo's nightly [requirements](https://mojolang.static.modular.com/nightly/docs/requirements/)
include glibc 2.34+, a C linker, 8 GiB RAM and x86-64-v3 instructions. Verify
the guest CPU flags and actual pinned compiler execution before attributing a
compiler crash to Moxi. `Haswell-v4` provides an explicit x86-64-v3 CPU identity
that the pinned compiler can recognize; the initial `max` CPU exposed the required
flags but Mojo rejected its detected `athlon-xp` identity.
[Lima's driver guidance](https://lima-vm.io/docs/config/vmtype/) distinguishes full
Intel guests from translated userspace. Experimental
[macOS guests](https://lima-vm.io/docs/usage/guests/macos/) require an ARM host and
a host macOS version at least as new as the guest.

## Evidence rules

Record the source commit, archive checksum, guest OS/kernel/CPU flags, VM driver
and tool versions with each log. Transfer `git archive` output into the guest's
own disk; do not copy host `.pixi`, `dist`, native objects or caches. Install the
locked environment inside that snapshot.

Report each command's result and skipped checks. A fake-DOM pass, a successful
compile and a real browser interaction are different evidence. Guest screenshots
and browser logs must come from the guest browser. Do not claim VoiceOver,
Japanese IME or physical trackpad acceptance from synthetic events.

## Initial status

On 2026-10-03, `feat/data-workbench` was rebased onto `main` at `773682c`; all
30 branch commits were retained. The additive support-matrix conflict preserved
both the WebAssembly limitation and AppKit distribution note. The original tip
is preserved locally as `backup/data-workbench-before-main-20261003` (`81dd247`).
The post-rebase macOS `layout-candidate-check` and full `check` both passed at
`116d20f`, including the independent precompiled consumer, upstream request and
plot regressions, native accessibility/paragraph checks and the honest WASM gate.
Android SDK/NDK and iPhone simulator SDK checks were skipped. Manual interaction
and the frame benchmark were not repeated.
The Ubuntu guest booted with kernel `6.8.0-134-generic`, glibc 2.39 and verified
x86-64-v3 flags (`abm` is Linux's alias for LZCNT). Build-tool provisioning passed:
GCC 13.3.0, Node 18.19.1 and checksum-verified Pixi 0.81.0 execute in the guest.
The guest reports `qemu` VM virtualization and `none` for container virtualization.

The first product run started at 2026-10-03 21:23:11 UTC against source commit
`18f5a27`. Its transferred archive has SHA-256
`1b6bb6fbdf3ea34c431d1c441e014ddd877da474519ecdd48cc24f212957006b`;
the runner used for that run has SHA-256
`3ce7c2b879779a9a89041b629997df1b9d1e2113054da73c011e28a283f6bd36`.
The runner subsequently gained explicit container rejection because
`systemd-detect-virt --vm` alone can report an outer VM from inside a container.
The first run's direct-guest identity was checked separately. Locked installation
passed and reported Mojo `1.1.0.dev2026082605 (dd957314)`, but the first headless
check failed before execution with `unknown target CPU 'athlon-xp'`. This is a
guest CPU/compiler compatibility failure, not a passing Moxi check. The guest
was stopped, changed to `Haswell-v4` and restarted for a fresh-snapshot rerun.
The default-target compiler smoke and portable plot execution passed with this
CPU setting. The broader rerun started at 2026-10-03 21:27:29 UTC against
`e3e0a72`; its archive SHA-256 is
`711bdb1be0bcab18b482a08dc7ea46eae5ad6e3bfcfd70423df279e60e91fed7`.
The complete guest run passed: the headless lane (including both source
precompiles), retained engine, box layout, 100,000-row collection, overlay
placement, request adapter, reactivity/tasks, plot-view and execution checks,
plus both Node host harnesses. No real browser was launched. QEMU TCG compilation
is slow; these observations do not establish native performance.

The Kiwi build and constraint check now select `.dylib`/libc++ on macOS and
`.so`/libstdc++ on Linux. The guest runner uses g++ for the C++ bridge, preserves
assertions in its C ABI tests, and runs the existing Mojo constraint publication
and rollback tests. This does not add a Linux window/text backend.
The changed build/link path passed `constraint-layout-check` on the macOS host,
including the C++ bridge and 1,000 Mojo staged rebuilds. A separate Linux run
started from a fresh snapshot of `60078ab`; its archive SHA-256 is
`1cf57e545001a990a241e1d41408e2bcb166be99f82bb6d349cb2200586dd0ed`.
It installed the locked environment within that snapshot and ran
`CXX=g++ pixi run --locked constraint-layout-check`. GCC rejected the bridge's
private `finite` helper because it conflicted with glibc's global `finite`
declaration. The helper and its calls were renamed to `is_finite_number` without
changing behavior or the external ABI. The macOS constraint check passed after
this rename; a fresh Linux guest rerun is next.

All five hosted CI jobs passed at `3dba206`, including the macOS candidate and
installed package consumer. This is separate from the guest observations.

Local logs are `/tmp/moxi-rebase-check.log`, `/tmp/moxi-vm-linux-start.log`,
`/tmp/moxi-vm-linux-bootstrap.log`, `/tmp/moxi-vm-linux-check-18f5a27.log`,
`/tmp/moxi-vm-linux-cpu-smoke.log`, `/tmp/moxi-vm-linux-check-e3e0a72.log` and
`/tmp/moxi-vm-kiwi-darwin-check.log` and
`/tmp/moxi-vm-linux-kiwi-60078ab.log`.
Guest browser interaction, macOS VM and Windows VM checks have not started.

On the user's request for a screenshot, a separate Xfce desktop was installed
inside the Ubuntu guest and started on TigerVNC display `:1`, listening only on
guest loopback. The VM was not restarted and host system settings were not
changed. `xfce4-screenshooter` captured the actual 1440×900 guest desktop to
`dist/vm-artifacts/linux-vm-desktop.png`. This proves the guest graphical session
is available; it does not establish Moxi native Linux window support or
accessibility behavior.
