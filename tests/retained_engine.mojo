"""Portable contracts for Mojo-owned retained flow/grid layout.

The deterministic provider deliberately differs from CoreText. These assertions
cover layout ownership and algorithms without any native link dependency.
"""
from moxi.retained_engine import RetainedEngine, RetainedParagraph, EngineSnapshot, RetainedStyle, RetainedTrack, RetainedPlacement, ROW, COLUMN, WRAP, GRID, STACK, LEAF, COLLAPSED, FIXED, FRACTION, MIN_CONTENT, MAX_CONTENT, FIT_CONTENT
from moxi.geometry import Rect, Size
from moxi.box_layout import BoxMetrics
from std.collections import List
from std.math import ceil
from std.memory import ArcPointer
from std.testing import assert_true, assert_equal, assert_almost_equal


struct Text(RetainedParagraph):
    var value: BoxMetrics
    var source: ArcPointer[String]
    def __init__(out self):
        self.value = BoxMetrics(Size(0,0),0,0)
        self.source = ArcPointer(String(""))
    @staticmethod
    def query(text: String, font: Float32, width: Float32, direction: Int, kind: Int) raises -> Self:
        if text=="FAIL":
            raise Error("Injected provider failure")
        var natural = Float32(text.byte_length())*font
        var w = width
        if kind==1:
            w = min(font,natural)
        elif kind==2:
            w = natural
        var lines = max(Float32(1),ceil(natural/max(w,font)))
        var result = Self()
        result.source = ArcPointer(text)
        if text=="BAD_WIDTH" and kind==0:
            w += 1
        result.value = BoxMetrics(Size(w,lines*font*2),font*1.5,(lines-1)*font*2+font*1.5)
        return result
    def metrics(self) -> BoxMetrics:
        return self.value


def close(a: Float32, b: Float32) raises:
    assert_almost_equal(a,b,atol=0.001)


def box(snapshot: EngineSnapshot[Text], key: Int, x: Float32, y: Float32, w: Float32, h: Float32) raises:
    var r = snapshot.bounds(key)
    close(r.x,x)
    close(r.y,y)
    close(r.width,w)
    close(r.height,h)


def nested_flow() raises:
    var e = RetainedEngine[Text]()
    e.set_node(1,RetainedStyle(padding=10,gap=5))
    e.set_node(2,RetainedStyle(ROW,gap=7,height_kind=FIXED,height=30))
    e.set_node(3,RetainedStyle(LEAF,width_kind=FIXED,width=40))
    e.set_node(4,RetainedStyle(LEAF,grow=1))
    e.set_node(5,RetainedStyle(LEAF,grow=1,min_height=20))
    e.children(1,[2,5])
    e.children(2,[3,4])
    var s = e.layout(1,Size(200,100))
    box(s,3,10,10,40,30)
    box(s,4,57,10,133,30)
    box(s,5,10,45,180,45)
    var mutations = e.mutations
    var again = e.layout(1,Size(200,100))
    assert_equal(again.generation,s.generation)
    assert_equal(e.publications,UInt64(1))
    assert_equal(e.mutations,mutations)
    # Identical declarations remain clean.
    e.set_node(3,RetainedStyle(LEAF,width_kind=FIXED,width=40))
    e.children(2,[3,4])
    assert_equal(e.mutations,mutations)


def flexible_rows() raises:
    var e = RetainedEngine[Text]()
    e.set_node(1,RetainedStyle(ROW))
    e.set_node(2,RetainedStyle(LEAF,grow=1,max_width=30))
    e.set_node(3,RetainedStyle(LEAF,grow=1))
    e.children(1,[2,3])
    var s = e.layout(1,Size(100,20))
    box(s,2,0,0,30,20)
    box(s,3,30,0,70,20)
    for key in [2,3]:
        e.set_node(key,RetainedStyle(LEAF,width_kind=FIXED,width=80))
    s = e.layout(1,Size(100,20))
    close(s.bounds(2).width,80)
    close(s.bounds(3).width,80)
    for key in [2,3]:
        e.set_node(key,RetainedStyle(LEAF,width_kind=FIXED,width=80,shrink=1))
    s = e.layout(1,Size(100,20))
    close(s.bounds(2).width,50)
    close(s.bounds(3).width,50)
    e.set_node(2,RetainedStyle(LEAF,width_kind=FIXED,width=80,shrink=1,min_width=70))
    s = e.layout(1,Size(100,20))
    close(s.bounds(2).width,70)
    close(s.bounds(3).width,30)


