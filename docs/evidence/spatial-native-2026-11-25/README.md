# Spatial native memory checks, November 25, 2026

Both applications exited successfully in three complete synthetic AppKit replays apiece under combined ASan and UBSan. Neither sanitizer emitted a diagnostic. A separate native test repeatedly resized and rendered real Metal targets and closed their owners in one process. No application repair was indicated.

The tested application revision was `22bc67995972074169264a7a2e81e006595c96e6`. The only new executable sources were the runner and lifecycle test in this change. The host was arm64 macOS 27.2.1 with Apple Clang 21.0.0 (clang-2100.3.34.2), SDK 27.0 and Mojo 1.1.0 (8189361e). The Mojo archive carried a 27.2 deployment version and the linker warned about the 27.0 link target. Execution succeeded on this host.

## D06 geometry explorer — pass for the exercised native code

The real explorer opened its 1100 × 760 point window with three generated surfaces. Each replay exercised parameter changes, picking and annotation, stale work, constrained previews, cancellation, numeric editing, undo, disposal, recreation and 60 camera frames. The host-queue assertion confirmed that pointer cancellation, focus loss and a resize event discarded previews. The camera and idle reuse assertions passed and each process returned after closing its viewport and window.

The final run produced 17 offscreen captures at 2200 × 1520 pixels. The [recreated viewport](explorer-recreated.png) shows three rendered surfaces, selected object 101 and the inspector after recovery. The PNG SHA-256 is `188a013c47d76396f18bdef67a2b1cea6ab3751adfc7be729d4e7c1f20d13240`. Current D06 PNG hashes differ from its older gallery manifest. This check establishes the replay assertions and reviewed recovery state only.

The single-view lifecycle test opened and destroyed 20 owners, with six camera and viewport updates each. All 120 updates advanced the submitted-frame counter exactly once.

## D07 assembly inspector — pass for the exercised native code

The actual 1200 × 790 point assembly app ran its four-object, three-level hierarchy through linked selection and editing, measurement, clipping and undo, stale work, disposal and recovery of the right view, and 60 camera updates per view. Every run reported 18,240 shared vertices and 583,680 geometry bytes, passed the camera/idle reuse assertions and exited after closing both views and the window.

All 14 PNGs from the final run matched the individual SHA-256 values in the [November 23 manifest](../../../artifacts/demo-slideshows/spatial-assembly/manifest.json). The 14 retained files also matched those hashes. The [original capture provenance](../../../artifacts/demo-slideshows/spatial-assembly/provenance.json) remains tied to `49ebcdd`. Seventeen of its 156 recorded source inputs differ at the tested revision, including shared window and Metal code. The prior [frame review](../../../artifacts/demo-slideshows/spatial-assembly/validation.json) applies to the byte-identical output.

The linked-view lifecycle test opened and destroyed 20 more owners, each hosting two views. All 240 camera and viewport updates advanced the relevant submission counter exactly once. Both lifecycle cases alternate the target size between 180 × 140 and 220 × 160. The app windows themselves use fixed layouts.

## Reproduction and limits

Run from the repository root inside the pinned Mojo environment on a Mac with a GUI session and Metal.

```sh
bash scripts/spatial_native_sanitizers.sh
```

The runner prints the temporary build and evidence directory. It keeps per-run logs and the final set of AppKit cacheDisplay PNGs for each demo. Clang instruments the native spatial core/API, renderer bridge, text code and both Objective-C hosts, which include the real window and composition implementation. Both app binaries linked Apple's ASan runtime and imported ASan and UBSan handlers. Mojo-generated code, Metal shaders and system frameworks lack compiler instrumentation in this check.

Apple's ASan runtime rejected a minimal process with `detect_leaks=1` (exit 134, unsupported on this platform). Each ordinary binary was also rebuilt and run once via `/usr/bin/leaks --atExit -- ./dist/spatial-<demo>/<demo> --replay <temporary-directory>`. Both tool runs exited zero and reported zero total leaked bytes. The tool identified each process as restricted and said it could only show or save readonly memory contents. Leak acceptance remains open.

Confidence is high for the recorded synthetic paths on this host. A sanitizer finding, a replay assertion failure or a frame hash mismatch would require reassessment. The renderer remains experimental. Controlled performance, GPU memory safety, sustained leaks, physical input, compositor presentation, accessibility, other platforms, the full repository suite and remote CI were outside this run.
