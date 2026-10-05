"""Shared normalized event/semantic replay and software chart acceptance."""

from std.testing import assert_equal, assert_true

from moxi.event import WINDOW_RESIZED_KIND
from moxi.event_replay import event_replay_from_json
from moxi.layout_workbench import LayoutWorkbench
from moxi.layout_workbench_replay import WorkbenchController, WORKBENCH_REPLAY_ROWS, canonical_layout_workbench_replay, layout_workbench_chart
from moxi.geometry import Point, Rect, Size
from moxi.paint import paint_semantics_equal
from moxi.retained_leaf import RetainedPresentation
from moxi.accessibility import ROLE_DIALOG, ROLE_CANVAS, ROLE_TEXT_INPUT
from moxi.software import SoftwareSceneRenderer
from moxi.frame import SurfaceMetrics
from moxi.clipboard import MemoryClipboard
from moxi.event import Event, KeyEvent, KEY_A, KEY_C, KEY_X, KEY_V, MOD_COMMAND, MOD_CONTROL


def _assert_same_frame(left: RetainedPresentation, right: RetainedPresentation, size: Size = Size(1100,800)) raises:
    assert_equal(left.snapshot.generation,right.snapshot.generation)
    assert_equal(len(left.commands),len(right.commands))
    for index in range(len(left.commands)):
        assert_true(left.commands[index].equivalent(right.commands[index]))
    var left_ax = left.accessibility()
    var right_ax = right.accessibility()
    assert_true(left_ax.is_valid())
    assert_true(right_ax.is_valid())
    assert_equal(left_ax.count(),right_ax.count())
    for index in range(left_ax.count()):
        assert_true(paint_semantics_equal(left_ax.nodes[index],right_ax.nodes[index]))
    # The exact same publication also supplies the host-independent packet.
    var metrics = SurfaceMetrics(size,2)
    var left_packet = left.packet(metrics)
    var right_packet = right.packet(metrics)
    assert_equal(left_packet.generation,right_packet.generation)
    assert_equal(left_packet.metrics.pixel_width(),Int(size.width*2))
    assert_equal(left_packet.metrics.pixel_height(),Int(size.height*2))
    assert_equal(len(left_packet.commands),len(right_packet.commands))
    assert_equal(len(left_packet.resources),len(right_packet.resources))
    for index in range(len(left_packet.commands)):
        assert_true(left_packet.commands[index].equivalent(right_packet.commands[index]))
    for index in range(len(left_packet.resources)):
        var resource = left_packet.resources[index]
        var other = right_packet.resources[index]
        assert_equal(resource.id,other.id)
        assert_equal(resource.mount,other.mount)
        assert_equal(resource.command_index,other.command_index)
        assert_equal(left_packet.commands[resource.command_index].id,resource.id)
        assert_equal(left_packet.commands[resource.command_index].resource_id,resource.id)
        assert_equal(resource.mount,left.snapshot.output(resource.id).mount)
    assert_equal(left_packet.semantics.count(),left_ax.count())
    for index in range(left_ax.count()):
        assert_true(paint_semantics_equal(left_packet.semantics.nodes[index],left_ax.nodes[index]))
        assert_true(paint_semantics_equal(right_packet.semantics.nodes[index],right_ax.nodes[index]))


