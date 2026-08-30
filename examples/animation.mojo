"""Deterministic animation/invalidation example for the Moxi core."""

from moxi import (
    Animation,
    EASE_IN_OUT,
    INVALIDATE_CONTENT,
    Invalidation,
    Rect,
)


def main():
    var slide = Animation(0.0, 240.0, 1.0, EASE_IN_OUT)
    var invalidation = Invalidation()
    var frames = 0
    while not slide.finished():
        _ = slide.advance(0.25)
        invalidation.invalidate(
            INVALIDATE_CONTENT,
            Rect(slide.value(), 24.0, 48.0, 32.0),
        )
        frames += 1

    print("Moxi animation demo frames: ", frames)
    print("Moxi animation final x: ", slide.value())
    print("Moxi animation dirty width: ", invalidation.bounds.width)
