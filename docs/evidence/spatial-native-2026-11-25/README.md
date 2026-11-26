# Spatial native memory checks, November 25, 2026

Both applications exited successfully in three complete synthetic AppKit replays apiece under combined ASan and UBSan. Neither sanitizer emitted a diagnostic. A separate native test repeatedly resized and rendered real Metal targets and closed their owners in one process. The D07 replay now requires a successful render and exactly one additional submission from each view on every camera step. A right-view failure after capture 14 makes both the replay and its sanitizer runner exit nonzero. Leak acceptance remains open.

The original run tested `22bc67995972074169264a7a2e81e006595c96e6`. The corrected rerun builds directly on `ee64e0350af5ca172da173f8903cdc2c6af689cb`, with only `examples/spatial-assembly/main.mojo` changed among executable inputs. The [validation record](camera-loop-validation.json) identifies the exact source hashes, capture time, commands, observed outcomes and local logs. The host was arm64 macOS 27.2.1 with Apple Clang 21.0.0 (clang-2100.3.34.2), SDK 27.0 and Mojo 1.1.0 (8189361e). The Mojo archive carried a 27.2 deployment version and the linker warned about the 27.0 link target. Execution succeeded on this host.

## D06 geometry explorer — pass for the exercised native code

The real explorer opened its 1100 × 760 point window with three generated surfaces. Each replay exercised parameter changes, picking and annotation, stale work, constrained previews, cancellation, numeric editing, undo, disposal, recreation and 60 camera updates. The host-queue assertion confirmed that pointer cancellation, focus loss and a resize event discarded previews. The camera and idle reuse assertions passed and each process returned after closing its viewport and window. D06's camera loop checks reuse, without D07's new per-step render and submission assertions.

The final run produced 17 offscreen captures at 2200 × 1520 pixels. The [recreated viewport](explorer-recreated.png) shows three rendered surfaces, selected object 101 and the inspector after recovery. The PNG SHA-256 is `188a013c47d76396f18bdef67a2b1cea6ab3751adfc7be729d4e7c1f20d13240`. Current D06 PNG hashes differ from its older gallery manifest. This check establishes the replay assertions and reviewed recovery state only.

The single-view lifecycle test opened and destroyed 20 owners, with six camera and viewport updates each. All 120 updates advanced the submitted-frame counter exactly once.

## D07 assembly inspector — pass for the exercised native code

The actual 1200 × 790 point assembly app ran its four-object, three-level hierarchy through linked selection and editing, measurement, clipping and undo, stale work, disposal and recovery of the right view, and 60 camera updates per view. Every run reported 18,240 shared vertices and 583,680 geometry bytes, passed the camera/idle reuse assertions and exited after closing both views and the window. The corrected assertions verified all 120 camera renders and submission increments per replay, for 360 across the three positive runs. Each view emitted 60 timing records per run, after the assertions passed. Idle submitted no frames; camera updates caused no shared uploads, derived geometry builds or unrelated control rebuilds.

The original camera assertion could falsely pass if rendering stopped: unchanged reuse counters and stale timings were sufficient. `draw_view` and `Assembly.draw` now return the render outcomes, and the replay compares each view's submission counter immediately before and after every expected camera draw. A missing draw, failed render, missing submission or extra submission fails the replay with the view and camera-step number.

All 14 PNGs from the final run matched the individual SHA-256 values in the [November 23 manifest](../../../artifacts/demo-slideshows/spatial-assembly/manifest.json). The 14 retained files also matched those hashes. The [original capture provenance](../../../artifacts/demo-slideshows/spatial-assembly/provenance.json) remains tied to `49ebcdd`. Eighteen of its 156 recorded source inputs differ at the tested revision, including the corrected camera replay and shared window and Metal code. The prior [frame review](../../../artifacts/demo-slideshows/spatial-assembly/validation.json) applies to the byte-identical output.

