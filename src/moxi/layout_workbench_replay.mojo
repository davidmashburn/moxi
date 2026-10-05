"""Shared workbench event routing, chart projection and normalized replay.

The native demo and headless acceptance lane consume the same controller.
Only LayoutWorkbench owns application/layout state; this controller retains
pointer capture between normalized input events, without a window handle.
"""

from std.collections import List
from std.math import sin
from .layout_workbench import LayoutWorkbench
from .retained_leaf import RetainedPresentation
from .geometry import Point, Rect, Size
from .scene import Scene
from .style import Color
from .event_replay import EventReplay
from .event import Event, NONE_KIND, WINDOW_RESIZED_KIND, POINTER_DOWN_KIND, POINTER_UP_KIND, POINTER_MOVE_KIND, POINTER_CANCEL_KIND, CLICK_KIND, SCROLL_KIND, TEXT_INPUT_KIND, KEY_DOWN_KIND, COMPOSITION_UPDATE_KIND, COMPOSITION_END_KIND, KEY_ESCAPE, KEY_TAB, KEY_DOWN, KEY_UP, KEY_END, KEY_HOME, KEY_LEFT, KEY_RIGHT, DRAG_UPDATE_KIND, DROP_KIND, ACTION_KIND, KEY_ENTER, KEY_SPACE, MOD_SHIFT
from .event import ResizeEvent, TextInputEvent, CompositionEvent, KeyEvent, PointerEvent, ScrollEvent, SemanticActionEvent
from .accessibility import ACTION_PRESS
from .clipboard import ClipboardBackend
from .event import MOD_COMMAND, MOD_CONTROL, KEY_C, KEY_X, KEY_V


