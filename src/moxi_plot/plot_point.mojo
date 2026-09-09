"""Data-space point and scale value types: `PlotPoint` and `PlotScale`."""


from std.collections import List
from std.math import exp, log, pow, sqrt


from moxi.style import Color


comptime SCALE_LINEAR = 1
comptime SCALE_LOG = 2
comptime SCALE_POWER = 3
comptime SCALE_SQRT = 4
comptime SCALE_TEMPORAL = 5
comptime SCALE_ORDINAL = 6
comptime SCALE_BAND = 7
comptime SCALE_SYMLOG = 8
comptime SCALE_POINT = 9
comptime SCALE_THRESHOLD = 10
comptime SCALE_QUANTILE = 11
comptime SCALE_QUANTIZE = 12
comptime SCALE_SEQUENTIAL = 13
comptime SCALE_DIVERGING = 14
comptime SCALE_CATEGORICAL = 15


def _symlog(value: Float32) -> Float32:
    var magnitude = value if value >= 0.0 else -value
    var transformed = Float32(log(1.0 + magnitude))
    return transformed if value >= 0.0 else -transformed


def _symexp(value: Float32) -> Float32:
    var magnitude = value if value >= 0.0 else -value
    var transformed = Float32(exp(magnitude) - 1.0)
    return transformed if value >= 0.0 else -transformed


struct PlotPoint(ImplicitlyCopyable):
    """One data-space point."""

    var x: Float32
    var y: Float32
    var row_key: Int
    var facet_value: String
    var facet_column_value: String
    var panel_index: Int
    var x2: Float32
    var y2: Float32
    var has_x2: Bool
    var has_y2: Bool
    var size: Float32
    var opacity: Float32
    var text: String
    var tooltip: String
    var color: Color
    var has_color: Bool
    var stat_low: Float32
    var stat_high: Float32
    var stat_median: Float32
    var has_statistics: Bool

    def __init__(out self, x: Float32, y: Float32, row_key: Int = -1):
        self.x = x
        self.y = y
        self.row_key = row_key
        self.facet_value = ""
        self.facet_column_value = ""
        self.panel_index = 0
        self.x2 = x
        self.y2 = y
        self.has_x2 = False
        self.has_y2 = False
        self.size = 6.0
        self.opacity = 1.0
        self.text = ""
        self.tooltip = ""
        self.color = Color(0.0, 0.0, 0.0, 0.0)
        self.has_color = False
        self.stat_low = y
        self.stat_high = y
        self.stat_median = y
        self.has_statistics = False

    def set_facet(mut self, value: String):
        self.facet_value = value

    def set_facet_column(mut self, value: String):
        self.facet_column_value = value

    def set_extent(mut self, x2: Float32, y2: Float32, has_x2: Bool = True, has_y2: Bool = True):
        self.x2 = x2
        self.y2 = y2
        self.has_x2 = has_x2
        self.has_y2 = has_y2

    def set_visuals(
        mut self,
        size: Float32,
        opacity: Float32,
        text: String = "",
        tooltip: String = "",
    ):
        self.size = size if size > 0.0 else 1.0
        var safe_opacity = opacity
        if safe_opacity < 0.0:
            safe_opacity = 0.0
        if safe_opacity > 1.0:
            safe_opacity = 1.0
        self.opacity = safe_opacity
        self.text = text
        self.tooltip = tooltip

    def set_color(mut self, color: Color):
        self.color = color
        self.has_color = True

    def set_statistics(
        mut self,
        low: Float32,
        high: Float32,
        median: Float32,
    ):
        self.stat_low = low
        self.stat_high = high
        self.stat_median = median
        self.has_statistics = True


