# Cross-platform VM validation

Use real guest operating systems and clean source snapshots to check installation,
execution and host integration. A passing portable test does not certify a native
desktop backend. Keep guest results separate from hosted CI, fake-DOM harnesses,
browser interaction and physical input checks.

## Scope and order

| Guest | Checks | Current boundary |
| --- | --- | --- |
| Ubuntu 24.04 x86-64, first | Exact `pixi.lock`; Mojo retained engine, box/collection/overlay policies, Kiwi constraints, portable plotting and precompilation; rebased request/runtime/plot regressions; Node host contracts | Portable checks and the Linux Pango/Cairo/layout contracts have passed in the guest. Node harnesses do not exercise a browser; headless native contracts do not verify a window or real input. |
| Ubuntu native desktop, active | Compile the Mojo workbench with the GTK4/Cairo/Pango host; actual window screenshot, pointer/key/resize, RTL, scrolling and desktop services | GTK 4.14+ retained presenter implemented; stable Mojo 1.1.0 native build and synthetic X11 checks passed. External AT-SPI hierarchy/text/actions and cross-process clipboard checks pass. Spoken Orca, Wayland and physical scrolling remain unverified; real IME observations are recorded separately. |
| Ubuntu browser, separate | Actual guest browser rendering, pointer/key/resize, then a fixture for scroll, composition and ARIA | The browser demo is a JavaScript host demo, not the compiled Mojo layout app. The pinned compiler has no supported WASM package target. |
| macOS 15 ARM64, active | Clean native-services build, installed consumer and layout workbench in a GUI session | Locked Mojo 1.1.0 installation, native layout candidate and installed consumer passed in a clean guest. User completed desktop login and the compiled workbench was launched and visually captured. Interactive checks, VoiceOver, real Japanese composition and physical horizontal input require separate observations. |
| Windows 11 ARM64, later | Actual Edge/browser host and Python wheel consumption | Mojo has no native Windows support; WSL results must be reported as Linux. Moxi's Windows native backend is unavailable. Guest image/license and GUI provisioning are not established yet. |

The active Linux slice adds the retained presenter and tests the compiled Mojo
workbench in a real guest desktop. Windows native support and Android/iOS
emulator checks remain separate; the mobile host adapters currently do not execute the Mojo
layout engine.

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

Mojo's [system requirements](https://mojolang.org/docs/requirements/)
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
Japanese IME or physical trackpad acceptance from synthetic events. Native app
screenshots must likewise come from the guest's actual compiled Moxi window.

## Linux native workbench

The source-only GTK4 host presents retained labels, buttons, single-line editors
and custom canvas leaves using Cairo. Retained Pango paragraphs supply wrapping,
shaping and bidi; measurement and paint use the same paragraph payload. Mojo owns
the retained tree, flow/grid layout, hit testing, publication and editor state;
Kiwi remains the pinned C++ constraint solver. GTK supplies the native window and
input-method service. Native desktop clipboard and GTK AT-SPI proxies now supply
host services; external clients verify selected published semantics and actions.
Legacy widget parity, rich text, GPU acceleration and incremental rendering remain
unavailable. Spoken screen-reader navigation has not been certified.

Install the native development libraries and fonts inside the guest:

```sh
sudo apt-get update
sudo apt-get install --yes --no-install-recommends build-essential pkg-config libgtk-4-dev fonts-dejavu-core fonts-noto-cjk
pixi install --locked
pixi run --locked linux-layout-check
```

This requires GTK 4.14+ and runs the native text/paint/event and Mojo layout
contracts, then compiles `dist/layout-workbench-linux`. Lifecycle and clipboard
regressions use a display or Xvfb when available and report skipped checks. Set
`MOXI_LINUX_ATSPI_CHECK=1` in an X11/DBus/window-manager session to include the
external service client; install `python3-pyatspi xclip xdotool dbus-x11` first.
To build and launch the app from the guest desktop terminal:

```sh
pixi run --locked linux-layout-workbench
```

