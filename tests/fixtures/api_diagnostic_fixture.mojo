"""Intentionally invalid consumer used only for diagnostic-size baselines."""

from moxi import RequestHandle


def main():
    var handle = RequestHandle(1, 1, 1)
    # Keep this fixture invalid on purpose: the baseline records compiler
    # diagnostic size for a small public API misuse.
    _ = handle.not_a_real_method()
