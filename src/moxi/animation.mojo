"""Deterministic frame-stepped animation primitives."""


comptime EASE_LINEAR = 0
comptime EASE_IN = 1
comptime EASE_OUT = 2
comptime EASE_IN_OUT = 3


def eased_progress(progress: Float32, easing: Int) -> Float32:
    var value = progress
    if value < 0.0:
        value = 0.0
    if value > 1.0:
        value = 1.0
    if easing == EASE_IN:
        return value * value
    if easing == EASE_OUT:
        var inverse = 1.0 - value
        return 1.0 - inverse * inverse
    if easing == EASE_IN_OUT:
        if value < 0.5:
            return 2.0 * value * value
        var inverse = 1.0 - value
        return 1.0 - 2.0 * inverse * inverse
    return value


struct Animation(ImplicitlyCopyable):
    """A scalar tween advanced explicitly by the application frame clock."""

    var start_value: Float32
    var end_value: Float32
    var duration: Float32
    var elapsed: Float32
    var easing: Int
    var running: Bool

    def __init__(
        out self,
        start_value: Float32,
        end_value: Float32,
        duration: Float32,
        easing: Int = EASE_LINEAR,
    ):
        self.start_value = start_value
        self.end_value = end_value
        self.duration = duration if duration > 0.0 else 0.0
        self.elapsed = 0.0
        self.easing = easing
        self.running = self.duration > 0.0

    def progress(self) -> Float32:
        if self.duration <= 0.0:
            return 1.0
        var value = self.elapsed / self.duration
        if value < 0.0:
            value = 0.0
        if value > 1.0:
            value = 1.0
        return value

    def value(self) -> Float32:
        var progress = eased_progress(self.progress(), self.easing)
        return self.start_value + (self.end_value - self.start_value) * progress

    def finished(self) -> Bool:
        return not self.running

    def advance(mut self, delta_seconds: Float32) -> Bool:
        """Advance by a non-negative frame delta and report a value change."""
        if not self.running or delta_seconds <= 0.0:
            return False
        self.elapsed += delta_seconds
        if self.elapsed >= self.duration:
            self.elapsed = self.duration
            self.running = False
        return True

    def restart(mut self):
        """Restart this tween from its original start value."""
        self.elapsed = 0.0
        self.running = self.duration > 0.0

    def set_values(mut self, start_value: Float32, end_value: Float32):
        """Change endpoints and restart the tween."""
        self.start_value = start_value
        self.end_value = end_value
        self.restart()