The existing Xfce/TigerVNC graphical session uses guest display `:1`; an SSH
launch can use `DISPLAY=:1 pixi run --locked linux-layout-workbench`. GTK's X11
and Wayland paths share this host; the recorded graphical checks use X11.
Record Wayland separately when exercised.

## Initial portable VM evidence

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
and rollback tests. At this stage the Linux window/text backend was still absent.
The changed build/link path passed `constraint-layout-check` on the macOS host,
including the C++ bridge and 1,000 Mojo staged rebuilds. A separate Linux run
started from a fresh snapshot of `60078ab`; its archive SHA-256 is
`1cf57e545001a990a241e1d41408e2bcb166be99f82bb6d349cb2200586dd0ed`.
It installed the locked environment within that snapshot and ran
`CXX=g++ pixi run --locked constraint-layout-check`. GCC rejected the bridge's
private `finite` helper because it conflicted with glibc's global `finite`
declaration. The helper and its calls were renamed to `is_finite_number` without
changing behavior or the external ABI. The macOS constraint check passed after
this rename. The later Linux native run described below includes the corrected
bridge and constraint checks.

All five hosted CI jobs passed at `3dba206`, including the macOS candidate and
installed package consumer. This is separate from the guest observations.

Local logs are `/tmp/moxi-rebase-check.log`, `/tmp/moxi-vm-linux-start.log`,
`/tmp/moxi-vm-linux-bootstrap.log`, `/tmp/moxi-vm-linux-check-18f5a27.log`,
`/tmp/moxi-vm-linux-cpu-smoke.log`, `/tmp/moxi-vm-linux-check-e3e0a72.log` and
`/tmp/moxi-vm-kiwi-darwin-check.log` and
`/tmp/moxi-vm-linux-kiwi-60078ab.log`.
At that point, guest browser interaction, macOS VM and Windows VM checks had not
started. The subsequent native guest results are recorded below.

On the user's request for a screenshot, a separate Xfce desktop was installed
inside the Ubuntu guest and started on TigerVNC display `:1`, listening only on
guest loopback. The VM was not restarted and host system settings were not
changed. `xfce4-screenshooter` captured the actual 1440×900 guest desktop to
`dist/vm-artifacts/linux-vm-desktop.png`. This proves the guest graphical session
was available; this desktop-only screenshot preceded the native Linux presenter
work and does not show Moxi or establish accessibility behavior.

## Linux native evidence

On 2026-10-04, the Linux GTK4/Cairo/Pango presenter and shared Mojo workbench entry
point were implemented. The initial native archive was created at 2026-10-04
03:53:51 UTC as `/tmp/moxi-linux-native-source.tar`, with
SHA-256 `499123245433ac47fca6f806083d9c95ff9ec72571f3c484b9f89ddaa398145f`.
It contained `5bf06a2` plus the then-current native C, capability and build changes;
the candidate must not be attributed wholly to that commit. The guest checkout is
`$HOME/moxi-linux-native`; the guest log is `/tmp/moxi-linux-native-check.log` and
the host capture is `/tmp/moxi-linux-native-check-host.log`.

In the Ubuntu 24.04 x86-64 guest, the locked native run passed the retained
Pango paragraph contracts, retained engine, box layout, native retained layout,
the corrected Kiwi bridge and 1,000 staged rebuilds, and composed layout workbench
contracts. Separately, the strict C Cairo paint/paragraph ownership/event ABI
tests passed without opening a display. The complete initial
`linux-layout-check` run exited successfully, including app compilation. The
headless event test injects Unicode text/composition records into the bounded
transport; it does not exercise a real GTK input method. These observations
establish native service/layout contracts and a compiled app; the later GUI run
is separate evidence.

The guest source was then refreshed with the committed `8db8613` archive,
SHA-256 `97ea06efb02c0c00d72a730a41d941bafb6071460b0c5060541d532277d7f44b`,
and its production C host/app rebuilt successfully after focus/input-method fixes.
This refresh reuses the original guest-local locked environment; it is not a
second clean installation. The guest build log is
`/tmp/moxi-linux-native-8db8613-build.log`.

