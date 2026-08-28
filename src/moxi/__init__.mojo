"""Moxi's public package boundary."""

from .geometry import Point, Rect
from .event import ClickEvent
from .app import CounterState
from .paint import PaintCommand, Renderer
from .runtime import CounterRuntime, Runtime, Widget
from .view import Button, CounterView, Label
from .window import WindowBackend, WindowConfig


def moxi_version() -> String:
    """Return the package version embedded in this release."""
    return "0.2.0"
