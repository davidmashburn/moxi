"""Wave C data-space layouts; dataviz_mojo v0.8.0 MIT algorithm adaptations.

Reference and limits: docs/plot-specialized-wave-c.md. Tricontour has no
implementation in the pinned reference; its explicit-mesh marching triangles
are independently implemented here. All layout work is native Mojo.
"""
from std.collections import List
from std.math import sin, cos, sqrt, isfinite
from moxi.style import Color
from .plot_data import PlotDataTable, COLUMN_STRING, COLUMN_CATEGORY, COLUMN_BOOL
from .plot_point import PlotPoint, PlotGlyphKind
from .plot_series import PlotSeries
from .plot_spec_types import PlotLayer
from .plot_spec_json import _string_array, _read_number
from .plot_marks import *


def _wave_c(mark: Int) -> Bool:
    return mark == PLOT_TREEMAP or mark == PLOT_SUNBURST or mark == PLOT_TREE or mark == PLOT_SANKEY or mark == PLOT_CHORD or mark == PLOT_GRAPH or mark == PLOT_CALENDAR_HEATMAP or mark == PLOT_CORRPLOT or mark == PLOT_PUNCHCARD or mark == PLOT_MARIMEKKO or mark == PLOT_BARBS or mark == PLOT_TRICONTOUR


def _c_palette(i: Int) -> Color:
    if i % 4 == 1: return Color(0.95,0.45,0.30,1)
    if i % 4 == 2: return Color(0.4,0.85,0.55,1)
    if i % 4 == 3: return Color(0.65,0.45,0.95,1)
    return Color(0.25,0.75,1,1)


def _c_numbers(value: String, triangles: Bool = False) raises -> List[Float32]:
    # Strict grammar, including integer-only triangle indices. No silent defaults.
    var result = List[Float32]()
    var i = 0
    var depth = 0
    var count = 0
    var want_value = True
    while i < value.count_codepoints():
        var c = value[codepoint=i:i+1]
        if c == " " or c == "\n": i += 1; continue
        if c == "[":
            if (depth == 0 and i != 0) or depth >= (2 if triangles else 1) or not want_value: raise Error("invalid numeric array")
            depth += 1
            count = 0
            want_value = True
            i += 1
        elif c == "]":
            if depth == 0 or (want_value and count != 0) or (triangles and depth == 2 and count != 3): raise Error("invalid numeric array")
            depth -= 1
            want_value = False
            i += 1
            if depth == 0 and i != value.count_codepoints(): raise Error("trailing array content")
        elif c == ",":
            if want_value or depth == 0: raise Error("invalid array comma")
            want_value = True
            i += 1
        else:
            if not want_value or depth != (2 if triangles else 1): raise Error("invalid array value")
            var number = _read_number(value,i)
            if not number.ok or not isfinite(number.value): raise Error("invalid finite number")
            if triangles and (number.value < 0 or value[codepoint=i:number.next] != String(number.integer)): raise Error("triangle index must be integer")
            result.append(number.value)
            i = number.next
            count += 1
            want_value = False
    if depth != 0 or want_value: raise Error("unclosed array")
    return result^


def _c_validate(layer: PlotLayer) raises:
    if layer.horizontal or layer.percent or layer.range_fields_json != "[]" or layer.error_fields_json != "[]" or layer.total_field != "": raise Error("unused Wave A options")
    if layer.x2_field != "" or layer.color_field != "" or layer.fill_field != "" or layer.stroke_field != "" or layer.size_field != "" or layer.opacity_field != "" or layer.text_field != "" or layer.median_field != "" or layer.stat_low_field != "" or layer.stat_high_field != "": raise Error("unsupported Wave C visual channel")
    var fields = _string_array(layer.series_fields_json)
    if len(fields) == 0 and layer.series_fields_json != "[]": raise Error("invalid fields")
    for i in range(len(fields)):
        if fields[i] == "": raise Error("empty field")
        for j in range(i):
            if fields[i] == fields[j]: raise Error("duplicate field")
    var m = layer.mark
    if (m == PLOT_CORRPLOT or m == PLOT_MARIMEKKO) and len(fields) == 0: raise Error("matrix fields required")
    if m == PLOT_BARBS:
        if len(fields) != 2: raise Error("barbs need u/v")
    elif m == PLOT_TRICONTOUR or m == PLOT_PUNCHCARD:
        if len(fields) != 1: raise Error("one series field required")
    elif m != PLOT_CORRPLOT and m != PLOT_MARIMEKKO and len(fields) > 0: raise Error("unused series fields")
    if (m == PLOT_TREEMAP or m == PLOT_SUNBURST or m == PLOT_TREE or m == PLOT_SANKEY or m == PLOT_CHORD or m == PLOT_GRAPH) and layer.y2_field == "": raise Error("parent/target required")
    if m != PLOT_TRICONTOUR:
        if layer.triangles_json != "[]" or layer.levels_json != "[]": raise Error("mesh only for tricontour")
    else:
        var triangles = _c_numbers(layer.triangles_json,True)
        var levels = _c_numbers(layer.levels_json)
        if len(triangles) == 0 or len(levels) == 0: raise Error("mesh and levels required")
        for i in range(1,len(levels)):
            if levels[i] <= levels[i-1]: raise Error("levels must increase")
        for t in range(0,len(triangles),3):
            if triangles[t] == triangles[t+1] or triangles[t] == triangles[t+2] or triangles[t+1] == triangles[t+2]: raise Error("repeated vertex")
            for p in range(0,t,3):
                var matches = 0
                for a in range(3):
                    for b in range(3):
                        if triangles[t+a] == triangles[p+b]: matches += 1
                if matches == 3: raise Error("duplicate triangle")


