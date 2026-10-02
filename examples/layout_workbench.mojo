"""Native acceptance screen for the optional mixed layout candidate."""
from std.math import sin
from std.collections import List
from moxi.layout_workbench import LayoutWorkbench
from moxi.geometry import Point, Rect
from moxi.macos import MacOSRenderer, MacOSWindow, MacOSCanvasPainter
from moxi.window import WindowConfig
from moxi.style import Color
from moxi.event import NONE_KIND, WINDOW_RESIZED_KIND, POINTER_DOWN_KIND, POINTER_UP_KIND, POINTER_MOVE_KIND, POINTER_CANCEL_KIND, CLICK_KIND, SCROLL_KIND, TEXT_INPUT_KIND, KEY_DOWN_KIND, COMPOSITION_UPDATE_KIND, COMPOSITION_END_KIND, KEY_ESCAPE, KEY_TAB, KEY_DOWN, KEY_UP, KEY_END, KEY_HOME, KEY_LEFT, KEY_RIGHT, DRAG_UPDATE_KIND, DROP_KIND, ACTION_KIND, KEY_ENTER, KEY_SPACE, MOD_SHIFT


def main() raises:
    var screen = LayoutWorkbench()
    var window = MacOSWindow()
    var renderer = MacOSRenderer()
    var painter = MacOSCanvasPainter()
    var config = WindowConfig("Moxi · Composed layout workbench",1100,800)
    config.set_min_size(500,760)
    window.open(config)
    var presentation = screen.frame(window.size())
    var dirty = True
    var pressed = -1
    var dragging = False
    while window.is_open():
        if dirty:
            try:
                presentation = screen.frame(window.size())
            except error:
                screen.error = String(error)
                print("Layout rejected; retaining previous publication:",screen.error)
                presentation = screen.recovery()
            renderer.begin_frame()
            presentation.draw(renderer,custom_layer=22)
            var chart = presentation.snapshot.bounds(22)
            painter.begin(chart.intersection(Rect(0,0,window.size().width,window.size().height)))
            painter.fill_rect(chart,Color(0.10,0.14,0.21,1),Color(0.24,0.34,0.44,1),1)
            for i in range(1,121):
                var x0 = Float32(i-1)/120
                var x1 = Float32(i)/120
                painter.line(Point(chart.x+16+x0*(chart.width-32),chart.y+chart.height*(0.5-0.25*sin(x0*12))),Point(chart.x+16+x1*(chart.width-32),chart.y+chart.height*(0.5-0.25*sin(x1*12))),Color(0.35,0.85,0.75,1),2)
            painter.end()
            dirty = False
        window.pump()
        var event = window.poll_event()
        while event.kind != NONE_KIND:
            if event.kind==WINDOW_RESIZED_KIND:
                dragging = False
                pressed = -1
                if screen.focused==18 and window.size().width<760:
                    screen.focused = 13
                dirty = True
            var target = presentation.hit_test(event.position)
            var activate = -1
            if event.kind==POINTER_DOWN_KIND:
                pressed = target
                dragging = target==18
                if screen.popups.traps_focus() and (target<92 or target>94):
                    pressed = -1
                    dragging = False
                elif target==18:
                    screen.focused = 18
                    dirty = True
                elif target==13:
                    screen.focused = 13
                    dirty = True
                elif target>=1000:
                    screen.edit_row((target-1000)//10)
                    dirty = True
            elif (event.kind==POINTER_MOVE_KIND or event.kind==DRAG_UPDATE_KIND) and dragging:
                var pane = presentation.snapshot.bounds(10)
                screen.form_width = max(Float32(240),min(Float32(500),pane.x+pane.width-event.position.x if screen.rtl else event.position.x-pane.x))
                dirty = True
            elif event.kind==POINTER_UP_KIND or event.kind==DROP_KIND:
                if target==pressed:
                    activate = target
                pressed = -1
                dragging = False
            elif event.kind==POINTER_CANCEL_KIND:
                pressed = -1
                dragging = False
            elif event.kind==CLICK_KIND:
                activate = target
            elif event.kind==ACTION_KIND:
                activate = event.target
                if screen.popups.traps_focus() and (activate<92 or activate>94):
                    activate = -1
            elif event.kind==SCROLL_KIND and not screen.popups.traps_focus():
                screen.offset_y = max(Float64(0),screen.offset_y-Float64(event.scroll_delta.y))
                screen.offset_x = max(Float64(0),screen.offset_x-Float64(event.scroll_delta.x))
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
                    if window.size().width>=760:
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
            elif event.kind==TEXT_INPUT_KIND:
                if screen.focused==13:
                    if event.replacement_start>=0:
                        dirty = screen.editor.replace_text_range(event.text,event.replacement_start,event.replacement_end) or dirty
                    else:
                        dirty = screen.editor.insert_text(event.text) or dirty
                elif screen.focused>=1000:
                    if event.replacement_start>=0:
                        dirty = screen.cell_editor.replace_text_range(event.text,event.replacement_start,event.replacement_end) or dirty
                    else:
                        dirty = screen.cell_editor.insert_text(event.text) or dirty
            elif event.kind==COMPOSITION_UPDATE_KIND or event.kind==COMPOSITION_END_KIND:
                if screen.focused==13:
                    screen.editor.set_composition(event.text,event.selection_start,event.selection_end)
                elif screen.focused>=1000:
                    screen.cell_editor.set_composition(event.text,event.selection_start,event.selection_end)
                dirty = True
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
            event = window.poll_event()
