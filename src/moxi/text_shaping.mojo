"""Portable shaped-run data and a deterministic fallback shaper.

The fallback operates on Unicode scalar clusters and deliberately reports that
it is approximate. Native adapters can implement the same `TextShaper` seam
with CoreText, HarfBuzz, Android text, or browser shaping without changing the
layout/data contract.
"""

from std.collections import List

from .geometry import Size
from .style import Style
from .text_boundary import (
    codepoint_at,
    is_extend,
    is_regional_indicator,
)
from .measure import TextMeasurement


comptime SHAPER_PORTABLE_ESTIMATE = 1
comptime SHAPER_NATIVE = 2

# Direction values are kept here as well as in text_layout.mojo so the low-level
# shaper can be used without importing the layout request layer.
comptime TEXT_DIRECTION_AUTO = 0
comptime TEXT_DIRECTION_LTR = 1
comptime TEXT_DIRECTION_RTL = 2

# Stable, renderer-independent script classes. They are intentionally coarse:
# a host shaper can replace the run with a real Unicode script itemizer while
# retaining these fields for diagnostics and fallback policy decisions.
comptime SCRIPT_COMMON = 0
comptime SCRIPT_LATIN = 1
comptime SCRIPT_CYRILLIC = 2
comptime SCRIPT_ARABIC_HEBREW = 3
comptime SCRIPT_CJK = 4
comptime SCRIPT_DEVANAGARI = 5
comptime SCRIPT_EMOJI = 6


def _is_rtl(codepoint: Int) -> Bool:
    return (
        (codepoint >= 0x0590 and codepoint <= 0x08FF)
        or (codepoint >= 0xFB1D and codepoint <= 0xFDFF)
        or (codepoint >= 0xFE70 and codepoint <= 0xFEFF)
    )


def _is_emoji(codepoint: Int) -> Bool:
    return (
        (codepoint >= 0x1F000 and codepoint <= 0x1FAFF)
        or is_regional_indicator(codepoint)
    )


def _is_strong_ltr(codepoint: Int) -> Bool:
    return (
        (codepoint >= 0x0041 and codepoint <= 0x005A)
        or (codepoint >= 0x0061 and codepoint <= 0x007A)
        or (codepoint >= 0x00C0 and codepoint <= 0x02AF)
        or (codepoint >= 0x0370 and codepoint <= 0x058F)
        or (codepoint >= 0x0900 and codepoint <= 0x1FFF)
        or (codepoint >= 0x2E80 and codepoint <= 0x9FFF)
        or (codepoint >= 0xAC00 and codepoint <= 0xD7AF)
        or (codepoint >= 0x30A0 and codepoint <= 0x30FF)
    )


def script_id(codepoint: Int) -> Int:
    """Return a coarse stable script class for portable run segmentation."""
    if _is_emoji(codepoint):
        return SCRIPT_EMOJI
    if _is_rtl(codepoint):
        return SCRIPT_ARABIC_HEBREW
    if codepoint >= 0x0400 and codepoint <= 0x052F:
        return SCRIPT_CYRILLIC
    if codepoint >= 0x0900 and codepoint <= 0x097F:
        return SCRIPT_DEVANAGARI
    if (
        (codepoint >= 0x2E80 and codepoint <= 0x9FFF)
        or (codepoint >= 0x3040 and codepoint <= 0x30FF)
        or (codepoint >= 0xAC00 and codepoint <= 0xD7AF)
    ):
        return SCRIPT_CJK
    if _is_strong_ltr(codepoint):
        return SCRIPT_LATIN
    return SCRIPT_COMMON


def fallback_font_id(codepoint: Int) -> Int:
    """Return a stable fallback-face class for a Unicode scalar."""
    if _is_emoji(codepoint):
        return 2
    if codepoint >= 0x2E80 and codepoint <= 0x9FFF:
        return 1
    if _is_rtl(codepoint):
        return 3
    return 0


def _resolved_direction(text: String, requested: Int) -> Int:
    """Resolve auto direction from the first strong scalar in the text."""
    if requested == TEXT_DIRECTION_RTL:
        return TEXT_DIRECTION_RTL
    if requested == TEXT_DIRECTION_LTR:
        return TEXT_DIRECTION_LTR
    for index in range(text.count_codepoints()):
        var codepoint = codepoint_at(text, index)
        if _is_rtl(codepoint):
            return TEXT_DIRECTION_RTL
        if _is_strong_ltr(codepoint):
            return TEXT_DIRECTION_LTR
    return TEXT_DIRECTION_LTR


