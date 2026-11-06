"""Wave B v1: upstream radial/KDE/swarm/stream layouts and Moxi grid contours.

Adapted from dataviz_mojo 3fd5a7e7c622d6130c99a290b88c4fee039deab2 (MIT).
See tests/fixtures/wave_a/DATAVIZ-LICENSE and docs/plot-specialized-wave-b.md.
Contours use fixed-diagonal piecewise-linear triangles, not a pinned upstream API.
"""
from std.collections import List
from std.math import cos, sin, pi, sqrt, exp, pow, isfinite, floor, ceil
from moxi.geometry import Point
from moxi.style import Color
from .plot_point import PlotPoint, PlotGlyphKind, PlotSelectionPolicy
from .plot_series import PlotSeries
from .plot_data import PlotDataTable, COLUMN_STRING, COLUMN_CATEGORY, COLUMN_BOOL
from .plot_spec_types import PlotLayer
from .plot_spec_json import _string_array
from .plot_marks import (PLOT_PIE, PLOT_DONUT, PLOT_RADAR, PLOT_GAUGE, PLOT_POLAR, PLOT_POLAR_BAR, PLOT_RADIALBAR, PLOT_BEESWARM, PLOT_VIOLIN, PLOT_RIDGELINE, PLOT_NIGHTINGALE, PLOT_STREAMGRAPH, PLOT_CONTOUR, PLOT_CONTOURF)

comptime _KDE_SAMPLES = 30
comptime _CONTOUR_BANDS = 8
comptime _ARC_STEPS = 128


def _wave_b(mark: Int) -> Bool:
    return mark == PLOT_PIE or mark == PLOT_DONUT or mark == PLOT_RADAR or mark == PLOT_GAUGE or mark == PLOT_POLAR or mark == PLOT_POLAR_BAR or mark == PLOT_RADIALBAR or mark == PLOT_BEESWARM or mark == PLOT_VIOLIN or mark == PLOT_RIDGELINE or mark == PLOT_NIGHTINGALE or mark == PLOT_STREAMGRAPH or mark == PLOT_CONTOUR or mark == PLOT_CONTOURF


def _grid(mark: Int) -> Bool:
    return mark == PLOT_CONTOUR or mark == PLOT_CONTOURF


def _distribution(mark: Int) -> Bool:
    return mark == PLOT_BEESWARM or mark == PLOT_VIOLIN or mark == PLOT_RIDGELINE


def _b_valid(layer: PlotLayer) -> Bool:
    var mark = layer.mark
    if not _wave_b(mark) or layer.horizontal or layer.percent or layer.range_fields_json != "[]" or layer.error_fields_json != "[]" or layer.total_field != "":
        return False
    if layer.x2_field != "" or layer.color_field != "" or layer.fill_field != "" or layer.stroke_field != "" or layer.size_field != "" or layer.opacity_field != "" or layer.text_field != "" or layer.median_field != "":
        return False
    if layer.series_fields_json != "[]" and mark != PLOT_RADAR and mark != PLOT_STREAMGRAPH:
        return False
    if mark == PLOT_STREAMGRAPH and len(_string_array(layer.series_fields_json)) == 0:
        return False
    if layer.y2_field != "" and not _grid(mark) and mark != PLOT_RADAR:
        return False
    if _grid(mark) and layer.y2_field == "":
        return False
    if (layer.stat_low_field != "" or layer.stat_high_field != "") and mark != PLOT_GAUGE:
        return False
    if mark == PLOT_GAUGE and (layer.stat_low_field == "") != (layer.stat_high_field == ""):
        return False
    return True


def _numeric(data: PlotDataTable, field: String) -> Bool:
    var kind = data.field_kind(field)
    if kind == 0 or kind == COLUMN_STRING or kind == COLUMN_CATEGORY or kind == COLUMN_BOOL:
        return False
    for i in range(data.row_count()):
        var v = data.float_field_at(field, i)
        if not data.field_is_valid(field, i) or not isfinite(v) or abs(v) > 1e15:
            return False
    return True


