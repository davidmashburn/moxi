"""Real Moxi frames, native AX edits/actions, sheets and AppKit drag callbacks."""
from std.ffi import external_call
from moxi.native_instance import MacOSWindowInstance
from moxi.lifecycle_workbench import LifecycleWorkbench, NEXT_ID, REOPEN_ID, ROW_ID_BASE, DIALOG_RESULT_ID, DEEP_OFFSET
from moxi.window import WindowConfig
from moxi.event import NONE_KIND


def check(condition: Bool, message: String) raises:
    if not condition:
        raise Error(message)


def drain(mut window: MacOSWindowInstance, mut model: LifecycleWorkbench) raises:
    for _ in range(64):
        var event = window.poll_event()
        if event.kind == NONE_KIND:
            break
        _ = model.dispatch(event)
    window.submit(model.frame(window.size()))


def assert_ax(window: MacOSWindowInstance, model: LifecycleWorkbench) raises:
    window.activate()
    var text = model.editor.text
    external_call["moxi_lifecycle_assert_ax", NoneType](text.as_c_string_span().ptr(),Int32(model.selected),Int32(1))


def snapshot(window: MacOSWindowInstance, name: String, sheet: Bool = False) raises:
    window.activate()
    var filename = name
    external_call["moxi_lifecycle_snapshot", NoneType](filename.as_c_string_span().ptr(), Int32(sheet))


