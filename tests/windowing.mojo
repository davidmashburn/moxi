"""Contract tests for portable multi-window ownership."""

from moxi import Size, WindowConfig, WindowManager, test_check


def main():
    var config = WindowConfig("Main", 640.0, 480.0)
    config.set_min_size(320.0, 240.0)
    config.set_resizable(False)
    test_check(config.min_width == 320.0)
    test_check(not config.resizable)

    var manager = WindowManager(2)
    var first = manager.open(config)
    var second = manager.open(WindowConfig("Inspector", 320.0, 240.0))
    var third = manager.open(WindowConfig("Overflow", 100.0, 100.0))
    test_check(first.is_valid())
    test_check(second.is_valid())
    test_check(not third.is_valid())
    test_check(manager.count() == 2)
    test_check(manager.window(0).focused)
    test_check(manager.focus(second))
    test_check(manager.window(1).focused)
    test_check(not manager.focus(third))
    test_check(manager.window(1).focused)
    test_check(manager.resize(second, Size(400.0, 300.0)))
    test_check(manager.window(1).size.width == 400.0)
    test_check(manager.close(second))
    test_check(manager.count() == 1)

    print("Moxi windowing test passed")
