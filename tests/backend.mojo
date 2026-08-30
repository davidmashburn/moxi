"""Backend capability matrix contract test."""

from moxi import test_check
from moxi import (
    BACKEND_GPU,
    BACKEND_HEADLESS,
    BACKEND_IOS,
    BACKEND_ANDROID,
    BACKEND_WEB,
    BACKEND_LINUX,
    BACKEND_MACOS_APPKIT,
    BACKEND_WINDOWS,
    backend_capabilities,
)


def main():
    var headless = backend_capabilities(BACKEND_HEADLESS)
    test_check(headless.available)
    test_check(headless.clipping)
    test_check(headless.incremental)
    test_check(not headless.text_shaping)

    var macos = backend_capabilities(BACKEND_MACOS_APPKIT)
    test_check(macos.available)
    test_check(macos.native_window)
    test_check(macos.text_shaping)
    test_check(macos.bidi)
    test_check(macos.accessibility)

    test_check(not backend_capabilities(BACKEND_GPU).available)
    test_check(not backend_capabilities(BACKEND_WINDOWS).available)
    test_check(not backend_capabilities(BACKEND_LINUX).available)
    var ios = backend_capabilities(BACKEND_IOS)
    test_check(ios.name == "iOS UIKit + Metal")
    test_check(not ios.available)
    var android = backend_capabilities(BACKEND_ANDROID)
    test_check(android.name == "Android surface + GPU")
    test_check(not android.available)
    var web = backend_capabilities(BACKEND_WEB)
    test_check(web.name == "Web Canvas/WebGPU")
    test_check(not web.available)
    print("Moxi backend test passed")
