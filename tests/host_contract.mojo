"""Native-host status contract test."""

from moxi import (
    BACKEND_ANDROID,
    BACKEND_IOS,
    BACKEND_MACOS_APPKIT,
    BACKEND_WEB,
    HOST_NATIVE,
    HOST_PORTABLE_BRIDGE,
    host_contract,
    test_check,
)


def main():
    var macos = host_contract(BACKEND_MACOS_APPKIT)
    test_check(macos.status == HOST_NATIVE)
    test_check(macos.native_available())
    test_check(macos.gpu_surface)

    var ios = host_contract(BACKEND_IOS)
    test_check(ios.status == HOST_PORTABLE_BRIDGE)
    test_check(ios.portable_fallback())
    test_check(ios.lifecycle)
    test_check(ios.input)
    test_check(ios.requirement.count_codepoints() > 0)

    var android = host_contract(BACKEND_ANDROID)
    test_check(android.status == HOST_PORTABLE_BRIDGE)
    test_check(android.gpu_surface)
    var web = host_contract(BACKEND_WEB)
    test_check(web.status == HOST_PORTABLE_BRIDGE)
    test_check(web.input)
    print("Moxi host-contract test passed")
