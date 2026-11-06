"""Recursive math geometry; one publication for drawing, caret, hit and semantics."""
from std.collections import List, Dict
from std.math import abs
from moxi.geometry import Point, Rect
from moxi.text_boundary import next_text_boundary
from .model import MathDocument, MathKind
from .editor import MathPosition
from .font import MathFont, MathGlyph, MathConstant

struct _Measure(ImplicitlyCopyable):
    var width: Float32
    var height: Float32
    var baseline: Float32
    var glyphs: List[MathGlyph]
    var rules: List[Rect]
    var positions: List[Point]
    var sizes: List[Float32]
    var columns: List[Float32]
    var missing: Bool
    def __init__(out self):
        self.width = 0
        self.height = 0
        self.baseline = 0
        self.glyphs = List[MathGlyph]()
        self.rules = List[Rect]()
        self.positions = List[Point]()
        self.sizes = List[Float32]()
        self.columns = List[Float32]()
        self.missing = False
    def __init__(out self, *, copy: Self):
        self.width = copy.width
        self.height = copy.height
        self.baseline = copy.baseline
        self.glyphs = copy.glyphs.copy()
        self.rules = copy.rules.copy()
        self.positions = copy.positions.copy()
        self.sizes = copy.sizes.copy()
        self.columns = copy.columns.copy()
        self.missing = copy.missing

struct MathRegion(ImplicitlyCopyable):
    var id: Int
    var bounds: Rect
    var baseline: Float32
    var label: String
    var value: String
    var diagnostic: Bool
    def __init__(out self, id: Int, bounds: Rect, baseline: Float32, label: String, value: String, diagnostic: Bool = False):
        self.id = id
        self.bounds = bounds
        self.baseline = baseline
        self.label = label
        self.value = value
        self.diagnostic = diagnostic

struct MathCaret(ImplicitlyCopyable):
    var position: MathPosition
    var bounds: Rect
    def __init__(out self, position: MathPosition, bounds: Rect):
        self.position = position
        self.bounds = bounds

struct MathSnapshot(ImplicitlyCopyable):
    var glyphs: List[MathGlyph]
    var rules: List[Rect]
    var regions: List[MathRegion]
    var carets: List[MathCaret]
    var width: Float32
    var height: Float32
    var baseline: Float32
    var generation: Int
    var measured_nodes: Int
    def __init__(out self):
        self.glyphs = List[MathGlyph]()
        self.rules = List[Rect]()
        self.regions = List[MathRegion]()
        self.carets = List[MathCaret]()
        self.width = 0
        self.height = 0
        self.baseline = 0
        self.generation = 0
        self.measured_nodes = 0
    def __init__(out self, *, copy: Self):
        self.glyphs = copy.glyphs.copy()
        self.rules = copy.rules.copy()
        self.regions = copy.regions.copy()
        self.carets = copy.carets.copy()
        self.width = copy.width
        self.height = copy.height
        self.baseline = copy.baseline
        self.generation = copy.generation
        self.measured_nodes = copy.measured_nodes
    def bounds(self, id: Int) -> Rect:
        for region in self.regions:
            if region.id == id:
                return region.bounds
        return Rect(0, 0, 1, 24)
    def caret(self, position: MathPosition) -> Rect:
        for stop in self.carets:
            if stop.position.id == position.id and stop.position.offset == position.offset:
                return stop.bounds
        var box = self.bounds(position.id)
        return Rect(box.x + box.width, box.y, 1.5, box.height)
    def hit(self, point: Point) -> MathPosition:
        var best = MathPosition()
        var distance: Float32 = 1e30
        for stop in self.carets:
            var r = stop.bounds
            var dx = abs(point.x-r.x)
            var dy = max(Float32(0), max(r.y-point.y, point.y-r.y-r.height))
            var score = dx*dx + dy*dy*4
            if score < distance:
                distance = score
                best = stop.position
        return best
    def vertical(self, position: MathPosition, direction: Int, preferred_x: Float32 = -1) -> MathPosition:
        var from_rect = self.caret(position)
        var x = from_rect.x if preferred_x < 0 else preferred_x
        var best = position
        var score: Float32 = 1e30
        var cy = from_rect.y+from_rect.height/2
        for stop in self.carets:
            var dy = stop.bounds.y+stop.bounds.height/2-cy
            if dy*Float32(direction) > 2:
                var distance = abs(stop.bounds.x-x)*2 + abs(dy)
                if distance < score:
                    score = distance
                    best = stop.position
        return best

