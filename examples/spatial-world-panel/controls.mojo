"""Ordinary Moxi component, identical model and controls in both presentations."""
from moxi import Component, ColumnView, Rect
from moxi.controls_text import TextInputControl, TextInputState
from moxi.controls_basic import LabelControl, ButtonControl, SliderControl
from moxi.controls_state import SliderState
from moxi.style import default_label_style
from moxi.event import *

struct Controls(Component):
    var input: TextInputState
    var slider: SliderState
    var clicks: Int
    def __init__(out self):
        self.input = TextInputState("Spatial ordinary controls")
        self.slider = SliderState(40, 0, 100, 1)
        self.clicks = 0
    def build(self, bounds: Rect) -> ColumnView:
        var view = ColumnView(bounds, 16, 12)
        view.add(LabelControl(4, "ONE MODEL / ORDINARY MOXI", 24).node())
        var field = TextInputControl(1,self.input.text,self.input.cursor,self.input.anchor,38)
        field.set_composition(self.input.composition,self.input.composition_selection_start,self.input.composition_selection_end)
        view.add(field.node())
        view.set_accessibility_label(1,"Panel text")
        view.add(ButtonControl(2,String("Apply · ",self.clicks),36).node())
        view.add(SliderControl(3,"Level",self.slider.value,0,100,1,36).node())
        var status_style = default_label_style()
        status_style.font_size = 16
        view.add(LabelControl(5,String("Shared level ",Int(self.slider.value)),20,status_style).node())
        view.layout()
        return view^
    def update(mut self,event: Event,view: ColumnView) -> Bool:
        if event.target == 1:
            if event.kind == TEXT_INPUT_KIND:
                if event.replacement_start >= 0:
                    return self.input.replace_text_range(event.text,event.replacement_start,event.replacement_end)
                return self.input.insert_text(event.text)
            if event.kind == COMPOSITION_UPDATE_KIND:
                self.input.set_composition(event.text,event.selection_start,event.selection_end)
                return True
            if event.kind == COMPOSITION_END_KIND:
                self.input.clear_composition()
                return True
            if event.kind == KEY_DOWN_KIND:
                return self.input.handle_key(event.key,event.modifiers)
        if event.target == 2 and (event.kind == CLICK_KIND or (event.kind == KEY_DOWN_KIND and (event.key == KEY_ENTER or event.key == KEY_SPACE))):
            self.clicks += 1
            return True
        if event.target == 3:
            if event.kind == POINTER_DOWN_KIND or event.kind == POINTER_MOVE_KIND or event.kind == DRAG_UPDATE_KIND:
                return self.slider.set_from_position(event.position,view.bounds_for(3))
            if event.kind == KEY_DOWN_KIND:
                return self.slider.handle_key(event.key)
        return False
    def clipboard_copy(mut self,target: Int,view: ColumnView) -> String:
        return self.input.selected_text() if target == 1 else ""
    def clipboard_cut(mut self,target: Int,view: ColumnView) -> String:
        if target == 1:
            var text = self.input.selected_text()
            _ = self.input.cut_selection()
            return text
        return ""
    def clipboard_paste(mut self,target: Int,text: String,view: ColumnView) -> Bool:
        return self.input.insert_text(text) if target == 1 else False