def _c_column(data: PlotDataTable, name: String, numeric: Bool = True) raises -> List[Float32]:
    var result = List[Float32]()
    var kind = data.field_kind(name)
    if kind == 0: raise Error("missing field")
    if numeric and (kind == COLUMN_STRING or kind == COLUMN_CATEGORY or kind == COLUMN_BOOL): raise Error("numeric field required")
    if not numeric and kind != COLUMN_STRING and kind != COLUMN_CATEGORY: raise Error("string identity required")
    for i in range(data.row_count()):
        if not data.field_is_valid(name,i): raise Error("null source")
        var v = data.float_field_at(name,i) if numeric else Float32(0)
        if not isfinite(v): raise Error("nonfinite source")
        result.append(v)
    return result^


def _c_zeros(n: Int) -> List[Float32]:
    var result = List[Float32]()
    for _ in range(n): result.append(0)
    return result^


def _c_find(values: List[String], value: String) -> Int:
    for i in range(len(values)):
        if values[i] == value: return i
    return -1


def _c_g(mut s: PlotSeries, data: PlotDataTable, row: Int, kind: PlotGlyphKind, part: String, x: Float32, y: Float32, x2: Float32, y2: Float32, color: Color, interactive: Bool = True, x3: Float32 = 0, y3: Float32 = 0, sources: List[Int] = List[Int](), size: Float32 = 6, stroke_width: Float32 = 0):
    var p = PlotPoint(x,y,data.key_at(row))
    p.set_extent(x2,y2)
    p.x3 = x3
    p.y3 = y3
    p.source_keys = sources.copy() if len(sources) > 0 else [data.key_at(row)]
    p.glyph = kind
    p.part = part
    p.text = part
    p.tooltip = String(part,"; source_keys=",p.source_keys_text())
    p.interactive = interactive
    p.color = color
    p.has_color = True
    p.size = size
    p.stroke_width = stroke_width
    s.append(p)


def _c_quad(mut s: PlotSeries, d: PlotDataTable, row: Int, part: String, ax: Float32, ay: Float32, bx: Float32, by: Float32, cx: Float32, cy: Float32, dx: Float32, dy: Float32, color: Color, interactive: Bool = True, sources: List[Int] = List[Int]()):
    _c_g(s,d,row,PlotGlyphKind.TRIANGLE,part,ax,ay,bx,by,color,interactive,cx,cy,sources)
    _c_g(s,d,row,PlotGlyphKind.TRIANGLE,part,ax,ay,cx,cy,color,interactive,dx,dy,sources)


def _c_sector(mut s: PlotSeries,d: PlotDataTable,row: Int,part: String,inner: Float32,outer: Float32,a: Float32,b: Float32,color: Color,interactive: Bool = True,sources: List[Int] = List[Int]()):
    var steps = max(1,Int((b-a)*32/3.141592653589793)+1)
    for j in range(steps):
        var u = a+(b-a)*Float32(j)/Float32(steps)
        var v = a+(b-a)*Float32(j+1)/Float32(steps)
        _c_quad(s,d,row,part,0.5+inner*cos(u),0.5-inner*sin(u),0.5+outer*cos(u),0.5-outer*sin(u),0.5+outer*cos(v),0.5-outer*sin(v),0.5+inner*cos(v),0.5-inner*sin(v),color,interactive,sources)


def _c_orient(x: List[Float32], y: List[Float32], a: Int, b: Int, c: Int) -> Float32:
    return (x[b]-x[a])*(y[c]-y[a])-(y[b]-y[a])*(x[c]-x[a])


