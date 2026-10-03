from std.testing import assert_true, assert_equal, assert_almost_equal
from moxi.layout_workbench import LayoutWorkbench
from moxi.geometry import Size, Point
from moxi.event import Event, TextInputEvent, CompositionEvent
from moxi.accessibility import ROLE_DIALOG, ROLE_MENU


def main() raises:
    var screen = LayoutWorkbench()
    var wide = screen.frame(Size(1100,800))
    assert_true(screen.table.realized()<200)
    assert_true(wide.snapshot.bounds(20).x>wide.snapshot.bounds(10).x)
    # Input, paint and AX all consume the same final cell rectangle.
    var first = wide.snapshot.output(1011)
    assert_equal(wide.hit_test(Point(first.rect.x+4,first.rect.y+4)),1011)
    var second = wide.snapshot.output(1012)
    assert_equal(wide.hit_test(Point(second.rect.x+4,second.rect.y+4)),1012)
    var ax = wide.snapshot.accessibility()
    assert_equal(ax.node_for_id(13).label,String("Dataset"))
    assert_equal(ax.node_for_id(13).value,screen.editor.text)
    var found = False
    for node in ax.nodes:
        if node.id==1012:
            assert_equal(node.bounds.x,second.rect.x)
            assert_equal(node.bounds.y,second.rect.y)
            found = True
    assert_true(found)
    var pane_mount = wide.snapshot.output(10).mount
    var editor_mount = wide.snapshot.output(13).mount
    var measurements = screen.tree.measurements()
    var builds = screen.form.solver_builds
    var same = screen.frame(Size(1100,800))
    assert_equal(screen.tree.measurements(),measurements)
    assert_equal(screen.form.solver_builds,builds)
    screen.summary = True
    var summary = screen.frame(Size(1100,800))
    assert_true(summary.snapshot.bounds(8).y>wide.snapshot.bounds(8).y)
    screen.editor.anchor = 2
    screen.editor.set_composition("にほん",1,2)
    screen.edit_row(100)
    screen.cell_editor.set_composition("かな",0,1)
    var narrow = screen.frame(Size(540,900))
    assert_equal(narrow.snapshot.output(10).mount,pane_mount)
    assert_equal(narrow.snapshot.output(13).mount,editor_mount)
    assert_true(narrow.snapshot.bounds(20).y>narrow.snapshot.bounds(10).y)
    assert_equal(screen.editor.composition,String("にほん"))
    assert_equal(screen.editor.anchor,2)
    assert_equal(screen.cell_editor.composition,String("かな"))
    var cell = 1000+100*10+2
    var narrow_ax = narrow.snapshot.accessibility()
    assert_equal(narrow_ax.node_for_id(13).label,String("Dataset"))
    assert_equal(narrow_ax.node_for_id(cell).label,String("Value, region 100, column 2"))
    assert_equal(narrow_ax.node_for_id(cell).value,screen.cell_editor.text)
    var mount = narrow.snapshot.output(cell).mount
    screen.offset_y = 50000
    var scrolled = screen.frame(Size(540,900))
    assert_equal(scrolled.snapshot.output(cell).mount,mount)
    assert_equal(scrolled.snapshot.output(cell).clip.height,Float32(0))
    assert_equal(scrolled.snapshot.output(cell).semantics.label,String("Value, region 100, column 2"))
    screen.open_popup()
    var popup = screen.frame(Size(540,900))
    var popup_button = popup.snapshot.bounds(92)
    assert_equal(popup.hit_test(Point(popup_button.x+4,popup_button.y+4)),92)
    assert_true(popup.snapshot.bounds(90).width<=540)
    assert_equal(screen.popups.top_bounds().y,popup.snapshot.bounds(90).y)
    var menu_ax = popup.accessibility()
    assert_true(menu_ax.is_valid())
    assert_equal(menu_ax.node_for_id(90).role,ROLE_MENU)
    assert_equal(menu_ax.node_for_id(13).label,String("Dataset"))
    var anchor_y = popup.snapshot.bounds(90).y
    screen.summary = False
    var moved = screen.frame(Size(1100,800))
    assert_true(moved.snapshot.bounds(90).y!=anchor_y)
    screen.close_popup()
    screen.open_popup(modal=True)
    var dialog = screen.frame(Size(1100,800))
    var dialog_ax = dialog.accessibility()
    assert_true(dialog_ax.is_valid())
    assert_equal(dialog_ax.count(),5)
    assert_equal(dialog_ax.node_for_id(90).role,ROLE_DIALOG)
    assert_true(dialog_ax.node_for_id(90).expanded)
    assert_equal(dialog_ax.node_for_id(90).parent_id,-1)
    assert_true(dialog_ax.node_for_id(92).focused)
    assert_equal(dialog_ax.node_for_id(13).id,-1)
    assert_equal(dialog_ax.node_for_id(46).id,-1)
    # Modal AX scope leaves the background's geometry and paint intact.
    assert_equal(dialog.snapshot.output(13).mount,editor_mount)
    var background_painted = False
    for command in dialog.commands:
        background_painted = background_painted or command.id==13
    assert_true(background_painted)
    screen.focused = 93
    var resized_dialog = screen.frame(Size(540,900))
    var resized_dialog_ax = resized_dialog.accessibility()
    assert_true(resized_dialog_ax.is_valid())
    assert_equal(resized_dialog_ax.count(),5)
    assert_true(resized_dialog_ax.node_for_id(93).focused)
    assert_true(screen.popups.traps_focus())
    assert_true(not screen.popups.allows_focus(13))
    screen.close_popup()
    assert_equal(screen.focused,cell)
    var published = screen.frame(Size(1100,800))
    var restored_ax = published.accessibility()
    assert_true(restored_ax.is_valid())
    assert_equal(restored_ax.node_for_id(13).label,String("Dataset"))
    assert_true(restored_ax.node_for_id(cell).focused)
    assert_equal(restored_ax.node_for_id(90).id,-1)
    screen.conflict = True
    var rejected = False
    try:
        _ = screen.frame(Size(1100,800))
    except:
        rejected = True
    assert_true(rejected)
    assert_equal(screen.recovery().snapshot.generation,published.snapshot.generation)
    screen.conflict = False
    screen.rtl = True
    var rtl = screen.frame(Size(1100,800))
    assert_true(rtl.snapshot.bounds(10).x>rtl.snapshot.bounds(20).x)
    assert_true(rtl.snapshot.bounds(18).x<rtl.snapshot.bounds(10).x)
    assert_almost_equal(rtl.snapshot.bounds(18).x+9,rtl.snapshot.bounds(10).x)
    screen.set_rows(0)
    _ = screen.frame(Size(1100,800))
    assert_equal(screen.table.realized(),0)
    screen.set_rows(100000)
    screen.text_scale = 1.25
    _ = screen.frame(Size(1100,800))
    assert_true(screen.table.realized()<200)
    var large = screen.frame(Size(2000,1400))
    assert_true(len(large.commands)>128)
    assert_true(len(large.commands)<1024)
    # Removing the active row closes its editor even if the following solve fails.
    screen.open_popup(modal=True)
    screen.set_rows(0)
    screen.close_popup()
    assert_equal(screen.focused,13)
    screen.conflict = True
    try:
        _ = screen.frame(Size(2000,1400))
    except:
        pass
    var removed = screen.recovery()
    for command in removed.commands:
        assert_true(command.id<1000)
    # Repeated simultaneous strategy changes and injected conflicts preserve one publication.
    var churn = LayoutWorkbench(100000)
    for iteration in range(250):
        churn.summary = iteration%3==0
        churn.rtl = iteration%2==0
        churn.offset_y = Float64(iteration*48)
        churn.offset_x = Float64(iteration%4*60)
        churn.form_width = Float32(280+iteration%5*12)
        var size = Size(Float32(1100 if iteration%2==0 else 540),900)
        var current = churn.frame(size)
        assert_true(churn.table.realized()<200)
        var generation = current.snapshot.generation
        if iteration%7==0:
            churn.conflict = True
            var failed = False
            try:
                _ = churn.frame(size)
            except:
                failed = True
            assert_true(failed)
            assert_equal(churn.recovery().snapshot.generation,generation)
            churn.conflict = False
    # Host capacity rejects before any geometry or recycler lifecycle publishes.
    var bounded = LayoutWorkbench()
    var accepted = bounded.frame(Size(1100,800))
    var created = bounded.table.created
    var capacity_rejected = False
    try:
        _ = bounded.frame(Size(1100,20000))
    except:
        capacity_rejected = True
    assert_true(capacity_rejected)
    assert_equal(bounded.recovery().snapshot.generation,accepted.snapshot.generation)
    assert_equal(bounded.table.created,created)
    var recovered = bounded.frame(Size(1100,800))
    assert_equal(recovered.snapshot.output(13).mount,accepted.snapshot.output(13).mount)
    # Addressed AX edits follow their semantic target rather than keyboard focus.
    var routed = LayoutWorkbench(4)
    routed.edit_row(2)
    var routed_cell = 1022
    var original_cell_text = routed.cell_editor.text
    var dataset_write = Event(TextInputEvent("Dataset 日本語",0,routed.editor.text.count_codepoints()))
    dataset_write.set_target(13)
    assert_true(routed.handle_text_input(dataset_write))
    assert_equal(routed.editor.text,String("Dataset 日本語"))
    assert_equal(routed.cell_editor.text,original_cell_text)
    assert_equal(routed.focused,routed_cell)
    for focus in [13,40]:
        routed.focused = focus
        var cell_write = Event(TextInputEvent(String("Cell ",focus),0,routed.cell_editor.text.count_codepoints()))
        cell_write.set_target(routed_cell)
        assert_true(routed.handle_text_input(cell_write))
        assert_equal(routed.cell_editor.text,String("Cell ",focus))
        assert_equal(routed.editor.text,String("Dataset 日本語"))
        assert_equal(routed.focused,focus)
    var composition = Event(CompositionEvent("かな",0,1))
    composition.set_target(routed_cell)
    assert_true(routed.handle_text_input(composition))
    assert_equal(routed.cell_editor.composition,String("かな"))
    assert_equal(routed.editor.composition,String(""))
    var composition_end = Event(CompositionEvent())
    composition_end.set_target(routed_cell)
    assert_true(routed.handle_text_input(composition_end))
    assert_equal(routed.cell_editor.composition,String(""))
    var invalid_write = Event(TextInputEvent("Wrong editor"))
    invalid_write.set_target(9999)
    assert_true(not routed.handle_text_input(invalid_write))
    routed.edit_row(3)
    invalid_write.set_target(routed_cell)
    assert_true(not routed.handle_text_input(invalid_write))
    routed.focused = 13
    assert_true(routed.handle_text_input(Event(TextInputEvent("!"))))
    assert_equal(routed.editor.text,String("Dataset 日本語!"))
    routed.focused = 1032
    assert_true(routed.handle_text_input(Event(TextInputEvent("!"))))
    assert_equal(routed.cell_editor.text,String("Cell 40!"))
    routed.open_popup(modal=True)
    assert_true(not routed.handle_text_input(dataset_write))
    composition.set_target(13)
    assert_true(not routed.handle_text_input(composition))
    assert_equal(routed.editor.text,String("Dataset 日本語!"))
    assert_equal(routed.editor.composition,String(""))
    routed.close_popup()
    routed.set_rows(0)
    invalid_write.set_target(1032)
    assert_true(not routed.handle_text_input(invalid_write))
    assert_equal(routed.cell_editor.text,String("Cell 40!"))
    # Rejected popup transitions recover the scope and focus actually painted.
    var faulted = LayoutWorkbench(4)
    var published_normal = faulted.frame(Size(1100,800))
    faulted.conflict = True
    faulted.open_popup(modal=True)
    var rejected_open = False
    try:
        _ = faulted.frame(Size(1100,800))
    except:
        rejected_open = True
    assert_true(rejected_open)
    var recovered_normal = faulted.recovery()
    var recovered_normal_ax = recovered_normal.accessibility()
    assert_equal(recovered_normal.snapshot.generation,published_normal.snapshot.generation)
    assert_equal(recovered_normal.snapshot.bounds(13).x,published_normal.snapshot.bounds(13).x)
    assert_true(recovered_normal_ax.is_valid())
    assert_equal(recovered_normal.accessibility_root,-1)
    assert_equal(recovered_normal_ax.node_for_id(90).id,-1)
    assert_true(recovered_normal_ax.node_for_id(13).focused)
    assert_equal(recovered_normal.focused,published_normal.focused)
    faulted.conflict = False
    faulted.focused = 93
    var published_dialog = faulted.frame(Size(1100,800))
    faulted.conflict = True
    faulted.close_popup()
    var rejected_close = False
    try:
        _ = faulted.frame(Size(1100,800))
    except:
        rejected_close = True
    assert_true(rejected_close)
    var recovered_dialog = faulted.recovery()
    var recovered_dialog_ax = recovered_dialog.accessibility()
    assert_equal(recovered_dialog.snapshot.generation,published_dialog.snapshot.generation)
    assert_equal(recovered_dialog.snapshot.bounds(90).x,published_dialog.snapshot.bounds(90).x)
    assert_true(recovered_dialog_ax.is_valid())
    assert_equal(recovered_dialog.accessibility_root,90)
    assert_equal(recovered_dialog_ax.count(),5)
    assert_equal(recovered_dialog_ax.node_for_id(90).role,ROLE_DIALOG)
    assert_equal(recovered_dialog_ax.node_for_id(13).id,-1)
    assert_true(recovered_dialog_ax.node_for_id(93).focused)
    assert_equal(recovered_dialog.focused,published_dialog.focused)
    # Source removal overrides cached focus even when the next solve is rejected.
    faulted.conflict = False
    faulted.edit_row(2)
    _ = faulted.frame(Size(1100,800))
    faulted.set_rows(0)
    faulted.conflict = True
    var rejected_remove = False
    try:
        _ = faulted.frame(Size(1100,800))
    except:
        rejected_remove = True
    assert_true(rejected_remove)
    var removed_focus = faulted.recovery()
    assert_equal(removed_focus.focused,13)
    assert_true(removed_focus.accessibility().node_for_id(13).focused)
    print("Composed layout workbench contracts passed")
