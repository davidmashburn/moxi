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

`.github/workflows/windows-host-experimental.yml` prepares the outstanding scalar
C ABI run. It is triggered by pull requests affecting this experiment, the mobile
counter/caller/control, their source imports, or the compiler manifest/lock, and
can be dispatched manually by the parent. It has no push trigger. Jobs are gated
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

The ARM64 native machine is `0xAA64`. A matching target and an exit status of zero
from **both** Windows jobs are required; a crossbuild alone does not pass this
gate. There are no additional result artifacts; the run logs are the evidence.
The runner images and their installed MSVC/SDK versions can change independently
of the locked Mojo environment. This workflow has not been run as part of its
preparation; the parent handles GitHub execution and records the actual run.

## Decision and remaining gates

A loader and C ABI trial is feasible. Moxi's Windows descriptor in
`src/moxi/backend.mojo` still reports no native bridge, and the workspace
declares only Linux and macOS compiler environments. No Windows guest was
provisioned for this test.

1. Run both native Windows CI jobs above. The normal imports must load each DLL
   and call its Int32 C ABI through the existing three-transition test. Inspect
   the logged dependencies. A hosted-runner pass does not establish clean-machine
   packaging or redistribution requirements.
2. Link and execute a representative shared application that needs the Mojo
   runtime, including allocation and cleanup. Establish a supported compiler
   workflow, SDK/import libraries and redistribution requirements.
3. Specify and implement the Win32 host boundary. A canonical run needs
   window creation, a message loop, frame presentation, DPI/resize, keyboard,
   pointer and text composition, accessibility and orderly shutdown.

The exported leaf and its DLL headers establish a cross-link result only.
Execution, native Windows compilation, graphical behavior, packaging and
signing are unverified. The P11 Windows scenario sequence awaits a working host.
