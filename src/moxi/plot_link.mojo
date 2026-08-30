"""Explicit propagation helpers for linked plot views."""

from .plot_runtime import PlotRuntime
from .plot_selection import PlotSelection


struct PlotLink:
    """A shared stable-key selection channel for multiple plot runtimes."""

    var selection: PlotSelection
    var version: Int

    def __init__(out self):
        self.selection = PlotSelection()
        self.version = 0

    def capture(mut self, runtime: PlotRuntime):
        self.selection = runtime.selection()
        self.version += 1

    def apply(mut self, mut runtime: PlotRuntime):
        runtime.set_linked_selection(self.selection)

    def add(mut self, key: Int) -> Bool:
        var changed = self.selection.add(key)
        if changed:
            self.version += 1
        return changed

    def remove(mut self, key: Int) -> Bool:
        var changed = self.selection.remove(key)
        if changed:
            self.version += 1
        return changed

    def clear(mut self):
        self.selection.clear()
        self.version += 1

    def contains(self, key: Int) -> Bool:
        return self.selection.contains(key)

    def selected(self) -> PlotSelection:
        return self.selection.clone()