struct WorkbenchController:
    var pressed: Int
    var dragging: Bool

    def __init__(out self):
        self.pressed = -1
        self.dragging = False

    def dispatch_with_clipboard[ClipboardType: ClipboardBackend](
        mut self, mut screen: LayoutWorkbench, presentation: RetainedPresentation,
        event: Event, size: Size, mut clipboard: ClipboardType,
    ) raises -> Bool:
        if event.kind == KEY_DOWN_KIND and (event.modifiers & (MOD_COMMAND | MOD_CONTROL)) != 0 and not screen.popups.traps_focus():
            if screen.focused == 13 or screen.focused >= 1000:
                if event.key == KEY_C or event.key == KEY_X:
                    var text = screen.editor.selected_text() if screen.focused == 13 else screen.cell_editor.selected_text()
                    if text.count_codepoints() > 0:
                        clipboard.copy(text)
                elif event.key == KEY_V:
                    var text = clipboard.paste()
                    if screen.focused == 13:
                        screen.editor.clipboard = text
                    else:
                        screen.cell_editor.clipboard = text
        return self.dispatch(screen, presentation, event, size)

    def dispatch(
        mut self,
        mut screen: LayoutWorkbench,
        presentation: RetainedPresentation,
        event: Event,
        size: Size,
    ) raises -> Bool:
        """Apply one normalized event using the demo's shared focus/capture policy."""
        var dirty = False
        if event.kind==WINDOW_RESIZED_KIND:
            self.dragging = False
            self.pressed = -1
            if screen.focused==18 and size.width<760:
                screen.focused = 13
            dirty = True
        var target = presentation.hit_test(event.position)
        var activate = -1
        if event.kind==POINTER_DOWN_KIND:
            self.pressed = target
            self.dragging = target==18
            if screen.popups.traps_focus() and (target<92 or target>94):
                self.pressed = -1
                self.dragging = False
            elif target==18:
                screen.focused = 18
                dirty = True
            elif target==13:
                screen.focused = 13
                dirty = True
            elif target>=1000:
                screen.edit_row((target-1000)//10)
                dirty = True
        elif (event.kind==POINTER_MOVE_KIND or event.kind==DRAG_UPDATE_KIND) and self.dragging:
            var pane = presentation.snapshot.bounds(10)
            screen.form_width = max(Float32(240),min(Float32(500),pane.x+pane.width-event.position.x if screen.rtl else event.position.x-pane.x))
            dirty = True
        elif event.kind==POINTER_UP_KIND or event.kind==DROP_KIND:
            if target==self.pressed:
                activate = target
            self.pressed = -1
            self.dragging = False
        elif event.kind==POINTER_CANCEL_KIND:
            self.pressed = -1
            self.dragging = False
        elif event.kind==CLICK_KIND:
            activate = target
        elif event.kind==ACTION_KIND:
            activate = event.target
            if screen.popups.traps_focus() and (activate<92 or activate>94):
                activate = -1
        elif event.kind==SCROLL_KIND and not screen.popups.traps_focus():
            screen.offset_y = max(Float64(0),screen.offset_y+Float64(event.scroll_delta.y))
            screen.offset_x = max(Float64(0),screen.offset_x+Float64(event.scroll_delta.x))
            dirty = True
        elif event.kind==KEY_DOWN_KIND:
            if event.key==KEY_ESCAPE:
                screen.close_popup()
                dirty = True
            elif screen.popups.is_open():
                if event.key==KEY_TAB or event.key==KEY_DOWN:
                    screen.focused = 92+(screen.focused-92+(2 if event.key==KEY_TAB and (event.modifiers & MOD_SHIFT)!=0 else 1))%3
                    dirty = True
                elif event.key==KEY_UP:
                    screen.focused = 92+(screen.focused-92+2)%3
                    dirty = True
                elif event.key==KEY_ENTER or event.key==KEY_SPACE:
                    activate = screen.focused
            elif event.key==KEY_TAB:
                var order: List[Int] = [13,40,41,42,43,44,45,46]
                if size.width>=760:
                    order.append(18)
                order.append(21)
                var next = 13
                for index in range(len(order)):
                    if order[index]==screen.focused:
                        next = order[(index+len(order)+(-1 if (event.modifiers & MOD_SHIFT)!=0 else 1))%len(order)]
                screen.focused = next
                dirty = True
            elif (event.key==KEY_ENTER or event.key==KEY_SPACE) and screen.focused>=40 and screen.focused<=46:
                activate = screen.focused
            elif screen.focused==18 and (event.key==KEY_LEFT or event.key==KEY_RIGHT):
                screen.form_width = max(Float32(240),min(Float32(500),screen.form_width+Float32(-10 if (event.key==KEY_LEFT)!=screen.rtl else 10)))
                dirty = True
            elif screen.focused==21 and screen.table.rows.count()>0:
                var row = max(1,screen.table.focused_row)
                if event.key==KEY_DOWN:
                    row = min(screen.table.rows.count(),row+1)
                elif event.key==KEY_UP:
                    row = max(1,row-1)
                elif event.key==KEY_END:
                    row = screen.table.rows.count()
                elif event.key==KEY_HOME:
                    row = 1
                screen.offset_y = screen.table.focus(row,screen.offset_y,Float64(presentation.snapshot.bounds(21).height),1)
                dirty = True
            elif screen.focused==13:
                dirty = screen.editor.handle_key(event.key,event.modifiers) or dirty
            elif screen.focused>=1000:
                dirty = screen.cell_editor.handle_key(event.key,event.modifiers) or dirty
        elif event.kind==TEXT_INPUT_KIND or event.kind==COMPOSITION_UPDATE_KIND or event.kind==COMPOSITION_END_KIND:
            dirty = screen.handle_text_input(event) or dirty
        if screen.popups.traps_focus() and (activate<92 or activate>94):
            activate = -1
        if activate==40:
            screen.summary = not screen.summary
        elif activate==41:
            screen.rtl = not screen.rtl
        elif activate==42:
            screen.open_popup()
        elif activate==43:
            screen.conflict = not screen.conflict
        elif activate==44:
            screen.set_rows(100000 if screen.table.rows.count()==0 else 0)
        elif activate==45:
            screen.text_scale = 1.25 if screen.text_scale==1 else 1
        elif activate==46:
            screen.open_popup(modal=True)
        elif activate>=92 and activate<=94:
            screen.close_popup()
        if activate>=40 and activate<=94:
            dirty = True
        return dirty


def layout_workbench_chart(bounds: Rect) -> Scene:
    """Canonical chart geometry used by native and software frame consumers."""
    var scene = Scene()
    scene.append_rect(2200,bounds,Color(0.10,0.14,0.21,1))
    var border = Color(0.24,0.34,0.44,1)
    scene.append_line(2201,Point(bounds.x,bounds.y),Point(bounds.x+bounds.width,bounds.y),border,1)
    scene.append_line(2202,Point(bounds.x+bounds.width,bounds.y),Point(bounds.x+bounds.width,bounds.y+bounds.height),border,1)
    scene.append_line(2203,Point(bounds.x+bounds.width,bounds.y+bounds.height),Point(bounds.x,bounds.y+bounds.height),border,1)
    scene.append_line(2204,Point(bounds.x,bounds.y+bounds.height),Point(bounds.x,bounds.y),border,1)
    for i in range(1,121):
        var x0 = Float32(i-1)/120
        var x1 = Float32(i)/120
        scene.append_line(
            2210+i,
            Point(bounds.x+16+x0*(bounds.width-32),bounds.y+bounds.height*(0.5-0.25*sin(x0*12))),
            Point(bounds.x+16+x1*(bounds.width-32),bounds.y+bounds.height*(0.5-0.25*sin(x1*12))),
            Color(0.35,0.85,0.75,1),2,
        )
    return scene^


comptime WORKBENCH_REPLAY_ROWS = 128


def canonical_layout_workbench_replay() raises -> EventReplay:
    """Form, retained collection, IME, responsive layout and modal fixture.

    Generate content coordinates from the canonical workbench at its initial
    size, so a native text provider's metrics cannot turn a cell click into a
    different target. The resulting JSON is reusable by a native or headless
    driver with the same fixture size and font provider.
    """
    var replay = EventReplay()
    var screen = LayoutWorkbench(WORKBENCH_REPLAY_ROWS)
    var initial = screen.frame(Size(1100,800))
    var cell = initial.snapshot.bounds(1012)
    var point = Point(cell.x+4,cell.y+4)
    replay.append(Event(ResizeEvent(Size(1100,800))))
    var dataset = Event(TextInputEvent("Observations 日本語",0,screen.editor.text.count_codepoints()))
    dataset.set_target(13)
    replay.append(dataset)
    var composition = Event(CompositionEvent("かな",0,1))
    composition.set_target(13)
    replay.append(composition)
    replay.append(Event(KeyEvent(KEY_TAB)))
    var cancelled = Event(CompositionEvent())
    cancelled.set_target(13)
    replay.append(cancelled)
    replay.append(Event(SemanticActionEvent(40,ACTION_PRESS)))
    replay.append(Event(ResizeEvent(Size(540,900))))
    replay.append(Event(KeyEvent(KEY_TAB,MOD_SHIFT)))
    dataset = Event(TextInputEvent("気温",0,String("Observations 日本語").count_codepoints()))
    dataset.set_target(13)
    replay.append(dataset)
    replay.append(Event(ResizeEvent(Size(1100,800))))
    replay.append(Event(SemanticActionEvent(40,ACTION_PRESS)))
    var down = PointerEvent(POINTER_DOWN_KIND,point,7,1)
    down.set_modifiers(MOD_SHIFT)
    replay.append(Event(down))
    replay.append(Event(PointerEvent(POINTER_UP_KIND,point,7,0)))
    var cell_text = Event(TextInputEvent("24.5",0,screen.cell_editor.text.count_codepoints()))
    cell_text.set_target(1012)
    replay.append(cell_text)
    composition = Event(CompositionEvent("にほん",1,2))
    composition.set_target(1012)
    replay.append(composition)
    replay.append(Event(ScrollEvent(point,Point(80,200))))
    cancelled.set_target(1012)
    replay.append(cancelled)
    replay.append(Event(SemanticActionEvent(46,ACTION_PRESS)))
    replay.append(Event(SemanticActionEvent(40,ACTION_PRESS)))
    dataset = Event(TextInputEvent("Blocked",0,2))
    dataset.set_target(13)
    replay.append(dataset)
    replay.append(Event(KeyEvent(KEY_TAB,MOD_SHIFT)))
    replay.append(Event(KeyEvent(KEY_ENTER)))
    replay.append(Event(SemanticActionEvent(41,ACTION_PRESS)))
    replay.append(Event(ResizeEvent(Size(540,900))))
    replay.append(Event(SemanticActionEvent(42,ACTION_PRESS)))
    replay.append(Event(KeyEvent(KEY_ESCAPE)))
    replay.append(Event(SemanticActionEvent(44,ACTION_PRESS)))
    replay.append(Event(SemanticActionEvent(44,ACTION_PRESS)))
    return replay^