def _b_valid(layer: PlotLayer, data: PlotDataTable) -> Bool:
    if not _b_valid(layer) or data.row_count() == 0 or data.field_kind(layer.x_field) == 0:
        return False
    var fields = _string_array(layer.series_fields_json)
    var numeric: List[String] = [layer.y_field]
    for f in fields:
        numeric.append(f)
    if layer.y2_field != "":
        numeric.append(layer.y2_field)
    if layer.stat_low_field != "":
        numeric.append(layer.stat_low_field)
        numeric.append(layer.stat_high_field)
    if data.field_kind(layer.x_field) != COLUMN_STRING and data.field_kind(layer.x_field) != COLUMN_CATEGORY and data.field_kind(layer.x_field) != COLUMN_BOOL:
        numeric.append(layer.x_field)
    for f in numeric:
        if not _numeric(data, f):
            return False
    var maximum: Float32 = 0.0
    for i in range(data.row_count()):
        if not data.field_is_valid(layer.x_field, i):
            return False
        var v = data.float_field_at(layer.y_field, i)
        maximum = max(maximum, v)
        if not _distribution(layer.mark) and not _grid(layer.mark) and layer.mark != PLOT_GAUGE and v < 0.0:
            return False
        if layer.mark == PLOT_RADAR or layer.mark == PLOT_STREAMGRAPH:
            for f in fields:
                if data.float_field_at(f, i) < 0.0:
                    return False
            if layer.mark == PLOT_RADAR and layer.y2_field != "" and data.float_field_at(layer.y2_field,i) < 0.0:
                return False
    var mark = layer.mark
    if (mark == PLOT_PIE or mark == PLOT_DONUT or mark == PLOT_POLAR_BAR or mark == PLOT_NIGHTINGALE or mark == PLOT_RADIALBAR or mark == PLOT_POLAR) and maximum <= 0.0:
        return False
    if mark == PLOT_RADAR and (data.row_count() < 3 or data.row_count() > 4095) or mark == PLOT_STREAMGRAPH and data.row_count() < 2:
        return False
    if mark == PLOT_GAUGE:
        if data.row_count() != 1:
            return False
        if layer.stat_low_field != "" and data.float_field_at(layer.stat_low_field,0) >= data.float_field_at(layer.stat_high_field,0):
            return False
    if _grid(mark):
        var xs = _unique(data, layer.x_field)
        var ys = _unique(data, layer.y_field)
        if len(xs) < 2 or len(ys) < 2 or len(xs)*len(ys) != data.row_count():
            return False
        for i in range(data.row_count()):
            for j in range(i):
                if data.float_field_at(layer.x_field,i) == data.float_field_at(layer.x_field,j) and data.float_field_at(layer.y_field,i) == data.float_field_at(layer.y_field,j):
                    return False
    return True


def _unique(data: PlotDataTable, field: String) -> List[Float32]:
    var result = List[Float32]()
    for i in range(data.row_count()):
        var v = data.float_field_at(field,i)
        var found = False
        for x in result:
            if x == v:
                found = True
        if not found:
            result.append(v)
    # Stable insertion sort keeps the grid contract independent of source row order.
    for i in range(1,len(result)):
        var j = i
        while j > 0 and result[j] < result[j-1]:
            var tmp = result[j]
            result[j] = result[j-1]
            result[j-1] = tmp
            j -= 1
    return result^


def _color(i: Int) -> Color:
    if i%4 == 0:
        return Color(.25,.75,1,1)
    if i%4 == 1:
        return Color(.95,.45,.30,1)
    if i%4 == 2:
        return Color(.4,.85,.55,1)
    return Color(.65,.45,.95,1)


def _emit(mut result: PlotSeries, layer: PlotLayer, data: PlotDataTable, ids: List[Int], kind: PlotGlyphKind, part: String, vertices: List[Point], color: Color, interactive: Bool = True):
    if len(vertices) == 0:
        return
    var p = PlotPoint(vertices[0].x,vertices[0].y,data.key_at(ids[0]))
    p.selection_policy = PlotSelectionPolicy.CONTRIBUTORS
    p.glyph = kind
    p.interactive = interactive
    p.part = part
    p.set_extent(vertices[len(vertices)-1].x,vertices[len(vertices)-1].y)
    if kind.value == PlotGlyphKind.POLYGON.value:
        p.vertices = vertices.copy()
        for v in vertices:
            p.x = min(p.x,v.x)
            p.y = min(p.y,v.y)
            p.x2 = max(p.x2,v.x)
            p.y2 = max(p.y2,v.y)
    p.color = color
    p.has_color = True
    p.size = layer.size
    p.text = data.string_field_at(layer.x_field,ids[0])
    p.tooltip = String(part, "; representative key=", p.row_key, "; source keys=")
    for i in ids:
        p.source_keys.append(data.key_at(i))
        p.tooltip += String(data.key_at(i), " ")
    result.append(p)


