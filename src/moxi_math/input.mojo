"""Events from the math-local NSTextInputClient, preserving native IME ownership."""
from std.ffi import external_call
from moxi.event import Event

def poll_math_event() -> Event:
    var event=Event()
    event.kind=Int(external_call["moxi_math_input_poll",Int32]())
    if event.kind==0:
        return event
    event.key=Int(external_call["moxi_math_input_field",Int32](Int32(0)))
    event.modifiers=Int(external_call["moxi_math_input_field",Int32](Int32(1)))
    event.replacement_start=Int(external_call["moxi_math_input_field",Int32](Int32(2)))
    event.replacement_end=Int(external_call["moxi_math_input_field",Int32](Int32(3)))
    var length=Int(external_call["moxi_math_input_length",Int32]())
    for i in range(length):
        event.text+=chr(Int(external_call["moxi_math_input_codepoint",Int32](Int32(i))))
    return event