struct PlotScale(ImplicitlyCopyable):
    """A clamped linear data-to-pixel transform."""

    var data_min: Float32
    var data_max: Float32
    var pixel_min: Float32
    var pixel_max: Float32
    var kind: Int
    var power: Float32

    def __init__(
        out self,
        data_min: Float32 = 0.0,
        data_max: Float32 = 1.0,
        pixel_min: Float32 = 0.0,
        pixel_max: Float32 = 1.0,
    ):
        self.data_min = data_min
        self.data_max = data_max
        self.pixel_min = pixel_min
        self.pixel_max = pixel_max
        self.kind = SCALE_LINEAR
        self.power = 2.0
        self.set_domain(data_min, data_max)

    def set_kind(mut self, kind: Int):
        if kind < SCALE_LINEAR or kind > SCALE_CATEGORICAL:
            self.kind = SCALE_LINEAR
        else:
            self.kind = kind
        # Log domains cannot contain zero or negative values. Keep the public
        # domain valid as soon as the scale kind changes, including when a
        # caller configures a scale after loading data.
        if self.kind == SCALE_LOG:
            self.set_domain(self.data_min, self.data_max)

    def set_power(mut self, power: Float32):
        self.power = power if power > 0.0 else 1.0

    def kind_name(self) -> String:
        if self.kind == SCALE_LOG:
            return "log"
        if self.kind == SCALE_POWER:
            return "power"
        if self.kind == SCALE_SQRT:
            return "sqrt"
        if self.kind == SCALE_TEMPORAL:
            return "temporal"
        if self.kind == SCALE_ORDINAL:
            return "ordinal"
        if self.kind == SCALE_BAND:
            return "band"
        if self.kind == SCALE_SYMLOG:
            return "symlog"
        if self.kind == SCALE_POINT:
            return "point"
        if self.kind == SCALE_THRESHOLD:
            return "threshold"
        if self.kind == SCALE_QUANTILE:
            return "quantile"
        if self.kind == SCALE_QUANTIZE:
            return "quantize"
        if self.kind == SCALE_SEQUENTIAL:
            return "sequential"
        if self.kind == SCALE_DIVERGING:
            return "diverging"
        if self.kind == SCALE_CATEGORICAL:
            return "categorical"
        return "linear"

    def set_domain(mut self, minimum: Float32, maximum: Float32):
        var lower = minimum
        var upper = maximum
        if lower > upper:
            var swap = lower
            lower = upper
            upper = swap
        if self.kind == SCALE_LOG:
            if lower <= 0.0:
                lower = 0.000001
            if upper <= lower:
                upper = lower * 10.0
        if lower == upper:
            lower -= 0.5
            upper += 0.5
        self.data_min = lower
        self.data_max = upper

    def set_range(mut self, minimum: Float32, maximum: Float32):
        self.pixel_min = minimum
        self.pixel_max = maximum

    def map(self, value: Float32) -> Float32:
        var amount = (value - self.data_min) / (self.data_max - self.data_min)
        if self.kind == SCALE_LOG:
            var lower = self.data_min if self.data_min > 0.0 else 0.000001
            var safe_value = value if value > 0.0 else lower
            var upper = self.data_max if self.data_max > lower else lower * 10.0
            amount = Float32(
                (log(safe_value) - log(lower))
                / (log(upper) - log(lower))
            )
        elif self.kind == SCALE_SYMLOG:
            var lower = _symlog(self.data_min)
            var upper = _symlog(self.data_max)
            amount = (_symlog(value) - lower) / (upper - lower)
        elif self.kind == SCALE_POWER:
            var safe_amount = amount if amount > 0.0 else 0.0
            amount = Float32(pow(safe_amount, self.power))
        elif self.kind == SCALE_SQRT:
            var safe_amount = amount if amount > 0.0 else 0.0
            amount = Float32(sqrt(safe_amount))
        if amount < 0.0:
            amount = 0.0
        if amount > 1.0:
            amount = 1.0
        return self.pixel_min + amount * (self.pixel_max - self.pixel_min)

    def fraction(self, value: Float32) -> Float32:
        var span = self.pixel_max - self.pixel_min
        if span == 0.0:
            return 0.0
        return (self.map(value) - self.pixel_min) / span

    def domain_is_valid(self) -> Bool:
        if self.data_max <= self.data_min:
            return False
        if self.kind == SCALE_LOG and self.data_min <= 0.0:
            return False
        return True

    def range_is_valid(self) -> Bool:
        return self.pixel_max != self.pixel_min

    def inverse(self, pixel: Float32) -> Float32:
        """Map a pixel coordinate back into the unclamped data domain."""
        var pixel_span = self.pixel_max - self.pixel_min
        if pixel_span == 0.0:
            return self.data_min
        var amount = (pixel - self.pixel_min) / pixel_span
        if self.kind == SCALE_LOG:
            var lower = self.data_min if self.data_min > 0.0 else 0.000001
            var upper = self.data_max if self.data_max > lower else lower * 10.0
            return exp(log(lower) + amount * (log(upper) - log(lower)))
        if self.kind == SCALE_SYMLOG:
            var lower = _symlog(self.data_min)
            var upper = _symlog(self.data_max)
            return _symexp(lower + amount * (upper - lower))
        if self.kind == SCALE_POWER:
            var safe_power = self.power if self.power > 0.0 else 1.0
            var sign: Float32 = 1.0 if amount >= 0.0 else -1.0
            var magnitude = amount if amount >= 0.0 else -amount
            var powered = Float32(pow(magnitude, 1.0 / safe_power))
            return self.data_min + powered * sign * (self.data_max - self.data_min)
        if self.kind == SCALE_SQRT:
            var safe_amount = amount if amount >= 0.0 else 0.0
            return self.data_min + safe_amount * safe_amount * (self.data_max - self.data_min)
        return self.data_min + amount * (self.data_max - self.data_min)

    def pan_pixels(mut self, pixels: Float32):
        """Translate the domain by a logical pixel distance."""
        var pixel_span = self.pixel_max - self.pixel_min
        if pixel_span == 0.0:
            return
        var data_delta = pixels / pixel_span * (self.data_max - self.data_min)
        self.data_min -= data_delta
        self.data_max -= data_delta

    def zoom_at(mut self, factor: Float32, pixel: Float32):
        """Zoom around a pixel anchor without losing the current domain."""
        if factor <= 0.0 or factor == 1.0:
            return
        var safe_factor = factor
        if safe_factor < 0.1:
            safe_factor = 0.1
        if safe_factor > 10.0:
            safe_factor = 10.0
        var anchor = self.inverse(pixel)
        var minimum = anchor - (anchor - self.data_min) / safe_factor
        var maximum = anchor + (self.data_max - anchor) / safe_factor
        self.set_domain(minimum, maximum)

    def tick(self, index: Int, count: Int) -> Float32:
        """Return a scale-aware data-space tick value."""
        var safe_count = count if count > 0 else 1
        var safe_index = index
        if safe_index < 0:
            safe_index = 0
        if safe_index > safe_count:
            safe_index = safe_count
        var fraction = Float32(safe_index) / Float32(safe_count)
        if self.kind == SCALE_LOG:
            var lower = self.data_min if self.data_min > 0.0 else 0.000001
            var upper = self.data_max if self.data_max > lower else lower * 10.0
            return Float32(exp(log(lower) + fraction * (log(upper) - log(lower))))
        if self.kind == SCALE_POWER:
            return self.data_min + Float32(pow(fraction, 1.0 / self.power)) * (self.data_max - self.data_min)
        if self.kind == SCALE_SQRT:
            return self.data_min + fraction * fraction * (self.data_max - self.data_min)
        return self.data_min + (self.data_max - self.data_min) * fraction

    def ticks(self, count: Int) -> List[Float32]:
        """Return a deterministic list of scale-aware tick values."""
        var result = List[Float32]()
        var safe_count = count if count > 0 else 1
        for index in range(safe_count + 1):
            result.append(self.tick(index, safe_count))
        return result^

    def format(self, value: Float32) -> String:
        """Format a guide value through the current scale's portable fallback."""
        return String(value)