def _polar(a: Float64, r: Float64) -> Point:
    return Point(Float32(r*cos(a)),Float32(r*sin(a)))


def _sector(mut result: PlotSeries, layer: PlotLayer, data: PlotDataTable, i: Int, part: String, a: Float64, b: Float64, outer: Float64, inner: Float64, color: Color, interactive: Bool = True):
    if b <= a or outer <= inner:
        return
    var steps = max(1,Int(ceil((b-a)/(2*pi)*_ARC_STEPS)))
    var points = List[Point]()
    for j in range(steps+1):
        points.append(_polar(a+(b-a)*Float64(j)/Float64(steps),outer))
    if inner > 0.0:
        for j in range(steps,-1,-1):
            points.append(_polar(a+(b-a)*Float64(j)/Float64(steps),inner))
    else:
        points.append(Point(0,0))
    _emit(result,layer,data,[i],PlotGlyphKind.POLYGON,part,points,color,interactive)


def _b_series(layer: PlotLayer, data: PlotDataTable, id: Int, width: Float32, height: Float32) -> PlotSeries:
    var result = PlotSeries(id,layer.label,layer.color,layer.mark)
    result.line_width = layer.line_width
    result.marker_size = layer.size
    result.opacity = layer.opacity
    if not _b_valid(layer,data):
        return result^
    var mark = layer.mark
    var n = data.row_count()
    var values = List[Float64]()
    var lo = Float64(data.float_field_at(layer.y_field,0))
    var hi = lo
    var total = Float64(0.0)
    for i in range(n):
        var v = Float64(data.float_field_at(layer.y_field,i))
        values.append(v)
        lo = min(lo,v)
        hi = max(hi,v)
        total += v
    var pad = (hi-lo)*.05 if hi>lo else 1.0
    result.has_layout_domain = True
    result.layout_x_min = -.5
    result.layout_x_max = Float32(n)-.5
    result.layout_y_min = Float32(lo-pad)
    result.layout_y_max = Float32(hi+pad)
    if not _distribution(mark) and not _grid(mark) and mark != PLOT_STREAMGRAPH:
        var aspect = max(Float32(1),width)/max(Float32(1),height)
        result.layout_x_min = -max(Float32(1),aspect)/.9
        result.layout_x_max = -result.layout_x_min
        result.layout_y_min = -max(Float32(1),1/aspect)/.9
        result.layout_y_max = -result.layout_y_min
    if mark == PLOT_PIE or mark == PLOT_DONUT or mark == PLOT_POLAR_BAR or mark == PLOT_NIGHTINGALE or mark == PLOT_RADIALBAR:
        var angle = pi/2
        for i in range(n):
            var v = values[i]
            if mark == PLOT_PIE or mark == PLOT_DONUT:
                var span = 2*pi*v/total
                _sector(result,layer,data,i,"wedge",angle-span,angle,1,.5 if mark == PLOT_DONUT else 0.0,_color(i))
                angle -= span
            elif mark == PLOT_RADIALBAR:
                var outer = 1-Float64(i)/Float64(n)-.125/Float64(n)
                var inner = 1-Float64(i+1)/Float64(n)+.125/Float64(n)
                _sector(result,layer,data,i,"track",pi/2-2*pi,pi/2,outer,inner,Color(.9,.9,.9,1),False)
                _sector(result,layer,data,i,"arc",pi/2-2*pi*v/hi,pi/2,outer,inner,_color(i))
            else:
                var span = 2*pi/Float64(n)
                var gap = span*.1 if mark == PLOT_POLAR_BAR else 0.0
                _sector(result,layer,data,i,"wedge",angle-span+gap,angle-gap,v/hi,0,_color(i))
                angle -= span
    elif mark == PLOT_GAUGE:
        var minimum = Float64(data.float_field_at(layer.stat_low_field,0)) if layer.stat_low_field != "" else 0.0
        var maximum = Float64(data.float_field_at(layer.stat_high_field,0)) if layer.stat_high_field != "" else 100.0
        var breaks: List[Float64] = [0,.2,.8,1]
        for j in range(3):
            _sector(result,layer,data,0,String("band:",j),-3*pi/4-3*pi/2*breaks[j+1],-3*pi/4-3*pi/2*breaks[j],1,.7,_color(j),False)
        var a = -3*pi/4-3*pi/2*max(Float64(0),min(Float64(1),(values[0]-minimum)/(maximum-minimum)))
        _emit(result,layer,data,[0],PlotGlyphKind.SEGMENT,"needle",[Point(0,0),_polar(a,.9)],Color(.15,.20,.28,1))
        _emit(result,layer,data,[0],PlotGlyphKind.POINT,"pivot",[Point(0,0)],Color(.15,.20,.28,1))
    elif mark == PLOT_POLAR:
        var points = List[Point]()
        for i in range(n):
            points.append(_polar(-Float64(data.float_field_at(layer.x_field,i)),values[i]/hi))
            if i > 0:
                _emit(result,layer,data,[i-1,i],PlotGlyphKind.SEGMENT,"line",[points[i-1],points[i]],layer.color)
        for i in range(n):
            _emit(result,layer,data,[i],PlotGlyphKind.POINT,"sample",[points[i]],layer.color)
    elif mark == PLOT_RADAR:
        var fields = _string_array(layer.series_fields_json)
        if len(fields) == 0:
            fields.append(layer.y_field)
        for j in range(len(fields)):
            var points = List[Point]()
            var ids = List[Int]()
            for i in range(n):
                var maximum = Float64(0)
                if layer.y2_field != "":
                    maximum = Float64(data.float_field_at(layer.y2_field,i))
                else:
                    for f in fields:
                        maximum = max(maximum,Float64(data.float_field_at(f,i)))
                var frac = Float64(data.float_field_at(fields[j],i))/maximum if maximum > 0 else 0.0
                points.append(_polar(pi/2-2*pi*Float64(i)/Float64(n),frac))
                ids.append(i)
            var color = _color(j)
            var fill = color
            fill.alpha = .25
            _emit(result,layer,data,ids,PlotGlyphKind.POLYGON,String("series:",j),points,fill)
            for i in range(n):
                _emit(result,layer,data,[i,(i+1)%n],PlotGlyphKind.SEGMENT,String("edge:",j),[points[i],points[(i+1)%n]],color)
            for i in range(n):
                _emit(result,layer,data,[i],PlotGlyphKind.POINT,String("indicator:",j),[points[i]],color)
    elif _distribution(mark):
        _distributions(result,layer,data,width,height,lo-pad,hi+pad)
    elif mark == PLOT_STREAMGRAPH:
        _stream(result,layer,data)
    elif _grid(mark):
        _contour(result,layer,data)
    return result^