def _c_mesh(x: List[Float32], y: List[Float32], triangles: List[Float32]) raises:
    for a in range(len(x)):
        for b in range(a):
            if x[a]==x[b] and y[a]==y[b]: raise Error("duplicate coordinates")
    for t in range(0,len(triangles),3):
        var a=Int(triangles[t])
        var b=Int(triangles[t+1])
        var c=Int(triangles[t+2])
        if a>=len(x) or b>=len(x) or c>=len(x): raise Error("missing vertex")
        var area=_c_orient(x,y,a,b,c)
        if not isfinite(area) or area==0: raise Error("invalid triangle area")
    for t in range(0,len(triangles),3):
        for u in range(0,t,3):
            for side in range(2):
                var first=t if side==0 else u
                var second=u if side==0 else t
                for j in range(3):
                    var a=Int(triangles[first+j])
                    var positive=True
                    var negative=True
                    for k in range(3):
                        var cross=_c_orient(x,y,Int(triangles[second+k]),Int(triangles[second+(k+1)%3]),a)
                        var b=Int(triangles[second+k])
                        var c=Int(triangles[second+(k+1)%3])
                        if a!=b and a!=c and cross==0 and min(x[b],x[c])<=x[a]<=max(x[b],x[c]) and min(y[b],y[c])<=y[a]<=max(y[b],y[c]): raise Error("mesh T junction")
                        positive=positive and cross>0
                        negative=negative and cross<0
                    if positive or negative: raise Error("overlapping triangles")
            for j in range(3):
                var a=Int(triangles[t+j])
                var b=Int(triangles[t+(j+1)%3])
                for k in range(3):
                    var c=Int(triangles[u+k])
                    var d=Int(triangles[u+(k+1)%3])
                    if (a==c and b==d) or (a==d and b==c):
                        if _c_orient(x,y,a,b,Int(triangles[t+(j+2)%3]))*_c_orient(x,y,a,b,Int(triangles[u+(k+2)%3]))>=0: raise Error("same side shared edge")
                    elif a!=c and a!=d and b!=c and b!=d:
                        if _c_orient(x,y,a,b,c)*_c_orient(x,y,a,b,d)<=0 and _c_orient(x,y,c,d,a)*_c_orient(x,y,c,d,b)<=0 and max(min(x[a],x[b]),min(x[c],x[d]))<=min(max(x[a],x[b]),max(x[c],x[d])) and max(min(y[a],y[b]),min(y[c],y[d]))<=min(max(y[a],y[b]),max(y[c],y[d])): raise Error("crossing mesh edges")


