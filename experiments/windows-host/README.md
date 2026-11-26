# Windows compiler and host feasibility

On November 25, 2026, Linux x86-64 Mojo 1.1.0 (8189361e) compiled the
existing C-callable Moxi counter at source revision
`0da6f295b6d20cdf663aaf66a039a43e8fb66dd0`. Its Linux C caller passed
three transitions. The same source produced these Windows artifacts.

| Target | Compiler output | Linked image | Named export |
| --- | --- | --- | --- |
| x86_64-pc-windows-msvc | AMD64 COFF | PE32+ x86-64 DLL | moxi_mobile_increment |
| aarch64-pc-windows-msvc | ARM64 COFF | PE32+ AArch64 DLL | moxi_mobile_increment |

## Reproduce

From the repository root on Ubuntu 24.04 x86-64, run the following. The compiler's
bundled LLD links this dependency-free leaf without a Windows SDK, then generates
the import libraries for the Windows C callers. No dependency is added to Moxi's
runtime.

```bash
pixi install --locked
pixi run --locked bash experiments/windows-host/crossbuild.sh
```

The original run used Linux `file` and Apple LLVM objdump 21.0.0 for independent
image inspection. Linux GNU objdump on this guest could inspect only the x86-64
image. The CI inspector uses Python's standard library for both architectures;
it checks the COFF machine, PE32+ DLL flag, absent entry point and imports, the
single named function export, and the import library's machines, DLL and symbol.

## Native Windows CI gate

`.github/workflows/windows-host-experimental.yml` tests the scalar C ABI on both Windows architectures. It is triggered by pull requests affecting this experiment, the mobile
counter/caller/control, their source imports, or the compiler manifest/lock, and
can be dispatched manually. It has no push trigger. Jobs are gated
to public repositories and use only standard `ubuntu-24.04`, `windows-2025`
(AMD64), and `windows-11-arm` (ARM64) runners. See GitHub's
[runner reference](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)
and [Windows ARM64 runner announcement](https://github.blog/changelog/2025-08-07-arm64-hosted-runners-for-public-repositories-are-now-generally-available/).

The Ubuntu job installs with `--locked`, runs the existing Linux host positive
control, and builds both DLLs from `experiments/mobile-runtime/counter.mojo`.
Only each target's `moxi-counter.dll` and `moxi-counter.lib` are transferred, in
separate artifacts with one-day retention. No compiler environment, object,
executable, cache or binary is committed or uploaded beyond those two input pairs.
The token has only `contents: read`; checkout does not persist credentials.

Each Windows job selects the preinstalled native MSVC host/target tools and SDK
using `vswhere`/`VsDevCmd`. It compiles the **unchanged**
`experiments/mobile-runtime/check.c`, renaming only `main` to link the small
`architecture.c` wrapper. The caller links the generated import library normally;
it uses no `LoadLibrary`, `GetProcAddress`, emulation, or fallback architecture.
The C runtime is linked statically (`/MT`), so the check needs no installed VC
redistributable. Runner architecture, compiler host/target path, caller PE
machine and normal DLL import are checked. In the actual caller process,
`IsWow64Process2` must report no emulation and the matching native machine before
the shared three-transition test executes.

The logs include tool versions, target triples, file characteristics, artifact
SHA-256 values, caller dependencies and these success lines (machine IDs differ):

```text
ARCH: target=AMD64 process=0x0000 native=0x8664 pointer_bits=64
PASS: C called the Mojo Counter increment for three transitions
PASS: AMD64 native Windows scalar C ABI
```

## Native result

On November 26, 2026, the Ubuntu crossbuild and both native Windows jobs passed at revision `7eb6d88`. Each C caller loaded its architecture’s DLL through the MSVC import library and returned the expected results for 0 → 1 → 2 and −3 → −2. The caller import tables listed `moxi-counter.dll` and `KERNEL32.dll`. [GitHub Actions run 45764035618](https://github.com/davidmashburn/moxi/actions/runs/45764035618)

| Windows runner | MSVC host and target | Native machine reported by the caller | Result |
| --- | --- | --- | --- |
| AMD64 | x64 | `0x8664` | All three calls passed |
| ARM64 | arm64 | `0xAA64` | All three calls passed |

Both runs used MSVC tools 14.52.37025 and Windows SDK 10.0.26100.0. Each process reported a 64-bit pointer and a process machine of `0x0000`, confirming native execution.

## Remaining gates

1. Link and execute a shared application that uses the Mojo runtime, including allocation and cleanup. Verify clean-machine packaging, signing and redistribution requirements.
2. Specify and implement the Win32 bridge. A working host needs window creation, a message loop, frame presentation, DPI and resize handling, keyboard and pointer input, text composition, accessibility and orderly shutdown.

The current build cross-compiles Mojo on Linux and compiles the C caller on Windows. Building Mojo source directly on Windows remains unverified.