def _distributions(mut result: PlotSeries, layer: PlotLayer, data: PlotDataTable, width: Float32, height: Float32, low: Float64, high: Float64):
    var groups = List[String]()
    for i in range(data.row_count()):
        var category = data.string_field_at(layer.x_field,i)
        var found = False
        for g in groups:
            if g == category:
                found = True
        if not found:
            groups.append(category)
    result.layout_x_max = Float32(len(groups))-.5
    for g in range(len(groups)):
        var ids = List[Int]()
        var values = List[Float64]()
        for i in range(data.row_count()):
            if data.string_field_at(layer.x_field,i) == groups[g]:
                ids.append(i)
                values.append(Float64(data.float_field_at(layer.y_field,i)))
        var n = len(ids)
        if layer.mark == PLOT_BEESWARM:
            var pixels = List[Int]()
            var order = List[Int]()
            for i in range(n):
                pixels.append(Int(floor((high-values[i])/(high-low)*Float64(height)+.5)))
                order.append(i)
            for i in range(1,n):
                var j = i
                while j > 0 and pixels[order[j]] < pixels[order[j-1]]:
                    var tmp = order[j]
                    order[j] = order[j-1]
                    order[j-1] = tmp
                    j -= 1
            var spacing = max(1,Int(layer.size))
            var start = 0
            for end in range(1,n+1):
                if end == n or pixels[order[end]]-pixels[order[end-1]] > spacing:
                    for k in range(end-start):
                        var j = order[start+k]
                        var offset = 0 if k == 0 else ((k+1)//2)*spacing*(1 if k%2 != 0 else -1)
                        var x = Float32(g)+Float32(offset)*Float32(len(groups))/max(Float32(1),width)
                        _emit(result,layer,data,[ids[j]],PlotGlyphKind.POINT,"sample",[Point(x,Float32(values[j]))],layer.color)
                    start = end
        else:
            var mean = Float64(0)
            var lo = values[0]
            var hi = lo
            for v in values:
                mean += v
                lo = min(lo,v)
                hi = max(hi,v)
            mean /= Float64(n)
            var variance = Float64(0)
            for v in values:
                variance += (v-mean)**2
            var std = sqrt(variance/Float64(n))
            var bandwidth = .9*std*pow(Float64(n),Float64(-.2)) if std > 0 else 1.0
            var samples = List[Float64]()
            var density = List[Float64]()
            var peak = Float64(0)
            for j in range(_KDE_SAMPLES):
                var x = lo+(hi-lo)*Float64(j)/Float64(_KDE_SAMPLES-1)
                samples.append(x)
                var d = Float64(0)
                for v in values:
                    var u = (x-v)/bandwidth
                    d += exp(-.5*u*u)/sqrt(2*pi)
                d /= Float64(n)*bandwidth
                density.append(d)
                peak = max(peak,d)
            var vertices = List[Point]()
            if layer.mark == PLOT_VIOLIN:
                for j in range(_KDE_SAMPLES):
                    vertices.append(Point(Float32(Float64(g)+.32*density[j]/peak),Float32(samples[j])))
                for j in range(_KDE_SAMPLES-1,-1,-1):
                    vertices.append(Point(Float32(Float64(g)-.32*density[j]/peak),Float32(samples[j])))
            else:
                var base = Float32(len(groups)-1-g)
                vertices.append(Point(Float32(samples[0]),base))
                for j in range(_KDE_SAMPLES):
                    vertices.append(Point(Float32(samples[j]),base+Float32(1.3*density[j]/peak)))
                vertices.append(Point(Float32(samples[_KDE_SAMPLES-1]),base))
            _emit(result,layer,data,ids,PlotGlyphKind.POLYGON,"density",vertices,layer.color)
    if layer.mark == PLOT_RIDGELINE:
        result.layout_x_min = Float32(low)
        result.layout_x_max = Float32(high)
        result.layout_y_min = 0
        result.layout_y_max = Float32(len(groups))


def _stream(mut result: PlotSeries, layer: PlotLayer, data: PlotDataTable):
    var fields = _string_array(layer.series_fields_json)
    var n = data.row_count()
    var running = List[Float64]()
    var maximum = Float64(0)
    for i in range(n):
        var total = Float64(0)
        for f in fields:
            total += Float64(data.float_field_at(f,i))
        maximum = max(maximum,total)
        running.append(-total/2)
    var bound = maximum*.55 if maximum > 0 else 1.0
    result.layout_y_min = -Float32(bound)
    result.layout_y_max = Float32(bound)
    for j in range(len(fields)):
        var top = List[Float64]()
        for i in range(n):
            top.append(running[i]+Float64(data.float_field_at(fields[j],i)))
        for i in range(n-1):
            var vertices: List[Point] = [Point(Float32(i),Float32(top[i])),Point(Float32(i+1),Float32(top[i+1])),Point(Float32(i+1),Float32(running[i+1])),Point(Float32(i),Float32(running[i]))]
            _emit(result,layer,data,[i,i+1],PlotGlyphKind.POLYGON,fields[j],vertices,_color(j))
        running = top^


struct _ScalarVertex(ImplicitlyCopyable):
    var x: Float64
    var y: Float64
    var z: Float64
    def __init__(out self, x: Float64, y: Float64, z: Float64):
        self.x = x
        self.y = y
        self.z = z


def _interpolate(a: _ScalarVertex, b: _ScalarVertex, level: Float64) -> _ScalarVertex:
    var t = (level-a.z)/(b.z-a.z)
    return _ScalarVertex(a.x+t*(b.x-a.x),a.y+t*(b.y-a.y),level)


def _clip(vertices: List[_ScalarVertex], level: Float64, above: Bool) -> List[_ScalarVertex]:
    var result = List[_ScalarVertex]()
    for i in range(len(vertices)):
        var a = vertices[i]
        var b = vertices[(i+1)%len(vertices)]
        var ai = a.z >= level if above else a.z <= level
        var bi = b.z >= level if above else b.z <= level
        if ai:
            result.append(a)
        if ai != bi:
            result.append(_interpolate(a,b,level))
    return result^


def _contour(mut result: PlotSeries, layer: PlotLayer, data: PlotDataTable):
    var xs = _unique(data,layer.x_field)
    var ys = _unique(data,layer.y_field)
    result.layout_x_min = xs[0]
    result.layout_x_max = xs[len(xs)-1]
    result.layout_y_min = ys[0]
    result.layout_y_max = ys[len(ys)-1]
    var grid = List[Int]()
    var lo = Float64(data.float_field_at(layer.y2_field,0))
    var hi = lo
    for y in ys:
        for x in xs:
            for i in range(data.row_count()):
                if x == data.float_field_at(layer.x_field,i) and y == data.float_field_at(layer.y_field,i):
                    grid.append(i)
                    var z = Float64(data.float_field_at(layer.y2_field,i))
                    lo = min(lo,z)
                    hi = max(hi,z)
    if hi == lo:
        return
    for gy in range(len(ys)-1):
        for gx in range(len(xs)-1):
            var corners: List[Int] = [grid[gy*len(xs)+gx],grid[gy*len(xs)+gx+1],grid[(gy+1)*len(xs)+gx+1],grid[(gy+1)*len(xs)+gx]]
            for t in range(2):
                var ids: List[Int] = [corners[0],corners[t+1],corners[t+2]]
                var vertices = List[_ScalarVertex]()
                for i in ids:
                    vertices.append(_ScalarVertex(Float64(data.float_field_at(layer.x_field,i)),Float64(data.float_field_at(layer.y_field,i)),Float64(data.float_field_at(layer.y2_field,i))))
                if layer.mark == PLOT_CONTOUR:
                    for k in range(1,_CONTOUR_BANDS):
                        var level = lo+(hi-lo)*Float64(k)/Float64(_CONTOUR_BANDS)
                        var hits = List[Point]()
                        for j in range(3):
                            var a = vertices[j]
                            var b = vertices[(j+1)%3]
                            if (a.z < level) != (b.z < level):
                                var p = _interpolate(a,b,level)
                                hits.append(Point(Float32(p.x),Float32(p.y)))
                        if len(hits) == 2 and (hits[0].x != hits[1].x or hits[0].y != hits[1].y):
                            _emit(result,layer,data,ids,PlotGlyphKind.SEGMENT,String("level:",k),hits,_color(k-1))
                else:
                    for k in range(_CONTOUR_BANDS):
                        var lower = lo+(hi-lo)*Float64(k)/Float64(_CONTOUR_BANDS)
                        var upper = lo+(hi-lo)*Float64(k+1)/Float64(_CONTOUR_BANDS)
                        if k < _CONTOUR_BANDS-1 and vertices[0].z == upper and vertices[1].z == upper and vertices[2].z == upper:
                            continue
                        var clipped = _clip(_clip(vertices,lower,True),upper,False)
                        var points = List[Point]()
                        for v in clipped:
                            points.append(Point(Float32(v.x),Float32(v.y)))
                        var area = Float64(0)
                        for i in range(len(clipped)):
                            var a = clipped[i]
                            var b = clipped[(i+1)%len(clipped)]
                            area += a.x*b.y-b.x*a.y
                        if len(points) >= 3 and abs(area) > 0:
                            _emit(result,layer,data,ids,PlotGlyphKind.POLYGON,String("band:",k),points,_color(k))
