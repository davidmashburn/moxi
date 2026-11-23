"""Scalar color and numeric labels shared by the contour layout families."""


def scalar_color(value, low, high):
    """Sequential blue-to-yellow RGB ramp with increasing luminance."""
    fraction = max(0., min(1., (value-low)/(high-low))) if high > low else .5
    return (.18+.80*fraction, .32+.56*fraction, .62-.30*fraction, 1.)


def scalar_level_label(field, value):
    return f'{field} = {value:g}'


def scalar_band_label(field, low, high, closed):
    return f'{field} in [{low:g}, {high:g}'+(']' if closed else ')')
