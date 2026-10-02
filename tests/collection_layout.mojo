from std.collections import List
from std.testing import assert_true, assert_equal, assert_almost_equal
from moxi.collection_layout import ExtentIndex, CollectionViewport
from moxi.geometry import Rect


def main() raises:
    var index = ExtentIndex()
    index.sync([1,2,3,4], [Float64(10),0,20,30])
    assert_equal(index.at(0),0)
    assert_equal(index.at(10),2)
    assert_equal(index.at(60),4)
    index.update(1,15)
    assert_almost_equal(index.offset(3), Float64(35))
    index.sync([4,2,1,3], [Float64(30),0,10,20])
    assert_almost_equal(index.extent(2), Float64(15))
    var revision = index.revision
    try:
        index.sync([1,1], [Float64(10),10])
    except:
        pass
    assert_equal(index.revision,revision)
    assert_equal(index.count(),4)
    var table = CollectionViewport()
    var keys = List[Int]()
    var heights = List[Float64]()
    for i in range(100000):
        keys.append(i+1)
        heights.append(24 + Float64(i % 3))
    table.sync_rows(keys,heights)
    table.columns.sync([1,2,3,4,5], [Float64(80),100,120,140,160])
    var viewport = Rect(20,30,300,240)
    var plan = table.stage(viewport,offset_y=50000,frozen_rows=1,frozen_columns=1)
    assert_true(len(plan.cells) < 100)
    assert_equal(table.realized(),0)
    var first_mount = plan.cells[0].mount
    table.commit(plan^)
    assert_true(table.realized()<100)
    var created = table.created
    var next = table.stage(viewport,offset_y=50000,frozen_rows=1,frozen_columns=1)
    assert_equal(next.cells[0].mount,first_mount)
    table.commit(next^)
    assert_equal(table.created,created)
    next = table.stage(viewport,offset_y=50025,frozen_rows=1,frozen_columns=1)
    table.commit(next^)
    assert_true(table.created-created < 15)
    var offset: Float64 = 50000
    var anchor = table.anchor(offset,1)
    offset = table.measure_row(100,74,offset,240,1)
    assert_almost_equal(offset, Float64(50050))
    assert_equal(table.anchor(offset,1).key,anchor.key)
    assert_almost_equal(table.anchor(offset,1).within,anchor.within)
    table.pin_editor(99999)
    next = table.stage(viewport,offset_y=offset,frozen_rows=1,frozen_columns=1)
    var pinned = False
    for cell in next.cells:
        if cell.row_key == 99999:
            pinned = cell.pinned
            assert_equal(cell.clip.height,Float32(0))
    assert_true(pinned)
    table.commit(next^)
    offset = table.focus(100000,offset,240,1)
    assert_true(offset > 2000000)
    next = table.stage(viewport,offset_y=offset,frozen_rows=1,frozen_columns=1,rtl=True)
    var last_visible = False
    for cell in next.cells:
        last_visible = last_visible or cell.row_key == 100000 and cell.clip.height > 0
        if cell.column == 0:
            assert_almost_equal(cell.rect.x, Float32(240))
    assert_true(last_visible)
    # A source mutation invalidates a staged realization without creating slots.
    var old_count = table.realized()
    table.rows.update(1,25)
    var rejected = False
    try:
        table.commit(next^)
    except:
        rejected = True
    assert_true(rejected)
    assert_equal(table.realized(),old_count)
    # Frozen tracks beyond the visible viewport do not realize the whole source.
    next = table.stage(viewport,frozen_rows=100000,frozen_columns=5)
    assert_true(len(next.cells)<100)
    table.pin_editor(10)
    table.pin_editor(11)
    table.pin_editor(12)
    rejected = False
    try:
        table.pin_editor(13)
    except:
        rejected = True
    assert_true(rejected)
    # Width/font changes can retire measured extents while retaining source keys.
    index.invalidate_measurements(40)
    assert_almost_equal(index.total(), Float64(160))
    table.sync_rows([],[])
    assert_equal(table.focused_row,-1)
    next = table.stage(viewport)
    assert_equal(len(next.cells),0)
    table.commit(next^)
    assert_equal(table.realized(),0)
    print("Collection layout contracts passed (100,000 rows)")
