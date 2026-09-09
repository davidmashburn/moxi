"""Minimal JSON token-reader primitives used to parse a `PlotSpec` document."""


from std.collections import List


from moxi.json import json_char
from moxi.style import Color


struct _JsonString:
    var value: String
    var next: Int
    var ok: Bool

    def __init__(out self):
        self.value = ""
        self.next = 0
        self.ok = False


struct _JsonNumber:
    var value: Float32
    var integer: Int
    var next: Int
    var ok: Bool

    def __init__(out self):
        self.value = 0.0
        self.integer = 0
        self.next = 0
        self.ok = False


def _find_token(value: String, token: String, start: Int = 0) -> Int:
    var first = start if start >= 0 else 0
    var last = value.count_codepoints() - token.count_codepoints()
    while first <= last:
        if value[codepoint=first:first + token.count_codepoints()] == token:
            return first
        first += 1
    return -1


def _read_string(value: String, start: Int) -> _JsonString:
    var result = _JsonString()
    if json_char(value, start) != chr(34):
        return result^
    var index = start + 1
    while index < value.count_codepoints():
        var glyph = json_char(value, index)
        if glyph == chr(34):
            result.next = index + 1
            result.ok = True
            return result^
        if glyph == chr(92):
            index += 1
            var escaped = json_char(value, index)
            if escaped == "n":
                result.value += chr(10)
            elif escaped == "r":
                result.value += chr(13)
            elif escaped == "t":
                result.value += chr(9)
            elif escaped == "b":
                result.value += chr(8)
            elif escaped == "f":
                result.value += chr(12)
            else:
                result.value += escaped
        else:
            result.value += glyph
        index += 1
    return result^


def _read_number(value: String, start: Int) -> _JsonNumber:
    var result = _JsonNumber()
    var index = start
    var sign: Float32 = 1.0
    if json_char(value, index) == "-":
        sign = -1.0
        index += 1
    if not (
        json_char(value, index) == "0"
        or json_char(value, index) == "1"
        or json_char(value, index) == "2"
        or json_char(value, index) == "3"
        or json_char(value, index) == "4"
        or json_char(value, index) == "5"
        or json_char(value, index) == "6"
        or json_char(value, index) == "7"
        or json_char(value, index) == "8"
        or json_char(value, index) == "9"
    ):
        return result^
    var whole: Float32 = 0.0
    while index < value.count_codepoints():
        var glyph = json_char(value, index)
        if not (
            glyph == "0"
            or glyph == "1"
            or glyph == "2"
            or glyph == "3"
            or glyph == "4"
            or glyph == "5"
            or glyph == "6"
            or glyph == "7"
            or glyph == "8"
            or glyph == "9"
        ):
            break
        whole = whole * 10.0 + Float32(ord(glyph) - ord("0"))
        index += 1
    var fraction: Float32 = 0.0
    if json_char(value, index) == ".":
        index += 1
        var place: Float32 = 0.1
        while index < value.count_codepoints():
            var glyph = json_char(value, index)
            if not (
                glyph == "0"
                or glyph == "1"
                or glyph == "2"
                or glyph == "3"
                or glyph == "4"
                or glyph == "5"
                or glyph == "6"
                or glyph == "7"
                or glyph == "8"
                or glyph == "9"
            ):
                break
            fraction += Float32(ord(glyph) - ord("0")) * place
            place *= 0.1
            index += 1
    var magnitude = whole + fraction
    if json_char(value, index) == "e" or json_char(value, index) == "E":
        index += 1
        var exponent_sign: Float32 = 1.0
        if json_char(value, index) == "-":
            exponent_sign = -1.0
            index += 1
        elif json_char(value, index) == "+":
            index += 1
        var exponent = 0
        while index < value.count_codepoints():
            var glyph = json_char(value, index)
            if not (
                glyph == "0"
                or glyph == "1"
                or glyph == "2"
                or glyph == "3"
                or glyph == "4"
                or glyph == "5"
                or glyph == "6"
                or glyph == "7"
                or glyph == "8"
                or glyph == "9"
            ):
                break
            exponent = exponent * 10 + ord(glyph) - ord("0")
            index += 1
        var scale: Float32 = 1.0
        var steps = exponent
        if steps < 0:
            steps = -steps
        for _ in range(steps):
            if exponent_sign > 0.0:
                scale *= 10.0
            else:
                scale *= 0.1
        magnitude *= scale
    result.value = sign * magnitude
    result.integer = Int(result.value)
    result.next = index
    result.ok = True
    return result^


def _member_start(object: String, name: String) -> Int:
    var marker = String(chr(34), name, chr(34), ":")
    var location = _find_token(object, marker)
    if location == -1:
        return -1
    return location + marker.count_codepoints()


def _string_member(object: String, name: String) -> _JsonString:
    var location = _member_start(object, name)
    if location == -1:
        return _JsonString()
    return _read_string(object, location)


def _number_member(object: String, name: String) -> _JsonNumber:
    var location = _member_start(object, name)
    if location == -1:
        return _JsonNumber()
    return _read_number(object, location)


def _bool_member(object: String, name: String) -> Bool:
    var location = _member_start(object, name)
    return location != -1 and json_char(object, location) == "t"


def _color_member(object: String) -> Color:
    var location = _member_start(object, "color")
    if location == -1 or json_char(object, location) != "[":
        return Color(0.0, 0.0, 0.0, 1.0)
    var red = _read_number(object, location + 1)
    var green_start = _find_token(object, ",", red.next)
    var green = _read_number(object, green_start + 1)
    var blue_start = _find_token(object, ",", green.next)
    var blue = _read_number(object, blue_start + 1)
    var alpha_start = _find_token(object, ",", blue.next)
    var alpha = _read_number(object, alpha_start + 1)
    return Color(red.value, green.value, blue.value, alpha.value)


def _object_array(value: String, start: Int, end: Int) -> List[String]:
    """Extract the flat object members emitted by ``PlotSpec.to_json``."""
    var result = List[String]()
    if start < 0 or end < start:
        return result^
    var content = String(value[codepoint=start:end])
    var cursor = 0
    while True:
        var object_start = _find_token(content, "{", cursor)
        if object_start == -1:
            break
        var object_end = _find_token(content, "}", object_start)
        if object_end == -1:
            break
        result.append(String(content[codepoint=object_start:object_end + 1]))
        cursor = object_end + 1
    return result^


def _array_content(value: String, start_marker: String, end_marker: String) -> String:
    var start = _find_token(value, start_marker)
    if start == -1:
        return ""
    var content_start = start + start_marker.count_codepoints()
    var end = _find_token(value, end_marker, content_start)
    if end == -1:
        return ""
    return String(value[codepoint=content_start:end])


