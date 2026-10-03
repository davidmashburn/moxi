# Cross-platform VM validation

Use real guest operating systems and clean source snapshots to check installation,
execution and host integration. A passing portable test does not certify a native
desktop backend. Keep guest results separate from hosted CI, fake-DOM harnesses,
browser interaction and physical input checks.

## Scope and order

| Guest | Checks | Current boundary |
| --- | --- | --- |
| Ubuntu 24.04 x86-64, first | Exact `pixi.lock`; Mojo retained engine, box/collection/overlay policies, portable plotting and precompilation; rebased request/runtime/plot regressions; Node host contracts | Linux native window, text and accessibility backends are unavailable. Node harnesses do not exercise a browser. |
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
compiler crash to Moxi. `max` selects QEMU's emulated CPU features.
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
The post-rebase macOS layout candidate check passed, including the independent
precompiled consumer. The broader macOS suite remains in progress.
The Ubuntu guest booted with kernel `6.8.0-134-generic`, glibc 2.39 and verified
x86-64-v3 flags (`abm` is Linux's alias for LZCNT). Build-tool provisioning is in
progress. No guest product checks, guest browser interaction, macOS VM or Windows
VM results are claimed yet.