The `dbb13c3` archive (SHA-256
`40aa1231f115a26c967244e7ec8c698cdf009399a309403a2d5f018eae5a059f`)
then supplied the row-editor cancellation fix and GUI harness. Its app build
passed; the host log is `/tmp/moxi-linux-native-dbb13c3-build-host.log`.
The first actual GUI run passed seven checks but failed the harness's exact
540×900 window-size assertion on a 1440×900 desktop. A fresh painted frame had
already established stacked panes and retained preedit. The corrected harness
preserves the existing window height and requires both a narrower X11 window and
a drawn canvas below the stacking breakpoint.

With that corrected harness, the same nightly app passed all 15 synthetic X11
checks, including screenshot capture and clean close. The per-run guest summary
is `dist/linux-native-artifacts/ui-a7ahvhlm/summary.json`; its trace and app log are
beside it. The host capture is `/tmp/moxi-linux-nightly-ui-full-host.log` and the
copied screenshot is `dist/vm-artifacts/linux-moxi-workbench-narrow.png`.
This binary used Mojo `1.1.0.dev2026082605 (dd957314)` and has SHA-256
`f989ed1dad5ae1f181fc235d7e19639a9f4e4a4d3ad8062ebdbf577567e96bc6`.
The GUI tests cover drawing, reflow, RTL, focus, addressed Unicode input,
composition cancellation/retention, modal and row-editor routing, and positive
horizontal/vertical scroll delivery and geometry changes. GTK-simple Unicode
input is not a Japanese input-method check. Noto CJK fonts were extracted from
Ubuntu's `fonts-noto-cjk` package into the guest user's font directory while a
system unattended upgrade held the package-manager lock.

On 2026-10-04, the branch was pulled and rebased onto `main` at `e3be517`.
All 40 branch patches were retained unchanged; the original tip is preserved as
`backup/data-workbench-before-pull-20261004`. Main changed the pinned toolchain to
stable Mojo 1.1.0 and the upstream Canvas revision. The corrected harness archive
at `d333091` has SHA-256
`4ccf02b765a0b2afedcbf1dcda7b3302d6bee069267bb16027bc220949a962ee`.
It was installed with `--locked` and rebuilt within the existing guest checkout;
this is a toolchain refresh, not a second clean installation. Stable Mojo 1.1.0
(`8189361e`) passed the complete `linux-layout-check`, including native Pango and
Cairo/event contracts, Mojo retained engine/box/layout, the Kiwi bridge and 1,000
staged rebuilds, composed workbench contracts and app compilation. The host
capture is `/tmp/moxi-linux-native-stable-check-host.log`.

The rebuilt app passed all 15 synthetic X11 GUI checks from 21:44:14 to
21:44:29 UTC and closed normally. Its SHA-256 is
`3a8468402235034c6a019d314b9b0a790bb973d1212009fcccad905412933474`. Its
guest evidence is `dist/linux-native-artifacts/ui-9aot7dmv`; the host capture is
`/tmp/moxi-linux-stable-ui-host.log`. The copied summary, trace and app log are
`dist/vm-artifacts/linux-stable-ui-summary.json`,
`dist/vm-artifacts/linux-stable-ui-trace.jsonl` and
`dist/vm-artifacts/linux-stable-ui-app.log`. The narrow screenshot is
`dist/vm-artifacts/linux-moxi-workbench-narrow-stable.png`. A separate fresh wide
window capture also passed visible drawing and clean close, recorded in
`dist/linux-native-artifacts/wide-yz4kt_64` and
`/tmp/moxi-linux-wide-capture-host.log`. Its screenshot is
`dist/vm-artifacts/linux-moxi-workbench.png`, and its copied summary is
`dist/vm-artifacts/linux-stable-wide-summary.json`. Both screenshots were visually
inspected on the host. The app stderr contained only software-display DRI3
acceleration warnings; no GTK critical errors were recorded.

