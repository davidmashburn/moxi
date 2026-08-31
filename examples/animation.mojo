"""Deterministic animation/invalidation example using a real component."""

from moxi import (
    App,
    SHOWCASE_ANIMATION,
    ShowcaseState,
    Rect,
)


def main():
    var app = App[ShowcaseState](
        ShowcaseState(SHOWCASE_ANIMATION),
        Rect(0.0, 0.0, 640.0, 420.0),
    )
    var frames = 0
    while frames < 4:
        _ = app.tick(0.25)
        frames += 1

    print("Moxi animation demo frames: ", frames)
    print("Moxi animation final value: ", app.component.animation.value())
    print("Moxi animation component frame: ", app.component.frame_count)