def _c_layout(layer: PlotLayer,data: PlotDataTable,id: Int) raises -> PlotSeries:
    _c_validate(layer)
    var n = data.row_count()
    if n == 0: raise Error("empty Wave C input")
    var result = PlotSeries(id,layer.label,layer.color,layer.mark)
    result.line_width = layer.line_width
    result.marker_size = layer.size
    result.opacity = layer.opacity
    result.has_layout_domain = True
    result.layout_x_min = 0
    result.layout_x_max = 1
    result.layout_y_min = 0
    result.layout_y_max = 1
    var m = layer.mark
    var fields = _string_array(layer.series_fields_json)
    var pi: Float32 = 3.141592653589793
    if m == PLOT_TREEMAP or m == PLOT_SUNBURST or m == PLOT_TREE:
        _ = _c_column(data,layer.x_field,False)
        _ = _c_column(data,layer.y2_field,False)
        var totals = _c_column(data,layer.y_field)
        var ids = List[String]()
        var children = List[List[Int]]()
        var parent = List[Int]()
        for i in range(n):
            var name = data.string_field_at(layer.x_field,i)
            if name == "" or _c_find(ids,name) >= 0 or totals[i] < 0: raise Error("invalid hierarchy identity/value")
            ids.append(name)
            children.append(List[Int]())
        var root = -1
        for i in range(n):
            var p = data.string_field_at(layer.y2_field,i)
            if p == "":
                if root >= 0: raise Error("multiple roots")
                root = i
                parent.append(-1)
            else:
                var j = _c_find(ids,p)
                if j < 0: raise Error("missing parent")
                children[j].append(i)
                parent.append(j)
        if root < 0: raise Error("no root")
        var depth = _c_zeros(n)
        var branch = _c_zeros(n)
        var order = List[Int]()
        order.append(root)
        var qi = 0
        var maxdepth: Float32 = 0
        while qi < len(order):
            var node = order[qi]
            qi += 1
            for j in range(len(children[node])):
                var c = children[node][j]
                depth[c] = depth[node]+1
                maxdepth = max(maxdepth,depth[c])
                branch[c] = Float32(j) if node == root else branch[node]
                order.append(c)
                if len(order)>n: raise Error("cycle")
        if len(order)!=n: raise Error("cycle/disconnected hierarchy")
        for j in range(n-1,-1,-1):
            var node = order[j]
            if len(children[node]) > 0:
                totals[node] = 0
                for c in children[node]: totals[node] += totals[c]
        if totals[root] <= 0 or not isfinite(totals[root]): raise Error("positive finite leaf total required")
        var x0 = _c_zeros(n)
        var y0 = _c_zeros(n)
        var x1 = _c_zeros(n)
        var y1 = _c_zeros(n)
        x1[root] = 1
        y1[root] = 1
        if m == PLOT_TREEMAP:
            for node in order:
                if len(children[node]) == 0:
                    if totals[node] > 0: _c_g(result,data,node,PlotGlyphKind.RECT,"leaf",x0[node],y0[node],x1[node],y1[node],_c_palette(Int(branch[node])))
                elif totals[node] > 0:
                    var cursor: Float32 = 0
                    for c in children[node]:
                        var end = cursor+totals[c]/totals[node]
                        x0[c] = x0[node]
                        y0[c] = y0[node]
                        x1[c] = x1[node]
                        y1[c] = y1[node]
                        if Int(depth[node])%2 == 0:
                            x0[c] += (x1[node]-x0[node])*cursor
                            x1[c] = x0[node]+(x1[node]-x0[node])*end
                        else:
                            y0[c] = y1[node]-(y1[node]-y0[node])*end
                            y1[c] = y1[node]-(y1[node]-y0[node])*cursor
                        cursor = end
        elif m == PLOT_SUNBURST:
            x0[root] = -pi/2
            x1[root] = 3*pi/2
            for node in order:
                if node != root and totals[node]>0: _c_sector(result,data,node,"sector",0.45*(depth[node]-1)/maxdepth,0.45*depth[node]/maxdepth,x0[node],x1[node],_c_palette(Int(branch[node])))
                var cursor = x0[node]
                for c in children[node]:
                    var end = cursor+(x1[node]-x0[node])*totals[c]/totals[node] if totals[node]>0 else cursor
                    x0[c] = cursor
                    x1[c] = end
                    cursor = end
        else:
            var stack = List[Int]()
            var dfs = List[Int]()
            stack.append(root)
            var leaves = 0
            while len(stack)>0:
                var node = stack.pop()
                dfs.append(node)
                if len(children[node])==0:
                    x0[node] = Float32(leaves)
                    leaves += 1
                for j in range(len(children[node])-1,-1,-1): stack.append(children[node][j])
            for j in range(n-1,-1,-1):
                var node = dfs[j]
                if len(children[node])>0:
                    for c in children[node]: x0[node] += x0[c]
                    x0[node] /= Float32(len(children[node]))
            for i in range(n):
                x0[i] = x0[i]/Float32(leaves-1) if leaves>1 else Float32(0.5)
                y0[i] = 1-depth[i]/max(Float32(1),maxdepth)
            for node in order:
                for c in children[node]: _c_g(result,data,c,PlotGlyphKind.SEGMENT,"parent-edge",x0[node],y0[node],x0[c],y0[c],_c_palette(Int(branch[c])),sources=[data.key_at(node),data.key_at(c)])
            for node in order: _c_g(result,data,node,PlotGlyphKind.POINT,"node",x0[node],y0[node],x0[node],y0[node],_c_palette(Int(branch[node])))
    elif m == PLOT_SANKEY or m == PLOT_CHORD or m == PLOT_GRAPH:
        _ = _c_column(data,layer.x_field,False)
        _ = _c_column(data,layer.y2_field,False)
        var values = _c_column(data,layer.y_field)
        var nodes = List[String]()
        var src = List[Int]()
        var dst = List[Int]()
        var total: Float32 = 0
        for field in [layer.x_field, layer.y2_field]:
            for i in range(n):
                var name = data.string_field_at(field,i)
                if name == "": raise Error("empty edge identity")
                if _c_find(nodes,name)<0: nodes.append(name)
        for i in range(n):
            var a = data.string_field_at(layer.x_field,i)
            var b = data.string_field_at(layer.y2_field,i)
            if values[i]<0: raise Error("invalid edge")
            src.append(_c_find(nodes,a))
            dst.append(_c_find(nodes,b))
            total += values[i]
        if not isfinite(total): raise Error("overflow flow")
        var count = len(nodes)
        var incidents = List[List[Int]]()
        var representative = List[Int]()
        for j in range(count):
            var keys = List[Int]()
            var first = -1
            for i in range(n):
                if src[i] == j or dst[i] == j:
                    if first < 0: first = i
                    keys.append(data.key_at(i))
            incidents.append(keys^)
            representative.append(first)
        var x = _c_zeros(count)
        var y = _c_zeros(count)
        if m == PLOT_GRAPH:
            var maximum: Float32=0
            for v in values: maximum=max(maximum,v)
            for j in range(count):
                var a = -pi/2+2*pi*Float32(j)/Float32(count)
                x[j] = 0.5+0.45*cos(a)
                y[j] = 0.5-0.45*sin(a)
            for i in range(n):
                if src[i]!=dst[i]: _c_g(result,data,i,PlotGlyphKind.SEGMENT,"edge",x[src[i]],y[src[i]],x[dst[i]],y[dst[i]],_c_palette(src[i]),stroke_width=layer.line_width*(1+2*values[i]/maximum) if maximum>0 else layer.line_width)
            for j in range(count): _c_g(result,data,representative[j],PlotGlyphKind.POINT,String("node:",nodes[j]),x[j],y[j],x[j],y[j],_c_palette(j),False,sources=incidents[j])
        elif m == PLOT_CHORD:
            if total<=0: raise Error("positive chord total required")
            var totals = _c_zeros(count)
            for i in range(n):
                totals[src[i]] += values[i]
                totals[dst[i]] += values[i]
            var cursor = -pi/2
            for j in range(count):
                x[j] = cursor
                y[j] = cursor
                cursor += pi*totals[j]/total
            for i in range(n):
                var a = y[src[i]]
                var b = a+pi*values[i]/total
                y[src[i]] = b
                var c = y[dst[i]]
                var d = c+pi*values[i]/total
                y[dst[i]] = d
                var ax = 0.5+0.414*cos(a)
                var ay = 0.5-0.414*sin(a)
                var bx = 0.5+0.414*cos(b)
                var by = 0.5-0.414*sin(b)
                var cx = 0.5+0.414*cos(c)
                var cy = 0.5-0.414*sin(c)
                var dx = 0.5+0.414*cos(d)
                var dy = 0.5-0.414*sin(d)
                for j in range(24):
                    var t = Float32(j)/24
                    var u = Float32(j+1)/24
                    _c_quad(result,data,i,"ribbon",(1-t)**2*ax+t*t*dx+t*(1-t),(1-t)**2*ay+t*t*dy+t*(1-t),(1-t)**2*bx+t*t*cx+t*(1-t),(1-t)**2*by+t*t*cy+t*(1-t),(1-u)**2*bx+u*u*cx+u*(1-u),(1-u)**2*by+u*u*cy+u*(1-u),(1-u)**2*ax+u*u*dx+u*(1-u),(1-u)**2*ay+u*u*dy+u*(1-u),_c_palette(src[i]))
                for side in range(2):
                    var start = a if side == 0 else c
                    var end = b if side == 0 else d
                    for j in range(16):
                        var u = start+(end-start)*Float32(j)/16
                        var v = start+(end-start)*Float32(j+1)/16
                        _c_g(result,data,i,PlotGlyphKind.TRIANGLE,"rim",0.5+0.414*cos(start),0.5-0.414*sin(start),0.5+0.414*cos(u),0.5-0.414*sin(u),_c_palette(src[i]),x3=0.5+0.414*cos(v),y3=0.5-0.414*sin(v))
            for j in range(count): _c_sector(result,data,representative[j],String("node:",nodes[j]),0.414,0.45,x[j],x[j]+pi*totals[j]/total,_c_palette(j),False,incidents[j])
        else:
            var degree = _c_zeros(count)
            var columns = _c_zeros(count)
            var queue = List[Int]()
            for i in range(n):
                if src[i]==dst[i]: raise Error("Sankey self cycle")
            var active_total: Float32 = 0
            for i in range(n):
                if src[i]!=dst[i]:
                    degree[dst[i]] += 1
                    active_total += values[i]
            for j in range(count):
                if degree[j] == 0: queue.append(j)
            var qi = 0
            while qi<len(queue):
                var node = queue[qi]
                qi += 1
                for i in range(n):
                    if src[i]==node and src[i]!=dst[i]:
                        columns[dst[i]] = max(columns[dst[i]],columns[node]+1)
                        degree[dst[i]] -= 1
                        if degree[dst[i]] == 0: queue.append(dst[i])
            if len(queue)!=count: raise Error("Sankey cycle")
            if active_total<=0: raise Error("positive non-self flow required")
            var es = List[Int]()
            var et = List[Int]()
            var er = List[Int]()
            var maxcol: Float32 = 0
            for c in columns: maxcol = max(maxcol,c)
            for i in range(n):
                if src[i]==dst[i]: continue
                var prev = src[i]
                for c in range(Int(columns[src[i]])+1,Int(columns[dst[i]])):
                    var dummy = len(columns)
                    columns.append(Float32(c))
                    es.append(prev)
                    et.append(dummy)
                    er.append(i)
                    prev = dummy
                es.append(prev)
                et.append(dst[i])
                er.append(i)
            var size = len(columns)
            var incoming = _c_zeros(size)
            var outgoing = _c_zeros(size)
            for e in range(len(es)):
                outgoing[es[e]] += values[er[e]]
                incoming[et[e]] += values[er[e]]
            var totals = _c_zeros(size)
            var low = _c_zeros(size)
            var high = _c_zeros(size)
            var xs = _c_zeros(size)
            for j in range(size):
                totals[j] = max(incoming[j],outgoing[j])
                xs[j] = 0.96*columns[j]/maxcol
            for c in range(Int(maxcol)+1):
                var coltotal: Float32 = 0
                for j in range(size):
                    if Int(columns[j])==c: coltotal += totals[j]
                var cursor: Float32 = 0
                for j in range(size):
                    if Int(columns[j])!=c: continue
                    low[j] = cursor
                    cursor += totals[j]/coltotal if coltotal>0 else Float32(0)
                    high[j] = cursor
            var out = low.copy()
            var inc = low.copy()
            for e in range(len(es)):
                var a = es[e]
                var b = et[e]
                var i = er[e]
                var ah = values[i]/totals[a]*(high[a]-low[a]) if totals[a]>0 else Float32(0)
                var bh = values[i]/totals[b]*(high[b]-low[b]) if totals[b]>0 else Float32(0)
                _c_quad(result,data,i,"flow",xs[a]+0.04,1-out[a],xs[a]+0.04,1-out[a]-ah,xs[b],1-inc[b]-bh,xs[b],1-inc[b],_c_palette(src[i]))
                out[a] += ah
                inc[b] += bh
            for j in range(count): _c_g(result,data,representative[j],PlotGlyphKind.RECT,String("node:",nodes[j]),xs[j],1-high[j],xs[j]+0.04,1-low[j],_c_palette(j),False,sources=incidents[j])
    elif m == PLOT_CORRPLOT or m == PLOT_MARIMEKKO:
        _ = _c_column(data,layer.x_field,False)
        var labels = List[String]()
        for i in range(n):
            var label = data.string_field_at(layer.x_field,i)
            if _c_find(labels,label)>=0: raise Error("duplicate matrix label")
            labels.append(label)
        var matrix = List[List[Float32]]()
        for field in fields: matrix.append(_c_column(data,field))
        if m == PLOT_CORRPLOT:
            if len(matrix)!=n: raise Error("square matrix required")
            result.layout_x_min = -0.5
            result.layout_x_max = Float32(n)-0.5
            result.layout_y_min = -0.5
            result.layout_y_max = Float32(n)-0.5
            for i in range(n):
                for j in range(n):
                    var v = matrix[j][i]
                    if abs(v)>1: raise Error("correlation outside [-1,1]")
                    var r = 0.4*abs(v)
                    var color = Color(0.2+0.7*max(v,Float32(0)),0.35,0.2+0.7*max(-v,Float32(0)),1)
                    for k in range(32):
                        var a = Float32(k)*pi/16
                        var b = Float32(k+1)*pi/16
                        _c_g(result,data,i,PlotGlyphKind.TRIANGLE,String("cell:",fields[j]),Float32(j),Float32(n-1-i),Float32(j)+r*cos(a),Float32(n-1-i)+r*sin(a),color,x3=Float32(j)+r*cos(b),y3=Float32(n-1-i)+r*sin(b))
        else:
            var totals = _c_zeros(n)
            var grand: Float32 = 0
            for values in matrix:
                for i in range(n):
                    if values[i]<0: raise Error("negative matrix")
                    totals[i] += values[i]
                    grand += values[i]
            if grand<=0 or not isfinite(grand): raise Error("positive finite matrix total required")
            var x: Float32 = 0
            for i in range(n):
                var end = x+totals[i]/grand
                var y: Float32 = 0
                for j in range(len(matrix)):
                    var top = y+matrix[j][i]/totals[i] if totals[i]>0 else y
                    if top>y: _c_g(result,data,i,PlotGlyphKind.RECT,String("cell:",fields[j]),x,y,end,top,_c_palette(j))
                    y = top
                x = end
    elif m == PLOT_PUNCHCARD:
        _ = _c_column(data,layer.x_field,False)
        _ = _c_column(data,layer.y_field,False)
        var values = _c_column(data,fields[0])
        var xs = List[String]()
        var ys = List[String]()
        for i in range(n):
            var x = data.string_field_at(layer.x_field,i)
            var y = data.string_field_at(layer.y_field,i)
            if _c_find(xs,x)<0: xs.append(x)
            if _c_find(ys,y)<0: ys.append(y)
            if values[i]<0: raise Error("negative punchcard size")
        result.layout_x_min = -0.5
        result.layout_x_max = Float32(len(xs))-0.5
        result.layout_y_min = -0.5
        result.layout_y_max = Float32(len(ys))-0.5
        for i in range(n):
            var x = Float32(_c_find(xs,data.string_field_at(layer.x_field,i)))
            var y = Float32(len(ys)-1-_c_find(ys,data.string_field_at(layer.y_field,i)))
            _c_g(result,data,i,PlotGlyphKind.POINT,"cell",x,y,x,y,_c_palette(i),size=values[i]/5,interactive=values[i]>0)
    elif m == PLOT_CALENDAR_HEATMAP:
        _ = _c_column(data,layer.x_field,False)
        var values = _c_column(data,layer.y_field)
        var days = List[Int]()
        var names = List[String]()
        var year = -1
        var offset = 0
        var weeks = 0
        var low = values[0]
        var high = values[0]
        for i in range(n):
            var name = data.string_field_at(layer.x_field,i)
            if name.count_codepoints()!=10 or String(name[codepoint=4:5])!="-" or String(name[codepoint=7:8])!="-" or _c_find(names,name)>=0: raise Error("invalid/duplicate ISO date")
            names.append(name)
            var digits = List[Int]()
            for j in range(10):
                if j==4 or j==7: continue
                var c = name[codepoint=j:j+1]
                var digit = -1
                for k in range(10):
                    if c==String(k): digit=k
                if digit<0: raise Error("invalid date digit")
                digits.append(digit)
            var yy = digits[0]*1000+digits[1]*100+digits[2]*10+digits[3]
            var month = digits[4]*10+digits[5]
            var day = digits[6]*10+digits[7]
            if yy<1 or month<1 or month>12: raise Error("invalid date")
            var leap = yy%4==0 and (yy%100!=0 or yy%400==0)
            var lengths: List[Int] = [31,29 if leap else 28,31,30,31,30,31,31,30,31,30,31]
            if day<1 or day>lengths[month-1]: raise Error("invalid day")
            if year<0:
                year=yy
                var prev=yy-1
                offset=(prev+prev//4-prev//100+prev//400+1)%7
                weeks=((366 if leap else 365)-1+offset)//7+1
            elif year!=yy: raise Error("calendar spans years")
            var ordinal=day-1+offset
            for j in range(month-1): ordinal+=lengths[j]
            days.append(ordinal)
            low=min(low,values[i])
            high=max(high,values[i])
        result.layout_x_max=Float32(weeks)
        result.layout_y_max=7
        for i in range(n):
            var week=Float32(days[i]//7)
            var dow=Float32(days[i]%7)
            var v=(values[i]-low)/(high-low) if high>low else Float32(0.5)
            _c_g(result,data,i,PlotGlyphKind.RECT,"day",week,6-dow,week+1,7-dow,Color(0.9-0.7*v,0.95-0.4*v,1-0.2*v,1))
    elif m == PLOT_BARBS:
        var x = _c_column(data,layer.x_field)
        var y = _c_column(data,layer.y_field)
        var u = _c_column(data,fields[0])
        var v = _c_column(data,fields[1])
        var xmin=x[0]
        var xmax=x[0]
        var ymin=y[0]
        var ymax=y[0]
        for i in range(n):
            xmin=min(xmin,x[i])
            xmax=max(xmax,x[i])
            ymin=min(ymin,y[i])
            ymax=max(ymax,y[i])
        var xp=(xmax-xmin) if xmax>xmin else Float32(1)
        var yp=(ymax-ymin) if ymax>ymin else Float32(1)
        result.layout_x_min=xmin-0.2*xp
        result.layout_x_max=xmax+0.2*xp
        result.layout_y_min=ymin-0.2*yp
        result.layout_y_max=ymax+0.2*yp
        var length=0.08*max(result.layout_x_max-result.layout_x_min,result.layout_y_max-result.layout_y_min)
        for i in range(n):
            var speed=sqrt(u[i]*u[i]+v[i]*v[i])
            if not isfinite(speed) or speed>50000: raise Error("barb flag limit")
            var rounded=Int(speed/5+0.5)*5
            var flags=rounded//50
            var full=(rounded%50)//10
            var half=rounded%10>=5
            if rounded==0:
                for k in range(32):
                    var a=Float32(k)*pi/16
                    var b=Float32(k+1)*pi/16
                    _c_g(result,data,i,PlotGlyphKind.SEGMENT,"calm",x[i]+length*0.15*cos(a),y[i]+length*0.15*sin(a),x[i]+length*0.15*cos(b),y[i]+length*0.15*sin(b),_c_palette(i))
                continue
            var ux=-length*u[i]/speed
            var uy=-length*v[i]/speed
            _c_g(result,data,i,PlotGlyphKind.SEGMENT,"staff",x[i],y[i],x[i]+ux,y[i]+uy,_c_palette(i))
            var cursor: Float32=1
            for _ in range(flags):
                _c_g(result,data,i,PlotGlyphKind.TRIANGLE,"flag",x[i]+cursor*ux,y[i]+cursor*uy,x[i]+cursor*ux-0.4*uy,y[i]+cursor*uy+0.4*ux,_c_palette(i),x3=x[i]+(cursor-0.25)*ux,y3=y[i]+(cursor-0.25)*uy)
                cursor-=0.25
            if flags>0: cursor-=0.125
            for _ in range(full):
                _c_g(result,data,i,PlotGlyphKind.SEGMENT,"full",x[i]+cursor*ux,y[i]+cursor*uy,x[i]+(cursor-0.125)*ux-0.4*uy,y[i]+(cursor-0.125)*uy+0.4*ux,_c_palette(i))
                cursor-=0.125
            if half and flags==0 and full==0: cursor-=0.125
            if half: _c_g(result,data,i,PlotGlyphKind.SEGMENT,"half",x[i]+cursor*ux,y[i]+cursor*uy,x[i]+(cursor-0.0625)*ux-0.2*uy,y[i]+(cursor-0.0625)*uy+0.2*ux,_c_palette(i))
    else:
        var x = _c_column(data,layer.x_field)
        var y = _c_column(data,layer.y_field)
        var z = _c_column(data,fields[0])
        var triangles = _c_numbers(layer.triangles_json,True)
        var levels = _c_numbers(layer.levels_json)
        result.layout_x_min=x[0]
        result.layout_x_max=x[0]
        result.layout_y_min=y[0]
        result.layout_y_max=y[0]
        for i in range(n):
            result.layout_x_min=min(result.layout_x_min,x[i])
            result.layout_x_max=max(result.layout_x_max,x[i])
            result.layout_y_min=min(result.layout_y_min,y[i])
            result.layout_y_max=max(result.layout_y_max,y[i])
        if result.layout_x_min==result.layout_x_max or result.layout_y_min==result.layout_y_max: raise Error("degenerate triangle domain")
        _c_mesh(x,y,triangles)
        var edge_a=List[Int]()
        var edge_b=List[Int]()
        var edge_count=List[Int]()
        for t in range(0,len(triangles),3):
            var a=Int(triangles[t])
            var b=Int(triangles[t+1])
            var c=Int(triangles[t+2])
            if a>=n or b>=n or c>=n: raise Error("missing vertex")
            if (x[b]-x[a])*(y[c]-y[a])-(y[b]-y[a])*(x[c]-x[a])==0: raise Error("zero area triangle")
            var indices: List[Int]=[a,b,c]
            for j in range(3):
                var ea=min(indices[j],indices[(j+1)%3])
                var eb=max(indices[j],indices[(j+1)%3])
                var found=-1
                for k in range(len(edge_a)):
                    if edge_a[k]==ea and edge_b[k]==eb: found=k
                if found<0:
                    edge_a.append(ea)
                    edge_b.append(eb)
                    edge_count.append(1)
                else:
                    edge_count[found]+=1
                    if edge_count[found]>2: raise Error("nonmanifold triangulation")
            for level in levels:
                var cx=List[Float32]()
                var cy=List[Float32]()
                for j in range(3):
                    var p=indices[j]
                    var q=indices[(j+1)%3]
                    if (z[p]<=level and level<z[q]) or (z[q]<=level and level<z[p]):
                        var f=(level-z[p])/(z[q]-z[p])
                        cx.append(x[p]+f*(x[q]-x[p]))
                        cy.append(y[p]+f*(y[q]-y[p]))
                if len(cx)==2 and (cx[0]!=cx[1] or cy[0]!=cy[1]): _c_g(result,data,a,PlotGlyphKind.SEGMENT,String("triangle:",t//3,":level:",level),cx[0],cy[0],cx[1],cy[1],_c_palette(a),sources=[data.key_at(a),data.key_at(b),data.key_at(c)])
    return result^
