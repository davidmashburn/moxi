"""Portable Unicode text-boundary helpers.

Moxi stores editor offsets as Unicode codepoint offsets so they can cross the
small native ABI without exposing a platform string type. These helpers keep
those offsets at practical grapheme-cluster boundaries for common combining
marks, variation selectors, emoji modifiers, zero-width-joiner sequences, and
CRLF. A platform text engine may provide more complete UAX #29 behavior; the
portable editor remains deterministic and never splits the sequences covered
here.
"""


def codepoint_at(text: String, index: Int) -> Int:
    """Return one Unicode scalar, or -1 for an out-of-range offset."""
    if index < 0 or index >= text.count_codepoints():
        return -1
    return ord(String(text[codepoint=index:index + 1]))


def is_combining_mark(codepoint: Int) -> Bool:
    """Return whether a scalar is in a common combining-mark block."""
    return (
        (codepoint >= 0x0300 and codepoint <= 0x036F)
        or (codepoint >= 0x1AB0 and codepoint <= 0x1AFF)
        or (codepoint >= 0x1DC0 and codepoint <= 0x1DFF)
        or (codepoint >= 0x20D0 and codepoint <= 0x20FF)
        or (codepoint >= 0xFE20 and codepoint <= 0xFE2F)
        or codepoint == 0x20E3
    )


def is_variation_selector(codepoint: Int) -> Bool:
    """Return whether a scalar is a standard variation selector."""
    return (
        (codepoint >= 0xFE00 and codepoint <= 0xFE0F)
        or (codepoint >= 0xE0100 and codepoint <= 0xE01EF)
    )


def is_emoji_modifier(codepoint: Int) -> Bool:
    """Return whether a scalar is an emoji skin-tone modifier."""
    return codepoint >= 0x1F3FB and codepoint <= 0x1F3FF


def is_regional_indicator(codepoint: Int) -> Bool:
    """Return whether a scalar is a regional-indicator symbol."""
    return codepoint >= 0x1F1E6 and codepoint <= 0x1F1FF


def is_extend(codepoint: Int) -> Bool:
    """Return whether a scalar extends the preceding grapheme cluster."""
    return (
        is_combining_mark(codepoint)
        or is_variation_selector(codepoint)
        or is_emoji_modifier(codepoint)
        or codepoint == 0x200D
    )


def previous_text_boundary(text: String, offset: Int) -> Int:
    """Return the previous practical grapheme boundary before ``offset``."""
    var length = text.count_codepoints()
    var cursor = offset
    if cursor > length:
        cursor = length
    if cursor <= 0:
        return 0

    cursor -= 1
    while cursor > 0:
        var current = codepoint_at(text, cursor)
        var previous = codepoint_at(text, cursor - 1)
        if is_extend(current) or previous == 0x200D:
            cursor -= 1
            continue
        # Treat CRLF as one editing unit.
        if current == 0x0A and previous == 0x0D:
            cursor -= 1
            continue
        break
    return cursor


def next_text_boundary(text: String, offset: Int) -> Int:
    """Return the next practical grapheme boundary after ``offset``."""
    var length = text.count_codepoints()
    var cursor = offset
    if cursor < 0:
        cursor = 0
    if cursor >= length:
        return length

    cursor += 1
    while cursor < length:
        var current = codepoint_at(text, cursor)
        var previous = codepoint_at(text, cursor - 1)
        if is_extend(current) or previous == 0x200D:
            cursor += 1
            continue
        # Treat CRLF as one editing unit.
        if current == 0x0A and previous == 0x0D:
            cursor += 1
            continue
        break
    return cursor


def clamp_text_boundary(text: String, offset: Int) -> Int:
    """Clamp an offset to the closest valid practical grapheme boundary."""
    var length = text.count_codepoints()
    var value = offset
    if value < 0:
        value = 0
    if value > length:
        value = length
    if value == 0 or value == length:
        return value
    var previous = previous_text_boundary(text, value)
    var next = next_text_boundary(text, previous)
    if value - previous <= next - value:
        return previous
    return next