def wrap_fraction_rtl() raises:
    var e = RetainedEngine[Text]()
    e.set_node(1,RetainedStyle(WRAP,gap=5,align=1))
    for key in [2,3,4]:
        e.set_node(key,RetainedStyle(LEAF,width_kind=FIXED,width=50.25,height_kind=FIXED,height=20))
    e.children(1,[2,3,4])
    var s = e.layout(1,Size(160.75,100))
    close(s.bounds(4).y,0)
    s = e.layout(1,Size(160.74,100))
    assert_true(s.bounds(4).y>20)
    e.set_node(1,RetainedStyle(ROW,rtl=True))
    e.set_node(2,RetainedStyle(LEAF,width_kind=FRACTION,width=0.25))
    s = e.layout(1,Size(200,100))
    close(s.bounds(2).width,50)
    close(s.bounds(2).x,150)
    assert_true(s.bounds(2).x>s.bounds(3).x)


def paragraphs_and_cache() raises -> EngineSnapshot[Text]:
    var e = RetainedEngine[Text]()
    e.set_node(1,RetainedStyle(ROW,align=4))
    e.set_node(2,RetainedStyle(LEAF),True,"small",10)
    e.set_node(3,RetainedStyle(LEAF),True,"BIG",20)
    e.children(1,[2,3])
    var s = e.layout(1,Size(200,100))
    var a = s.outputs[][1]
    var b = s.outputs[][2]
    close(a.rect.y+a.payload.metrics().first_baseline,b.rect.y+b.payload.metrics().first_baseline)
    close(a.rect.width,a.payload.metrics().size.width)
    var before = e.measurements
    _ = e.layout(1,Size(200,100))
    assert_equal(e.measurements,before)
    e.set_node(1,RetainedStyle())
    for w in range(1,100):
        _ = e.layout(1,Size(Float32(w),100))
    assert_true(len(e.nodes[1].cache)<=8)
    before = e.measurements
    e.invalidate_environment()
    _ = e.layout(1,Size(99,100))
    assert_true(e.measurements>before)
    return s


def ownership_and_failures() raises:
    var e = RetainedEngine[Text]()
    for key in range(1,5):
        e.set_node(key,RetainedStyle())
    e.children(1,[2,3])
    e.children(2,[4])
    var before = e.mutations
    var caught = False
    try:
        e.children(3,[4])
    except:
        caught = True
    assert_true(caught)
    caught = False
    try:
        e.children(4,[1])
    except:
        caught = True
    assert_true(caught)
    caught = False
    try:
        e.children(1,[2,2])
    except:
        caught = True
    assert_true(caught)
    assert_equal(e.mutations,before)
    assert_equal(e.nodes[e.indices[4]].parent,2)
    e.set_node(3,RetainedStyle(LEAF),True,"ok",10)
    var s = e.layout(1,Size(100,100))
    var mount = e.nodes[e.indices[3]].mount
    e.remove(3)
    e.set_node(4,RetainedStyle(LEAF),True,"FAIL",10)
    caught = False
    try:
        _ = e.layout(1,Size(100,100))
    except:
        caught = True
    assert_true(caught)
    assert_equal(len(e.published.outputs[]),3)
    assert_equal(len(s.outputs[]),4)
    e.set_node(3,RetainedStyle(LEAF),True,"new",10)
    assert_true(e.nodes[e.indices[3]].mount>mount)
    # Orphans reject publication.
    caught = False
    try:
        _ = e.stage(1,Size(100,100))
    except:
        caught = True
    assert_true(caught)
    e.children(1,[2,3])
    e.set_node(4,RetainedStyle(LEAF),True,"BAD_WIDTH",10)
    caught = False
    try:
        _ = e.layout(1,Size(100,100))
    except:
        caught = True
    assert_true(caught)
    assert_equal(e.published.generation,s.generation+1)


def grids() raises:
    var e = RetainedEngine[Text]()
    e.set_node(1,RetainedStyle(GRID,gap=10))
    e.tracks(1,[RetainedTrack.fraction(1,30),RetainedTrack.fraction(2,20)])
    e.set_node(2,RetainedStyle(LEAF,column=1,row=1,height_kind=FIXED,height=20))
    e.set_node(3,RetainedStyle(LEAF,column=2,row=1,height_kind=FIXED,height=20))
    e.set_node(4,RetainedStyle(LEAF,column=1,row=2,column_span=2,height_kind=FIXED,height=20))
    e.children(1,[2,3,4])
    var s = e.layout(1,Size(310,100))
    close(s.bounds(2).width,100)
    close(s.bounds(3).width,200)
    close(s.bounds(4).width,310)
    s = e.layout(1,Size(55,100))
    close(s.bounds(2).width,30)
    close(s.bounds(3).width,20)
    # A nested grid sizes its own tracks independently of the outer grid.
    e.set_node(4,RetainedStyle(GRID,column=1,row=2,column_span=2))
    e.tracks(4,[RetainedTrack(3,3)])
    e.set_node(5,RetainedStyle(LEAF),True,"intrinsic",10)
    e.children(4,[5])
    s = e.layout(1,Size(310,160))
    close(s.bounds(5).width,90)
    # Auto placements avoid an explicit reservation, including its span.
    e.set_node(2,RetainedStyle(LEAF,height_kind=FIXED,height=20))
    e.set_node(3,RetainedStyle(LEAF,column=1,row=1,height_kind=FIXED,height=20))
    s = e.layout(1,Size(310,160))
    assert_true(s.bounds(2).x>s.bounds(3).x)
    # Max-content and min-content query the provider, not available width.
    var intrinsic = RetainedEngine[Text]()
    intrinsic.set_node(1,RetainedStyle(GRID,gap=5))
    intrinsic.tracks(1,[RetainedTrack(2,2),RetainedTrack(3,3)])
    intrinsic.set_node(2,RetainedStyle(LEAF),True,"abcd",10)
    intrinsic.set_node(3,RetainedStyle(LEAF),True,"abcdef",10)
    intrinsic.children(1,[2,3])
    s = intrinsic.layout(1,Size(200,100))
    close(s.bounds(2).width,10)
    close(s.bounds(3).width,60)


