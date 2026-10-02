"""Mojo-owned retained geometry with a closed flow/grid profile.

Native text is a provider, not a tree owner. Plans stage immutable outputs;
only commit publishes. No Rust engine or native layout ABI is required.
"""
from std.collections import List, Dict
from std.memory import ArcPointer
from std.math import isfinite
from std.time import perf_counter_ns
from .geometry import Rect, Size
from .box_layout import BoxMetrics

comptime CONTENT = 0
comptime FIXED = 1
comptime FILL = 2
comptime FRACTION = 3
comptime MIN_CONTENT = 4
comptime MAX_CONTENT = 5
comptime FIT_CONTENT = 6
comptime COLUMN = 0
comptime ROW = 1
comptime WRAP = 2
comptime GRID = 3
comptime STACK = 4
comptime LEAF = 5
comptime COLLAPSED = 6


struct RetainedStyle(ImplicitlyCopyable):
    """Validated style. Fraction means a fraction of the containing axis;
    weighted remaining space uses grow. Shrink is explicitly opt-in.

    Dimensions and geometry remain exact logical Float32 values.
    """
    var kind: Int32
    var width_kind: Int32
    var height_kind: Int32
    var width: Float32
    var height: Float32
    var min_width: Float32
    var min_height: Float32
    var max_width: Float32
    var max_height: Float32
    var gap: Float32
    var padding: Float32
    var grow: Float32
    var shrink: Float32
    var align: Int32
    var rtl: Int32
    var overflow: Int32
    var column: Int32
    var column_span: Int32
    var row: Int32
    var row_span: Int32

    def __init__(out self, kind: Int = COLUMN, width_kind: Int = CONTENT,
                 height_kind: Int = CONTENT, width: Float32 = 0, height: Float32 = 0,
                 min_width: Float32 = 0, min_height: Float32 = 0,
                 max_width: Float32 = 3.4028234e38, max_height: Float32 = 3.4028234e38,
                 gap: Float32 = 0, padding: Float32 = 0, grow: Float32 = 0,
                 shrink: Float32 = 0, align: Int = 0, rtl: Bool = False,
                 overflow: Int = 0, column: Int = 0, column_span: Int = 1,
                 row: Int = 0, row_span: Int = 1):
        self.kind = Int32(kind)
        self.width_kind = Int32(width_kind)
        self.height_kind = Int32(height_kind)
        self.width = width
        self.height = height
        self.min_width = min_width
        self.min_height = min_height
        self.max_width = max_width
        self.max_height = max_height
        self.gap = gap
        self.padding = padding
        self.grow = grow
        self.shrink = shrink
        self.align = Int32(align)
        self.rtl = Int32(Int(rtl))
        self.overflow = Int32(overflow)
        self.column = Int32(column)
        self.column_span = Int32(column_span)
        self.row = Int32(row)
        self.row_span = Int32(row_span)


struct RetainedTrack(ImplicitlyCopyable):
    """Track limits: auto=0, fixed=1, min-content=2, max-content=3, fr=4(max)."""
    var min_kind: Int32
    var max_kind: Int32
    var minimum: Float32
    var maximum: Float32

    def __init__(out self, min_kind: Int = 0, max_kind: Int = 0,
                 minimum: Float32 = 0, maximum: Float32 = 0):
        self.min_kind = Int32(min_kind)
        self.max_kind = Int32(max_kind)
        self.minimum = minimum
        self.maximum = maximum

    @staticmethod
    def fixed(points: Float32) -> Self:
        return Self(1, 1, points, points)

    @staticmethod
    def fraction(weight: Float32, minimum: Float32 = 0) -> Self:
        return Self(1, 4, minimum, weight)


struct RetainedPlacement(ImplicitlyCopyable):
    var key: UInt64
    var x: Float32
    var y: Float32
    var width: Float32
    var height: Float32
    def __init__(out self, key: Int, rect: Rect):
        self.key = UInt64(key)
        self.x = rect.x
        self.y = rect.y
        self.width = rect.width
        self.height = rect.height


trait RetainedParagraph(ImplicitlyCopyable & Deinitable):
    def __init__(out self): ...
    @staticmethod
    def query(text: String, font: Float32, width: Float32, direction: Int, kind: Int) raises -> Self: ...
    def metrics(self) -> BoxMetrics: ...


def _extent(value: Float32) raises:
    if not isfinite(value) or value < 0:
        raise Error("Retained extent must be finite and nonnegative")


def _clamp(value: Float32, minimum: Float32, maximum: Float32) -> Float32:
    return max(minimum, min(maximum, value))


def _same_style(a: RetainedStyle, b: RetainedStyle) -> Bool:
    return a.kind==b.kind and a.width_kind==b.width_kind and a.height_kind==b.height_kind and a.width==b.width and a.height==b.height and a.min_width==b.min_width and a.min_height==b.min_height and a.max_width==b.max_width and a.max_height==b.max_height and a.gap==b.gap and a.padding==b.padding and a.grow==b.grow and a.shrink==b.shrink and a.align==b.align and a.rtl==b.rtl and a.overflow==b.overflow and a.column==b.column and a.column_span==b.column_span and a.row==b.row and a.row_span==b.row_span


