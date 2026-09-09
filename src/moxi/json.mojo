"""Generic, capability-bus-independent JSON helpers used across Moxi.

These functions quote, validate, and parse the small bounded JSON
fragments Moxi emits and accepts. They have no dependency on the
capability bus or any other Moxi domain type.
"""


def json_quote(value: String) -> String:
    """Quote controlled metadata with the JSON escapes Moxi emits."""
    var result = String("")
    result += chr(34)
    for index in range(value.count_codepoints()):
        var glyph = String(value[codepoint=index:index + 1])
        if glyph == chr(34) or glyph == chr(92):
            result += chr(92)
            result += glyph
        elif glyph == chr(10):
            result += chr(92)
            result += "n"
        elif glyph == chr(13):
            result += chr(92)
            result += "r"
        elif glyph == chr(9):
            result += chr(92)
            result += "t"
        elif glyph == chr(8):
            result += chr(92)
            result += "b"
        elif glyph == chr(12):
            result += chr(92)
            result += "f"
        elif json_is_control(glyph):
            result += chr(92)
            result += "u"
            result += json_control_escape(glyph)
        else:
            result += glyph
    result += chr(34)
    return result


def json_char(value: String, index: Int) -> String:
    if index < 0 or index >= value.count_codepoints():
        return ""
    return String(value[codepoint=index:index + 1])


def json_is_whitespace(glyph: String) -> Bool:
    return (
        glyph == " "
        or glyph == chr(9)
        or glyph == chr(10)
        or glyph == chr(13)
    )


def json_is_digit(glyph: String) -> Bool:
    return (
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
    )


def json_is_hex_digit(glyph: String) -> Bool:
    return (
        json_is_digit(glyph)
        or glyph == "a"
        or glyph == "b"
        or glyph == "c"
        or glyph == "d"
        or glyph == "e"
        or glyph == "f"
        or glyph == "A"
        or glyph == "B"
        or glyph == "C"
        or glyph == "D"
        or glyph == "E"
        or glyph == "F"
    )


def json_is_control(glyph: String) -> Bool:
    """Return whether a glyph is forbidden raw JSON string control data."""
    return (
        glyph == chr(0)
        or glyph == chr(1)
        or glyph == chr(2)
        or glyph == chr(3)
        or glyph == chr(4)
        or glyph == chr(5)
        or glyph == chr(6)
        or glyph == chr(7)
        or glyph == chr(8)
        or glyph == chr(9)
        or glyph == chr(10)
        or glyph == chr(11)
        or glyph == chr(12)
        or glyph == chr(13)
        or glyph == chr(14)
        or glyph == chr(15)
        or glyph == chr(16)
        or glyph == chr(17)
        or glyph == chr(18)
        or glyph == chr(19)
        or glyph == chr(20)
        or glyph == chr(21)
        or glyph == chr(22)
        or glyph == chr(23)
        or glyph == chr(24)
        or glyph == chr(25)
        or glyph == chr(26)
        or glyph == chr(27)
        or glyph == chr(28)
        or glyph == chr(29)
        or glyph == chr(30)
        or glyph == chr(31)
    )


def json_control_escape(glyph: String) -> String:
    """Return the four hex digits for a raw control's JSON escape."""
    if glyph == chr(0):
        return "0000"
    if glyph == chr(1):
        return "0001"
    if glyph == chr(2):
        return "0002"
    if glyph == chr(3):
        return "0003"
    if glyph == chr(4):
        return "0004"
    if glyph == chr(5):
        return "0005"
    if glyph == chr(6):
        return "0006"
    if glyph == chr(7):
        return "0007"
    if glyph == chr(8):
        return "0008"
    if glyph == chr(9):
        return "0009"
    if glyph == chr(10):
        return "000a"
    if glyph == chr(11):
        return "000b"
    if glyph == chr(12):
        return "000c"
    if glyph == chr(13):
        return "000d"
    if glyph == chr(14):
        return "000e"
    if glyph == chr(15):
        return "000f"
    if glyph == chr(16):
        return "0010"
    if glyph == chr(17):
        return "0011"
    if glyph == chr(18):
        return "0012"
    if glyph == chr(19):
        return "0013"
    if glyph == chr(20):
        return "0014"
    if glyph == chr(21):
        return "0015"
    if glyph == chr(22):
        return "0016"
    if glyph == chr(23):
        return "0017"
    if glyph == chr(24):
        return "0018"
    if glyph == chr(25):
        return "0019"
    if glyph == chr(26):
        return "001a"
    if glyph == chr(27):
        return "001b"
    if glyph == chr(28):
        return "001c"
    if glyph == chr(29):
        return "001d"
    if glyph == chr(30):
        return "001e"
    return "001f"


