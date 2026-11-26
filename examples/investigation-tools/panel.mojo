"""Versioned fixed controls and stable targets, never serialized live components."""
from std.ffi import external_call
from moxi.json import json_quote, json_char, json_document_is_valid, json_skip_whitespace, json_parse_number
from model import Investigation, MembershipMode, ModelKind, FixtureState, FIXTURE_ID, TARGET_ID, PANEL_CONTROLS

comptime PANEL_VERSION = 1
comptime RULE_ID = "reading>=70"
comptime MAX_PANEL_BYTES = 8192


struct Reader:
    """Small strict reader; escape decoding follows the existing FDG adapter."""
    var text: String
    var pos: Int

    def __init__(out self, text: String):
        self.text = text
        self.pos = 0

    def peek(mut self) -> String:
        self.pos = json_skip_whitespace(self.text, self.pos)
        return json_char(self.text, self.pos)

    def take(mut self, expected: String) raises:
        if self.peek() != expected:
            raise Error("Invalid panel value type")
        self.pos += 1

    def hex4(mut self) -> Int:
        var code = 0
        for _ in range(4):
            var glyph = ord(json_char(self.text, self.pos))
            self.pos += 1
            var digit = glyph - 48
            if glyph >= 97:
                digit = glyph - 87
            elif glyph >= 65:
                digit = glyph - 55
            code = code*16 + digit
        return code

    def string(mut self) raises -> String:
        self.take(chr(34))
        var result = String("")
        while json_char(self.text, self.pos) != chr(34):
            var glyph = json_char(self.text, self.pos)
            self.pos += 1
            if glyph == chr(92):
                glyph = json_char(self.text, self.pos)
                self.pos += 1
                if glyph == "u":
                    var code = self.hex4()
                    if code >= 0xD800 and code <= 0xDBFF:
                        self.take(chr(92))
                        self.take("u")
                        var low = self.hex4()
                        if low < 0xDC00 or low > 0xDFFF:
                            raise Error("Invalid Unicode surrogate")
                        code = 0x10000 + (code - 0xD800)*1024 + low - 0xDC00
                    elif code >= 0xDC00 and code <= 0xDFFF:
                        raise Error("Unpaired Unicode surrogate")
                    if code < 32:
                        raise Error("Panel text cannot contain control characters")
                    result += chr(code)
                elif glyph == "n" or glyph == "r" or glyph == "t" or glyph == "b" or glyph == "f":
                    raise Error("Panel text cannot contain control characters")
                else:
                    result += glyph
            else:
                result += glyph
        self.pos += 1
        return result

    def number_text(mut self) raises -> String:
        _ = self.peek()
        var start = self.pos
        if not json_parse_number(self.text, self.pos):
            raise Error("Expected a panel number")
        return String(self.text[codepoint=start:self.pos])


def panel_json(model: Investigation) raises -> String:
    model.validate_panel()
    return String('{"version":', PANEL_VERSION, ',"fixture":', json_quote(FIXTURE_ID),
        ',"target":', json_quote(TARGET_ID), ',"fixture_state":', json_quote(model.fixture.value),
        ',"cohort_name":', json_quote(model.name), ',"hypothesis":', json_quote(model.hypothesis),
        ',"membership":', json_quote(model.mode.value), ',"rule":', json_quote(RULE_ID),
        ',"members":', model.ids(), ',"model":', json_quote(model.fit.kind.value),
        ',"coefficients":[', model.fit.c0, ',', model.fit.c1, ',', model.fit.c2,
        '],"controls":', PANEL_CONTROLS, '}')


def parse_panel(text: String) raises -> Investigation:
    if text.byte_length() > MAX_PANEL_BYTES or not json_document_is_valid(text):
        raise Error("Invalid panel JSON or file exceeds 8 KiB")
    var reader = Reader(text)
    var model = Investigation()
    var seen = List[String]()
    reader.take("{")
    while reader.peek() != "}":
        var key = reader.string()
        for field in seen:
            if field == key:
                raise Error("Duplicate panel field")
        seen.append(key)
        reader.take(":")
        if key == "version":
            if Int(reader.number_text()) != PANEL_VERSION:
                raise Error("Unsupported panel version")
        elif key == "fixture":
            if reader.string() != FIXTURE_ID:
                raise Error("Unknown fixture; refusing to retarget observations")
        elif key == "target":
            if reader.string() != TARGET_ID:
                raise Error("Unknown panel target")
        elif key == "fixture_state":
            model.fixture = FixtureState.parse(reader.string())
        elif key == "cohort_name":
            model.name = reader.string()
        elif key == "hypothesis":
            model.hypothesis = reader.string()
        elif key == "membership":
            model.mode = MembershipMode.parse(reader.string())
        elif key == "rule":
            if reader.string() != RULE_ID:
                raise Error("Unsupported cohort rule")
        elif key == "members":
            reader.take("[")
            while reader.peek() != "]":
                model.members.append(Int(reader.number_text()))
                if len(model.members) > 8:
                    raise Error("Too many cohort members")
                if reader.peek() == "]":
                    break
                reader.take(",")
            reader.take("]")
        elif key == "model":
            model.fit.kind = ModelKind.parse(reader.string())
        elif key == "coefficients":
            reader.take("[")
            model.fit.c0 = Float64(reader.number_text())
            reader.take(",")
            model.fit.c1 = Float64(reader.number_text())
            reader.take(",")
            model.fit.c2 = Float64(reader.number_text())
            reader.take("]")
        elif key == "controls":
            reader.take("[")
            if reader.string() != "refit":
                raise Error("Unsupported panel controls")
            reader.take(",")
            if reader.string() != "coefficients":
                raise Error("Unsupported panel controls")
            reader.take("]")
        else:
            raise Error("Unsupported panel field")
        if reader.peek() == "}":
            break
        reader.take(",")
    reader.take("}")
    if len(seen) != 12:
        raise Error("Panel is missing required fields")
    # Set the declared fixture without re-collecting or overwriting frozen IDs.
    model.notebook.rows[1].reading = 76 if model.fixture == FixtureState.CROSSING else 58
    model.fitted = True
    model.validate_panel()
    return model^


def save_panel(path: String, model: Investigation) raises:
    var contents = panel_json(model)
    var filename = path
    if external_call["investigation_save", Int32](filename.as_c_string_span().ptr(), contents.as_c_string_span().ptr()) == 0:
        raise Error("Could not save panel; previous file was preserved")


def load_panel(path: String) raises -> Investigation:
    with open(path, "r") as source:
        return parse_panel(source.read(MAX_PANEL_BYTES + 1))
