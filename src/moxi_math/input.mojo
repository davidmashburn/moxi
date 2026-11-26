"""Events from the math-local NSTextInputClient, preserving native IME ownership."""
from std.ffi import external_call
from moxi.event import Event, KEY_DELETE
from .editor import MathEditorState
from .model import MathKind

def poll_math_event() -> Event:
    var event=Event()
    event.kind=Int(external_call["moxi_math_input_poll",Int32]())
    if event.kind==0:
        return event
    event.key=Int(external_call["moxi_math_input_field",Int32](Int32(0)))
    event.modifiers=Int(external_call["moxi_math_input_field",Int32](Int32(1)))
    event.key_repeat=external_call["moxi_math_input_field",Int32](Int32(4))!=0
    event.replacement_start=Int(external_call["moxi_math_input_field",Int32](Int32(2)))
    event.replacement_end=Int(external_call["moxi_math_input_field",Int32](Int32(3)))
    var length=Int(external_call["moxi_math_input_length",Int32]())
    for i in range(length):
        event.text+=chr(Int(external_call["moxi_math_input_codepoint",Int32](Int32(i))))
    return event

struct MathDeleteHold(ImplicitlyCopyable):
    """A hold can repeat only inside the token or abbreviation it began erasing."""
    var key: Int
    var token_id: Int
    var offset: Int
    var revision: Int
    var symbol_entry: Bool
    def __init__(out self):
        self.key = -1
        self.token_id = -1
        self.offset = -1
        self.revision = -1
        self.symbol_entry = False
    def stop(mut self):
        self.key = -1
    def matches(self, state: MathEditorState, key: Int) -> Bool:
        if self.key != key or state.document.revision != self.revision:
            return False
        if self.symbol_entry:
            return state.symbol_entry and state.abbreviation.count_codepoints() == self.offset
        if state.symbol_entry or state.selected >= 0 or state.has_range_selection():
            return False
        var i = state.document.find_id(state.caret.id)
        if i < 0 or state.document.nodes[i].kind != MathKind.TOKEN or state.caret.id != self.token_id or state.caret.offset != self.offset:
            return False
        return state.caret.offset < state.document.nodes[i].text.count_codepoints() if key == KEY_DELETE else state.caret.offset > 0
    def delete(mut self, mut state: MathEditorState, key: Int, key_repeat: Bool) raises:
        if key_repeat and not self.matches(state,key):
            return
        var token_id = state.caret.id
        var was_symbol = state.symbol_entry
        var i = state.document.find_id(token_id)
        var was_token = not was_symbol and state.selected < 0 and not state.has_range_selection() and i >= 0 and state.document.nodes[i].kind == MathKind.TOKEN
        var revision = state.document.revision
        self.stop()
        state.delete(key == KEY_DELETE)
        if was_symbol and state.symbol_entry:
            self.symbol_entry = True
            self.offset = state.abbreviation.count_codepoints()
        elif was_token and state.caret.id == token_id and state.selected < 0 and not state.has_range_selection() and state.document.revision > revision:
            i = state.document.find_id(token_id)
            if i < 0 or state.document.nodes[i].kind != MathKind.TOKEN:
                return
            self.symbol_entry = False
            self.offset = state.caret.offset
        else:
            return
        self.key = key
        self.token_id = token_id
        self.revision = state.document.revision