def _validate_style(style: RetainedStyle, paragraph: Bool) raises:
    if style.kind<0 or style.kind>6 or style.width_kind<0 or style.width_kind>6 or style.height_kind<0 or style.height_kind>6 or style.align<0 or style.align>4 or style.rtl<0 or style.rtl>1 or style.overflow<0 or style.overflow>2 or style.column<0 or style.column>32767 or style.row<0 or style.row>32767 or style.column_span<1 or style.column_span>65535 or style.row_span<1 or style.row_span>65535:
        raise Error("Invalid retained style enum or grid placement")
    for value in [style.width,style.height,style.min_width,style.min_height,style.max_width,style.max_height,style.gap,style.padding,style.grow,style.shrink]:
        _extent(value)
    if style.min_width>style.max_width or style.min_height>style.max_height:
        raise Error("Contradictory retained size bounds")
    if paragraph and (style.kind!=LEAF or style.padding!=0):
        raise Error("Paragraph requires an unpadded leaf style")


struct _Measurement[P: RetainedParagraph](ImplicitlyCopyable):
    var width: Float32
    var query: Int
    var payload: Self.P
    def __init__(out self, width: Float32, query: Int, payload: Self.P):
        self.width = width
        self.query = query
        self.payload = payload


struct _Node[P: RetainedParagraph](Copyable):
    var key: Int
    var parent: Int
    var mount: UInt64
    var style: RetainedStyle
    var children: List[Int]
    var columns: List[RetainedTrack]
    var rows: List[RetainedTrack]
    var hidden: Bool
    var text: String
    var font: Float32
    var direction: Int
    var paragraph: Bool
    var placed: Bool
    var placement: Rect
    var clipped: Bool
    var clip: Rect
    var cache: List[_Measurement[Self.P]]
    def __init__(out self, key: Int, mount: UInt64, style: RetainedStyle):
        self.key = key
        self.parent = 0
        self.mount = mount
        self.style = style
        self.children = List[Int]()
        self.columns = List[RetainedTrack]()
        self.rows = List[RetainedTrack]()
        self.hidden = False
        self.text = ""
        self.font = 16
        self.direction = 0
        self.paragraph = False
        self.placed = False
        self.placement = Rect(0,0,0,0)
        self.clipped = False
        self.clip = Rect(0,0,0,0)
        self.cache = List[_Measurement[Self.P]]()


struct GeometryOutput[P: RetainedParagraph](ImplicitlyCopyable):
    var key: Int
    var parent: Int
    var mount: UInt64
    var rect: Rect
    var clip: Rect
    var hidden: Bool
    var paragraph: Bool
    var payload: Self.P
    def __init__(out self, node: _Node[Self.P], rect: Rect, clip: Rect, hidden: Bool, payload: Self.P):
        self.key = node.key
        self.parent = node.parent
        self.mount = node.mount
        self.rect = rect
        self.clip = clip
        self.hidden = hidden
        self.paragraph = node.paragraph and not hidden
        self.payload = payload


struct EngineSnapshot[P: RetainedParagraph](ImplicitlyCopyable):
    var generation: UInt64
    var outputs: ArcPointer[List[GeometryOutput[Self.P]]]
    def __init__(out self):
        self.generation = 0
        self.outputs = ArcPointer(List[GeometryOutput[Self.P]]())
    def bounds(self, key: Int) raises -> Rect:
        for item in self.outputs[]:
            if item.key==key:
                return item.rect
        raise Error("Unknown retained geometry key")


struct EnginePlan[P: RetainedParagraph]:
    var snapshot: EngineSnapshot[Self.P]
    var owner: ArcPointer[Int]
    var revision: UInt64
    var base_generation: UInt64
    var root: Int
    var size: Size
    def __init__(out self, snapshot: EngineSnapshot[Self.P], owner: ArcPointer[Int], revision: UInt64, generation: UInt64, root: Int, size: Size):
        self.snapshot = snapshot
        self.owner = owner
        self.revision = revision
        self.base_generation = generation
        self.root = root
        self.size = size


struct _ChildBox(ImplicitlyCopyable):
    var index: Int
    var rect: Rect
    def __init__(out self, index: Int, rect: Rect):
        self.index = index
        self.rect = rect


struct _GridCell(ImplicitlyCopyable):
    var index: Int
    var column: Int
    var row: Int
    var columns: Int
    var rows: Int
    def __init__(out self, index: Int, column: Int, row: Int, columns: Int, rows: Int):
        self.index = index
        self.column = column
        self.row = row
        self.columns = columns
        self.rows = rows


