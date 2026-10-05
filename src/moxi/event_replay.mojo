"""Lossless, versioned normalized-event fixtures without native handles.

Each JSON row is a version followed by every ``Event`` field in declaration
order. Float32 fields use signed 32-bit IEEE bits, avoiding decimal rounding,
including signed zero. Text is a JSON string, never a diagnostic trace. The
bounded reader accepts the same format from native recording tools.
"""

from std.collections import List
from std.memory import bitcast

from .event import Event
from .geometry import Point, Size
from .json import json_char, json_quote, json_skip_whitespace


comptime EVENT_REPLAY_VERSION = 1
comptime EVENT_REPLAY_MAX_EVENTS = 4096
comptime EVENT_REPLAY_MAX_CODEPOINTS = 1048576


def _float_bits(value: Float32) -> Int:
    return Int(bitcast[DType.int32](value))


def _float_from_bits(value: Int) raises -> Float32:
    if value < -2147483648 or value > 2147483647:
        raise Error("Event replay Float32 bits outside Int32 range")
    return bitcast[DType.float32](Int32(value))


def event_to_json(event: Event) -> String:
    """Encode every normalized payload field, including inactive fields."""
    return String(
        "[", EVENT_REPLAY_VERSION, ",", event.kind, ",", event.target, ",",
        event.action_id, ",", _float_bits(event.position.x), ",",
        _float_bits(event.position.y), ",", event.key, ",", event.modifiers,
        ",", json_quote(event.text), ",", event.selection_start, ",",
        event.selection_end, ",", event.replacement_start, ",",
        event.replacement_end, ",", _float_bits(event.size.width), ",",
        _float_bits(event.size.height), ",", _float_bits(event.delta_seconds),
        ",", _float_bits(event.scroll_delta.x), ",",
        _float_bits(event.scroll_delta.y), ",", event.task_id, ",",
        event.task_status, ",", event.request_key, ",", event.request_generation,
        ",", event.request_scope_id, ",", event.pointer_id, ",", event.buttons,
        ",", _float_bits(event.drag_delta.x), ",", _float_bits(event.drag_delta.y),
        "]",
    )


