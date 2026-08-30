# Native host slices

These files are small host-owned lifecycle/input bridges. They deliberately
stop at the scalar callback boundary in [`moxi_host.h`](moxi_host.h): Moxi
receives normalized resize, pointer/touch, key, text, composition, and frame
notifications, while the platform owns its application object and surface.

- `moxi_ios_host.m` is a UIKit `MTKView` that reports layout, touch, drawable,
  and frame callbacks. `../ios/MoxiHost.xcodeproj` is an app target and
  `../../scripts/ios_build.sh` builds a signed arm64 simulator app with UIKit,
  Metal, and MetalKit.
- `moxi_android_host.cpp` owns an `ANativeWindow*` lifetime and translates NDK
  motion/key events. `../android/` contains the CMake/JNI host and a tiny
  installable APK target; `../../scripts/android_build.sh` builds the arm64
  API-35 APK and forwards IME text through the host ABI.
- `moxi_web_host.mjs` is framework-free browser glue for Canvas/WebGPU or SVG.
  It owns pointer/touch, keyboard, composition, resize-observer, animation,
  and teardown listeners. `../web/host_demo.html` is a browser-run Canvas
  example, while `presentSVG()` is the deterministic browser fallback.

The current `osx-arm64` Mojo package does not link UIKit, the Android NDK, or a
browser runtime. `scripts/host_check.sh` checks the Android NDK/APK and iOS
simulator app when their SDKs are installed, and always runs the Web host under
Node. The Mojo `HostContract` reports the portable bridge separately from the
native host artifact: Mojo code is not yet compiled to iOS, Android, or Web.