def visibility_clipping_stack() raises:
    var e = RetainedEngine[Text]()
    e.set_node(1,RetainedStyle(overflow=1))
    e.set_node(2,RetainedStyle(LEAF,height_kind=FIXED,height=60))
    e.set_node(3,RetainedStyle(LEAF,height_kind=FIXED,height=60))
    e.children(1,[2,3])
    e.hide(2,True)
    var s = e.layout(1,Size(100,100))
    box(s,3,0,60,100,60)
    assert_true(s.outputs[][1].hidden)
    close(s.outputs[][2].clip.height,40)
    e.set_node(2,RetainedStyle(COLLAPSED))
    s = e.layout(1,Size(100,100))
    box(s,2,0,0,0,0)
    close(s.bounds(3).y,0)
    e.set_node(1,RetainedStyle(STACK,padding=10))
    e.set_node(2,RetainedStyle(LEAF))
    e.hide(2,False)
    e.clip(3,Rect(5,3,20,4))
    s = e.layout(1,Size(100,100))
    close(s.bounds(2).x,s.bounds(3).x)
    close(s.bounds(2).y,s.bounds(3).y)
    close(s.outputs[][2].clip.x,10)
    close(s.outputs[][2].clip.y,10)
    close(s.outputs[][2].clip.width,15)


def plans_and_validation() raises:
    var e = RetainedEngine[Text]()
    e.set_node(1,RetainedStyle(min_height=50))
    var caught = False
    try:
        _ = e.stage(1,Size(100,20))
    except:
        caught = True
    assert_true(caught)
    assert_equal(e.published.generation,UInt64(0))
    e.set_node(2,RetainedStyle(LEAF,min_width=30))
    e.children(1,[2])
    var s = e.layout(1,Size(200,100))
    var tentative = e.stage(1,Size(300,100))
    assert_equal(e.published.generation,s.generation)
    e.place([RetainedPlacement(2,Rect(10.5,12,70,20))])
    caught = False
    try:
        _ = e.commit(tentative)
    except:
        caught = True
    assert_true(caught)
    var ready = e.stage(1,Size(300,100))
    box(ready.snapshot,2,10.5,12,70,20)
    var other = RetainedEngine[Text]()
    caught = False
    try:
        _ = other.commit(ready)
    except:
        caught = True
    assert_true(caught)
    s = e.commit(ready)
    caught = False
    try:
        _ = e.commit(ready)
    except:
        caught = True
    assert_true(caught)
    var mutations = e.mutations
    caught = False
    try:
        e.place([RetainedPlacement(2,Rect(0,0,80,20)),RetainedPlacement(999,Rect(0,0,80,20))])
    except:
        caught = True
    assert_true(caught)
    assert_equal(e.mutations,mutations)
    e.place([RetainedPlacement(2,Rect(0,0,10,20))])
    caught = False
    try:
        _ = e.stage(1,Size(300,100))
    except:
        caught = True
    assert_true(caught)
    assert_equal(e.published.generation,s.generation)
    e.clear_placement(2)
    close(e.layout(1,Size(300,100)).bounds(2).width,300)
    caught = False
    try:
        e.set_node(9,RetainedStyle(min_width=50,max_width=10))
    except:
        caught = True
    assert_true(caught)
    assert_true(9 not in e.indices)
    caught = False
    try:
        e.set_node(9,RetainedStyle(LEAF,padding=1),True,"text")
    except:
        caught = True
    assert_true(caught)
    e.set_node(3,RetainedStyle(GRID))
    caught = False
    try:
        e.tracks(3,[RetainedTrack(1,1,50,20)])
    except:
        caught = True
    assert_true(caught)