The linked-view lifecycle test opened and destroyed 20 more owners, each hosting two views. All 240 camera and viewport updates advanced the relevant submission counter exactly once. Both lifecycle cases alternate the target size between 180 × 140 and 220 × 160. The app windows themselves use fixed layouts.

## Negative controls — expected failures observed

The [fault patch](fail-right-after-capture-14.patch) reproduces the review control in temporary source copies. Immediately after `14-recovered.png`, it enables an early `return 0` for image slot 1 in `ms_renderer_frame`. Earlier captures and the left renderer are unaffected. The direct assembly binary exited 1, and the unchanged `set -e` sanitizer runner also exited 1. Both produced all 14 captures, then reported `Right view camera step 1 did not render and submit exactly one frame`. Neither printed the assembly PASS line. The runner stopped before assembly round 2 and the lifecycle test.

A second temporary renderer returned 1 at the same point without submitting a frame. That direct replay also exited 1 at right-view camera step 1, demonstrating that a successful return value alone cannot pass the new check. These failures were replay assertions, with no ASan/UBSan diagnostics. The fault injection is absent from application and renderer sources in the commit.

## Reproduction and limits

Run from the repository root inside the pinned Mojo environment on a Mac with a GUI session and Metal. Activate its environment, including `MODULAR_HOME`, rather than selecting only the Mojo executable. An initial setup attempt without that variable could not locate `std` and ran no app replay; the recorded successful runs used the pinned environment's `share/max` directory.

```sh
bash scripts/spatial_native_sanitizers.sh
```

The runner prints the temporary build and evidence directory. It keeps per-run logs and the final set of AppKit cacheDisplay PNGs for each demo. Clang instruments the native spatial core/API, renderer bridge, text code and both Objective-C hosts, which include the real window and composition implementation. Both app binaries linked Apple's ASan runtime and imported ASan and UBSan handlers. Mojo-generated code, Metal shaders and system frameworks lack compiler instrumentation in this check.

To reproduce the failing runner without modifying the checkout, use the same activated environment:

```sh
repo=$PWD
scratch=$(mktemp -d /tmp/moxi-camera-negative.XXXXXX)
cp -R native src examples "$scratch/"
mkdir -p "$scratch/scripts" "$scratch/tests/spatial"
cp scripts/spatial_native_sanitizers.sh "$scratch/scripts/"
cp tests/spatial/resize_close.m "$scratch/tests/spatial/"
git -C "$scratch" apply "$repo/docs/evidence/spatial-native-2026-11-25/fail-right-after-capture-14.patch"
(cd "$scratch" && bash scripts/spatial_native_sanitizers.sh) > "$scratch/runner.log" 2>&1
# Expected exit status: 1. runner.log identifies the build directory;
# its assembly-1.log contains the step-1 error, without an assembly PASS.
```

The validation record also preserves the direct binary command and sanitizer environment. To repeat the second control, change only the injected `return 0` to `return 1` in the temporary renderer and rebuild. Focused C++ contract and assembly tests also passed under ASan/UBSan, with 1,832 and 2,522 assertions respectively.

Historical leak probes were not repeated for this correction. Apple's ASan runtime rejected a minimal process with `detect_leaks=1` (exit 134, unsupported on this platform). Each ordinary binary was also rebuilt and run once via `/usr/bin/leaks --atExit -- ./dist/spatial-<demo>/<demo> --replay <temporary-directory>`. Both tool runs exited zero and reported zero total leaked bytes. The tool identified each process as restricted and said it could only show or save readonly memory contents. Leak acceptance remains open; the rerun's `detect_leaks=0` is not leak evidence.

Confidence is high for the recorded synthetic paths on this host. A sanitizer finding, a replay assertion failure or a frame hash mismatch would require reassessment. The renderer remains experimental. Controlled performance, GPU memory safety, sustained leaks, physical input, compositor presentation, accessibility, other platforms, the full repository suite and remote CI were outside this run.