def _workbench_replay() raises:
    var fixture = canonical_layout_workbench_replay()
    var decoded = event_replay_from_json(fixture.to_json())
    assert_equal(len(fixture.events),28)
    var live = LayoutWorkbench(WORKBENCH_REPLAY_ROWS)
    var replayed = LayoutWorkbench(WORKBENCH_REPLAY_ROWS)
    var live_controller = WorkbenchController()
    var replay_controller = WorkbenchController()
    var size = Size(1100,800)
    var live_frame = live.frame(size)
    var replay_frame = replayed.frame(size)
    _assert_same_frame(live_frame,replay_frame)
    var editor_mount = live_frame.snapshot.output(13).mount
    var normal_body_y = live_frame.snapshot.bounds(8).y
    for index in range(len(fixture.events)):
        var event = fixture.events[index]
        if event.kind==WINDOW_RESIZED_KIND:
            size = event.size
        var changed = live_controller.dispatch(live,live_frame,event,size)
        var replay_changed = replay_controller.dispatch(replayed,replay_frame,decoded.events[index],size)
        assert_equal(changed,replay_changed)
        if changed:
            live_frame = live.frame(size)
            replay_frame = replayed.frame(size)
        _assert_same_frame(live_frame,replay_frame,size)
        assert_equal(live_frame.snapshot.output(13).mount,editor_mount)
        assert_true(live.table.realized()<200)
        var semantics = replay_frame.accessibility()
        if index==1:
            var dataset = semantics.node_for_id(13)
            assert_equal(dataset.role,ROLE_TEXT_INPUT)
            assert_equal(dataset.label,String("Dataset"))
            assert_equal(dataset.value,String("Observations 日本語"))
            assert_true(dataset.focused)
        elif index==2:
            assert_equal(replayed.editor.composition,String("かな"))
            assert_equal(replayed.editor.composition_selection_start,0)
            assert_equal(replayed.editor.composition_selection_end,1)
        elif index==4:
            assert_equal(replayed.editor.composition,String(""))
            assert_equal(replayed.focused,40)
        elif index==5:
            assert_true(replayed.summary)
            assert_true(replay_frame.snapshot.bounds(8).y>normal_body_y)
        elif index==6:
            assert_true(replay_frame.snapshot.bounds(20).y>replay_frame.snapshot.bounds(10).y)
        elif index==8:
            assert_equal(semantics.node_for_id(13).value,String("気温"))
        elif index==11:
            assert_equal(replayed.editing_row,1)
            assert_equal(replayed.focused,1012)
        elif index==13:
            var cell = semantics.node_for_id(1012)
            assert_equal(cell.role,ROLE_TEXT_INPUT)
            assert_equal(cell.label,String("Value, region 1, column 2"))
            assert_equal(cell.value,String("24.5"))
            assert_true(cell.focused)
        elif index==14:
            assert_equal(replayed.cell_editor.composition,String("にほん"))
        elif index==15:
            assert_equal(replayed.offset_y,Float64(200))
            assert_equal(replayed.cell_editor.composition,String("にほん"))
        elif index==17 or index==18 or index==19:
            assert_equal(semantics.count(),5)
            assert_equal(semantics.node_for_id(90).role,ROLE_DIALOG)
            assert_equal(semantics.node_for_id(13).id,-1)
            assert_equal(semantics.node_for_id(22).id,-1)
            assert_true(not replayed.summary)
            assert_equal(replayed.editor.text,String("気温"))
        elif index==20:
            assert_equal(replayed.focused,94)
            assert_true(semantics.node_for_id(94).focused)
        elif index==21:
            assert_equal(replayed.focused,1012)
            assert_equal(semantics.node_for_id(90).id,-1)
            assert_equal(semantics.node_for_id(22).role,ROLE_CANVAS)
        elif index==22:
            assert_true(replayed.rtl)
            assert_true(replay_frame.snapshot.bounds(10).x>replay_frame.snapshot.bounds(20).x)
        elif index==26:
            assert_equal(replayed.table.rows.count(),0)
            assert_equal(replayed.focused,13)
        elif index==27:
            assert_equal(replayed.table.rows.count(),100000)
            assert_equal(semantics.node_for_id(21).value,String("100000 rows, 4 columns"))
    assert_equal(replayed.cell_editor.text,String("24.5"))
    assert_equal(replayed.cell_editor.composition,String(""))


def _software_plot_oracle() raises:
    # The native demo uses this exact scene helper. Software coverage is
    # geometric: platform text rasterization stays outside this checksum.
    var scene = layout_workbench_chart(Rect(0,0,160,100))
    assert_equal(len(scene.commands),125)
    var renderer = SoftwareSceneRenderer(160,100)
    renderer.render_scene(scene)
    assert_equal(renderer.command_count,125)
    assert_true(renderer.rasterized_pixels>16000)
    var checksum = renderer.checksum()
    assert_equal(checksum,53751903)
    var second = SoftwareSceneRenderer(160,100)
    second.render_scene(scene)
    assert_equal(second.checksum(),checksum)
    print("Workbench software chart checksum:",checksum)


def _clipboard_routing() raises:
    # Exercise the native demo's exact controller with both desktop modifiers.
    for modifier in [MOD_COMMAND, MOD_CONTROL]:
        var screen = LayoutWorkbench(WORKBENCH_REPLAY_ROWS)
        var controller = WorkbenchController()
        var clipboard = MemoryClipboard()
        var size = Size(1100,800)
        var frame = screen.frame(size)
        screen.focused = 13
        screen.editor.text = "日本語 🦊"
        screen.editor.cursor = screen.editor.text.count_codepoints()
        assert_true(controller.dispatch_with_clipboard(screen,frame,Event(KeyEvent(KEY_A,modifier)),size,clipboard))
        assert_equal(screen.editor.selected_text(),String("日本語 🦊"))
        _ = controller.dispatch_with_clipboard(screen,frame,Event(KeyEvent(KEY_C,modifier)),size,clipboard)
        assert_equal(clipboard.paste(),String("日本語 🦊"))
        assert_true(controller.dispatch_with_clipboard(screen,frame,Event(KeyEvent(KEY_X,modifier)),size,clipboard))
        assert_equal(screen.editor.text,String(""))
        assert_true(controller.dispatch_with_clipboard(screen,frame,Event(KeyEvent(KEY_V,modifier)),size,clipboard))
        assert_equal(screen.editor.text,String("日本語 🦊"))
        screen.edit_row(1)
        frame = screen.frame(size)
        _ = controller.dispatch_with_clipboard(screen,frame,Event(KeyEvent(KEY_A,modifier)),size,clipboard)
        assert_true(controller.dispatch_with_clipboard(screen,frame,Event(KeyEvent(KEY_V,modifier)),size,clipboard))
        assert_equal(screen.cell_editor.text,String("日本語 🦊"))
        screen.open_popup(modal=True)
        frame = screen.frame(size)
        clipboard.copy("keep")
        _ = controller.dispatch_with_clipboard(screen,frame,Event(KeyEvent(KEY_C,modifier)),size,clipboard)
        assert_equal(clipboard.paste(),String("keep"))
        _ = controller.dispatch_with_clipboard(screen,frame,Event(KeyEvent(KEY_V,modifier)),size,clipboard)
        assert_equal(screen.cell_editor.text,String("日本語 🦊"))


def main() raises:
    _workbench_replay()
    _software_plot_oracle()
    _clipboard_routing()
    print("Moxi normalized workbench replay passed")
