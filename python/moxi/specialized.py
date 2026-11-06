"""Wave A layout v1, adapted from dataviz_mojo v0.8.0 (MIT).

Reference: 3fd5a7e7c622d6130c99a290b88c4fee039deab2, dataviz/{lollipop,
waterfall,candlestick,bullet,grouped_bar,stacked_bar,gantt,span_chart,
population_pyramid}.mojo. See tests/fixtures/wave_a/DATAVIZ-LICENSE.
Columns remain the data boundary; wide series/range columns preserve upstream
matrix order. Glyphs retain source category rows, including decorative pieces.
"""
from dataclasses import dataclass
from enum import Enum, IntEnum
from math import isfinite
from typing import Any, List, Tuple


class LayoutVersion(IntEnum):
    ROW = 0
    SPECIALIZED = 1


class WaveAMark(str, Enum):
    LOLLIPOP = "lollipop"
    WATERFALL = "waterfall"
    CANDLESTICK = "candlestick"
    BULLET = "bullet"
    GROUPED = "grouped_bar"
    STACKED = "stacked_bar"
    GANTT = "gantt"
    SPAN = "span_chart"
    PYRAMID = "population_pyramid"


class GlyphKind(str, Enum):
    RECT = "rect"
    SEGMENT = "segment"
    POINT = "point"
    POLYGON = "polygon"
    TRIANGLE = "triangle"


@dataclass(frozen=True)
class Glyph:
    kind: GlyphKind
    row: int
    part: str
    bounds: Tuple[float, float, float, float]
    color: Tuple[float, ...]
    interactive: bool = True
    vertices: Tuple[Tuple[float, float], ...] = ()
    source_rows: Tuple[int, ...] = ()
    size: float = 6.0
    stroke_width: float = 0.0


@dataclass
class Layout:
    glyphs: List[Glyph]
    x_domain: Tuple[float, float]
    y_domain: Tuple[float, float]
    rows: List[dict]


PALETTE = ((0.25, .75, 1., 1.), (.95, .45, .30, 1.), (.4, .85, .55, 1.), (.65, .45, .95, 1.))
NEGATIVE = (.90, .30, .30, 1.)
TOTAL = (.35, .40, .55, 1.)
INK = (.15, .20, .28, 1.)


def validate_layout(layer: Any) -> None:
    if type(layer.layout_version) not in (int, LayoutVersion):
        raise ValueError("layout_version must be an integer")
    version = LayoutVersion(layer.layout_version)
    if version is LayoutVersion.ROW:
        return
    from .specialized_c import WaveCMark, validate
    if layer.mark in WaveCMark._value2member_map_:
        return validate(layer)
    if layer.triangles or layer.levels:
        raise ValueError("triangles/levels require tricontour")
    from .wave_b import WaveBMark, validate as validate_b
    if layer.mark in WaveBMark._value2member_map_:
        validate_b(layer)
        return
    mark = WaveAMark(layer.mark)
    if not isinstance(layer.horizontal, bool) or not isinstance(layer.percent, bool):
        raise ValueError("horizontal and percent must be boolean")
    if layer.series_fields and mark not in (WaveAMark.GROUPED, WaveAMark.STACKED):
        raise ValueError("series_fields require grouped/stacked bars")
    if layer.range_fields and mark is not WaveAMark.BULLET:
        raise ValueError("range_fields require bullet")
    if any(getattr(layer, name) for name in ("x2", "color_field", "fill_field", "stroke_field", "size_field", "opacity_field", "text_field", "median_field")):
        raise ValueError("specialized v1 uses layout colors/sizes and source-row text; row visual encodings are unsupported")
    for fields in (layer.series_fields, layer.range_fields, layer.error_fields):
        if not isinstance(fields, list) or any(not isinstance(f, str) or not f for f in fields) or len(set(fields)) != len(fields):
            raise ValueError("layout fields must be distinct nonempty column names")
    if layer.horizontal and mark not in (WaveAMark.LOLLIPOP, WaveAMark.GROUPED, WaveAMark.STACKED):
        raise ValueError("horizontal is supported only for lollipop/grouped/stacked")
    if layer.percent and mark is not WaveAMark.STACKED:
        raise ValueError("percent requires stacked_bar")
    if mark in (WaveAMark.GROUPED, WaveAMark.STACKED) and not layer.series_fields:
        raise ValueError("grouped/stacked layout needs series_fields")
    if mark is WaveAMark.BULLET and (not layer.range_fields or not layer.y2):
        raise ValueError("bullet needs range_fields and y2 target")
    if mark is WaveAMark.CANDLESTICK and not (layer.y2 and layer.stat_low_field and layer.stat_high_field):
        raise ValueError("candlestick needs y2 open, stat_low_field and stat_high_field")
    if mark in (WaveAMark.GANTT, WaveAMark.SPAN, WaveAMark.PYRAMID) and not layer.y2:
        raise ValueError("interval/pyramid layout needs y2")
    if layer.error_fields and (mark is not WaveAMark.GROUPED or len(layer.error_fields) != len(layer.series_fields)):
        raise ValueError("grouped errors must match series_fields")
    if layer.total_field and mark is not WaveAMark.WATERFALL:
        raise ValueError("total_field requires waterfall")