def json_skip_whitespace(value: String, index: Int) -> Int:
    var result = index
    while result < value.count_codepoints() and json_is_whitespace(
        json_char(value, result)
    ):
        result += 1
    return result


def json_parse_string(value: String, mut index: Int) -> Bool:
    if json_char(value, index) != chr(34):
        return False
    index += 1
    while index < value.count_codepoints():
        var glyph = json_char(value, index)
        if glyph == chr(34):
            index += 1
            return True
        if glyph == chr(92):
            index += 1
            if index >= value.count_codepoints():
                return False
            var escaped = json_char(value, index)
            if (
                escaped == chr(34)
                or escaped == chr(92)
                or escaped == "/"
                or escaped == "b"
                or escaped == "f"
                or escaped == "n"
                or escaped == "r"
                or escaped == "t"
            ):
                index += 1
                continue
            if escaped == "u":
                for _ in range(4):
                    index += 1
                    if index >= value.count_codepoints() or not json_is_hex_digit(
                        json_char(value, index)
                    ):
                        return False
                index += 1
                continue
            return False
        if json_is_control(glyph):
            return False
        index += 1
    return False


def json_parse_number(value: String, mut index: Int) -> Bool:
    var start = index
    if json_char(value, index) == "-":
        index += 1
    if not json_is_digit(json_char(value, index)):
        return False
    if json_char(value, index) == "0":
        index += 1
        if json_is_digit(json_char(value, index)):
            return False
    else:
        while json_is_digit(json_char(value, index)):
            index += 1
    if json_char(value, index) == ".":
        index += 1
        if not json_is_digit(json_char(value, index)):
            return False
        while json_is_digit(json_char(value, index)):
            index += 1
    var exponent = json_char(value, index)
    if exponent == "e" or exponent == "E":
        index += 1
        var sign = json_char(value, index)
        if sign == "+" or sign == "-":
            index += 1
        if not json_is_digit(json_char(value, index)):
            return False
        while json_is_digit(json_char(value, index)):
            index += 1
    return index > start


def json_parse_value(value: String, mut index: Int, depth: Int = 0) -> Bool:
    if depth > 32:
        return False
    index = json_skip_whitespace(value, index)
    var glyph = json_char(value, index)
    if glyph == chr(34):
        return json_parse_string(value, index)
    if glyph == "{":
        index += 1
        index = json_skip_whitespace(value, index)
        if json_char(value, index) == "}":
            index += 1
            return True
        while True:
            if not json_parse_string(value, index):
                return False
            index = json_skip_whitespace(value, index)
            if json_char(value, index) != ":":
                return False
            index += 1
            if not json_parse_value(value, index, depth + 1):
                return False
            index = json_skip_whitespace(value, index)
            if json_char(value, index) == "}":
                index += 1
                return True
            if json_char(value, index) != ",":
                return False
            index = json_skip_whitespace(value, index + 1)
    if glyph == "[":
        index += 1
        index = json_skip_whitespace(value, index)
        if json_char(value, index) == "]":
            index += 1
            return True
        while True:
            if not json_parse_value(value, index, depth + 1):
                return False
            index = json_skip_whitespace(value, index)
            if json_char(value, index) == "]":
                index += 1
                return True
            if json_char(value, index) != ",":
                return False
            index = json_skip_whitespace(value, index + 1)
    if glyph == "t" and value[codepoint=index:index + 4] == "true":
        index += 4
        return True
    if glyph == "f" and value[codepoint=index:index + 5] == "false":
        index += 5
        return True
    if glyph == "n" and value[codepoint=index:index + 4] == "null":
        index += 4
        return True
    if glyph == "-" or json_is_digit(glyph):
        return json_parse_number(value, index)
    return False


def json_fragment_is_valid(value: String, object_only: Bool = False) -> Bool:
    """Validate a complete JSON value before emitting or executing it."""
    if value.count_codepoints() == 0:
        return False
    var index = json_skip_whitespace(value, 0)
    if object_only and json_char(value, index) != "{":
        return False
    if not json_parse_value(value, index):
        return False
    index = json_skip_whitespace(value, index)
    return index == value.count_codepoints()


def json_document_is_valid(value: String) -> Bool:
    """Validate the bounded JSON document shapes accepted by invocations."""
    return json_fragment_is_valid(value)
