"""Deterministic animation/invalidation example using a real component."""

from moxi import (
    App,
    Animation,
    ButtonControl,
    CLICK_KIND,
    ColumnView,
    Component,
    EASE_IN_OUT,
    Event,
    FRAME_TICK_KIND,
    KEY_DOWN_KIND,
    KEY_ENTER,
    KEY_SPACE,
    Rect,
    default_panel_style,
    default_surface_style,
)


comptime ANIMATION_PROGRESS_ID = 1
comptime ANIMATION_RESET_ID = 2
comptime ANIMATION_STATUS_ID = 3


struct AnimationDemo(Component):
    """A component rebuilt by App whenever its frame state advances."""

    var animation: Animation
    var frame_count: Int

    def __init__(out self):
        self.animation = Animation(0.0, 1.0, 1.0, EASE_IN_OUT)
        self.frame_count = 0

    def build(self, bounds: Rect) -> ColumnView:
        var root = ColumnView(bounds, 24.0, 12.0)
        root.set_surface_style(default_surface_style())
        root.set_panel(
            0,
            Rect(
                bounds.x + 16.0,
                bounds.y + 16.0,
                bounds.width - 32.0,
                bounds.height - 32.0,
            ),
            default_panel_style(),
        )
        root.add_label(10, "Animation & invalidation", 34.0)
        root.add_progress(
            ANIMATION_PROGRESS_ID,
            String("Frame ", self.frame_count),
            self.animation.progress(),
            36.0,
        )
        var reset = ButtonControl(
            ANIMATION_RESET_ID,
            "Restart animation",
            36.0,
        )
        root.add(reset.node())
        root.set_intrinsic_width(ANIMATION_RESET_ID)
        root.add_label(
            ANIMATION_STATUS_ID,
            String(
                "Animation value: ",
                self.animation.value(),
                " · rebuilt frames: ",
                self.frame_count,
            ),
            28.0,
        )
        root.layout()
        return root^

    def update(mut self, event: Event, view: ColumnView) -> Bool:
        if event.kind == FRAME_TICK_KIND:
            if self.animation.finished():
                self.animation.restart()
            _ = self.animation.advance(event.delta_seconds)
            self.frame_count += 1
            return True
        if event.target == ANIMATION_RESET_ID and (
            event.kind == CLICK_KIND
            or (
                event.kind == KEY_DOWN_KIND
                and (event.key == KEY_ENTER or event.key == KEY_SPACE)
            )
        ):
            self.animation.restart()
            self.frame_count = 0
            return True
        return False


def main():
    var app = App[AnimationDemo](
        AnimationDemo(),
        Rect(0.0, 0.0, 640.0, 420.0),
    )
    var frames = 0
    while frames < 4:
        _ = app.tick(0.25)
        frames += 1

    print("Moxi animation demo frames: ", frames)
    print("Moxi animation final value: ", app.component.animation.value())
    print("Moxi animation component frame: ", app.component.frame_count)
