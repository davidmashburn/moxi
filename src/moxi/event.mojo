"""Input events shared by platform adapters and application state."""

from .geometry import Point


struct ClickEvent(ImplicitlyCopyable):
    """A primary-pointer click in window content coordinates."""

    var position: Point

    def __init__(out self, position: Point):
        self.position = position
