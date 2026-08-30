"""Small, backend-neutral performance accounting contracts.

Wall-clock timing is supplied by the host benchmark (the repository harness
uses `/usr/bin/time` so it stays portable). These counters make the amount of
UI work visible even when clocks, schedulers, or GPU drivers differ.
"""


comptime FRAME_BUDGET_60_HZ_MS: Float32 = 16.666667
comptime FRAME_BUDGET_120_HZ_MS: Float32 = 8.333333


def _nonnegative(value: Int) -> Int:
    return value if value > 0 else 0


struct PerformanceCounters(ImplicitlyCopyable):
    """Deterministic per-run work counters for a UI pipeline."""

    var frames: Int
    var reconcile_operations: Int
    var layout_operations: Int
    var paint_commands: Int
    var scene_commands: Int
    var rasterized_pixels: Int

    def __init__(out self):
        self.frames = 0
        self.reconcile_operations = 0
        self.layout_operations = 0
        self.paint_commands = 0
        self.scene_commands = 0
        self.rasterized_pixels = 0

    def record_frame(
        mut self,
        reconcile_operations: Int,
        layout_operations: Int,
        paint_commands: Int,
        scene_commands: Int,
        rasterized_pixels: Int = 0,
    ):
        self.frames += 1
        self.reconcile_operations += _nonnegative(reconcile_operations)
        self.layout_operations += _nonnegative(layout_operations)
        self.paint_commands += _nonnegative(paint_commands)
        self.scene_commands += _nonnegative(scene_commands)
        self.rasterized_pixels += _nonnegative(rasterized_pixels)

    def total_operations(self) -> Int:
        return (
            self.reconcile_operations
            + self.layout_operations
            + self.paint_commands
            + self.scene_commands
        )

    def average_operations(self) -> Float32:
        if self.frames <= 0:
            return 0.0
        return Float32(self.total_operations()) / Float32(self.frames)


struct PerformanceReport(ImplicitlyCopyable):
    """A counter snapshot paired with host-provided elapsed milliseconds."""

    var counters: PerformanceCounters
    var elapsed_ms: Float32

    def __init__(
        out self,
        counters: PerformanceCounters,
        elapsed_ms: Float32 = 0.0,
    ):
        self.counters = counters
        self.elapsed_ms = elapsed_ms if elapsed_ms >= 0.0 else 0.0

    def average_frame_ms(self) -> Float32:
        if self.counters.frames <= 0:
            return 0.0
        return self.elapsed_ms / Float32(self.counters.frames)

    def frames_per_second(self) -> Float32:
        if self.elapsed_ms <= 0.0:
            return 0.0
        return Float32(self.counters.frames) * 1000.0 / self.elapsed_ms

    def target_budget_ms(self, refresh_hz: Int) -> Float32:
        if refresh_hz >= 120:
            return FRAME_BUDGET_120_HZ_MS
        return FRAME_BUDGET_60_HZ_MS

    def meets_frame_budget(self, refresh_hz: Int) -> Bool:
        if self.counters.frames <= 0:
            return True
        return self.average_frame_ms() <= self.target_budget_ms(refresh_hz)
