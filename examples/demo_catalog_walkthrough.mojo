"""Capability-bus-driven sweep of every Moxi Playground catalog demo."""

from std.ffi import external_call
from std.sys import argv
from demo_browser import run_demo


def main() raises:
    # Keep the ordinary Playground shell and switch only its event source.
    # A LaunchServices-started recorder app has a non-repository working
    # directory, so let the capture script provide the checkout root.
    var arguments = argv()
    if len(arguments) > 1:
        var repo_dir = arguments[1]
        var c_repo_dir = repo_dir.as_c_string_span()
        var changed = external_call["chdir", Int32](c_repo_dir.ptr())
        if changed != 0:
            raise Error(String("Could not enter repository directory: ", repo_dir))
    run_demo(True, True)
