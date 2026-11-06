"""Specialized Wave A layout v1: source-row-preserving data-space glyphs.

Adapted from dataviz_mojo v0.8.0, commit 3fd5a7e7c622d6130c99a290b88c4fee039deab2,
MIT Copyright (c) 2026 Randy Zwitch. Full notice: tests/fixtures/wave_a/DATAVIZ-LICENSE.
Wide named columns correspond to upstream series/range matrices, in declared order.
"""
from .plot_layout_c import _wave_c, _c_validate, _c_layout
from std.collections import List
from .plot_wave_b import _wave_b, _b_valid, _b_series
from std.math import isfinite
from moxi.style import Color
from .plot_data import PlotDataTable, COLUMN_STRING, COLUMN_CATEGORY, COLUMN_BOOL
from .plot_point import PlotPoint, PlotGlyphKind
from .plot_series import PlotSeries
from .plot_spec_types import PlotLayer, PlotLayoutVersion
from .plot_spec_json import _string_array
from .plot_marks import (PLOT_LOLLIPOP, PLOT_WATERFALL, PLOT_CANDLESTICK, PLOT_BULLET, PLOT_GROUPED_BAR, PLOT_STACKED_BAR, PLOT_GANTT, PLOT_SPAN_CHART, PLOT_POPULATION_PYRAMID)




def _fields_valid(json: String) -> Bool:
    var fields = _string_array(json)
    if len(fields) == 0 and json != "[]":
        return False
    for i in range(len(fields)):
        if fields[i].count_codepoints() == 0:
            return False
        for j in range(i):
            if fields[i] == fields[j]:
                return False
    return True


def specialized_valid(layer: PlotLayer) -> Bool:
    if layer.layout_version.value == PlotLayoutVersion.ROW.value:
        return True
    if layer.layout_version.value != PlotLayoutVersion.SPECIALIZED.value:
        return False
    if _wave_c(layer.mark):
        try:
            _c_validate(layer)
            return True
        except:
            return False
    if layer.triangles_json != "[]" or layer.levels_json != "[]":
        return False
    var mark = layer.mark
    if _wave_b(mark):
        return _fields_valid(layer.series_fields_json) and _b_valid(layer)
    if layer.x2_field != "" or layer.color_field != "" or layer.fill_field != "" or layer.stroke_field != "" or layer.size_field != "" or layer.opacity_field != "" or layer.text_field != "" or layer.median_field != "":
        return False
    if not (mark == PLOT_LOLLIPOP or mark == PLOT_WATERFALL or mark == PLOT_CANDLESTICK or mark == PLOT_BULLET or mark == PLOT_GROUPED_BAR or mark == PLOT_STACKED_BAR or mark == PLOT_GANTT or mark == PLOT_SPAN_CHART or mark == PLOT_POPULATION_PYRAMID):
        return False
    if not _fields_valid(layer.series_fields_json) or not _fields_valid(layer.range_fields_json) or not _fields_valid(layer.error_fields_json):
        return False
    var series = _string_array(layer.series_fields_json)
    var ranges = _string_array(layer.range_fields_json)
    var errors = _string_array(layer.error_fields_json)
    if len(series) > 0 and mark != PLOT_GROUPED_BAR and mark != PLOT_STACKED_BAR:
        return False
    if len(ranges) > 0 and mark != PLOT_BULLET:
        return False
    if layer.horizontal and mark != PLOT_LOLLIPOP and mark != PLOT_GROUPED_BAR and mark != PLOT_STACKED_BAR:
        return False
    if layer.percent and mark != PLOT_STACKED_BAR:
        return False
    if (mark == PLOT_GROUPED_BAR or mark == PLOT_STACKED_BAR) and len(series) == 0:
        return False
    if mark == PLOT_BULLET and (len(ranges) == 0 or layer.y2_field == ""):
        return False
    if mark == PLOT_CANDLESTICK and (layer.y2_field == "" or layer.stat_low_field == "" or layer.stat_high_field == ""):
        return False
    if (mark == PLOT_GANTT or mark == PLOT_SPAN_CHART or mark == PLOT_POPULATION_PYRAMID) and layer.y2_field == "":
        return False
    if len(errors) > 0 and (mark != PLOT_GROUPED_BAR or len(errors) != len(series)):
        return False
    if layer.total_field != "" and mark != PLOT_WATERFALL:
        return False
    return True