struct ShapedRun(ImplicitlyCopyable):
    """One logical itemization run in a portable shaped result.

    ``glyph_start`` and ``glyph_end`` address logical glyph order. An explicit
    RTL request may expose the glyphs in visual order for compatibility with
    the original shaper; the source cluster range remains logical and stable.
    """

    var line: Int
    var glyph_start: Int
    var glyph_end: Int
    var cluster_start: Int
    var cluster_end: Int
    var direction: Int
    var level: Int
    var font_id: Int
    var script: Int

    def __init__(
        out self,
        line: Int,
        glyph_start: Int,
        glyph_end: Int,
        cluster_start: Int,
        cluster_end: Int,
        direction: Int,
        font_id: Int,
        script: Int,
    ):
        self.line = line
        self.glyph_start = glyph_start
        self.glyph_end = glyph_end
        self.cluster_start = cluster_start
        self.cluster_end = cluster_end
        self.direction = direction
        self.level = 1 if direction == TEXT_DIRECTION_RTL else 0
        self.font_id = font_id
        self.script = script

    def glyph_count(self) -> Int:
        return self.glyph_end - self.glyph_start


struct ShapedGlyph(ImplicitlyCopyable):
    """One glyph with source cluster, engine id, and placement metadata."""

    var codepoint: Int
    var glyph_id: Int
    var cluster: Int
    var font_id: Int
    var advance: Float32
    var x: Float32
    var y: Float32
    var line: Int

    def __init__(
        out self,
        codepoint: Int,
        glyph_id: Int,
        cluster: Int,
        font_id: Int,
        advance: Float32,
        x: Float32,
        y: Float32,
        line: Int,
    ):
        self.codepoint = codepoint
        self.glyph_id = glyph_id
        self.cluster = cluster
        self.font_id = font_id
        self.advance = advance
        self.x = x
        self.y = y
        self.line = line


struct ShapedText:
    """Result of shaping with enough metadata for renderers and hit testing."""

    var glyphs: List[ShapedGlyph]
    var runs: List[ShapedRun]
    var measurement: TextMeasurement
    var direction: Int
    var bidi_applied: Bool
    var approximate: Bool
    var used_fallback_font: Bool

    def __init__(out self):
        self.glyphs = List[ShapedGlyph]()
        self.runs = List[ShapedRun]()
        self.measurement = TextMeasurement(Size(0.0, 0.0), 0)
        self.direction = 1
        self.bidi_applied = False
        self.approximate = True
        self.used_fallback_font = False

    def glyph_count(self) -> Int:
        return len(self.glyphs)

    def glyph(self, index: Int) -> ShapedGlyph:
        return self.glyphs[index]

    def run_count(self) -> Int:
        return len(self.runs)

    def run(self, index: Int) -> ShapedRun:
        return self.runs[index]


trait TextShaper:
    """Backend seam for native or portable text shaping implementations."""

    def shape(
        self,
        text: String,
        style: Style,
        max_width: Float32,
        direction: Int,
    ) -> ShapedText:
        ...