def main() raises:
    var a=MacOSWindowInstance()
    var b=MacOSWindowInstance()
    var left=LifecycleWorkbench("A")
    var right=LifecycleWorkbench("B")
    a.open(WindowConfig("F02 integration A",560,640),40,850)
    b.open(WindowConfig("F02 integration B",560,640),630,850)
    a.submit(left.frame(a.size()))
    b.submit(right.frame(b.size()))
    snapshot(a,"01-initial-a.png")
    snapshot(b,"02-initial-b.png")
    # B edits a different deep row while A is selected at the native boundary.
    external_call["moxi_lifecycle_press",NoneType](Int32(ROW_ID_BASE+DEEP_OFFSET+2))
    drain(b,right)
    external_call["moxi_lifecycle_capture",NoneType]()
    a.activate()
    var other_edit=String("Beta retained edit")
    external_call["moxi_lifecycle_edit_captured",NoneType](other_edit.as_c_string_span().ptr())
    drain(a,left)
    check(left.editor.text=="A observation 50001", "B edit must not reach A")
    drain(b,right)
    check(right.editor.text==other_edit and right.selected==DEEP_OFFSET+2, "B keeps its distinct edit and selection")
    assert_ax(b,right)
    a.activate()
    external_call["moxi_lifecycle_capture",NoneType]()
    b.activate()
    var edit=String("Alpha deep edit 日本語")
    external_call["moxi_lifecycle_edit_captured",NoneType](edit.as_c_string_span().ptr())
    drain(b,right)
    check(right.editor.text==other_edit, "A edit must not reach B")
    drain(a,left)
    check(left.editor.text==edit, "left.editor.text==edit")
    assert_ax(a,left)
    # AppKit drag callbacks route to captured A, even with B selected.
    snapshot(a,"03-edited-a.png")
    snapshot(b,"04-edited-b.png")
    b.activate()
    external_call["moxi_lifecycle_drag",NoneType]()
    drain(b,right)
    drain(a,left)
    check(left.rows.key_at(DEEP_OFFSET+2)==DEEP_OFFSET, "left.rows.key_at(DEEP_OFFSET+2)==DEEP_OFFSET")
    check(right.rows.key_at(DEEP_OFFSET)==DEEP_OFFSET, "right.rows.key_at(DEEP_OFFSET)==DEEP_OFFSET")
    check(left.selected==DEEP_OFFSET and left.editor.text==edit, "left.selected==DEEP_OFFSET and left.editor.text==edit")
    assert_ax(a,left)
    # Native AX press -> portable page change -> leave and return to stable edit.
    snapshot(a,"05-reordered-a.png")
    external_call["moxi_lifecycle_press",NoneType](Int32(NEXT_ID))
    drain(a,left)
    left.page(DEEP_OFFSET)
    left.select(DEEP_OFFSET)
    a.submit(left.frame(a.size()))
    check(left.editor.text==edit, "left.editor.text==edit")
    # Native menu target ownership and existing portable MenuState result.
    _ = left.menu.show()
    external_call["moxi_lifecycle_menu_choose",NoneType](Int32(1))
    _ = left.menu.activate(1)
    left.menu_result(1)
    check(not left.menu.open and left.offset==DEEP_OFFSET, "not left.menu.open and left.offset==DEEP_OFFSET")
    left.select(DEEP_OFFSET)
    left.menu_result(2)
    external_call["moxi_window_reset_input",NoneType]()
    left.input_reset=False
    a.submit(left.frame(a.size()))
    external_call["moxi_lifecycle_assert_native_selection",NoneType]()
    snapshot(a,"06-selected-text.png")
    a.dialog(left.dialog,DIALOG_RESULT_ID,"Reset A?","Only the selected row")
    snapshot(a,"07-native-sheet.png",True)
    b.activate()
    check(not right.dialog.open, "not right.dialog.open")
    a.activate()
    external_call["moxi_lifecycle_resolve_dialog",NoneType](Int32(0))
    drain(a,left)
    check(not left.dialog.open and left.editor.text==edit, "not left.dialog.open and left.editor.text==edit")
    snapshot(a,"08-cancelled.png")
    a.dialog(left.dialog,DIALOG_RESULT_ID,"Reset A?","Apply test")
    a.activate()
    external_call["moxi_lifecycle_resolve_dialog",NoneType](Int32(1))
    drain(a,left)
    check(not left.dialog.open and left.editor.text=="A observation 50001", "not left.dialog.open and left.editor.text==\"A observation 50001\"")
    snapshot(a,"09-applied.png")
    # Restore a meaningful retained edit through actual AX, then close an open sheet.
    a.activate()
    external_call["moxi_lifecycle_capture",NoneType]()
    external_call["moxi_lifecycle_edit_captured",NoneType](edit.as_c_string_span().ptr())
    drain(a,left)
    a.dialog(left.dialog,DIALOG_RESULT_ID,"Close this sheet","Must not mutate sibling")
    var old=a.handle
    a.close()
    left.retire_native()
    b.activate()
    external_call["moxi_lifecycle_edit_captured",NoneType](edit.as_c_string_span().ptr())
    drain(b,right)
    check(right.editor.text==other_edit and b.is_open(), "B survives A's retired callback")
    snapshot(b,"10-sibling-survives.png")
    a.open(WindowConfig("F02 A reopened",560,640),40,850)
    check(a.handle!=old, "a.handle!=old")
    a.submit(left.frame(a.size()))
    assert_ax(a,left)
    assert_ax(b,right)
    check(left.editor.text==edit and left.selected==DEEP_OFFSET, "left.editor.text==edit and left.selected==DEEP_OFFSET")
    # Title-bar close follows the delegate path; the sibling's AX action requests reopening.
    a.activate()
    external_call["moxi_window_close",NoneType]()
    check(not a.is_open() and b.is_open(), "Closing A must leave B open")
    a.close()
    left.retire_native()
    b.activate()
    external_call["moxi_lifecycle_press",NoneType](Int32(REOPEN_ID))
    drain(b,right)
    check(right.reopen_requested, "B's reopen action reaches B's model")
    a.open(WindowConfig("F02 A reopened again",560,640),40,850)
    a.submit(left.frame(a.size()))
    assert_ax(a,left)
    assert_ax(b,right)
    snapshot(a,"11-reopened-a.png")
    a.close()
    snapshot(b,"12-final-b.png")
    b.close()
    print("F02 Moxi integration: deep edit, AX, native menu/sheet, drag, retained reopen PASS")