def layout(layer: Any, data: Any, width: float = 560., height: float = 416.) -> Layout:
    validate_layout(layer)
    from .wave_b import WaveBMark, layout as wave_b_layout
    if layer.mark in WaveBMark._value2member_map_:
        return wave_b_layout(layer, data, width, height)
    from .specialized_c import WaveCMark, layout as wave_c_layout
    if layer.mark in WaveCMark._value2member_map_:
        return wave_c_layout(layer, data)
    mark = WaveAMark(layer.mark)
    categories = list(data.column(layer.x))
    n = len(categories)
    if not n or any(c is None for c in categories):
        raise ValueError("specialized layout requires nonempty, nonnull categories")

    def column(name: str) -> List[float]:
        values = list(data.column(name))
        if len(values) != n or any(isinstance(v, (str, bool)) or v is None or not isfinite(float(v)) for v in values):
            raise ValueError(f"{name}: expected {n} finite numeric values")
        return [float(v) for v in values]

    values = column(layer.y)
    second = column(layer.y2) if layer.y2 else []
    series = [column(f) for f in layer.series_fields]
    ranges = [column(f) for f in layer.range_fields]
    errors = [column(f) for f in layer.error_fields]
    lows = column(layer.stat_low_field) if layer.stat_low_field else []
    highs = column(layer.stat_high_field) if layer.stat_high_field else []
    totals = list(data.column(layer.total_field)) if layer.total_field else []
    if totals and (len(totals) != n or any(v not in (False, True, 0, 1) for v in totals)):
        raise ValueError("waterfall totals must be boolean or 0/1")
    glyphs: List[Glyph] = []
    rows = []
    running = 0.0
    previous_right = 0.0
    color = tuple(layer.color)
    extrema = [0.0]

    def emit(kind: GlyphKind, i: int, part: str, a: float, b: float, c: float, d: float, fill=color, interactive=True):
        bounds = (b, a, d, c) if layer.horizontal else (a, b, c, d)
        glyphs.append(Glyph(kind, i, part, bounds, tuple(fill), interactive))

    for i in range(n):
        v = values[i]
        row = {"row_index": i, "category": categories[i], "mark": mark.value, "value": v}
        left, right = i - .4, i + .4
        if mark is WaveAMark.LOLLIPOP:
            emit(GlyphKind.SEGMENT, i, "stem", i, 0., i, v)
            emit(GlyphKind.POINT, i, "head", i, v, i, v)
            extrema.append(v)
        elif mark is WaveAMark.WATERFALL:
            before = running
            running += v
            total = bool(totals[i]) if totals else False
            start = 0. if total else before
            half = .4 if total or not totals else .24
            left, right = i-half, i+half
            if i:
                emit(GlyphKind.SEGMENT, i, "connector", previous_right, before, left, before, INK, False)
            emit(GlyphKind.RECT, i, "total" if total else "delta", left, start, right, running, TOTAL if total else NEGATIVE if v < 0 else color)
            previous_right = right
            extrema.extend((start, running))
            row.update(start=start, end=running, is_total=total)
        elif mark is WaveAMark.CANDLESTICK:
            opened, low, high = second[i], lows[i], highs[i]
            if low > min(opened, v) or high < max(opened, v) or low > high:
                raise ValueError("candlestick requires low <= open/close <= high")
            fill = color if v >= opened else NEGATIVE
            emit(GlyphKind.SEGMENT, i, "wick", i, low, i, high, fill)
            emit(GlyphKind.RECT, i, "body", left, opened, right, v, fill)
            extrema.extend((low, high))
            row.update(open=opened, close=v, low=low, high=high)
        elif mark is WaveAMark.BULLET:
            thresholds = [r[i] for r in ranges]
            if any(a > b for a,b in zip(thresholds, thresholds[1:])):
                raise ValueError("bullet ranges must be non-decreasing")
            start = 0.
            for j, end in enumerate(thresholds):
                shade = .86 - .30*j/max(1,len(thresholds)-1)
                emit(GlyphKind.RECT, i, f"range:{j}", left, start, right, end, (shade,shade,shade,1.))
                start = end
            emit(GlyphKind.RECT, i, "measure", i-.14, 0., i+.14, v)
            emit(GlyphKind.SEGMENT, i, "target", left, second[i], right, second[i], INK)
            extrema.extend(thresholds + [v,second[i]])
            row.update(target=second[i], ranges=thresholds)
        elif mark in (WaveAMark.GROUPED, WaveAMark.STACKED):
            pos = neg = 0.
            denominator = sum(s[i] for s in series)
            if layer.percent and any(s[i] < 0 for s in series):
                raise ValueError("percent stacks require nonnegative values")
            for j,s in enumerate(series):
                value = s[i] * 100/denominator if layer.percent and denominator else (0. if layer.percent else s[i])
                start = 0.
                a,b = left,right
                if mark is WaveAMark.GROUPED:
                    a = left + .8*j/len(series)
                    b = left + .8*(j+1)/len(series)
                elif value >= 0:
                    start = pos
                    pos += value
                else:
                    start = neg
                    neg += value
                end = start + value
                emit(GlyphKind.RECT, i, layer.series_fields[j], a, start, b, end, PALETTE[j % len(PALETTE)])
                extrema.extend((start,end))
                if errors:
                    error = errors[j][i]
                    if error < 0:
                        raise ValueError("grouped errors must be nonnegative")
                    center = (a+b)/2
                    emit(GlyphKind.SEGMENT, i, f"error:{j}", center, end-error, center, end+error, INK)
                    for tip in (end-error,end+error):
                        emit(GlyphKind.SEGMENT, i, f"error-cap:{j}", center-.04, tip, center+.04, tip, INK)
                    extrema.extend((end-error,end+error))
            row.update(series={f:s[i] for f,s in zip(layer.series_fields,series)})
        elif mark in (WaveAMark.GANTT, WaveAMark.SPAN):
            if mark is WaveAMark.GANTT:
                emit(GlyphKind.RECT, i, "span", min(v,second[i]), n-1-i-.4, max(v,second[i]), n-1-i+.4)
            else:
                emit(GlyphKind.RECT, i, "span", left, min(v,second[i]), right, max(v,second[i]))
            extrema.extend((v,second[i]))
            row.update(start=v, end=second[i])
        elif mark is WaveAMark.PYRAMID:
            emit(GlyphKind.RECT, i, "left", -abs(v), n-1-i-.4, 0., n-1-i+.4, PALETTE[0])
            emit(GlyphKind.RECT, i, "right", 0., n-1-i-.4, abs(second[i]), n-1-i+.4, PALETTE[1])
            extrema.extend((-abs(v),abs(second[i])))
            row.update(left=abs(v), right=abs(second[i]))
        rows.append(row)
    domain = (min(extrema), max(extrema))
    if domain[0] == domain[1]:
        domain = (domain[0], domain[0]+1.)
    categorical = (-.5, n-.5)
    if mark is WaveAMark.PYRAMID:
        extent = max(abs(domain[0]), abs(domain[1]))
        domain = (-extent,extent)
    if layer.percent:
        domain = (0.,100.)
    if mark is WaveAMark.LOLLIPOP:
        padding = (domain[1]-domain[0])*.05
        domain = (domain[0]-padding, domain[1]+padding)
    horizontal = layer.horizontal or mark in (WaveAMark.GANTT, WaveAMark.PYRAMID)
    return Layout(glyphs, domain if horizontal else categorical, categorical if horizontal else domain, rows)
