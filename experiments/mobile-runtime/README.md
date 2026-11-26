# Mobile counter compiler probe

Can the locked Mojo compiler export an existing Moxi screen's increment operation
to a mobile host? The probe imports the authoring example's Counter. The host
supplies the current count, and the exported function constructs the model,
invokes its increment method and returns the updated count. This tests a narrow
C ABI before introducing mobile view lifecycle or renderer dependencies.

Run each target independently from the repository root.

```sh
pixi run --locked bash experiments/mobile-runtime/probe.sh host
pixi run --locked bash experiments/mobile-runtime/probe.sh ios-simulator
pixi run --locked bash experiments/mobile-runtime/probe.sh ios-device
pixi run --locked bash experiments/mobile-runtime/probe.sh android
```

The host probe links the Mojo object to a C executable that calls it three
times. Each mobile probe checks the emitted object's architecture, format and
exported function. The Apple probes also check the device or simulator platform
and minimum OS. The checks use `file` and LLVM objdump (Apple's `objdump` on
macOS). Set `LLVM_OBJDUMP` to select an LLVM binary elsewhere.

## Results on November 25, 2026

| Target | Observed result with Mojo 1.1.0 |
| --- | --- |
| macOS arm64 | Linked C and Mojo. Consecutive transitions returned 1 and 2, and incrementing −3 returned −2. |
| iOS arm64 | Object exported the function. Mach-O recorded platform 2 (iOS) and minimum OS 17.0. |
| iOS Simulator arm64 | Object exported the function. Mach-O recorded platform 7 (iOS Simulator) and minimum OS 17.0. |
| Android AArch64 API 26 target triple | Produced an AArch64 ELF relocatable object exporting the function. The API level was supplied to the compiler. |

On a fresh rebuild of all four targets, the checker rejected swapped device and
simulator objects, a host object passed as Android, and a device object missing
the exported function.

P10 remains partial. Xcode's outstanding license agreement blocked simulator
tools. This machine also lacked the Android platform and NDK at the build
script's configured locations. Device linking, Mojo runtime packaging, execution
and event-to-state integration in the UIKit and Android shells remain open.
