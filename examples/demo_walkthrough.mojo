"""CapabilityBus automation entrypoint for the normal Moxi Playground host."""

from demo_browser import run_demo


def main() raises:
    # This is the exact normal demo_browser host: same shell, live-script
    # loader, clipboard path, renderer, and window title. Only the event
    # source is swapped from manual input to the CapabilityBus replay.
    run_demo(True)