struct MathLayout(ImplicitlyCopyable):
    var cache: Dict[String, _Measure]
    var snapshot: MathSnapshot
    var font: MathFont
    var last_text: String
    var last_ids: String
    var last_size: Float32
    var measured: Int
    def __init__(out self):
        self.cache = Dict[String, _Measure]()
        self.snapshot = MathSnapshot()
        self.font = MathFont()
        self.last_text = ""
        self.last_ids = ""
        self.last_size = 0
        self.measured = 0
    def __init__(out self, *, copy: Self):
        self.cache = copy.cache.copy()
        self.snapshot = copy.snapshot
        self.font = copy.font
        self.last_text = copy.last_text
        self.last_ids = copy.last_ids
        self.last_size = copy.last_size
        self.measured = copy.measured
    def _key(self, doc: MathDocument, i: Int, size: Float32) -> String:
        return doc.print_node(i) + "|" + String(size)
    def _text(self, text: String, size: Float32) -> _Measure:
        var b = _Measure()
        b.glyphs = self.font.shape(text, size)
        b.baseline = size*.8
        var descent = size*.2
        for g in b.glyphs:
            b.width = max(b.width, g.x + max(g.advance, self.font.metric(g.id, size, 3)+self.font.metric(g.id,size,4)))
            b.baseline = max(b.baseline, self.font.metric(g.id,size,1)-g.y)
            descent = max(descent,self.font.metric(g.id,size,2)+g.y)
            b.missing = b.missing or g.id == 0
        b.width = max(b.width, size*.4)
        b.height = b.baseline+descent
        for j in range(len(b.glyphs)):
            b.glyphs[j].y += b.baseline
        return b^
    def _append_stretch(self, mut box: _Measure, cp: Int, size: Float32, height: Float32, x: Float32, y: Float32) -> Float32:
        var glyphs = self.font.stretch(cp, size, height)
        var width: Float32 = 0
        for g in glyphs:
            width = max(width,g.advance)
            var item = g
            item.x += x
            item.y += y
            box.glyphs.append(item)
        return width
    def _measure(mut self, doc: MathDocument, i: Int, size: Float32) raises -> _Measure:
        var key = self._key(doc,i,size)
        if key in self.cache:
            return self.cache[key]
        self.measured += 1
        var n = doc.nodes[i]
        var b = _Measure()
        var small = max(Float32(9), size*self.font.constant(MathConstant.SCRIPT_SCALE,size))
        var gap = size*.18
        if n.kind == MathKind.TOKEN or n.kind == MathKind.ERROR:
            var display=n.text if n.text != "" else "□"
            if n.kind==MathKind.ERROR and display.count_codepoints()>160:
                display=String(display[codepoint=0:160])+"… [full literal in Text]"
            b = self._text(display, size)
            b.missing = b.missing or n.kind == MathKind.ERROR
        elif n.kind == MathKind.HOLE:
            b.width=size*.55; b.height=size; b.baseline=size*.8
        else:
            var children = List[_Measure]()
            for j in range(len(n.children)):
                var child_size = size
                if n.kind == MathKind.SCRIPTS and j > 0:
                    child_size = Float32(9) if doc.nodes[n.children[j]].kind==MathKind.HOLE else small
                elif n.kind == MathKind.ROOT and j == 0:
                    child_size = small*.8
                elif (n.kind == MathKind.SUM or n.kind == MathKind.INTEGRAL) and j < 3:
                    child_size = small
                b.sizes.append(child_size)
                children.append(self._measure(doc,n.children[j],child_size))
                b.positions.append(Point(0,0))
            if n.kind == MathKind.ROW:
                for c in children:
                    b.baseline=max(b.baseline,c.baseline)
                var descent: Float32 = size*.2
                for j in range(len(children)):
                    var c=children[j]
                    b.positions[j]=Point(b.width,b.baseline-c.baseline)
                    var token=doc.nodes[n.children[j]].text
                    var space=gap if token in "+−-=<>≤≥×*" and token != "" else Float32(0)
                    b.positions[j].x += space
                    b.width += c.width+space*2
                    descent=max(descent,c.height-c.baseline)
                b.height=b.baseline+descent
                if len(children)==0:
                    b.width=size*.5; b.height=size; b.baseline=size*.8
            elif n.kind == MathKind.FRACTION:
                var a=children[0]; var d=children[1]
                var rule=max(Float32(.7),self.font.constant(MathConstant.FRACTION_RULE,size))
                var above=max(gap,self.font.constant(MathConstant.NUM_GAP,size))
                var below=max(gap,self.font.constant(MathConstant.DEN_GAP,size))
                b.width=max(a.width,d.width)+gap*2
                b.positions[0]=Point((b.width-a.width)/2,0)
                b.rules.append(Rect(0,a.height+above,b.width,rule))
                b.positions[1]=Point((b.width-d.width)/2,a.height+above+rule+below)
                b.height=b.positions[1].y+d.height
                b.baseline=a.height+above+rule/2+self.font.constant(MathConstant.AXIS,size)
            elif n.kind == MathKind.SCRIPTS:
                var base=children[0]; var sub=children[1]; var sup=children[2]
                var under=children[3]; var over=children[4]
                var above=max(base.baseline-size*.3,max(sup.height*.65,self.font.constant(MathConstant.SUPER_SHIFT,size)))
                var below=max(base.height-base.baseline-small*.2,max(sub.height*.45,self.font.constant(MathConstant.SUB_SHIFT,size)))
                var top=over.height+gap+above
                var base_x=max(Float32(0),(max(over.width,under.width)-base.width)/2)
                b.positions[0]=Point(base_x,top)
                var italic: Float32=0
                if len(base.glyphs)>0:
                    italic=self.font.metric(base.glyphs[len(base.glyphs)-1].id,size,5)
                var script_x=base_x+base.width+italic+size*.06
                b.positions[2]=Point(script_x,top+base.baseline-above-sup.baseline)
                b.positions[1]=Point(script_x,top+base.baseline+below-sub.baseline)
                var min_gap=self.font.constant(MathConstant.SCRIPT_GAP,size)
                b.positions[1].y=max(b.positions[1].y,b.positions[2].y+sup.height+min_gap)
                b.width=max(script_x+max(sub.width,sup.width),max(under.width,over.width))
                b.positions[4]=Point((b.width-over.width)/2,0)
                b.positions[3]=Point((b.width-under.width)/2,max(top+base.height,b.positions[1].y+sub.height)+gap)
                b.height=b.positions[3].y+under.height
                b.baseline=top+base.baseline
            elif n.kind == MathKind.ROOT:
                var index=children[0]; var body=children[1]
                var rule=max(Float32(.7),self.font.constant(MathConstant.RADICAL_RULE,size))
                var top=max(index.height*.4,gap)
                var root_gap=max(gap,self.font.constant(MathConstant.RADICAL_GAP,size))
                var radical_width=self._append_stretch(b,0x221a,size,body.height+root_gap+rule,index.width*.6,top)
                b.positions[0]=Point(0,top+body.height*.2)
                b.positions[1]=Point(index.width*.6+radical_width,top+root_gap+rule)
                b.width=b.positions[1].x+body.width+gap
                b.height=b.positions[1].y+body.height
                b.baseline=b.positions[1].y+body.baseline
                b.rules.append(Rect(b.positions[1].x,top,b.width-b.positions[1].x,rule))
            elif n.kind == MathKind.GROUP or n.kind == MathKind.FUNCTION:
                var c=children[0]
                var prefix: Float32=0
                if n.kind == MathKind.FUNCTION:
                    var name=self._text(n.text,size)
                    b.glyphs=name.glyphs.copy()
                    prefix=name.width+gap
                var left=0x28; var right=0x29
                if n.kind == MathKind.GROUP:
                    for cp in n.text.codepoints():
                        left=Int(cp); break
                    for cp in n.extra.codepoints():
                        right=Int(cp); break
                var width=self._append_stretch(b,left,size,c.height+gap*2,prefix,0)
                b.positions[0]=Point(prefix+width+gap,gap)
                var right_width=self._append_stretch(b,right,size,c.height+gap*2,b.positions[0].x+c.width+gap,0)
                b.width=b.positions[0].x+c.width+gap+right_width
                b.height=c.height+gap*2
                b.baseline=c.baseline+gap
                if n.kind == MathKind.FUNCTION:
                    for j in range(len(b.glyphs)):
                        if b.glyphs[j].x<prefix:
                            b.glyphs[j].y += b.baseline-size*.8
            elif n.kind == MathKind.MATRIX:
                var cols=len(doc.nodes[n.children[0]].children)
                for _ in range(cols):
                    b.columns.append(0)
                for row in n.children:
                    for col in range(cols):
                        var c=self._measure(doc,doc.nodes[row].children[col],size)
                        b.columns[col]=max(b.columns[col],c.width)
                var total: Float32=gap*2
                for w in b.columns:
                    total+=w+gap*2
                var y=gap
                for j in range(len(n.children)):
                    var c=children[j]
                    b.positions[j]=Point(size*.5,y)
                    y+=c.height+gap
                b.height=y
                b.baseline=b.height/2+self.font.constant(MathConstant.AXIS,size)
                var left=self._append_stretch(b,0x5b,size,b.height,0,0)
                for j in range(len(b.positions)):
                    b.positions[j].x=left+gap
                var right=self._append_stretch(b,0x5d,size,b.height,left+total,0)
                b.width=left+total+right
            elif n.kind == MathKind.SUM or n.kind == MathKind.INTEGRAL:
                var variable=children[0]; var lower=children[1]; var upper=children[2]; var body=children[3]
                var op_size=size*1.5
                var op=self._text("∑" if n.kind==MathKind.SUM else "∫",op_size)
                var equals=self._text("=",small)
                var left=max(op.width,max(upper.width,lower.width))
                if n.kind==MathKind.SUM:
                    left=max(left,variable.width+equals.width+lower.width+gap*2)
                var op_y=upper.height+gap
                for g in op.glyphs:
                    var glyph=g
                    glyph.x+=(left-op.width)/2
                    glyph.y+=op_y
                    b.glyphs.append(glyph)
                b.positions[2]=Point((left-upper.width)/2,0)
                var bottom=op_y+op.height+gap
                b.positions[1]=Point((left-lower.width)/2,bottom)
                b.positions[3]=Point(left+gap,max(Float32(0),op_y+op.baseline-body.baseline))
                b.width=left+gap+body.width
                b.baseline=b.positions[3].y+body.baseline
                if n.kind==MathKind.SUM:
                    b.positions[0]=Point(0,bottom)
                    b.positions[1]=Point(variable.width+equals.width+gap*2,bottom)
                    for g in equals.glyphs:
                        var glyph=g
                        glyph.x+=variable.width+gap
                        glyph.y+=bottom
                        b.glyphs.append(glyph)
                else:
                    var differential=self._text("d",size)
                    for g in differential.glyphs:
                        var glyph=g
                        glyph.x+=b.width+gap
                        glyph.y+=b.baseline-differential.baseline
                        b.glyphs.append(glyph)
                    b.positions[0]=Point(b.width+gap+differential.width+gap/2,b.baseline-variable.baseline)
                    b.width=b.positions[0].x+variable.width
                b.height=max(bottom+max(variable.height,lower.height),b.positions[3].y+body.height)
        # Contain real font ink, including negative bearings and MATH assemblies.
        var min_x: Float32=0
        var min_y: Float32=0
        var max_x=b.width
        var max_y=b.height
        for glyph in b.glyphs:
            min_x=min(min_x,glyph.x+self.font.metric(glyph.id,glyph.size,3))
            min_y=min(min_y,glyph.y-self.font.metric(glyph.id,glyph.size,1))
            max_x=max(max_x,glyph.x+self.font.metric(glyph.id,glyph.size,3)+self.font.metric(glyph.id,glyph.size,4))
            max_y=max(max_y,glyph.y+self.font.metric(glyph.id,glyph.size,2))
        if min_x<0 or min_y<0:
            for j in range(len(b.glyphs)):
                b.glyphs[j].x-=min_x; b.glyphs[j].y-=min_y
            for j in range(len(b.positions)):
                b.positions[j].x-=min_x; b.positions[j].y-=min_y
            for j in range(len(b.rules)):
                b.rules[j].x-=min_x; b.rules[j].y-=min_y
            b.baseline-=min_y
        b.width=max_x-min_x; b.height=max_y-min_y
        self.cache[key]=b
        return b^

    def _emit(mut self, doc: MathDocument, i: Int, size: Float32, x: Float32, y: Float32) raises:
        var n=doc.nodes[i]
        var b=self.cache[self._key(doc,i,size)]
        self.snapshot.regions.append(MathRegion(n.id,Rect(x,y,b.width,b.height),y+b.baseline,role_label(n.kind),n.text,b.missing))
        for g in b.glyphs:
            var placed=g
            placed.x+=x; placed.y+=y
            self.snapshot.glyphs.append(placed)
        for rule in b.rules:
            self.snapshot.rules.append(Rect(x+rule.x,y+rule.y,rule.width,rule.height))
        if len(n.children)==0:
            var offset=0
            while True:
                var caret_x: Float32=0
                if offset>0:
                    var prefix=String(n.text[codepoint=0:offset])
                    var bytes=prefix.byte_length()
                    for glyph in b.glyphs:
                        if glyph.cluster<bytes:
                            caret_x=max(caret_x,glyph.x+glyph.advance)
                self.snapshot.carets.append(MathCaret(MathPosition(n.id,offset),Rect(x+caret_x,y,1.5,b.height)))
                if offset>=n.text.count_codepoints() or (n.kind==MathKind.ERROR and offset>=160):
                    break
                offset=next_text_boundary(n.text,offset)
        elif n.kind==MathKind.MATRIX:
            for row_index in range(len(n.children)):
                var row=n.children[row_index]
                var row_box=self.cache[self._key(doc,row,size)]
                var row_y=y+b.positions[row_index].y
                var col_x=x+b.positions[row_index].x
                self.snapshot.regions.append(MathRegion(doc.nodes[row].id,Rect(col_x,row_y,b.width-2*b.positions[row_index].x,row_box.height),row_y+row_box.baseline,"matrix row",""))
                for col in range(len(b.columns)):
                    var cell=doc.nodes[row].children[col]
                    var cell_box=self.cache[self._key(doc,cell,size)]
                    self._emit(doc,cell,size,col_x+(b.columns[col]-cell_box.width)/2,row_y+row_box.baseline-cell_box.baseline)
                    col_x+=b.columns[col]+size*.36
        else:
            for j in range(len(n.children)):
                self._emit(doc,n.children[j],b.sizes[j],x+b.positions[j].x,y+b.positions[j].y)
    def publish(mut self, doc: MathDocument, size: Float32 = 32) raises:
        var text=doc.text()
        var ids=String("")
        for node in doc.nodes:
            ids+=String(node.id)+","
        if text==self.last_text and ids==self.last_ids and size==self.last_size:
            self.snapshot.measured_nodes=0
            return
        if len(self.cache)>40000:
            self.cache.clear()
        self.measured=0
        var b=self._measure(doc,doc.root,size)
        var generation=self.snapshot.generation+1
        self.snapshot=MathSnapshot()
        self.snapshot.width=b.width
        self.snapshot.height=b.height
        self.snapshot.baseline=b.baseline
        self.snapshot.generation=generation
        self._emit(doc,doc.root,size,0,0)
        self.snapshot.measured_nodes=self.measured
        self.last_text=text
        self.last_ids=ids
        self.last_size=size

def role_label(kind: MathKind) -> String:
    if kind==MathKind.FRACTION:
        return "fraction · numerator, denominator"
    if kind==MathKind.ROOT:
        return "radical · index, radicand"
    if kind==MathKind.SCRIPTS:
        return "scripts · base, subscript, superscript, under, over"
    if kind==MathKind.MATRIX:
        return "matrix · rows and cells"
    if kind==MathKind.SUM:
        return "sum · variable, lower, upper, body"
    if kind==MathKind.INTEGRAL:
        return "integral · variable, lower, upper, body"
    if kind==MathKind.HOLE:
        return "empty slot"
    if kind==MathKind.ERROR:
        return "malformed text · preserved literally"
    if kind==MathKind.TOKEN: return "math token"
    if kind==MathKind.ROW: return "expression row"
    if kind==MathKind.GROUP: return "delimited expression"
    if kind==MathKind.FUNCTION: return "function application"
    return "unsupported math node"
