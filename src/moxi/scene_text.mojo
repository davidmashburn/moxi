"""Renderer-neutral text style carried by Scene text commands."""


comptime TEXT_ALIGN_START = 1
comptime TEXT_ALIGN_CENTER = 2
comptime TEXT_ALIGN_END = 3
comptime TEXT_BASELINE_ALPHABETIC = 1
comptime TEXT_BASELINE_MIDDLE = 2
comptime TEXT_BASELINE_HANGING = 3
comptime SCENE_TEXT_DIRECTION_AUTO = 1
comptime SCENE_TEXT_DIRECTION_LTR = 2
comptime SCENE_TEXT_DIRECTION_RTL = 3


struct SceneTextStyle(ImplicitlyCopyable):
    """Portable text intent; native backends may resolve family/fallback."""

    var family: String
    var size: Float32
    var weight: Int
    var italic: Bool
    var align: Int
    var baseline: Int
    var direction: Int
    var fallback: String

    def __init__(
        out self,
        family: String = "system-ui",
        size: Float32 = 14.0,
        weight: Int = 400,
        italic: Bool = False,
        align: Int = TEXT_ALIGN_START,
        baseline: Int = TEXT_BASELINE_ALPHABETIC,
        direction: Int = SCENE_TEXT_DIRECTION_AUTO,
        fallback: String = "sans-serif",
    ):
        self.family = family
        self.size = size if size > 0.0 else 1.0
        self.weight = weight if weight > 0 else 400
        self.italic = italic
        self.align = align
        self.baseline = baseline
        self.direction = direction
        self.fallback = fallback
