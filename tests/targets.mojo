"""Named target adapter contract test."""

from moxi import AndroidBackend, IOSBackend, SurfaceConfig, WebBackend, test_check


def main():
    var config = SurfaceConfig()
    var ios = IOSBackend()
    var android = AndroidBackend()
    var web = WebBackend()
    test_check(not ios.is_available())
    test_check(not android.is_available())
    test_check(not web.is_available())
    test_check(not ios.open(config))
    test_check(not android.open(config))
    test_check(not web.open(config))
    test_check(not web.set_scale_factor(2.0))
    print("Moxi named-targets test passed")
