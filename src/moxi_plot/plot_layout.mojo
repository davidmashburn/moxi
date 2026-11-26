"""Specialized Wave A layout v1: source-row-preserving data-space glyphs.

Adapted from dataviz_mojo v0.8.0, commit 3fd5a7e7c622d6130c99a290b88c4fee039deab2,
MIT Copyright (c) 2026 Randy Zwitch. Full notice: tests/fixtures/wave_a/DATAVIZ-LICENSE.
Wide named columns correspond to upstream series/range matrices, in declared order.
"""
from .plot_layout_c import _wave_c, _c_validate, _c_layout
from std.collections import Dict, List
from .plot_wave_b import _wave_b, _b_valid, _b_series, _emit
from std.math import cos, isfinite, pi, sin
from moxi.geometry import Point
from moxi.style import Color
from .plot_data import PlotDataTable, COLUMN_STRING, COLUMN_CATEGORY, COLUMN_BOOL, COLUMN_FLOAT64, COLUMN_INT64, COLUMN_TIMESTAMP, COLUMN_DURATION
from .plot_point import PlotPoint, PlotGlyphKind
from .plot_series import PlotSeries
from .plot_spec_types import PlotLayer, PlotLayoutVersion
from .plot_spec_json import _string_array
from .plot_marks import (PLOT_ARC_DIAGRAM, PLOT_BUMP, PLOT_PARALLEL, PLOT_FUNNEL, PLOT_LOLLIPOP, PLOT_WATERFALL, PLOT_CANDLESTICK, PLOT_BULLET, PLOT_GROUPED_BAR, PLOT_STACKED_BAR, PLOT_GANTT, PLOT_SPAN_CHART, PLOT_POPULATION_PYRAMID)




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
    if (mark != PLOT_ARC_DIAGRAM and layer.x2_field != "") or layer.color_field != "" or layer.fill_field != "" or layer.stroke_field != "" or layer.size_field != "" or layer.opacity_field != "" or layer.text_field != "" or layer.median_field != "":
        return False
    if mark == PLOT_FUNNEL and (layer.y2_field != "" or layer.stat_low_field != "" or layer.stat_high_field != ""):
        return False
    if (mark == PLOT_PARALLEL or mark == PLOT_BUMP) and (layer.y2_field != "" or layer.stat_low_field != "" or layer.stat_high_field != ""):
        return False
    if mark == PLOT_ARC_DIAGRAM and (layer.x2_field == "" or layer.y2_field != "" or layer.stat_low_field != "" or layer.stat_high_field != ""):
        return False
    if not (mark == PLOT_ARC_DIAGRAM or mark == PLOT_BUMP or mark == PLOT_PARALLEL or mark == PLOT_FUNNEL or mark == PLOT_LOLLIPOP or mark == PLOT_WATERFALL or mark == PLOT_CANDLESTICK or mark == PLOT_BULLET or mark == PLOT_GROUPED_BAR or mark == PLOT_STACKED_BAR or mark == PLOT_GANTT or mark == PLOT_SPAN_CHART or mark == PLOT_POPULATION_PYRAMID):
        return False
    if not _fields_valid(layer.series_fields_json) or not _fields_valid(layer.range_fields_json) or not _fields_valid(layer.error_fields_json):
        return False
    var series = _string_array(layer.series_fields_json)
    var ranges = _string_array(layer.range_fields_json)
    var errors = _string_array(layer.error_fields_json)
    if mark == PLOT_PARALLEL or mark == PLOT_BUMP:
        for name in series:
            if name == layer.y_field: return False
    if len(series) > 0 and mark != PLOT_BUMP and mark != PLOT_PARALLEL and mark != PLOT_GROUPED_BAR and mark != PLOT_STACKED_BAR:
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


def _stage_order[dtype: DType](values: List[Scalar[dtype]]) -> List[Int]:
    var order = List[Int](capacity=len(values))
    for row in range(len(values)):
        order.append(row)
        var rank = row
        while rank > 0 and values[order[rank - 1]] < values[row]:
            order[rank] = order[rank - 1]
            rank -= 1
        order[rank] = row
    return order^