struct PortableTextShaper(TextShaper):
    """Deterministic script-run shaper used by headless and unsupported hosts.

    This is a layout-safe fallback, not a replacement for OpenType shaping:
    ligatures, kerning, and complex script joining still require a native or
    HarfBuzz-backed adapter. Its run and cluster metadata is complete enough
    for stable hit testing, fallback selection, and renderer handoff.
    """

    def __init__(out self):
        pass

    def shape(
        self,
        text: String,
        style: Style,
        max_width: Float32,
        direction: Int,
    ) -> ShapedText:
        var result = ShapedText()
        var resolved_direction = _resolved_direction(text, direction)
        result.direction = resolved_direction
        var font_size = style.font_size
        if font_size <= 0.0:
            font_size = 16.0
        var base_advance = font_size * 0.56
        var line_height = font_size * 1.25
        if line_height < 16.0:
            line_height = 16.0
        var width_limit = max_width if max_width > 0.0 else 0.0
        var line_width: Float32 = 0.0
        var max_line_width: Float32 = 0.0
        var line = 0
        var line_count = 1
        var run_line = -1
        var run_direction = 0
        var run_font = -1
        var run_script = -1
        var run_glyph_start = 0
        var run_cluster_start = 0
        var index = 0
        while index < text.count_codepoints():
            var codepoint = codepoint_at(text, index)
            var advance = base_advance
            if codepoint == 0x0A:
                if line_width > max_line_width:
                    max_line_width = line_width
                if run_line != -1:
                    result.runs.append(
                        ShapedRun(
                            run_line,
                            run_glyph_start,
                            len(result.glyphs),
                            run_cluster_start,
                            index,
                            run_direction,
                            run_font,
                            run_script,
                        )
                    )
                    run_line = -1
                line += 1
                line_count += 1
                line_width = 0.0
                index += 1
                continue
            if codepoint == 0x09:
                advance *= 4.0
            elif is_extend(codepoint):
                advance = 0.0
            elif _is_emoji(codepoint):
                advance *= 1.15
            elif codepoint >= 0x2E80 and codepoint <= 0x9FFF:
                advance *= 1.75
            if width_limit > 0.0 and line_width > 0.0 and line_width + advance > width_limit:
                if line_width > max_line_width:
                    max_line_width = line_width
                if run_line != -1:
                    result.runs.append(
                        ShapedRun(
                            run_line,
                            run_glyph_start,
                            len(result.glyphs),
                            run_cluster_start,
                            index,
                            run_direction,
                            run_font,
                            run_script,
                        )
                    )
                    run_line = -1
                line += 1
                line_count += 1
                line_width = 0.0
            var glyph_direction = resolved_direction
            if _is_rtl(codepoint):
                glyph_direction = TEXT_DIRECTION_RTL
            elif _is_strong_ltr(codepoint):
                glyph_direction = TEXT_DIRECTION_LTR
            if glyph_direction != resolved_direction and not is_extend(codepoint):
                result.bidi_applied = True
            var font_id = fallback_font_id(codepoint)
            if is_extend(codepoint) and len(result.glyphs) > 0:
                # Marks, variation selectors, and ZWJ inherit the preceding
                # run's face/direction instead of creating a visual split.
                var previous = result.glyphs[len(result.glyphs) - 1]
                font_id = previous.font_id
                glyph_direction = run_direction if run_line != -1 else glyph_direction
            var glyph_script = script_id(codepoint)
            if is_extend(codepoint) and run_line != -1:
                glyph_script = run_script
            if font_id != 0:
                result.used_fallback_font = True
            if (
                run_line == -1
                or run_line != line
                or run_direction != glyph_direction
                or run_font != font_id
                or run_script != glyph_script
            ):
                if run_line != -1:
                    result.runs.append(
                        ShapedRun(
                            run_line,
                            run_glyph_start,
                            len(result.glyphs),
                            run_cluster_start,
                            index,
                            run_direction,
                            run_font,
                            run_script,
                        )
                    )
                run_line = line
                run_direction = glyph_direction
                run_font = font_id
                run_script = glyph_script
                run_glyph_start = len(result.glyphs)
                run_cluster_start = index
            result.glyphs.append(
                ShapedGlyph(
                    codepoint,
                    codepoint,
                    index,
                    font_id,
                    advance,
                    line_width,
                    line_height * Float32(line),
                    line,
                )
            )
            line_width += advance
            index += 1

        if run_line != -1:
            result.runs.append(
                ShapedRun(
                    run_line,
                    run_glyph_start,
                    len(result.glyphs),
                    run_cluster_start,
                    text.count_codepoints(),
                    run_direction,
                    run_font,
                    run_script,
                )
            )

        if line_width > max_line_width:
            max_line_width = line_width
        if width_limit > 0.0 and max_line_width > width_limit:
            max_line_width = width_limit
        result.measurement = TextMeasurement(
            Size(max_line_width, line_height * Float32(line_count)),
            line_count,
        )

        # The fallback has no full Unicode bidi engine, but it can provide a
        # stable run-level visual order for mixed paragraphs. Keep clusters and
        # positions intact so editors can still map back to source offsets.
        if resolved_direction == TEXT_DIRECTION_RTL:
            result.bidi_applied = True
        if result.bidi_applied:
            var visual = List[ShapedGlyph](capacity=len(result.glyphs))
            for visual_line in range(line_count):
                if resolved_direction == TEXT_DIRECTION_RTL:
                    var run_index = len(result.runs)
                    while run_index > 0:
                        run_index -= 1
                        var run = result.runs[run_index]
                        if run.line != visual_line:
                            continue
                        if run.direction == TEXT_DIRECTION_RTL:
                            var glyph_index = run.glyph_end
                            while glyph_index > run.glyph_start:
                                glyph_index -= 1
                                visual.append(result.glyphs[glyph_index])
                        else:
                            for glyph_index in range(run.glyph_start, run.glyph_end):
                                visual.append(result.glyphs[glyph_index])
                else:
                    for run_index in range(len(result.runs)):
                        var run = result.runs[run_index]
                        if run.line != visual_line:
                            continue
                        if run.direction == TEXT_DIRECTION_RTL:
                            var glyph_index = run.glyph_end
                            while glyph_index > run.glyph_start:
                                glyph_index -= 1
                                visual.append(result.glyphs[glyph_index])
                        else:
                            for glyph_index in range(run.glyph_start, run.glyph_end):
                                visual.append(result.glyphs[glyph_index])
            result.glyphs = visual^
        return result^


def shape_text(
    text: String,
    style: Style,
    max_width: Float32 = 0.0,
    direction: Int = 1,
) -> ShapedText:
    """Shape text through the portable adapter until a native shaper is used."""
    var shaper = PortableTextShaper()
    return shaper.shape(text, style, max_width, direction)