def intrinsic_alignment_and_depth() raises:
    var e = RetainedEngine[Text]()
    e.set_node(1,RetainedStyle(align=2))
    e.set_node(2,RetainedStyle(LEAF,width_kind=FIT_CONTENT,width=25),True,"abcdef",10)
    e.children(1,[2])
    var s = e.layout(1,Size(100,100))
    close(s.bounds(2).width,25)
    close(s.bounds(2).x,75)
    e.set_node(1,RetainedStyle(align=3))
    e.set_node(2,RetainedStyle(LEAF,width_kind=MIN_CONTENT),True,"abcdef",10)
    s = e.layout(1,Size(100,100))
    close(s.bounds(2).width,10)
    close(s.bounds(2).x,45)
    e.set_node(2,RetainedStyle(LEAF,width_kind=MAX_CONTENT),True,"abcdef",10)
    s = e.layout(1,Size(100,100))
    close(s.bounds(2).width,60)
    # Fixed max bounds still receive space when their minimum is smaller.
    e.set_node(1,RetainedStyle(GRID))
    e.tracks(1,[RetainedTrack(1,1,30,60)])
    e.set_node(2,RetainedStyle(LEAF))
    s = e.layout(1,Size(100,100))
    close(s.bounds(2).width,60)
    # Multiple definite-row/automatic-column cells require implicit columns.
    e.set_node(3,RetainedStyle(LEAF,row=1))
    e.set_node(2,RetainedStyle(LEAF,row=1))
    e.children(1,[2,3])
    s = e.layout(1,Size(100,100))
    assert_true(s.bounds(3).x>s.bounds(2).x)
    var deep = RetainedEngine[Text]()
    for key in range(1,260):
        deep.set_node(key,RetainedStyle())
        if key>1:
            deep.children(key-1,[key])
    var caught = False
    try:
        _ = deep.stage(1,Size(100,100))
    except:
        caught = True
    assert_true(caught)
    assert_equal(deep.published.generation,UInt64(0))


def nested_grid_memoization() raises:
    var e = RetainedEngine[Text]()
    for key in range(1,25):
        e.set_node(key,RetainedStyle(GRID))
        e.tracks(key,[RetainedTrack(3,3)])
        if key>1:
            e.children(key-1,[key])
    e.set_node(25,RetainedStyle(LEAF),True,"nested",10)
    e.children(24,[25])
    var s = e.layout(1,Size(200,100))
    close(s.bounds(25).width,60)
    assert_true(e.measurements<10)
    # A new request must discard intrinsic memo entries after text changes.
    e.set_node(25,RetainedStyle(LEAF),True,"changed text",10)
    s = e.layout(1,Size(200,100))
    close(s.bounds(25).width,120)
    # A nonparagraph leaf retains column behavior if it has owned children.
    e.set_node(1,RetainedStyle(LEAF))
    s = e.layout(1,Size(200,100))
    assert_true(s.bounds(25).height>0)


def grid_baseline_and_geometry_overflow() raises:
    var e = RetainedEngine[Text]()
    e.set_node(1,RetainedStyle(GRID,align=4))
    e.tracks(1,[RetainedTrack.fraction(1),RetainedTrack.fraction(1)])
    e.set_node(2,RetainedStyle(LEAF),True,"small",10)
    e.set_node(3,RetainedStyle(LEAF),True,"BIG",20)
    e.children(1,[2,3])
    var s = e.layout(1,Size(100,100))
    close(s.bounds(2).width,50)
    close(s.bounds(3).width,50)
    close(s.bounds(2).y+s.outputs[][1].payload.metrics().first_baseline,
          s.bounds(3).y+s.outputs[][2].payload.metrics().first_baseline)
    e.place([RetainedPlacement(2,Rect(3e38,0,3e38,20))])
    var caught = False
    try:
        _ = e.stage(1,Size(100,100))
    except:
        caught = True
    assert_true(caught)
    assert_equal(e.published.generation,s.generation)


def churn() raises:
    var e = RetainedEngine[Text]()
    e.set_node(1,RetainedStyle())
    for key in range(2,1002):
        e.set_node(key,RetainedStyle(LEAF),True,"replacement",10)
        e.children(1,[key])
        _ = e.layout(1,Size(100,100))
        e.remove(key)
    assert_equal(len(e.nodes),1)
    assert_equal(len(e.published.outputs[]),1)


def main() raises:
    nested_flow()
    flexible_rows()
    wrap_fraction_rtl()
    var detached = paragraphs_and_cache()
    assert_equal(detached.outputs[][1].payload.source[],"small")
    close(detached.outputs[][1].payload.metrics().size.width,50)
    ownership_and_failures()
    grids()
    visibility_clipping_stack()
    plans_and_validation()
    intrinsic_alignment_and_depth()
    nested_grid_memoization()
    grid_baseline_and_geometry_overflow()
    churn()
    print("Mojo retained engine contracts passed")