struct _ReplayReader:
    var source: String
    var index: Int

    def __init__(out self, source: String) raises:
        if source.count_codepoints() > EVENT_REPLAY_MAX_CODEPOINTS:
            raise Error("Event replay exceeds the fixture size limit")
        self.source = source
        self.index = 0

    def peek(mut self) -> String:
        self.index = json_skip_whitespace(self.source,self.index)
        return json_char(self.source,self.index)

    def expect(mut self, glyph: String) raises:
        if self.peek()!=glyph:
            raise Error("Malformed event replay delimiter")
        self.index += 1

    def integer(mut self) raises -> Int:
        _ = self.peek()
        var negative = False
        if json_char(self.source,self.index)=="-":
            negative = True
            self.index += 1
        var start = self.index
        var result = 0
        while self.index < self.source.count_codepoints():
            var glyph = json_char(self.source,self.index)
            var digit = -1
            for candidate in range(10):
                if glyph==String(candidate):
                    digit = candidate
                    break
            if digit<0:
                break
            # Accumulate negatively so Int.min is representable as well.
            if result < -922337203685477580 or (
                result == -922337203685477580 and digit > (8 if negative else 7)
            ):
                raise Error("Event replay integer overflow")
            result = result*10-digit
            self.index += 1
        if self.index==start:
            raise Error("Event replay expects an integer")
        if self.index-start>1 and json_char(self.source,start)=="0":
            raise Error("Event replay rejects leading zeroes")
        return result if negative else -result

    def next_integer(mut self) raises -> Int:
        self.expect(",")
        return self.integer()

    def hex_unit(mut self) raises -> Int:
        var digits = String("0123456789abcdef")
        var upper = String("0123456789ABCDEF")
        var result = 0
        for _ in range(4):
            var glyph = json_char(self.source,self.index)
            var digit = -1
            for candidate in range(16):
                if glyph==json_char(digits,candidate) or glyph==json_char(upper,candidate):
                    digit = candidate
                    break
            if digit<0:
                raise Error("Malformed event replay Unicode escape")
            self.index += 1
            result = result*16+digit
        return result

    def string(mut self) raises -> String:
        self.expect(chr(34))
        var result = String("")
        while self.index < self.source.count_codepoints():
            var glyph = json_char(self.source,self.index)
            self.index += 1
            if glyph==chr(34):
                return result
            if glyph!=chr(92):
                if ord(glyph)<32:
                    raise Error("Raw control character in event replay text")
                result += glyph
                continue
            var escaped = json_char(self.source,self.index)
            self.index += 1
            if escaped==chr(34) or escaped==chr(92) or escaped=="/":
                result += escaped
            elif escaped=="n":
                result += chr(10)
            elif escaped=="r":
                result += chr(13)
            elif escaped=="t":
                result += chr(9)
            elif escaped=="b":
                result += chr(8)
            elif escaped=="f":
                result += chr(12)
            elif escaped=="u":
                var unit = self.hex_unit()
                if unit>=55296 and unit<=56319:
                    if json_char(self.source,self.index)!=chr(92) or json_char(self.source,self.index+1)!="u":
                        raise Error("Event replay requires a paired Unicode surrogate")
                    self.index += 2
                    var low = self.hex_unit()
                    if low<56320 or low>57343:
                        raise Error("Malformed event replay Unicode surrogate")
                    unit = 65536+(unit-55296)*1024+low-56320
                elif unit>=56320 and unit<=57343:
                    raise Error("Unpaired event replay Unicode surrogate")
                result += chr(unit)
            else:
                raise Error("Unknown event replay string escape")
        raise Error("Unterminated event replay string")

    def event(mut self) raises -> Event:
        self.expect("[")
        if self.integer()!=EVENT_REPLAY_VERSION:
            raise Error("Unsupported event replay version")
        var event = Event()
        event.kind = self.next_integer()
        event.target = self.next_integer()
        event.action_id = self.next_integer()
        event.position.x = _float_from_bits(self.next_integer())
        event.position.y = _float_from_bits(self.next_integer())
        event.key = self.next_integer()
        event.modifiers = self.next_integer()
        self.expect(",")
        event.text = self.string()
        event.selection_start = self.next_integer()
        event.selection_end = self.next_integer()
        event.replacement_start = self.next_integer()
        event.replacement_end = self.next_integer()
        event.size.width = _float_from_bits(self.next_integer())
        event.size.height = _float_from_bits(self.next_integer())
        event.delta_seconds = _float_from_bits(self.next_integer())
        event.scroll_delta.x = _float_from_bits(self.next_integer())
        event.scroll_delta.y = _float_from_bits(self.next_integer())
        event.task_id = self.next_integer()
        event.task_status = self.next_integer()
        event.request_key = self.next_integer()
        event.request_generation = self.next_integer()
        event.request_scope_id = self.next_integer()
        event.pointer_id = self.next_integer()
        event.buttons = self.next_integer()
        event.drag_delta.x = _float_from_bits(self.next_integer())
        event.drag_delta.y = _float_from_bits(self.next_integer())
        self.expect("]")
        return event

    def finish(mut self) raises:
        if self.peek()!="":
            raise Error("Trailing data in event replay")


def event_from_json(source: String) raises -> Event:
    """Decode one strict, versioned row without losing Event payload fields."""
    var reader = _ReplayReader(source)
    var event = reader.event()
    reader.finish()
    return event


struct EventReplay:
    """A bounded ordered normalized-event fixture reusable by any host."""

    var events: List[Event]

    def __init__(out self):
        self.events = List[Event]()

    def append(mut self, event: Event) raises:
        if len(self.events)>=EVENT_REPLAY_MAX_EVENTS:
            raise Error("Event replay exceeds the event count limit")
        self.events.append(event)

    def to_json(self) -> String:
        var result = String("[")
        for index in range(len(self.events)):
            if index>0:
                result += ","
            result += event_to_json(self.events[index])
        return result+"]"


def event_replay_from_json(source: String) raises -> EventReplay:
    """Read the portable fixture format used by headless and native lanes."""
    var reader = _ReplayReader(source)
    var replay = EventReplay()
    reader.expect("[")
    if reader.peek()!="]":
        while True:
            replay.append(reader.event())
            if reader.peek()!=",":
                break
            reader.expect(",")
    reader.expect("]")
    reader.finish()
    return replay^
