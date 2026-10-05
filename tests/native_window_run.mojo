"""Standalone native runners consume input and stop without waiting on close."""

from std.ffi import external_call
from moxi import test_check
from moxi.window import WindowBackend
from moxi.macos import MacOSWindow
from moxi.linux import LinuxWindow


def check_runner[WindowType: WindowBackend](mut window: WindowType) raises:
    external_call["moxi_test_native_run_reset", NoneType]()
    window.run()
    test_check(external_call["moxi_test_native_run_failures", Int32]() == 0)
    test_check(external_call["moxi_test_native_run_pumps", Int32]() == 3)
    test_check(external_call["moxi_test_native_run_waits", Int32]() == 2)
    test_check(external_call["moxi_test_native_run_consumed", Int32]() == 4)


def main() raises:
    var macos = MacOSWindow()
    check_runner(macos)
    var linux = LinuxWindow()
    check_runner(linux)
    print("Moxi standalone macOS and Linux lifecycle runners passed")
