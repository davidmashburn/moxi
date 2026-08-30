# Native host slices

These files are small host-owned lifecycle/input bridges. They deliberately
stop at the scalar callback boundary in [`moxi_host.h`](moxi_host.h): Moxi
receives normalized resize, pointer/touch, key, text, composition, and frame
notifications, while the platform owns its application object and surface.

- `moxi_ios_host.m` is a UIKit `MTKView` that reports layout, touch, drawable,
  and frame callbacks. Build it inside an Xcode iOS application target with
  UIKit, Metal, and MetalKit.
- `moxi_android_host.cpp` owns an `ANativeWindow*` lifetime and translates NDK
  motion/key events. Build it from an Android NDK project and forward IME text
  through `moxi_android_host_text()`/`moxi_android_host_composition()`.
- `moxi_web_host.mjs` is framework-free browser glue for Canvas/WebGPU or SVG.
  It owns pointer/touch, keyboard, composition, resize-observer, animation,
  and teardown listeners. `presentSVG()` is the deterministic browser fallback.

The current `osx-arm64` package does not link UIKit, the Android NDK, or a
browser runtime. `scripts/host_check.sh` therefore syntax-checks the portable
Android branch, runs the Web host under Node, and conditionally checks the iOS
source when an iPhone simulator SDK is installed. The Mojo
`HostContract` reports these targets as portable bridges until a real app,
device/emulator/browser harness, accessibility mapping, and target renderer
are linked.
