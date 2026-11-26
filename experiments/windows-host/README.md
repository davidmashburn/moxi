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

From the repository root in the locked Linux environment, run the following.
The compiler's bundled LLD can link this dependency-free leaf without Windows
import libraries. Use an LLVM objdump with COFF support for both architectures.

```bash
set -eu
bash experiments/mobile-runtime/probe.sh host
out=dist/windows-host
mkdir -p "$out"
for target in x86_64-pc-windows-msvc aarch64-pc-windows-msvc; do
  mojo build -I src --target-triple "$target" --emit object \
    experiments/mobile-runtime/counter.mojo -o "$out/$target.obj"
  lld -flavor link /dll /noentry /nodefaultlib /export:moxi_mobile_increment \
    "/out:$out/$target.dll" "$out/$target.obj"
  file "$out/$target.obj" "$out/$target.dll"
  llvm-objdump -p "$out/$target.dll" | grep -w moxi_mobile_increment
done
```

The run used Linux `file` and Apple LLVM objdump 21.0.0 for independent image
inspection. Linux GNU objdump on this guest could inspect only the x86-64 image.

## Decision and remaining gates

A loader and C ABI trial is feasible. Moxi's Windows descriptor in
`src/moxi/backend.mojo` still reports no native bridge, and the workspace
declares only Linux and macOS compiler environments. No Windows guest was
provisioned for this test.

1. On a matching Windows installation, load each DLL, resolve the named export,
   call it through the Int32 C ABI, and compare the three transitions with
   `experiments/mobile-runtime/check.c`. Verify dependencies on a clean machine.
2. Link and execute a representative shared application that needs the Mojo
   runtime, including allocation and cleanup. Establish a supported compiler
   workflow, SDK/import libraries and redistribution requirements.
3. Specify and implement the Win32 host boundary. A canonical run needs
   window creation, a message loop, frame presentation, DPI/resize, keyboard,
   pointer and text composition, accessibility and orderly shutdown.

The exported leaf and its DLL headers establish a cross-link result only.
Execution, native Windows compilation, graphical behavior, packaging and
signing are unverified. The P11 Windows scenario sequence awaits a working host.
