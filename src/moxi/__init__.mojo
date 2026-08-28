"""Moxi's public package boundary."""

from .geometry import Rect
from .paint import PaintCommand, Renderer
from .runtime import Runtime, Widget
from .view import Label
from .window import WindowBackend, WindowConfig


def moxi_version() -> String:
    """Return the package version embedded in this release."""
    return "0.1.0"
