"""Two production Moxi/AppKit windows with independently retained models."""
from std.collections import List
from moxi.lifecycle_workbench import LifecycleWorkbench, DIALOG_RESULT_ID
from moxi.native_instance import MacOSWindowInstance
from moxi.window import WindowConfig
from moxi.event import NONE_KIND
from std.ffi import external_call


def open_window(mut window: MacOSWindowInstance, name: String, x: Float32) raises:
    var config = WindowConfig(String("Moxi lifecycle · ", name),560,640)
    config.resizable = False
    window.open(config,x,850)


def step(mut window: MacOSWindowInstance, mut model: LifecycleWorkbench) raises:
    if not window.is_open():
        if window.handle != 0:
            window.close()
            model.retire_native()
        return
    window.pump()
    var dirty = False
    for _ in range(64):
        var event = window.poll_event()
        if event.kind == NONE_KIND:
            break
        dirty = model.dispatch(event) or dirty
        if model.input_reset:
            window.activate()
            external_call["moxi_window_reset_input", NoneType]()
            model.input_reset = False
    if model.menu_requested:
        model.menu_requested = False
        var labels: List[String] = ["Jump to start","Jump to row 50001","Select editor text"]
        var chosen = window.menu(model.menu,labels,256,144)
        model.menu_result(chosen)
        if model.input_reset:
            window.activate()
            external_call["moxi_window_reset_input", NoneType]()
            model.input_reset = False
        dirty = True
    if model.dialog_requested:
        model.dialog_requested = False
        window.dialog(model.dialog,DIALOG_RESULT_ID,String("Reset row ",model.selected+1," in ",model.name,"?"),"Apply restores this label. Other rows and the other window are unchanged.")
        dirty = True
    if dirty and window.is_open():
        window.submit(model.frame(window.size()))


def main() raises:
    var a = MacOSWindowInstance()
    var b = MacOSWindowInstance()
    var left = LifecycleWorkbench("A")
    var right = LifecycleWorkbench("B")
    open_window(a,"A",40)
    open_window(b,"B",630)
    a.submit(left.frame(a.size()))
    b.submit(right.frame(b.size()))
    left.input_reset = False
    right.input_reset = False
    while a.is_open() or b.is_open():
        step(a,left)
        step(b,right)
        if left.reopen_requested:
            left.reopen_requested = False
            if not b.is_open():
                b.close()
                right.retire_native()
                open_window(b,"B",630)
                b.submit(right.frame(b.size()))
        if right.reopen_requested:
            right.reopen_requested = False
            if not a.is_open():
                a.close()
                left.retire_native()
                open_window(a,"A",40)
                a.submit(left.frame(a.size()))
        # Bounded wait lets both sessions consume their queues fairly.
        if a.is_open():
            a.wait(0.02)
        elif b.is_open():
            b.wait(0.02)
    a.close()
    b.close()