def _stage_value(data: PlotDataTable, field: String, row: Int) -> Float64:
    var index = data.column_index(field)
    if index >= 0:
        var kind = data.columns[index].kind
        if kind == COLUMN_FLOAT64:
            return data.columns[index].float64_values[row]
        if kind == COLUMN_INT64 or kind == COLUMN_TIMESTAMP or kind == COLUMN_DURATION:
            return Float64(data.int_field_at(field, row))
    return Float64(data.float_field_at(field, row))


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
    if layer.mark == PLOT_ARC_DIAGRAM:
        for field in [layer.x_field, layer.x2_field]:
            if data.field_kind(field) != COLUMN_STRING and data.field_kind(field) != COLUMN_CATEGORY: return False
            for row in range(data.row_count()):
                if not data.field_is_valid(field,row): return False
        for row in range(data.row_count()):
            if _stage_value(data,layer.y_field,row)<0: return False
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
            if not data.field_is_valid(name, i):
                return False
            if (layer.mark == PLOT_ARC_DIAGRAM or layer.mark == PLOT_BUMP or layer.mark == PLOT_PARALLEL) and not isfinite(_stage_value(data, name, i)):
                return False
            if layer.mark != PLOT_ARC_DIAGRAM and layer.mark != PLOT_BUMP and layer.mark != PLOT_PARALLEL and layer.mark != PLOT_FUNNEL and not isfinite(data.float_field_at(name, i)):
                return False
    var positive_stage = False
    for i in range(data.row_count()):
        if layer.mark == PLOT_FUNNEL:
            var value = _stage_value(data, layer.y_field, i)
            if not isfinite(value) or value < 0:
                return False
            positive_stage = positive_stage or value > 0
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
    return layer.mark != PLOT_FUNNEL or positive_stage


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
    if mark == PLOT_ARC_DIAGRAM:
        result.has_layout_domain = True
        # Fit a full semicircle in both pixel dimensions. Keep the default
        # full-width layout when height permits, otherwise center a shorter span.
        # Collapsed viewports retain keyed edges as degenerate, finite paths.
        # PlotView can then preserve selection and rebuild them on enlargement.
        var drawable = width > 0 and height > 0
        var span = min(Float32(1), 2*height/width) if drawable else Float32(0)
        var offset = (1-span)*0.5
        var nodes = List[String]()
        var indices = Dict[String,Int]()
        for field in [layer.x_field, layer.x2_field]:
            for row in range(n):
                var name = data.string_field_at(field,row)
                if name not in indices:
                    indices[name] = len(nodes)
                    nodes.append(name)
        var largest: Float64 = 0
        for row in range(n):
            largest = max(largest,_stage_value(data,layer.y_field,row))
        for row in range(n):
            var src = indices.get(data.string_field_at(layer.x_field,row),-1)
            var dst = indices.get(data.string_field_at(layer.x2_field,row),-1)
            if src == dst: continue
            var left = offset + span*Float32(min(src,dst))/Float32(len(nodes)-1)
            var right = offset + span*Float32(max(src,dst))/Float32(len(nodes)-1)
            var radius = (right-left)*0.5
            var rise = radius*width/height if drawable else Float32(0)
            _glyph(result,layer,data,row,PlotGlyphKind.POLYLINE,"edge",left,0,right,0,_palette(src))
            ref edge = result.points[len(result.points)-1]
            var frac = Float32(_stage_value(data,layer.y_field,row)/largest) if largest>0 else Float32(0)
            edge.stroke_width = layer.line_width*(1+2*frac)
            edge.text = String(nodes[src], " → ", nodes[dst])
            for i in range(49):
                var angle = Float32(pi)*Float32(i)/48
                edge.vertices.append(Point(left+radius*(1-cos(angle)),rise*sin(angle)))
        for i in range(len(nodes)):
            var x = offset + span*Float32(i)/Float32(len(nodes)-1) if len(nodes)>1 else Float32(0.5)
            _glyph(result,layer,data,0,PlotGlyphKind.POINT,"arc-node",x,0,x,0,_palette(i),False)
            result.points[len(result.points)-1].text = nodes[i]
            result.points[len(result.points)-1].size = 8
        return result^
    if mark == PLOT_PARALLEL or mark == PLOT_BUMP:
        result.has_layout_domain = True
        var dimensions: List[String] = [layer.y_field]
        for name in fields: dimensions.append(name)
        var paths = List[List[Point]]()
        for _ in range(n): paths.append(List[Point]())
        var bump = mark == PLOT_BUMP
        if bump:
            for rank in range(n):
                var level = 1 - Float32(rank)/Float32(n-1) if n>1 else Float32(0.5)
                _glyph(result, layer, data, 0, PlotGlyphKind.SEGMENT, "rank", 0, level, 1, level, Color(0.3,0.35,0.4,1), False)
                result.points[len(result.points)-1].text = String(rank+1)
        for dim in range(len(dimensions)):
            var field = dimensions[dim]
            var kind = data.field_kind(field)
            var integral = kind == COLUMN_INT64 or kind == COLUMN_TIMESTAMP or kind == COLUMN_DURATION
            var values = List[Float64](capacity=n)
            for row in range(n):
                if integral:
                    # Center before converting to Float64 to retain adjacent large counts.
                    var value = Int128(data.int_field_at(field,row))
                    values.append(Float64(value - Int128(data.int_field_at(field,0))))
                else:
                    values.append(_stage_value(data,field,row))
            var low = values[0]
            var high = low
            for value in values:
                low = min(low,value)
                high = max(high,value)
            var x = Float32(dim) / Float32(len(dimensions)-1) if len(dimensions)>1 else Float32(0.5)
            var ranks = List[Int](length=n, fill=0)
            if bump:
                x = (Float32(dim)+0.5)/Float32(len(dimensions))
                var order: List[Int]
                if integral:
                    var measures = List[Int64]()
                    for row in range(n): measures.append(data.int_field_at(field,row))
                    order = _stage_order(measures)
                else:
                    order = _stage_order(values)
                for rank in range(n): ranks[order[rank]] = rank
            _glyph(result, layer, data, 0, PlotGlyphKind.SEGMENT, "stage" if bump else "dimension", x, 0, x, Float32(0 if bump else 1), Color(0.15,0.20,0.28,1), False)
            result.points[len(result.points)-1].text = field
            for row in range(n):
                var y = Float32(0.5)
                if bump:
                    if n > 1: y = 1 - Float32(ranks[row])/Float32(n-1)
                elif high != low:
                    if isfinite(high-low):
                        y = Float32((values[row]-low)/(high-low))
                    else:
                        y = Float32((values[row]*0.5-low*0.5)/(high*0.5-low*0.5))
                paths[row].append(Point(x,y))
        for row in range(n):
            var start = paths[row][0]
            var end = paths[row][len(dimensions)-1]
            var kind = PlotGlyphKind.POLYLINE if len(dimensions)>1 else PlotGlyphKind.POINT
            _glyph(result,layer,data,row,kind,"record",start.x,start.y,end.x,end.y,_palette(row))
            result.points[len(result.points)-1].vertices = paths[row].copy()
            result.points[len(result.points)-1].stroke_width = layer.line_width
        return result^
    if mark == PLOT_FUNNEL:
        var values = List[Float64](capacity=n)
        for row in range(n):
            values.append(_stage_value(data, layer.y_field, row))
        var kind = data.field_kind(layer.y_field)
        var order: List[Int]
        if kind == COLUMN_INT64 or kind == COLUMN_TIMESTAMP or kind == COLUMN_DURATION:
            var index = data.column_index(layer.y_field)
            order = _stage_order(data.columns[index].int_values)
        else:
            order = _stage_order(values)
        var largest = values[order[0]]
        result.has_layout_domain = True
        result.layout_x_min = -1
        result.layout_x_max = 1
        result.layout_y_min = 0
        result.layout_y_max = Float32(n)
        for rank in range(n):
            var row = order[rank]
            var upper = Float32(values[row] / largest)
            var lower = Float32(values[order[min(rank + 1, n - 1)]] / largest)
            var top = Float32(n - rank)
            var bottom = top - 1
            var vertices: List[Point] = [Point(-upper, top), Point(upper, top),
                                         Point(lower, bottom), Point(-lower, bottom)]
            _emit(result, layer, data, [row], PlotGlyphKind.POLYGON, "stage",
                  vertices, _palette(rank), upper > 0, data.string_field_at(layer.x_field, row))
        return result^
    var reverse_categories = mark == PLOT_GANTT or mark == PLOT_POPULATION_PYRAMID
    result.categories_on_y = layer.horizontal or reverse_categories
    for i in range(n):
        var row = n - 1 - i if reverse_categories else i
        result.category_labels.append(data.string_field_at(layer.x_field, row))
    if mark == PLOT_POPULATION_PYRAMID:
        result.legend_labels.append("Left")
        result.legend_labels.append("Right")
    else:
        result.legend_labels = fields.copy()
    for i in range(len(result.legend_labels)):
        result.legend_colors.append(_palette(i))
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