def specialized_valid(layer: PlotLayer, data: PlotDataTable) -> Bool:
    if not specialized_valid(layer):
        return False
    if layer.layout_version.value == PlotLayoutVersion.ROW.value:
        return True
    if _wave_b(layer.mark):
        return _b_valid(layer,data)
    if _wave_c(layer.mark):
        try:
            _ = _c_layout(layer,data,0)
            return True
        except:
            return False
    if data.row_count() == 0 or data.field_kind(layer.x_field) == 0:
        return False
    var fields: List[String] = [layer.y_field]
    var optional_fields: List[String] = [layer.y2_field, layer.stat_low_field, layer.stat_high_field, layer.total_field]
    for name in optional_fields:
        if name != "":
            fields.append(name)
    var series = _string_array(layer.series_fields_json)
    var ranges = _string_array(layer.range_fields_json)
    var errors = _string_array(layer.error_fields_json)
    for name in series:
        fields.append(name)
    for name in ranges:
        fields.append(name)
    for name in errors:
        fields.append(name)
    for name in fields:
        if data.field_kind(name) == 0 or data.field_kind(name) == COLUMN_STRING or data.field_kind(name) == COLUMN_CATEGORY:
            return False
        if data.field_kind(name) == COLUMN_BOOL and name != layer.total_field:
            return False
        for i in range(data.row_count()):
            if not data.field_is_valid(name, i) or not isfinite(data.float_field_at(name, i)):
                return False
    for i in range(data.row_count()):
        if not data.field_is_valid(layer.x_field, i):
            return False
        if layer.total_field != "":
            var total = data.float_field_at(layer.total_field, i)
            if total != 0.0 and total != 1.0:
                return False
        for j in range(1, len(ranges)):
            if data.float_field_at(ranges[j-1], i) > data.float_field_at(ranges[j], i):
                return False
        for name in errors:
            if data.float_field_at(name, i) < 0.0:
                return False
        for name in series:
            if layer.percent and data.float_field_at(name, i) < 0.0:
                return False
        if layer.mark == PLOT_CANDLESTICK:
            var opened = data.float_field_at(layer.y2_field, i)
            var closed = data.float_field_at(layer.y_field, i)
            var low = data.float_field_at(layer.stat_low_field, i)
            var high = data.float_field_at(layer.stat_high_field, i)
            if low > min(opened, closed) or high < max(opened, closed) or low > high:
                return False
    return True


def _palette(index: Int) -> Color:
    if index % 4 == 0:
        return Color(0.25, 0.75, 1.0, 1.0)
    if index % 4 == 1:
        return Color(0.95, 0.45, 0.30, 1.0)
    if index % 4 == 2:
        return Color(0.4, 0.85, 0.55, 1.0)
    return Color(0.65, 0.45, 0.95, 1.0)


def _glyph(mut series: PlotSeries, layer: PlotLayer, data: PlotDataTable, row: Int, kind: PlotGlyphKind, part: String, x: Float32, y: Float32, x2: Float32, y2: Float32, color: Color, interactive: Bool = True):
    var point = PlotPoint(x, y, data.key_at(row))
    point.set_extent(x2, y2)
    if layer.horizontal:
        point.x = y
        point.y = x
        point.x2 = y2
        point.y2 = x2
    point.glyph = kind
    point.part = part
    point.interactive = interactive
    point.text = data.string_field_at(layer.x_field, row)
    point.tooltip = String(point.text, ": ", layer.y_field, "=", data.string_field_at(layer.y_field, row))
    for column_index in range(len(data.columns)):
        var name = data.columns[column_index].name
        if name != layer.x_field and name != layer.y_field:
            point.tooltip += String(", ", name, "=", data.string_field_at(name, row))
    point.color = color
    point.has_color = True
    point.size = layer.size
    series.append(point)