struct RetainedEngine[P: RetainedParagraph]:
    var nodes: List[_Node[Self.P]]
    var indices: Dict[Int,Int]
    var owner: ArcPointer[Int]
    var revision: UInt64
    var next_mount: UInt64
    var published: EngineSnapshot[Self.P]
    var _last_revision: UInt64
    var _last_root: Int
    var _last_size: Size
    var measurements: UInt64
    var mutations: UInt64
    var publications: UInt64
    var measurement_nanoseconds: UInt64
    def __init__(out self):
        self.nodes = List[_Node[Self.P]]()
        self.indices = Dict[Int,Int]()
        self.owner = ArcPointer(0)
        self.revision = 0
        self.next_mount = 1
        self.published = EngineSnapshot[Self.P]()
        self._last_revision = 0
        self._last_root = 0
        self._last_size = Size(0,0)
        self.measurements = 0
        self.mutations = 0
        self.publications = 0
        self.measurement_nanoseconds = 0

    def _index(self, key: Int) raises -> Int:
        if key not in self.indices:
            raise Error(String("Unknown retained layout key ",key))
        return self.indices[key]

    def _changed(mut self):
        self.revision += 1
        self.mutations += 1

    def set_node(mut self, key: Int, style: RetainedStyle, paragraph: Bool = False, text: String = "", font: Float32 = 16, direction: Int = 0) raises:
        if key<=0:
            raise Error("Retained keys must be positive")
        _validate_style(style,paragraph)
        if paragraph and (not isfinite(font) or font<=0 or direction<0 or direction>2 or "\x00" in text):
            raise Error("Invalid paragraph font, direction or text")
        if key not in self.indices:
            self.indices[key] = len(self.nodes)
            self.nodes.append(_Node[Self.P](key,self.next_mount,style))
            self.next_mount += 1
        else:
            var i = self.indices[key]
            if paragraph and len(self.nodes[i].children)>0:
                raise Error("Paragraph cannot own children")
            if _same_style(style,self.nodes[i].style) and self.nodes[i].paragraph==paragraph and (not paragraph or (self.nodes[i].text==text and self.nodes[i].font==font and self.nodes[i].direction==direction)):
                return
        var index = self.indices[key]
        var content_changed = self.nodes[index].paragraph!=paragraph or self.nodes[index].text!=text or self.nodes[index].font!=font or self.nodes[index].direction!=direction
        self.nodes[index].style = style
        self.nodes[index].paragraph = paragraph
        self.nodes[index].text = text
        self.nodes[index].font = font
        self.nodes[index].direction = direction
        if content_changed:
            self.nodes[index].cache.clear()
        self._changed()

    def children(mut self, key: Int, children: List[Int]) raises:
        var index = self._index(key)
        if self.nodes[index].paragraph:
            raise Error("Paragraph cannot own children")
        var seen = Dict[Int,Bool]()
        for child in children:
            var i = self._index(child)
            if child in seen:
                raise Error("Duplicate retained child key")
            seen[child] = True
            if self.nodes[i].parent!=0 and self.nodes[i].parent!=key:
                raise Error("Retained child already has an owner")
            var ancestor = key
            while ancestor!=0:
                if ancestor==child:
                    raise Error(String("Layout ownership cycle at key ",child))
                ancestor = self.nodes[self.indices[ancestor]].parent
        var same = len(children)==len(self.nodes[index].children)
        if same:
            for ordinal in range(len(children)):
                same = same and children[ordinal]==self.nodes[index].children[ordinal]
        if same:
            return
        for child in self.nodes[index].children:
            self.nodes[self.indices[child]].parent = 0
        for child in children:
            self.nodes[self.indices[child]].parent = key
        self.nodes[index].children = children.copy()
        self._changed()

    def tracks(mut self, key: Int, tracks: List[RetainedTrack], rows: Bool = False) raises:
        var i = self._index(key)
        if self.nodes[i].style.kind!=GRID:
            raise Error("Tracks require a grid owner")
        for track in tracks:
            _extent(track.minimum)
            _extent(track.maximum)
            if track.min_kind<0 or track.min_kind>3 or track.max_kind<0 or track.max_kind>4 or (track.min_kind==1 and track.max_kind==1 and track.minimum>track.maximum):
                raise Error("Invalid retained track bounds")
        var old = self.nodes[i].rows.copy() if rows else self.nodes[i].columns.copy()
        var same = len(old)==len(tracks)
        if same:
            for j in range(len(old)):
                same = same and old[j].min_kind==tracks[j].min_kind and old[j].max_kind==tracks[j].max_kind and old[j].minimum==tracks[j].minimum and old[j].maximum==tracks[j].maximum
        if same:
            return
        if rows:
            self.nodes[i].rows = tracks.copy()
        else:
            self.nodes[i].columns = tracks.copy()
        self._changed()

    def hide(mut self, key: Int, hidden: Bool) raises:
        var i = self._index(key)
        if self.nodes[i].hidden!=hidden:
            self.nodes[i].hidden = hidden
            self._changed()

    def place(mut self, placements: List[RetainedPlacement]) raises:
        var seen = Dict[Int,Bool]()
        for p in placements:
            var key = Int(p.key)
            var i = self._index(key)
            if key in seen or self.nodes[i].parent==0 or not isfinite(p.x) or not isfinite(p.y):
                raise Error("Custom placement requires unique owned children and finite origins")
            _extent(p.width)
            _extent(p.height)
            seen[key] = True
        for p in placements:
            var i = self.indices[Int(p.key)]
            var rect = Rect(p.x,p.y,p.width,p.height)
            var old = self.nodes[i].placement
            if not self.nodes[i].placed or old.x!=rect.x or old.y!=rect.y or old.width!=rect.width or old.height!=rect.height:
                self.nodes[i].placed = True
                self.nodes[i].placement = rect
                self._changed()

    def clear_placement(mut self, key: Int) raises:
        var i = self._index(key)
        if self.nodes[i].placed:
            self.nodes[i].placed = False
            self._changed()

    def clip(mut self, key: Int, rect: Rect) raises:
        var i = self._index(key)
        if not isfinite(rect.x) or not isfinite(rect.y):
            raise Error("Nonfinite clip origin")
        _extent(rect.width)
        _extent(rect.height)
        var old = self.nodes[i].clip
        if not self.nodes[i].clipped or old.x!=rect.x or old.y!=rect.y or old.width!=rect.width or old.height!=rect.height:
            self.nodes[i].clipped = True
            self.nodes[i].clip = rect
            self._changed()

    def remove(mut self, key: Int) raises:
        _ = self._index(key)
        var pending: List[Int] = [key]
        var retired = Dict[Int,Bool]()
        while len(pending)>0:
            var removed = pending.pop()
            retired[removed] = True
            for child in self.nodes[self.indices[removed]].children:
                pending.append(child)
        var kept = List[_Node[Self.P]]()
        self.indices = Dict[Int,Int]()
        for i in range(len(self.nodes)):
            if self.nodes[i].key not in retired:
                var children = List[Int]()
                for child in self.nodes[i].children:
                    if child not in retired:
                        children.append(child)
                self.nodes[i].children = children^
                self.indices[self.nodes[i].key] = len(kept)
                kept.append(self.nodes[i].copy())
        self.nodes = kept^
        var previous = self.published
        var recovery = EngineSnapshot[Self.P]()
        recovery.generation = previous.generation+1
        for output in previous.outputs[]:
            if output.key not in retired:
                recovery.outputs[].append(output)
        self.published = recovery
        self._changed()

    def invalidate_environment(mut self):
        for i in range(len(self.nodes)):
            self.nodes[i].cache.clear()
        self._changed()

    def _paragraph(mut self, index: Int, width: Float32, query: Int = 0) raises -> Self.P:
        for cached in self.nodes[index].cache:
            if cached.width==width and cached.query==query:
                return cached.payload
        self.measurements += 1
        var started = perf_counter_ns()
        var payload = Self.P.query(self.nodes[index].text,self.nodes[index].font,width,self.nodes[index].direction,query)
        self.measurement_nanoseconds += UInt64(max(0,perf_counter_ns()-started))
        var metrics = payload.metrics()
        _extent(metrics.size.width)
        _extent(metrics.size.height)
        if not isfinite(metrics.first_baseline) or not isfinite(metrics.last_baseline) or (query==0 and metrics.size.width!=width):
            raise Error("Paragraph returned invalid metrics or changed exact width")
        if len(self.nodes[index].cache)==8:
            _ = self.nodes[index].cache.pop(0)
        self.nodes[index].cache.append(_Measurement[Self.P](width,query,payload))
        return payload

    def _dimension(self, kind: Int32, value: Float32, available: Float32, natural: Float32) -> Float32:
        if kind==FIXED:
            return value
        if available>=0 and kind==FILL:
            return available
        if available>=0 and kind==FRACTION:
            return available*value
        return natural

    def _natural_width(mut self, index: Int, query: Int = 2) raises -> Float32:
        var s = self.nodes[index].style
        if s.kind==COLLAPSED:
            return 0
        if s.width_kind==FIXED:
            return _clamp(s.width,s.min_width,s.max_width)
        var width = Float32(0)
        if self.nodes[index].paragraph:
            width = self._paragraph(index,0,query).metrics().size.width
        elif s.kind==GRID:
            var cells = self._cells(index)
            var tracks = self._grid_tracks(index,cells,-1,False,List[Float32](),query)
            width = self._track_sum(tracks,0,len(tracks),s.gap)
        else:
            var count = 0
            var child_keys = self.nodes[index].children.copy()
            for key in child_keys:
                var child = self.indices[key]
                if self.nodes[child].placed or self.nodes[child].style.kind==COLLAPSED:
                    continue
                var next = self._natural_width(child,query)
                if s.kind==ROW or (s.kind==WRAP and query==2):
                    width += next
                else:
                    width = max(width,next)
                count += 1
            if s.kind==ROW or (s.kind==WRAP and query==2):
                width += Float32(max(0,count-1))*s.gap
            width += 2*s.padding
        if s.width_kind==FIT_CONTENT:
            width = max(self._natural_min_width(index),min(width,s.width))
        return _clamp(width,s.min_width,s.max_width)

    def _natural_min_width(mut self, index: Int) raises -> Float32:
        # Keep fit-content's minimum query separate to avoid recursive self calls.
        if self.nodes[index].paragraph:
            return self._paragraph(index,0,1).metrics().size.width
        var width = Float32(0)
        var child_keys = self.nodes[index].children.copy()
        for key in child_keys:
            var child = self.indices[key]
            if not self.nodes[child].placed and self.nodes[child].style.kind!=COLLAPSED:
                width = max(width,self._natural_width(child,1))
        return width+2*self.nodes[index].style.padding

    def _size(mut self, index: Int, available_width: Float32, available_height: Float32,
              forced_width: Float32 = -1, forced_height: Float32 = -1) raises -> Size:
        var s = self.nodes[index].style
        if s.kind==COLLAPSED:
            return Size(0,0)
        var width = forced_width
        if width<0:
            var query = 2
            if s.width_kind==MIN_CONTENT:
                query = 1
            width = self._dimension(s.width_kind,s.width,available_width,self._natural_width(index,query))
        width = _clamp(width,s.min_width,s.max_width)
        var height = forced_height
        if height<0:
            if s.height_kind==FIXED:
                height = s.height
            elif s.height_kind==FILL and available_height>=0:
                height = available_height
            elif s.height_kind==FRACTION and available_height>=0:
                height = available_height*s.height
            elif self.nodes[index].paragraph:
                height = self._paragraph(index,width).metrics().size.height
            else:
                var boxes = self._boxes(index,max(Float32(0),width-2*s.padding),-1)
                height = 2*s.padding
                for box in boxes:
                    height = max(height,box.rect.y+box.rect.height+2*s.padding)
        return Size(width,_clamp(height,s.min_height,s.max_height))

    def _cross(self, kind: Int32, available: Float32, natural: Float32, align: Int32) -> Float32:
        if kind==CONTENT and align==0 and available>=0:
            return available
        return natural

    def _offset(self, align: Int32, available: Float32, extent: Float32) -> Float32:
        if align==2:
            return available-extent
        if align==3:
            return (available-extent)/2
        return 0

    def _distribute(self, indices: List[Int], mut sizes: List[Float32], available: Float32, horizontal: Bool):
        # Recompute remaining space after every bound freezes a participant.
        var bases = sizes.copy()
        var active = List[Bool]()
        var total = Float32(0)
        for size in sizes:
            total += size
            active.append(True)
        var growing = total<available
        for _ in range(len(sizes)+1):
            var free = available
            var weight = Float32(0)
            for j in range(len(sizes)):
                free -= sizes[j]
                var s = self.nodes[indices[j]].style
                if active[j]:
                    weight += s.grow if growing else s.shrink*bases[j]
            if weight<=0 or abs(free)<0.00001 or (growing and free<0) or (not growing and free>0):
                break
            var froze = False
            for j in range(len(sizes)):
                if not active[j]:
                    continue
                var s = self.nodes[indices[j]].style
                var w = s.grow if growing else s.shrink*bases[j]
                var low = s.min_width if horizontal else s.min_height
                var high = s.max_width if horizontal else s.max_height
                var proposal = sizes[j]+free*w/weight
                var bounded = _clamp(proposal,low,high)
                sizes[j] = bounded
                if bounded!=proposal:
                    active[j] = False
                    froze = True
            if not froze:
                break

    def _boxes(mut self, index: Int, width: Float32, height: Float32) raises -> List[_ChildBox]:
        var s = self.nodes[index].style
        if s.kind==GRID:
            return self._grid_boxes(index,width,height)
        var children = List[Int]()
        var child_keys = self.nodes[index].children.copy()
        for key in child_keys:
            var child = self.indices[key]
            if not self.nodes[child].placed and self.nodes[child].style.kind!=COLLAPSED:
                children.append(child)
        var result = List[_ChildBox]()
        if s.kind==LEAF or s.kind==COLLAPSED:
            return result^
        if s.kind==STACK:
            for child in children:
                var cs = self.nodes[child].style
                var fw = width if cs.width_kind==CONTENT else Float32(-1)
                var fh = height if cs.height_kind==CONTENT else Float32(-1)
                var size = self._size(child,width,height,fw,fh)
                result.append(_ChildBox(child,Rect(0,0,size.width,size.height)))
            return result^
        if s.kind==COLUMN:
            var sizes = List[Size]()
            var heights = List[Float32]()
            for child in children:
                var cs = self.nodes[child].style
                var fw = width if cs.width_kind==CONTENT and s.align==0 else Float32(-1)
                var size = self._size(child,width,height,fw)
                sizes.append(size)
                heights.append(size.height)
            if height>=0:
                self._distribute(children,heights,max(Float32(0),height-Float32(max(0,len(children)-1))*s.gap),False)
            var y = Float32(0)
            for j in range(len(children)):
                var x = self._offset(s.align,width,sizes[j].width)
                if s.rtl!=0:
                    x = width-x-sizes[j].width
                result.append(_ChildBox(children[j],Rect(x,y,sizes[j].width,heights[j])))
                y += heights[j]+s.gap
            return result^
        # Rows and wrapping rows allocate each line independently.
        var widths = List[Float32]()
        for child in children:
            widths.append(self._size(child,width,height).width)
        var starts: List[Int] = [0]
        var used = Float32(0)
        for j in range(len(children)):
            if s.kind==WRAP and j>starts[len(starts)-1] and used+s.gap+widths[j]>width:
                starts.append(j)
                used = 0
            if j>starts[len(starts)-1]:
                used += s.gap
            used += widths[j]
        starts.append(len(children))
        var line_boxes = List[_ChildBox]()
        var line_heights = List[Float32]()
        for line in range(len(starts)-1):
            var ids = List[Int]()
            var allocated = List[Float32]()
            for j in range(starts[line],starts[line+1]):
                ids.append(children[j])
                allocated.append(widths[j])
            self._distribute(ids,allocated,max(Float32(0),width-Float32(max(0,len(ids)-1))*s.gap),True)
            var natural = List[Size]()
            var baseline = Float32(0)
            var descent = Float32(0)
            var cross = Float32(0)
            for j in range(len(ids)):
                var size = self._size(ids[j],width,height,allocated[j])
                natural.append(size)
                cross = max(cross,size.height)
                var b = size.height
                if self.nodes[ids[j]].paragraph:
                    b = self._paragraph(ids[j],size.width).metrics().first_baseline
                baseline = max(baseline,b)
                descent = max(descent,size.height-b)
            if s.align==4:
                cross = max(cross,baseline+descent)
            if s.kind==ROW and height>=0:
                cross = height
            var x = Float32(0)
            for j in range(len(ids)):
                var child_height = self._cross(self.nodes[ids[j]].style.height_kind,cross,natural[j].height,s.align)
                var cs = self.nodes[ids[j]].style
                child_height = _clamp(child_height,cs.min_height,cs.max_height)
                var y = self._offset(s.align,cross,child_height)
                if s.align==4:
                    var b = child_height
                    if self.nodes[ids[j]].paragraph:
                        b = self._paragraph(ids[j],allocated[j]).metrics().first_baseline
                    y = baseline-b
                var origin = x
                if s.rtl!=0:
                    origin = width-x-allocated[j]
                line_boxes.append(_ChildBox(ids[j],Rect(origin,y,allocated[j],child_height)))
                x += allocated[j]+s.gap
            line_heights.append(cross)
        var extra = Float32(0)
        if s.kind==WRAP and height>=0 and len(line_heights)>0:
            var total = Float32(max(0,len(line_heights)-1))*s.gap
            for h in line_heights:
                total += h
            extra = max(Float32(0),height-total)/Float32(len(line_heights))
        var y = Float32(0)
        var cursor = 0
        for line in range(len(line_heights)):
            for _ in range(starts[line],starts[line+1]):
                var box = line_boxes[cursor]
                box.rect.y += y
                if s.kind==WRAP and s.align==0 and self.nodes[box.index].style.height_kind==CONTENT:
                    var cs = self.nodes[box.index].style
                    box.rect.height = _clamp(box.rect.height+extra,cs.min_height,cs.max_height)
                result.append(box)
                cursor += 1
            y += line_heights[line]+extra+s.gap
        return result^

    def _cells(self, index: Int) raises -> List[_GridCell]:
        var columns = max(1,len(self.nodes[index].columns))
        var child_keys = self.nodes[index].children.copy()
        for key in child_keys:
            var i = self.indices[key]
            var s = self.nodes[i].style
            if not self.nodes[i].placed and s.kind!=COLLAPSED:
                columns = max(columns,max(0,Int(s.column)-1)+Int(s.column_span))
        var row_reservations = Dict[Int,Int]()
        var row_auto_spans = Dict[Int,Int]()
        var keys = self.nodes[index].children.copy()
        for key in keys:
            var i = self.indices[key]
            var s = self.nodes[i].style
            if self.nodes[i].placed or s.kind==COLLAPSED or s.row==0:
                continue
            var row = Int(s.row)
            if s.column>0:
                row_reservations[row] = max(row_reservations.get(row,0),Int(s.column)-1+Int(s.column_span))
            else:
                row_auto_spans[row] = row_auto_spans.get(row,0)+Int(s.column_span)
        for row in row_auto_spans:
            columns = max(columns,row_reservations.get(row,0)+row_auto_spans[row])
        var result = List[_GridCell]()
        var occupied = Dict[Int,Bool]()
        # Definite placements reserve their area before auto placement.
        for pass_index in range(2):
            var child_keys = self.nodes[index].children.copy()
            for key in child_keys:
                var i = self.indices[key]
                var s = self.nodes[i].style
                if self.nodes[i].placed or s.kind==COLLAPSED:
                    continue
                var definite = s.column>0 and s.row>0
                if definite!=(pass_index==0):
                    continue
                var column = max(0,Int(s.column)-1)
                var row = max(0,Int(s.row)-1)
                var span_x = Int(s.column_span)
                var span_y = Int(s.row_span)
                if span_x*span_y>1000000:
                    raise Error("Grid span exceeds retained profile capacity")
                if not definite:
                    var found = False
                    for attempt in range(1000000):
                        if s.column==0 and s.row==0:
                            column = attempt%columns
                            row = attempt//columns
                        elif s.column==0:
                            column = attempt
                        else:
                            row = attempt
                        if column+span_x>columns:
                            continue
                        var free = True
                        for y in range(row,row+span_y):
                            for x in range(column,column+span_x):
                                if y*columns+x in occupied:
                                    free = False
                        if free:
                            found = True
                            break
                    if not found:
                        raise Error("Grid auto placement exceeds retained profile capacity")
                for y in range(row,row+span_y):
                    for x in range(column,column+span_x):
                        occupied[y*columns+x] = True
                result.append(_GridCell(i,column,row,span_x,span_y))
        return result^

    def _track_sum(self, tracks: List[Float32], start: Int, count: Int, gap: Float32) -> Float32:
        var total = Float32(max(0,count-1))*gap
        for i in range(start,start+count):
            total += tracks[i]
        return total

    def _grid_tracks(mut self, index: Int, cells: List[_GridCell], available: Float32,
                     vertical: Bool, columns: List[Float32], query: Int = 2) raises -> List[Float32]:
        var s = self.nodes[index].style
        var definitions = self.nodes[index].rows.copy() if vertical else self.nodes[index].columns.copy()
        var count = len(definitions)
        for cell in cells:
            count = max(count,cell.row+cell.rows if vertical else cell.column+cell.columns)
        if not vertical:
            count = max(1,count)
        if count>100000:
            raise Error("Grid track count exceeds retained profile capacity")
        while len(definitions)<count:
            definitions.append(RetainedTrack())
        var minimum = List[Float32]()
        var sizes = List[Float32]()
        var limits = List[Float32]()
        for t in definitions:
            var low = t.minimum if t.min_kind==1 else Float32(0)
            minimum.append(low)
            sizes.append(t.maximum if t.max_kind==1 else low)
            limits.append(t.maximum if t.max_kind==1 else Float32(3.4028234e38))
        # Single spans precede multi-span contributions, preventing double counting.
        for pass_index in range(2):
            for cell in cells:
                var start = cell.row if vertical else cell.column
                var span = cell.rows if vertical else cell.columns
                if (span==1)!=(pass_index==0):
                    continue
                var contribution: Float32
                var min_contribution: Float32
                if vertical:
                    var w = self._track_sum(columns,cell.column,cell.columns,s.gap)
                    var cs = self.nodes[cell.index].style
                    var fw = w if cs.width_kind==CONTENT else Float32(-1)
                    contribution = self._size(cell.index,w,available,fw).height
                    min_contribution = contribution
                else:
                    contribution = self._natural_width(cell.index,query)
                    min_contribution = self._natural_width(cell.index,1)
                var missing = contribution-self._track_sum(sizes,start,span,s.gap)
                var missing_min = min_contribution-self._track_sum(minimum,start,span,s.gap)
                for _ in range(span+1):
                    var eligible = 0
                    for j in range(start,start+span):
                        if definitions[j].max_kind!=1 and sizes[j]<limits[j] and not (definitions[j].max_kind==4 and available>=0):
                            eligible += 1
                    if missing<=0 or eligible==0:
                        break
                    var share = missing/Float32(eligible)
                    for j in range(start,start+span):
                        var t = definitions[j]
                        if t.max_kind!=1 and sizes[j]<limits[j] and not (t.max_kind==4 and available>=0):
                            var wanted = share
                            if t.max_kind==2:
                                wanted = max(Float32(0),min_contribution-self._track_sum(sizes,start,span,s.gap))/Float32(eligible)
                            var added = min(wanted,limits[j]-sizes[j])
                            sizes[j] += added
                            missing -= added
                var eligible_min = 0
                for j in range(start,start+span):
                    if definitions[j].min_kind!=1:
                        eligible_min += 1
                if missing_min>0 and eligible_min>0:
                    for j in range(start,start+span):
                        var t = definitions[j]
                        if t.min_kind!=1:
                            var need = missing_min/Float32(eligible_min)
                            if t.min_kind==3:
                                need = max(need,contribution/Float32(span))
                            minimum[j] = min(limits[j],minimum[j]+need)
                            sizes[j] = max(sizes[j],minimum[j])
        var free = available-Float32(max(0,count-1))*s.gap
        if available<0:
            var unit = Float32(0)
            for j in range(count):
                if definitions[j].max_kind==4 and definitions[j].maximum>0:
                    unit = max(unit,sizes[j]/definitions[j].maximum)
            for j in range(count):
                if definitions[j].max_kind==4:
                    sizes[j] = max(minimum[j],unit*definitions[j].maximum)
            return sizes^
        # Fractional tracks freeze at their minimum before the remaining fr unit.
        var flexible = List[Bool]()
        for t in definitions:
            flexible.append(t.max_kind==4 and t.maximum>0)
        for _ in range(count+1):
            var remainder = free
            var weight = Float32(0)
            for j in range(count):
                if flexible[j]:
                    weight += definitions[j].maximum
                else:
                    remainder -= sizes[j]
            if weight==0:
                break
            var unit = max(Float32(0),remainder)/weight
            var froze = False
            for j in range(count):
                if flexible[j]:
                    var desired = unit*definitions[j].maximum
                    sizes[j] = max(minimum[j],desired)
                    if desired<minimum[j]:
                        flexible[j] = False
                        froze = True
            if not froze:
                break
        var total = Float32(0)
        var auto = 0
        for j in range(count):
            total += sizes[j]
            if definitions[j].max_kind==0:
                auto += 1
        if free>total and auto>0:
            for j in range(count):
                if definitions[j].max_kind==0:
                    sizes[j] += (free-total)/Float32(auto)
        elif free<total:
            var capacity = Float32(0)
            for j in range(count):
                capacity += max(Float32(0),sizes[j]-minimum[j])
            if capacity>0:
                var ratio = min(Float32(1),(total-free)/capacity)
                for j in range(count):
                    sizes[j] -= max(Float32(0),sizes[j]-minimum[j])*ratio
        return sizes^

    def _grid_boxes(mut self, index: Int, width: Float32, height: Float32) raises -> List[_ChildBox]:
        var cells = self._cells(index)
        var s = self.nodes[index].style
        var columns = self._grid_tracks(index,cells,width,False,List[Float32]())
        var rows = self._grid_tracks(index,cells,height,True,columns)
        var result = List[_ChildBox]()
        for cell in cells:
            var x = Float32(0)
            var y = Float32(0)
            for j in range(cell.column):
                x += columns[j]+s.gap
            for j in range(cell.row):
                y += rows[j]+s.gap
            var w = self._track_sum(columns,cell.column,cell.columns,s.gap)
            var h = self._track_sum(rows,cell.row,cell.rows,s.gap)
            var cs = self.nodes[cell.index].style
            var fw = w if cs.width_kind==CONTENT and s.align==0 else Float32(-1)
            var fh = h if cs.height_kind==CONTENT and s.align==0 else Float32(-1)
            var size = self._size(cell.index,w,h,fw,fh)
            x += self._offset(s.align,w,size.width)
            y += self._offset(s.align,h,size.height)
            if s.rtl!=0:
                x = width-x-size.width
            result.append(_ChildBox(cell.index,Rect(x,y,size.width,size.height)))
        return result^

    def _check_tree(self, index: Int, depth: Int, mut visited: Dict[Int,Bool]) raises:
        if depth>256:
            raise Error("Retained tree exceeds maximum depth")
        visited[self.nodes[index].key] = True
        var child_keys = self.nodes[index].children.copy()
        for key in child_keys:
            self._check_tree(self.indices[key],depth+1,visited)

    def _collect(mut self, index: Int, rect: Rect, inherited_clip: Rect,
                 parent_rect: Rect, hidden: Bool, collapsed: Bool,
                 mut outputs: List[GeometryOutput[Self.P]]) raises:
        var s = self.nodes[index].style
        var is_collapsed = collapsed or s.kind==COLLAPSED
        var current = Rect(0,0,0,0) if is_collapsed else rect
        _extent(current.width)
        _extent(current.height)
        if not isfinite(current.x) or not isfinite(current.y):
            raise Error("Retained geometry overflow")
        var is_hidden = hidden or self.nodes[index].hidden or is_collapsed
        var clip = current.intersection(inherited_clip)
        if self.nodes[index].clipped:
            var local = self.nodes[index].clip
            clip = clip.intersection(Rect(parent_rect.x+local.x,parent_rect.y+local.y,local.width,local.height))
        var payload = Self.P()
        if self.nodes[index].paragraph and not is_hidden:
            payload = self._paragraph(index,current.width)
        outputs.append(GeometryOutput[Self.P](self.nodes[index],current,clip,is_hidden,payload))
        var child_clip = inherited_clip
        if s.overflow!=0:
            child_clip = child_clip.intersection(current)
        var boxes = List[_ChildBox]()
        if not is_collapsed:
            boxes = self._boxes(index,max(Float32(0),current.width-2*s.padding),max(Float32(0),current.height-2*s.padding))
        var child_keys = self.nodes[index].children.copy()
        for key in child_keys:
            var child = self.indices[key]
            var allocation = Rect(0,0,0,0)
            if not is_collapsed:
                if self.nodes[child].placed:
                    allocation = self.nodes[child].placement
                    var cs = self.nodes[child].style
                    if allocation.width<cs.min_width or allocation.width>cs.max_width or allocation.height<cs.min_height or allocation.height>cs.max_height:
                        raise Error("Custom allocation violates retained bounds")
                    allocation.x += current.x
                    allocation.y += current.y
                else:
                    for box in boxes:
                        if box.index==child:
                            allocation = box.rect
                            allocation.x += current.x+s.padding
                            allocation.y += current.y+s.padding
                            break
            self._collect(child,allocation,child_clip,current,is_hidden,is_collapsed,outputs)

    def stage(mut self, root: Int, size: Size) raises -> EnginePlan[Self.P]:
        _extent(size.width)
        _extent(size.height)
        var index = self._index(root)
        if self.nodes[index].parent!=0:
            raise Error("Retained layout root is owned by another node")
        var visited = Dict[Int,Bool]()
        self._check_tree(index,0,visited)
        if len(visited)!=len(self.nodes):
            raise Error("Retained layout has unowned nodes")
        var s = self.nodes[index].style
        if size.width<s.min_width or size.width>s.max_width or size.height<s.min_height or size.height>s.max_height:
            raise Error("Root allocation violates retained bounds")
        var snapshot = self.published
        if self._last_root!=root or self._last_revision!=self.revision or self._last_size.width!=size.width or self._last_size.height!=size.height:
            snapshot = EngineSnapshot[Self.P]()
            snapshot.generation = self.published.generation+1
            var rect = Rect(0,0,size.width,size.height)
            self._collect(index,rect,rect,rect,False,False,snapshot.outputs[])
        return EnginePlan[Self.P](snapshot,self.owner,self.revision,self.published.generation,root,size)

    def commit(mut self, plan: EnginePlan[Self.P]) raises -> EngineSnapshot[Self.P]:
        if plan.owner.ptr()!=self.owner.ptr() or plan.revision!=self.revision or plan.base_generation!=self.published.generation:
            raise Error("Stale or foreign retained layout plan")
        if plan.snapshot.generation!=self.published.generation:
            self.published = plan.snapshot
            self.publications += 1
            self._last_revision = self.revision
            self._last_root = plan.root
            self._last_size = plan.size
        return self.published

    def layout(mut self, root: Int, size: Size) raises -> EngineSnapshot[Self.P]:
        return self.commit(self.stage(root,size))