The macOS host's stable `layout-candidate-check` passed, including its independent
precompiled consumer.
The host's full `pixi run --locked check` also passed all 78 test files, native
paragraph/scene/screenshot/accessibility checks, Python consumption and host
harnesses. Logs are `/tmp/moxi-stable-rebase-layout-check.log` and
`/tmp/moxi-stable-rebase-full-check.log`. Android SDK/NDK and iPhone simulator SDK
checks were skipped because those SDKs are unavailable; manual interaction and
the frame benchmark were not repeated. After raising the generated consumer
requirement to macOS 15, `pixi run --locked layout-package-consumer` also passed
both the independent precompiled consumer and installed native archive consumer;
its capture is `/tmp/moxi-stable-macos15-consumer-check.log`.

All six hosted CI jobs passed at `a2f6bf9` in
[run 37235797526](https://github.com/davidmashburn/moxi/actions/runs/37235797526),
including the stable-toolchain Linux native build and compiled X11 UI smoke,
macOS validation/candidate and installed package consumer. The Linux CI lane
uses Xvfb/Openbox and is separate from the full Ubuntu VM desktop. Openbox
readiness is checked before attempting window activation. The subsequent CI
configuration moves all three Mojo jobs to macOS 15, matching stable Mojo
1.1.0's supported OS requirement; the native archive retains its macOS 14 ABI
deployment target.

The refreshed guest remains Ubuntu 24.04.4 LTS, kernel `6.8.0-134-generic`, glibc
2.39 under full QEMU x86 virtualization, with no container. It reports GTK 4.14.5,
Pango 1.52.1 and Cairo 1.18.0. DejaVu Sans is the default font; the Japanese font
match is Noto Sans CJK JP. The captured guest provenance is
`/tmp/moxi-linux-stable-guest-provenance.log`.

At this October 4 baseline, Wayland, Linux real IME composition, physical
horizontal scrolling, the macOS manual release checks and Windows VM checks
were unverified, and Linux AT-SPI was unavailable. The October 5 service
implementation and observations below supersede that availability limit.
No native frame-performance claim is made for TCG.

## macOS native VM evidence

The [macOS guest configuration](../scripts/vm/macos-15-arm64.yaml) pins the base
restore image independently of Lima's installed templates. On an ARM64 Mac
running macOS 15.6.1 or newer, validate and start it with Lima 2.2.0:

```sh
limactl validate scripts/vm/macos-15-arm64.yaml
limactl start --tty=false --name=moxi-macos15-arm scripts/vm/macos-15-arm64.yaml
```

Choose an unused instance name for a clean reproduction; starting an existing
instance reuses its disk. This configuration provisions the base VM. First
desktop login, developer tools, Pixi and the project environment are separate
steps. It does not reuse the host's build environment.

On 2026-10-04, `moxi-macos15-arm` booted macOS 15.6.1 (`24G90`) under Lima 2.2.0's
VZ driver on an ARM64 host. The guest has 4 CPUs, 8 GiB RAM and a 100 GiB disk,
with no host mounts, extra host SSH keys, SSH agent forwarding or containerd.
The official Apple restore image is pinned to SHA-256
`3d87686b691ac765eb6a6b3082b2334e2af9710096a00432dd519af89ff2ea78`.
The guest became SSH-ready at 22:10:03 UTC. Its captured login screen is
`dist/vm-artifacts/macos-first-boot.png`; this is a guest boot observation,
not a Moxi workbench screenshot.

Source commit `291ac02` was transferred as a `git archive` with SHA-256
`7ac52dcce28b31b0d7c8708ff2dde7566e2375b3f224609de8964103f7504be3` and extracted
into the guest's own `$HOME/moxi`. No host build objects, environments or caches
were copied. Pixi 0.81.0 was copied as a standalone ARM64 executable and its
SHA-256 was verified as
`e671115a49b9f886273a5d7ef19c2d4977e261d378e2340608658146eb2fb479`.
The initial locked install stopped because Apple's Git launcher required
developer tools. Installing only Apple's Command Line Tools 16.4 resolved that
prerequisite; the locked retry passed with Mojo 1.1.0 (`8189361e`). The active
macOS SDK is 15.5 and Apple clang is 17.0.0 (`clang-1700.0.13.5`).

Both `pixi run --locked layout-candidate-check` and
`pixi run --locked layout-package-consumer` passed in the clean guest. The
candidate executed retained engine/native layout, Kiwi's 1,000 staged rebuilds,
composed workbench, native AppKit paint/accessibility identity/field-editor
marked-range retention, 100,000-row collection and overlay placement checks,
plus an independent precompiled consumer. The separate consumer also installed
and consumed the native archive from a temporary local package channel.
The compiled workbench executable has SHA-256
`edf3a15d27fe82e062711cda08f2c377b52f21716aa6625fbc7ea43fe9dd5b7d`.
The host log is `/tmp/moxi-macos15-native-check-host.log`; copied guest logs are
`dist/vm-artifacts/macos-layout-candidate.log` and
`dist/vm-artifacts/macos-layout-consumer.log`. Only deprecation and documentation
warnings were recorded; neither test log contains a failure or skip marker.

The user completed first desktop login. On 2026-10-05 at 03:22:14 UTC, the guest
console user was confirmed as `davmash`, the compiled workbench was launched via
SSH, and Lima captured `dist/vm-artifacts/macos-moxi-workbench.png`. Visual
inspection confirmed the macOS desktop and drawn AppKit workbench, including
its controls, dataset field, result grid and plot. This is visible launch
evidence; interactive GUI checks have not been performed.

The computer-use connector still rejects Lima's unbundled `limactl` GUI process,
although SSH and Lima's screenshot command work. VoiceOver speech, real Japanese
IME composition and physical horizontal scrolling remain unverified. The full
check suite and benchmarks were not repeated in this guest.

## October 5 host/frame validation

The architecture slice adds portable frame/semantic publication, deadline-driven
loops and lossless normalized replay. Mojo owns retained state/layout; Kiwi
remains the constraint solver. [ADR-005](architecture/adr-005-host-frame-contract.md)
records the accepted boundaries. H4 GPU work and H5 additional hosts remain
deferred, and manual desktop acceptance remains separate.

### macOS contracts and guest builds

The host's full `pixi run --locked check` passed all 81 portable test files,
native text/scene/accessibility/screenshot checks, package/host harnesses and API
inventory checks. The reviewed inventory contains 977 exports and 98 trait
methods. Android SDK/NDK and iPhone simulator checks remain skipped.
`/tmp/moxi-final-check-rerun.log` captures this full run. Targeted native resource,
clipboard-routing and semantic-only publication checks also pass. This full run
preceded the final native-loop and AX-wake fixes; the final candidate and targeted
regressions below cover those changes.

The host candidate at `959477f` passed, including first and later frames painted
before idle on the original AppKit canvas and the independent precompiled
consumer (`/tmp/moxi-final-host-candidate.log`). A bounded standalone runner
regression fails on the old loop and passes for both backend aliases at
`bd16cde`: input is drained and close prevents another wait.

An actual AX callback also reproduced an idle-wake defect: a press at 21 ms was
delivered only after unrelated fallback input at 201 ms. After `16ea17c`, the same
probe returns at 21 ms without fallback. The new bounded native regression checks
AX actions, addressed Unicode edits and asynchronous close; its exact fixture
fails against pre-fix source and passes after the fix. Logs are
`/tmp/moxi-appkit-prewake-fixture.log`, `/tmp/moxi-appkit-ax-idle-probe-fixed.log`
and `/tmp/moxi-appkit-wait-final.log`. These checks do not certify VoiceOver speech.

The final host candidate at `16ea17c` passes, including the AX-wake regression,
standalone runner checks, frame publication and independent precompiled consumer.
Its log is `/tmp/moxi-final-wake-host-candidate.log`.

An exact `959477f` archive was installed in the new empty guest directory
`$HOME/moxi-frame-final-959477f`; SHA-256 is
`e261fe2567b044a423716078089afa2a3ac6efb5bca27beec6b403807185ae04`.
Locked install, `layout-candidate-check` and `layout-package-consumer` pass on
macOS 15.6.1 ARM64, Mojo 1.1.0 and CLT 16.4, including installed native archive
consumption. No host objects or environment were copied. The signed bundle's
executable hash is
`a972b6f25682697a962885739e48c703d55bc195b40896e567a556c8b3fd6389`.
Copied logs are `dist/vm-artifacts/macos-frame-final-candidate.log` and
`dist/vm-artifacts/macos-frame-final-consumer.log`. The outer capture exited 1
only because its final hash command used the wrong executable name; both test
commands passed, and the corrected hash was checked separately.

The final exact `16ea17c` archive has SHA-256
`ad4a752e618cf0ae5ffdf0959f0c0397ff0748eca33dcf40c450a4dde27f463b`.
It was transferred into the new empty guest directory
`$HOME/moxi-frame-final-16ea17c`. Fresh locked installation, the complete
`layout-candidate-check` and `layout-package-consumer` all pass on the same macOS
15.6.1 ARM64 guest. The outer run also exits successfully; the signed bundle's
executable SHA-256 is
`8a86de577cb40355897fcb866d4ac97266763d5a8a3575325cb309adca6fff78`.
No host objects or environment were copied. The host capture is
`/tmp/moxi-frame-wake-final-host.log`; combined guest check logs are copied to
`dist/vm-artifacts/macos-frame-wake-final-checks.log`.

A fresh Lima capture is black and does not establish visible launch for this
snapshot. Guest `screencapture` excludes app windows;
`CGPreflightScreenCaptureAccess` returns false. Screen-capture settings were not
changed. The 03:22:14 UTC screenshot above remains historical evidence for its
earlier binary; newer AppKit paint checks pass independently of this capture limit.

### Ubuntu contracts and services

The exact `7d9bbe3` archive has SHA-256
`6ef9c3905e04bdba8d78145eb2382dbca4807e6a4d46147cf3f98c00850154b6`.
The contract lane passed from 05:45:40 to 06:20:19 UTC: Pango/Cairo/event ABI;
selected-range editor preview; same-ID close/reopen and stale input rejection;
host scale/waits; bounded clipboard timeout, stable leases, deferral and overflow;
external AT-SPI; portable retained/box/event replay; linked retained, Kiwi's
1,000 staged rebuilds, workbench/replay and native resource contracts.
The log is `/tmp/moxi-linux-final-7d9bbe3.log`.

The new source directory `$HOME/moxi-linux-final-7d9bbe3` reused the guest's own
locked environment rather than installing a fresh one; both lock hashes are
`b17ce5daafc18cb10ca54e75c338fa4bf6ac9e2f3839dd9e4e65e818e32977f0`.
No host environment or objects were copied. App/GUI orchestration was explicitly
deferred to the later shipping source using temporary guest wrappers, then
restored; those deferred steps are not app/GUI passes for `7d9bbe3`.

The separate DBus/Xvfb/Openbox client checks AT-SPI hierarchy, roles, hints,
GTK 4.14's sensitive/enabled mapping, checked/selected states, Unicode caret and
selection, focus, window-relative bounds, addressed activation and focused-key
routing. An external clipboard peer verifies Unicode text and stable leases.
This service inspection does not establish spoken Orca acceptance.

The final shipping Linux build uses exact `bd16cde` source, whose archive SHA-256
is `0503a13e4d1541b5a3891f9f724b97947dbe0d7d1e57aa753cd2b4ceedacacba`.
The new source directory `$HOME/moxi-linux-final-bd16cde` reuses the same
guest-local locked environment. Its focused final build passes strict C, unset
and explicit IBus-mode checks, actual `GDK_SCALE=2` GTK lifecycle checks and both
standalone native runner aliases. It compiles the app once; the executable's
SHA-256 is `5ca20e030f2303c0c64afa5764f2377be3227cc7db2deaae10108ad8f4b76a3c`.
The build runs from 06:21:39 to 06:28:06 UTC; its log is
`/tmp/moxi-linux-final-bd16cde-build.log`. The subsequent `16ea17c` code change is
macOS-only and does not change these Linux sources.

That same executable passes all 15 compiled X11 GUI checks from 06:31:00 to
06:31:12 UTC on a separate Xvfb/Openbox/DBus session: visible drawing, reflow,
RTL, rapid focus/action routing, Unicode/preedit, modal and cell cancellation,
resize retention, horizontal/vertical scrolling, screenshot and clean close.
Its trace contains 49 published frames and no native event drops or overflow.
The host-inspected screenshot is `dist/vm-artifacts/linux-frame-final-workbench.png`;
the copied summary and trace are beside it. These synthetic GUI checks do not
exercise a real IME, spoken accessibility, physical input or Wayland; the real
engine result below uses a separate session and the same executable.

### Real Japanese input-method service

GTK 4.14.5, IBus 1.5.29 and Mozc 2.28.4715.102 were exercised in the guest's
Xfce/X11 session using synthetic X11 keys through actual GTK IBus transport,
the Mozc engine and candidate renderer. Accessibility was disabled for this
isolated IME probe and checked separately.

Default synchronous mode reproduced a cancellation failure: Escape left `かな`
marked, with a `Type 'h' is not supported` diagnostic. The
[IBus 1.5.29 implementation](https://github.com/ibus/ibus/blob/1.5.29/src/ibusinputcontext.c)
does not handle that hide-preedit response. Hybrid mode `2` passes preedit,
Space conversion, selected-range commit, Escape cancellation and modal focus
cancellation. The readable candidate popup sits below Dataset and anchors inside
its width; exact caret x-coordinate placement was not asserted. This diagnostic
run finished at 06:13:18 UTC (`/tmp/moxi-ime-hybrid-modal-restore.log`); final
shipping-app observations remain separate.

Commit `d644e3b` defaults only an unset `IBUS_ENABLE_SYNC_MODE` to `2`, before
window or clipboard-first GTK initialization. Explicit `0`, `1`, `2` and empty
values are preserved, with no desktop setting changes. Strict C, headless and
real GTK lifecycle tests pass for unset and explicit-mode cases
(`/tmp/moxi-ibus-fix-native-check.log`). Each real-engine probe backed up and
restored dconf input-source settings and the full XKB map, used private
configuration/cache directories and stopped only its temporary IBus processes.
Restoration comparisons passed.

The final shipping executable above passes all five actual-engine checks from
06:31:00 to 06:31:39 UTC with `IBUS_ENABLE_SYNC_MODE` unset at launch and no probe
override: preedit, conversion to `日本`, selected-range commit, Escape cancellation
and modal focus-loss cancellation. Its log is `/tmp/moxi-ime-final-bd16cde.log`;
the copied summary is `dist/vm-artifacts/linux-frame-final-ime-summary.json`.
The host-inspected candidate screenshot shows a readable Japanese list below
Dataset, anchored horizontally inside the editor; exact caret placement remains
unasserted. Dconf and XKB restoration comparisons pass and no temporary IBus or
Mozc processes remain. There is no unsupported hide-preedit diagnostic. This
establishes the app's default behavior on the tested Ubuntu X11 stack, not
physical-input or Wayland acceptance.

### Performance and remaining acceptance

[The delivery ledger](layout-delivery.md#frame-cost) records native
macOS reference timings and a separate 56-frame Linux TCG smoke profile. The
Linux run excludes live GTK proxy submission and enforces no native frame budget;
its full timing profile was skipped to bound emulation cost.

Spoken VoiceOver/Orca, macOS real Japanese composition, physical horizontal
input, Wayland, Windows and mobile/browser linked runtimes remain unverified or
deferred. Public layout promotion remains pending its manual macOS gates.