def specialized_series(layer: PlotLayer, data: PlotDataTable, id: Int, width: Float32 = 560, height: Float32 = 416) -> PlotSeries:
    if _wave_b(layer.mark):
        return _b_series(layer,data,id,width,height)
    if _wave_c(layer.mark):
        try:
            return _c_layout(layer,data,id)
        except:
            return PlotSeries(id,layer.label,layer.color,layer.mark)
    var result = PlotSeries(id, layer.label, layer.color, layer.mark)
    result.line_width = layer.line_width
    result.marker_size = layer.size
    result.opacity = layer.opacity
    if not specialized_valid(layer, data):
        return result^
    var fields = _string_array(layer.series_fields_json)
    var ranges = _string_array(layer.range_fields_json)
    var errors = _string_array(layer.error_fields_json)
    var mark = layer.mark
    var n = data.row_count()
    var running: Float32 = 0.0
    var previous_right: Float32 = 0.0
    var low: Float32 = 0.0
    var high: Float32 = 0.0
    var ink = Color(0.15, 0.20, 0.28, 1.0)
    var negative = Color(0.9, 0.3, 0.3, 1.0)
    for i in range(n):
        var x = Float32(i)
        var value = data.float_field_at(layer.y_field, i)
        var second = data.float_field_at(layer.y2_field, i)
        var left = x - 0.4
        var right = x + 0.4
        if mark == PLOT_LOLLIPOP:
            _glyph(result, layer, data, i, PlotGlyphKind.SEGMENT, "stem", x, 0.0, x, value, layer.color)
            _glyph(result, layer, data, i, PlotGlyphKind.POINT, "head", x, value, x, value, layer.color)
        elif mark == PLOT_WATERFALL:
            var before = running
            running += value
            var total = layer.total_field != "" and data.float_field_at(layer.total_field, i) != 0.0
            var start = 0.0 if total else before
            var half: Float32 = 0.4 if total or layer.total_field == "" else 0.24
            left = x - half
            right = x + half
            if i > 0:
                _glyph(result, layer, data, i, PlotGlyphKind.SEGMENT, "connector", previous_right, before, left, before, ink, False)
            var color = Color(0.35, 0.4, 0.55, 1.0) if total else (negative if value < 0.0 else layer.color)
            _glyph(result, layer, data, i, PlotGlyphKind.RECT, "total" if total else "delta", left, start, right, running, color)
            previous_right = right
        elif mark == PLOT_CANDLESTICK:
            var color = layer.color if value >= second else negative
            _glyph(result, layer, data, i, PlotGlyphKind.SEGMENT, "wick", x, data.float_field_at(layer.stat_low_field, i), x, data.float_field_at(layer.stat_high_field, i), color)
            _glyph(result, layer, data, i, PlotGlyphKind.RECT, "body", left, second, right, value, color)
        elif mark == PLOT_BULLET:
            var start: Float32 = 0.0
            for j in range(len(ranges)):
                var end = data.float_field_at(ranges[j], i)
                var shade = 0.86 - 0.30 * Float32(j) / Float32(max(1, len(ranges)-1))
                _glyph(result, layer, data, i, PlotGlyphKind.RECT, String("range:", j), left, start, right, end, Color(shade, shade, shade, 1.0))
                start = end
            _glyph(result, layer, data, i, PlotGlyphKind.RECT, "measure", x-0.14, 0.0, x+0.14, value, layer.color)
            _glyph(result, layer, data, i, PlotGlyphKind.SEGMENT, "target", left, second, right, second, ink)
        elif mark == PLOT_GROUPED_BAR or mark == PLOT_STACKED_BAR:
            var pos: Float32 = 0.0
            var neg: Float32 = 0.0
            var denominator: Float32 = 0.0
            for field in fields:
                denominator += data.float_field_at(field, i)
            for j in range(len(fields)):
                var v = data.float_field_at(fields[j], i)
                if layer.percent:
                    v = v * 100.0 / denominator if denominator != 0.0 else 0.0
                var a = left
                var b = right
                var start: Float32 = 0.0
                if mark == PLOT_GROUPED_BAR:
                    a = left + 0.8 * Float32(j) / Float32(len(fields))
                    b = left + 0.8 * Float32(j+1) / Float32(len(fields))
                elif v >= 0.0:
                    start = pos
                    pos += v
                else:
                    start = neg
                    neg += v
                var end = start + v
                _glyph(result, layer, data, i, PlotGlyphKind.RECT, fields[j], a, start, b, end, _palette(j))
                if len(errors) > 0:
                    var error = data.float_field_at(errors[j], i)
                    var center = (a+b)*0.5
                    _glyph(result, layer, data, i, PlotGlyphKind.SEGMENT, String("error:", j), center, end-error, center, end+error, ink)
                    _glyph(result, layer, data, i, PlotGlyphKind.SEGMENT, String("error-cap:", j), center-0.04, end-error, center+0.04, end-error, ink)
                    _glyph(result, layer, data, i, PlotGlyphKind.SEGMENT, String("error-cap:", j), center-0.04, end+error, center+0.04, end+error, ink)
        elif mark == PLOT_GANTT:
            _glyph(result, layer, data, i, PlotGlyphKind.RECT, "span", min(value, second), Float32(n-1-i)-0.4, max(value, second), Float32(n-1-i)+0.4, layer.color)
        elif mark == PLOT_SPAN_CHART:
            _glyph(result, layer, data, i, PlotGlyphKind.RECT, "span", left, min(value, second), right, max(value, second), layer.color)
        elif mark == PLOT_POPULATION_PYRAMID:
            _glyph(result, layer, data, i, PlotGlyphKind.RECT, "left", -abs(value), Float32(n-1-i)-0.4, 0.0, Float32(n-1-i)+0.4, _palette(0))
            _glyph(result, layer, data, i, PlotGlyphKind.RECT, "right", 0.0, Float32(n-1-i)-0.4, abs(second), Float32(n-1-i)+0.4, _palette(1))
    var horizontal = layer.horizontal or mark == PLOT_GANTT or mark == PLOT_POPULATION_PYRAMID
    for point in result.points:
        var a = point.x if horizontal else point.y
        var b = point.x2 if horizontal else point.y2
        low = min(low, min(a,b))
        high = max(high, max(a,b))
    if high == low:
        high = low + 1.0
    if layer.percent:
        low = 0.0
        high = 100.0
    if mark == PLOT_POPULATION_PYRAMID:
        high = max(abs(low), abs(high))
        low = -high
    if mark == PLOT_LOLLIPOP:
        var padding = (high-low)*0.05
        low -= padding
        high += padding
    result.has_layout_domain = True
    result.layout_x_min = low if horizontal else -0.5
    result.layout_x_max = high if horizontal else Float32(n)-0.5
    result.layout_y_min = -0.5 if horizontal else low
    result.layout_y_max = Float32(n)-0.5 if horizontal else high
    return result^
