"""Portable lossless normalized-event fixture contract; no host libraries."""

from std.memory import bitcast
from std.testing import assert_equal, assert_true
from moxi.event import Event, KEY_RIGHT
from moxi.event_replay import EventReplay, event_to_json, event_from_json, event_replay_from_json
from moxi.geometry import Point, Size


def _bits(value: Float32) -> Int:
    return Int(bitcast[DType.int32](value))


def _assert_event(actual: Event, expected: Event) raises:
    assert_equal(actual.kind,expected.kind)
    assert_equal(actual.target,expected.target)
    assert_equal(actual.action_id,expected.action_id)
    assert_equal(_bits(actual.position.x),_bits(expected.position.x))
    assert_equal(_bits(actual.position.y),_bits(expected.position.y))
    assert_equal(actual.key,expected.key)
    assert_equal(actual.modifiers,expected.modifiers)
    assert_equal(actual.text,expected.text)
    assert_equal(actual.selection_start,expected.selection_start)
    assert_equal(actual.selection_end,expected.selection_end)
    assert_equal(actual.replacement_start,expected.replacement_start)
    assert_equal(actual.replacement_end,expected.replacement_end)
    assert_equal(_bits(actual.size.width),_bits(expected.size.width))
    assert_equal(_bits(actual.size.height),_bits(expected.size.height))
    assert_equal(_bits(actual.delta_seconds),_bits(expected.delta_seconds))
    assert_equal(_bits(actual.scroll_delta.x),_bits(expected.scroll_delta.x))
    assert_equal(_bits(actual.scroll_delta.y),_bits(expected.scroll_delta.y))
    assert_equal(actual.task_id,expected.task_id)
    assert_equal(actual.task_status,expected.task_status)
    assert_equal(actual.request_key,expected.request_key)
    assert_equal(actual.request_generation,expected.request_generation)
    assert_equal(actual.request_scope_id,expected.request_scope_id)
    assert_equal(actual.pointer_id,expected.pointer_id)
    assert_equal(actual.buttons,expected.buttons)
    assert_equal(_bits(actual.drag_delta.x),_bits(expected.drag_delta.x))
    assert_equal(_bits(actual.drag_delta.y),_bits(expected.drag_delta.y))


def _codec_contract() raises:
    # Every field carries a distinct non-default value, including fields which
    # a diagnostic/native trace previously omitted. Exercise all event kinds.
    var record = Event()
    record.target = 1012
    record.action_id = 16
    record.position = Point(-0.0,37.125)
    record.key = KEY_RIGHT
    record.modifiers = 15
    record.text = String("日本語 العربية 😀 ",chr(34),chr(92),chr(10),chr(9),chr(0))
    record.selection_start = 2
    record.selection_end = 4
    record.replacement_start = 6
    record.replacement_end = 9
    record.size = Size(540.5,900.25)
    record.delta_seconds = 0.016666668
    record.scroll_delta = Point(-87.25,199.5)
    record.task_id = 21
    record.task_status = 3
    record.request_key = 22
    record.request_generation = 23
    record.request_scope_id = 24
    record.pointer_id = 25
    record.buttons = 7
    record.drag_delta = Point(-19.75,41.875)
    var replay = EventReplay()
    for kind in range(21):
        record.kind = kind
        replay.append(record)
        _assert_event(event_from_json(event_to_json(record)),record)
    var restored = event_replay_from_json(replay.to_json())
    assert_equal(len(restored.events),21)
    for index in range(len(replay.events)):
        _assert_event(restored.events[index],replay.events[index])
    assert_equal(len(event_replay_from_json(" [] ").events),0)
    record.target = -9223372036854775808
    record.action_id = 9223372036854775807
    _assert_event(event_from_json(event_to_json(record)),record)

    # JSON readers used by other hosts may escape Unicode rather than emit it.
    var simple = Event()
    var encoded = event_to_json(simple)
    var escaped = encoded.replace(String("\"\""),String("\"",chr(92),"u65e5",chr(92),"u672c",chr(92),"ud83d",chr(92),"ude00\""))
    assert_equal(event_from_json(escaped).text,String("日本😀"))
    var unpaired = encoded.replace(String("\"\""),String("\"",chr(92),"ud800\""))
    var invalid_bits = encoded.replace("[1,0,-1,-1,0,","[1,0,-1,-1,2147483648,")
    for malformed in ["", "[]", "[2]", "[1,01]", "[1,9223372036854775808]", "[1,-9223372036854775809]", "[1,0.0]", encoded+"null", encoded+",", encoded.replace("[1,","[1,0,")]:
        var rejected = False
        try:
            _ = event_from_json(malformed)
        except:
            rejected = True
        assert_true(rejected)
    for malformed in [unpaired,invalid_bits]:
        var rejected = False
        try:
            _ = event_from_json(malformed)
        except:
            rejected = True
        assert_true(rejected)


def main() raises:
    _codec_contract()
    print("Moxi portable event replay passed")
