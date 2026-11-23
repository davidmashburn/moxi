"""Shared scalar encoding for regular-grid and explicit-mesh contours."""
from moxi.style import Color


def scalar_color(value: Float64, low: Float64, high: Float64) -> Color:
    """Sequential blue-to-yellow RGB ramp with increasing luminance."""
    var fraction = max(Float64(0), min(Float64(1), (value-low)/(high-low))) if high > low else Float64(0.5)
    return Color(Float32(0.18+0.80*fraction), Float32(0.32+0.56*fraction), Float32(0.62-0.30*fraction), 1)


def scalar_level_label(field: String, value: Float64) -> String:
    return String(field, " = ", value)


def scalar_band_label(field: String, low: Float64, high: Float64, closed: Bool) -> String:
    return String(field, " in [", low, ", ", high, "]" if closed else ")")
