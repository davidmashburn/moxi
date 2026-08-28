"""Moxi's public package boundary."""

from .geometry import Point, Rect, Size
from .event import ClickEvent
from .component import Component
from .app import CounterState
from .app_runtime import App
from .layout import ColumnLayout
from .paint import PANEL_KIND, SURFACE_KIND, PaintCommand, PaintCommands, Renderer
from .runtime import ColumnRuntime, CounterRuntime, Runtime, Widget
from .style import Color, Panel, Style
from .view import (
    BUTTON_KIND,
    LABEL_KIND,
    Button,
    ColumnView,
    CounterView,
    Label,
    ViewNode,
)
from .window import WindowBackend, WindowConfig


def moxi_version() -> String:
    """Return the package version embedded in this release."""
    return "0.3.0"
