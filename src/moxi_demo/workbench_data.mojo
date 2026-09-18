"""Application-local data model for the numerical workbench.

The workbench keeps its data contract in the demo package.  It owns source row
identity, numeric fields, filtering, ordering, and selection so the UI can
rebuild views without teaching the core runtime about tabular data.

CSV support is intentionally small and deterministic: the first non-empty
line is a comma-separated header, every non-key column is numeric, blank or
``null`` numeric cells are missing, and a malformed non-empty numeric cell
rejects the entire import.  Imports are bounded to ``WORKBENCH_MAX_ROWS`` and
are committed atomically after parsing succeeds.
"""

from std.collections import List, Set

from moxi.plot_selection import PlotSelection
from moxi_plot.fixtures import make_plot_data_fixture
from moxi_plot.plot_data import (
    COLUMN_CATEGORY,
    COLUMN_FLOAT32,
    COLUMN_FLOAT64,
    COLUMN_INT64,
    COLUMN_TIMESTAMP,
    COLUMN_DURATION,
)


comptime WORKBENCH_MAX_ROWS = 100000
comptime WORKBENCH_MAX_COLUMNS = 64
comptime WORKBENCH_MAX_CSV_BYTES = 33554432
comptime WORKBENCH_MAX_INT = 9223372036854775807
# Keep exponent work bounded while covering Float64's finite decimal range;
# the final cast and midpoint check enforce the narrower Float32 contract.
comptime WORKBENCH_MAX_DECIMAL_EXPONENT = 308
# The midpoint between Float32's largest finite value and +infinity.  The
# shortest string emitted for Float32::MAX (3.4028235e+38) is above MAX's
# exact value but still rounds back to MAX, so comparing against MAX itself
# would reject our own export format.
comptime WORKBENCH_FLOAT32_OVERFLOW_MIDPOINT: Float64 = 3.4028235677973366e38


struct _FloatParseResult(ImplicitlyCopyable):
    var valid: Bool
    var value: Float32

    def __init__(out self, valid: Bool, value: Float32 = 0.0):
        self.valid = valid
        self.value = value


struct CsvLoadResult(ImplicitlyCopyable):
    """Result and user-facing diagnostic for one atomic CSV load attempt."""

    var accepted: Bool
    var message: String
    var line: Int
    var rows: Int
    var columns: Int
    var missing_values: Int
    var rejected_rows: Int

    def __init__(
        out self,
        accepted: Bool = False,
        message: String = "",
        line: Int = 0,
        rows: Int = 0,
        columns: Int = 0,
        missing_values: Int = 0,
        rejected_rows: Int = 0,
    ):
        self.accepted = accepted
        self.message = message
        self.line = line
        self.rows = rows
        self.columns = columns
        self.missing_values = missing_values
        self.rejected_rows = rejected_rows

    def ok(self) -> Bool:
        return self.accepted

    def succeeded(self) -> Bool:
        return self.accepted

    def error_message(self) -> String:
        return self.message


def _is_space(codepoint: Int) -> Bool:
    return (
        codepoint == 9
        or codepoint == 10
        or codepoint == 13
        or codepoint == 32
    )


def _trim(value: String) -> String:
    var length = value.count_codepoints()
    var first = 0
    var last = length
    while first < last:
        var glyph = String(value[codepoint=first:first + 1])
        if not _is_space(ord(glyph)):
            break
        first += 1
    while last > first:
        var glyph = String(value[codepoint=last - 1:last])
        if not _is_space(ord(glyph)):
            break
        last -= 1
    return String(value[codepoint=first:last])


def _is_blank(value: String) -> Bool:
    return _trim(value).count_codepoints() == 0


def _contains(value: String, needle: Int) -> Bool:
    for index in range(value.count_codepoints()):
        if ord(String(value[codepoint=index:index + 1])) == needle:
            return True
    return False


def _split_csv_line(line: String) -> List[String]:
    """Split the deliberately narrow CSV dialect without quote expansion."""
    var result = List[String]()
    var pieces = line.split(",")
    for index in range(len(pieces)):
        result.append(_trim(String(pieces[index])))
    return result^


def _parse_float32(text: String) -> _FloatParseResult:
    """Parse finite decimal/scientific notation without a runtime dependency."""
    var value = _trim(text)
    if value.count_codepoints() == 0 or value == "null":
        return _FloatParseResult(True)
    if _contains(value, 34) or _contains(value, 44):
        return _FloatParseResult(False)

    var length = value.count_codepoints()
    var cursor = 0
    # Accumulate in Float64 so decimal text is rounded only once when the
    # workbench stores the requested Float32 value.  Parsing through Float32
    # for each digit can move a later CSV round trip by one ulp.
    var sign: Float64 = 1.0
    if cursor < length:
        var glyph = String(value[codepoint=cursor:cursor + 1])
        if glyph == "-":
            sign = -1.0
            cursor += 1
        elif glyph == "+":
            cursor += 1

    var whole: Float64 = 0.0
    var digits = 0
    while cursor < length:
        var glyph = String(value[codepoint=cursor:cursor + 1])
        var codepoint = ord(glyph)
        if codepoint < 48 or codepoint > 57:
            break
        whole = whole * 10.0 + Float64(codepoint - 48)
        digits += 1
        cursor += 1

    var fraction: Float64 = 0.0
    var scale: Float64 = 0.1
    if cursor < length and String(value[codepoint=cursor:cursor + 1]) == ".":
        cursor += 1
        while cursor < length:
            var glyph = String(value[codepoint=cursor:cursor + 1])
            var codepoint = ord(glyph)
            if codepoint < 48 or codepoint > 57:
                break
            fraction += Float64(codepoint - 48) * scale
            scale *= 0.1
            digits += 1
            cursor += 1

    if digits == 0:
        return _FloatParseResult(False)

    var exponent = 0
    var exponent_sign = 1
    if cursor < length:
        var marker = String(value[codepoint=cursor:cursor + 1])
        if marker != "e" and marker != "E":
            return _FloatParseResult(False)
        cursor += 1
        if cursor < length:
            var sign_glyph = String(value[codepoint=cursor:cursor + 1])
            if sign_glyph == "-":
                exponent_sign = -1
                cursor += 1
            elif sign_glyph == "+":
                cursor += 1
        var exponent_digits = 0
        while cursor < length:
            var glyph = String(value[codepoint=cursor:cursor + 1])
            var codepoint = ord(glyph)
            if codepoint < 48 or codepoint > 57:
                return _FloatParseResult(False)
            var exponent_digit = codepoint - 48
            if exponent > WORKBENCH_MAX_DECIMAL_EXPONENT // 10:
                return _FloatParseResult(False)
            if (
                exponent == WORKBENCH_MAX_DECIMAL_EXPONENT // 10
                and exponent_digit > WORKBENCH_MAX_DECIMAL_EXPONENT % 10
            ):
                return _FloatParseResult(False)
            exponent = exponent * 10 + exponent_digit
            exponent_digits += 1
            cursor += 1
        if exponent_digits == 0:
            return _FloatParseResult(False)

    if cursor != length:
        return _FloatParseResult(False)

    exponent *= exponent_sign
    var numeric = whole + fraction
    if exponent > 0:
        for _ in range(exponent):
            numeric *= 10.0
    elif exponent < 0:
        for _ in range(-exponent):
            numeric *= 0.1
    numeric *= sign

    # Reject values which round to infinity.  The midpoint admits the
    # shortest decimal representation emitted for Float32::MAX while still
    # rejecting the first decimal values that cannot become finite Float32.
    if (
        numeric > WORKBENCH_FLOAT32_OVERFLOW_MIDPOINT
        or numeric < -WORKBENCH_FLOAT32_OVERFLOW_MIDPOINT
    ):
        return _FloatParseResult(False)
    return _FloatParseResult(True, Float32(numeric))


def _parse_key(text: String) -> Int:
    var value = _trim(text)
    if value.count_codepoints() == 0 or value == "null":
        return -1
    var length = value.count_codepoints()
    var cursor = 0
    if String(value[codepoint=0:1]) == "+":
        cursor = 1
    elif String(value[codepoint=0:1]) == "-":
        return -1
    var parsed = 0
    var digits = 0
    while cursor < length:
        var codepoint = ord(String(value[codepoint=cursor:cursor + 1]))
        if codepoint < 48 or codepoint > 57:
            return -1
        if parsed > WORKBENCH_MAX_INT // 10:
            return -1
        if parsed == WORKBENCH_MAX_INT // 10 and codepoint - 48 > WORKBENCH_MAX_INT % 10:
            return -1
        parsed = parsed * 10 + codepoint - 48
        digits += 1
        cursor += 1
    if digits == 0:
        return -1
    return parsed


def _numeric_kind(kind: Int) -> Bool:
    return (
        kind == COLUMN_FLOAT32
        or kind == COLUMN_FLOAT64
        or kind == COLUMN_INT64
        or kind == COLUMN_TIMESTAMP
        or kind == COLUMN_DURATION
    )


struct WorkbenchData(ImplicitlyCopyable):
    """Stable-key numeric rows and the projections needed by the workbench UI.

    ``values`` and ``valid`` are row-major flattened arrays.  Visible entries
    are source row indices, so filtering and sorting never change row identity.
    Selection is key-based and intentionally survives filtering; callers can
    expose ``hidden_selected_count`` to make that policy visible.
    """

    var keys: List[Int]
    var field_names: List[String]
    var values: List[Float32]
    var valid: List[Bool]
    var visible_rows: List[Int]
    var selected: PlotSelection
    var filter_field: String
    var filter_threshold: Float32
    var filter_enabled: Bool
    var sort_field: String
    var sort_descending: Bool
    var next_key: Int
    var version: Int
    var last_load: CsvLoadResult

    def __init__(out self):
        self.keys = List[Int]()
        self.field_names = List[String]()
        self.values = List[Float32]()
        self.valid = List[Bool]()
        self.visible_rows = List[Int]()
        self.selected = PlotSelection()
        self.filter_field = ""
        self.filter_threshold = 0.0
        self.filter_enabled = False
        self.sort_field = ""
        self.sort_descending = False
        self.next_key = 0
        self.version = 0
        self.last_load = CsvLoadResult(True, "empty", 0, 0, 0, 0, 0)

    def __init__(out self, *, copy: Self):
        self.keys = copy.keys.copy()
        self.field_names = copy.field_names.copy()
        self.values = copy.values.copy()
        self.valid = copy.valid.copy()
        self.visible_rows = copy.visible_rows.copy()
        self.selected = copy.selected.clone()
        self.filter_field = copy.filter_field
        self.filter_threshold = copy.filter_threshold
        self.filter_enabled = copy.filter_enabled
        self.sort_field = copy.sort_field
        self.sort_descending = copy.sort_descending
        self.next_key = copy.next_key
        self.version = copy.version
        self.last_load = copy.last_load

    def clone(self) -> WorkbenchData:
        return WorkbenchData(copy=self)

    def row_count(self) -> Int:
        return len(self.keys)

    def field_count(self) -> Int:
        return len(self.field_names)

    def visible_count(self) -> Int:
        return len(self.visible_rows)

    def selected_count(self) -> Int:
        return self.selected.count()

    def field_name(self, index: Int) -> String:
        if index < 0 or index >= self.field_count():
            return ""
        return self.field_names[index]

    def field_index(self, name: String) -> Int:
        for index in range(self.field_count()):
            if self.field_names[index] == name:
                return index
        return -1

    def numeric_fields(self) -> List[String]:
        return self.field_names.copy()

    def selected_field(self) -> String:
        return self.filter_field

    def last_load_result(self) -> CsvLoadResult:
        return self.last_load

    def key_at(self, row: Int) -> Int:
        if row < 0 or row >= self.row_count():
            return -1
        return self.keys[row]

    def visible_source_index_at(self, index: Int) -> Int:
        if index < 0 or index >= self.visible_count():
            return -1
        return self.visible_rows[index]

    def visible_key_at(self, index: Int) -> Int:
        var source_index = self.visible_source_index_at(index)
        return self.key_at(source_index)

    def source_index_for_key(self, key: Int) -> Int:
        # Fixture and generated CSV keys are monotone from zero; keep their
        # common lookup path constant-time while retaining support for sparse
        # explicit keys through the fallback scan.
        if key >= 0 and key < self.row_count() and self.keys[key] == key:
            return key
        for index in range(self.row_count()):
            if self.keys[index] == key:
                return index
        return -1

    def value_is_valid(self, field: String, row: Int) -> Bool:
        var field_index = self.field_index(field)
        if field_index < 0 or row < 0 or row >= self.row_count():
            return False
        return self.valid[row * self.field_count() + field_index]

    def value_at(self, field: String, row: Int) -> Float32:
        var field_index = self.field_index(field)
        if field_index < 0 or row < 0 or row >= self.row_count():
            return 0.0
        return self.values[row * self.field_count() + field_index]

    def numeric_value_at(self, field: String, row: Int) -> Float32:
        return self.value_at(field, row)

    def visible_value_at(self, field: String, visible_index: Int) -> Float32:
        return self.value_at(field, self.visible_source_index_at(visible_index))

    def visible_value_is_valid(self, field: String, visible_index: Int) -> Bool:
        return self.value_is_valid(field, self.visible_source_index_at(visible_index))

    def visible_indices(self) -> List[Int]:
        return self.visible_rows.copy()

    def _append_field(mut self, name: String):
        self.field_names.append(name)

    def _append_row(mut self, key: Int):
        self.keys.append(key)
        for _ in range(self.field_count()):
            self.values.append(0.0)
            self.valid.append(False)

    def _set_value(mut self, row: Int, field_index: Int, value: Float32, is_valid: Bool):
        if row < 0 or row >= self.row_count():
            return
        if field_index < 0 or field_index >= self.field_count():
            return
        var offset = row * self.field_count() + field_index
        self.values[offset] = value
        self.valid[offset] = is_valid

    def _rebuild_visible(mut self):
        self.visible_rows = List[Int]()
        for row in range(self.row_count()):
            var include = True
            if self.filter_enabled:
                include = (
                    self.value_is_valid(self.filter_field, row)
                    and self.value_at(self.filter_field, row) > self.filter_threshold
                )
            if include:
                self.visible_rows.append(row)
        if self.sort_field.count_codepoints() > 0:
            var active_sort_field = self.sort_field
            var active_sort_descending = self.sort_descending
            self._sort_visible_in_place(active_sort_field, active_sort_descending)

    def _sort_precedes(
        self,
        left: Int,
        right: Int,
        field_index: Int,
        descending: Bool,
    ) -> Bool:
        """Return whether ``left`` belongs before ``right``.

        Missing values sort after valid values in both directions.  Equal
        values deliberately return false, so the merge below keeps source
        order and therefore provides a stable sort.
        """
        var width = self.field_count()
        var left_valid = self.valid[left * width + field_index]
        var right_valid = self.valid[right * width + field_index]
        if left_valid and not right_valid:
            return True
        if not left_valid or not right_valid:
            return False
        var left_value = self.values[left * width + field_index]
        var right_value = self.values[right * width + field_index]
        return (
            left_value > right_value
            if descending
            else left_value < right_value
        )

    def _sort_visible_in_place(mut self, field: String, descending: Bool):
        """Stable bottom-up merge sort of source indices in O(n log n)."""
        var field_index = self.field_index(field)
        if field_index < 0 or len(self.visible_rows) < 2:
            return

        var count = len(self.visible_rows)
        var scratch = List[Int](capacity=count)
        for _ in range(count):
            scratch.append(0)

        var width = 1
        while width < count:
            var start = 0
            while start < count:
                var middle = start + width
                if middle > count:
                    middle = count
                var finish = middle + width
                if finish > count:
                    finish = count
                var left = start
                var right = middle
                var output = start
                while output < finish:
                    if left >= middle:
                        scratch[output] = self.visible_rows[right]
                        right += 1
                    elif right >= finish:
                        scratch[output] = self.visible_rows[left]
                        left += 1
                    elif self._sort_precedes(
                        self.visible_rows[right],
                        self.visible_rows[left],
                        field_index,
                        descending,
                    ):
                        scratch[output] = self.visible_rows[right]
                        right += 1
                    else:
                        # Choosing the left side on equality preserves source
                        # order and makes the operation stable.
                        scratch[output] = self.visible_rows[left]
                        left += 1
                    output += 1
                start = finish

            for index in range(count):
                self.visible_rows[index] = scratch[index]
            width *= 2

    def set_filter_field(mut self, field: String) -> Bool:
        if self.field_index(field) < 0:
            return False
        self.filter_field = field
        self._rebuild_visible()
        return True

    def set_threshold(mut self, threshold: Float32):
        self.filter_threshold = threshold
        self.filter_enabled = self.filter_field.count_codepoints() > 0
        self._rebuild_visible()

    def set_filter(mut self, field: String, threshold: Float32) -> Bool:
        if not self.set_filter_field(field):
            return False
        self.set_threshold(threshold)
        return True

    def clear_filter(mut self):
        self.filter_enabled = False
        self._rebuild_visible()

    def filter_is_active(self) -> Bool:
        return self.filter_enabled

    def sort_visible(mut self, field: String, descending: Bool = False) -> Bool:
        if self.field_index(field) < 0:
            return False
        self.sort_field = field
        self.sort_descending = descending
        self._sort_visible_in_place(field, descending)
        return True

    def clear_sort(mut self):
        self.sort_field = ""
        self.sort_descending = False
        self._rebuild_visible()

    def is_selected_key(self, key: Int) -> Bool:
        return self.selected.contains(key)

    def toggle_selected_key(mut self, key: Int) -> Bool:
        if self.source_index_for_key(key) < 0:
            return False
        return self.selected.toggle(key)

    def toggle_selected_visible(mut self, index: Int) -> Bool:
        return self.toggle_selected_key(self.visible_key_at(index))

    def select_key(mut self, key: Int) -> Bool:
        if self.source_index_for_key(key) < 0:
            return False
        return self.selected.add(key)

    def deselect_key(mut self, key: Int) -> Bool:
        return self.selected.remove(key)

    def clear_selection(mut self):
        self.selected.clear()

    def selected_visible_count(self) -> Int:
        var count = 0
        for index in range(self.visible_count()):
            if self.selected.contains(self.visible_key_at(index)):
                count += 1
        return count

    def hidden_selected_count(self) -> Int:
        return self.selected_count() - self.selected_visible_count()

    def selection_contains_hidden(self) -> Bool:
        return self.hidden_selected_count() > 0

    def selected_keys(self) -> List[Int]:
        return self.selected.keys.copy()

    def _reset_data(mut self):
        self.keys = List[Int]()
        self.field_names = List[String]()
        self.values = List[Float32]()
        self.valid = List[Bool]()
        self.visible_rows = List[Int]()
        self.selected.clear()
        self.filter_field = ""
        self.filter_threshold = 0.0
        self.filter_enabled = False
        self.sort_field = ""
        self.sort_descending = False
        self.next_key = 0

    def export_selected_csv(self) -> String:
        var result = "key"
        for field in range(self.field_count()):
            result += String(",", self.field_names[field])
        result += "\n"
        # Export in source order, while selection membership remains key based.
        for row in range(self.row_count()):
            if not self.selected.contains(self.keys[row]):
                continue
            result += String(self.keys[row])
            for field in range(self.field_count()):
                result += ","
                var offset = row * self.field_count() + field
                if self.valid[offset]:
                    result += String(self.values[offset])
            result += "\n"
        return result

    def load_csv_text(mut self, contents: String) -> CsvLoadResult:
        return self.load_csv(contents)

    def load_csv(mut self, contents: String) -> CsvLoadResult:
        """Parse numeric CSV atomically; failed input leaves current data intact."""
        if contents.byte_length() > WORKBENCH_MAX_CSV_BYTES:
            self.last_load = CsvLoadResult(
                False,
                String("CSV exceeds the ", WORKBENCH_MAX_CSV_BYTES, " byte limit"),
                1,
                0,
                0,
                0,
                1,
            )
            return self.last_load

        var temporary = WorkbenchData()
        var lines = contents.split("\n")
        var header_found = False
        var header = List[String]()
        var key_field_index = -1
        var seen_keys = Set[Int]()
        var missing_values = 0
        var line_number: Int

        for line_index in range(len(lines)):
            line_number = line_index + 1
            var line = String(lines[line_index])
            if line.count_codepoints() > 0 and ord(String(line[codepoint=line.count_codepoints() - 1:line.count_codepoints()])) == 13:
                var without_cr = String(line[codepoint=0:line.count_codepoints() - 1])
                line = without_cr
            if _is_blank(line):
                continue

            var fields = _split_csv_line(line)
            if not header_found:
                if len(fields) == 0:
                    self.last_load = CsvLoadResult(False, "CSV header is empty", line_number, 0, 0, 0, 1)
                    return self.last_load
                if len(fields) > WORKBENCH_MAX_COLUMNS:
                    self.last_load = CsvLoadResult(False, String("CSV exceeds the ", WORKBENCH_MAX_COLUMNS, " column limit"), line_number, 0, len(fields), 0, 1)
                    return self.last_load
                for field_index in range(len(fields)):
                    var name = fields[field_index]
                    if name.count_codepoints() == 0:
                        self.last_load = CsvLoadResult(False, "CSV header contains an empty field", line_number, 0, len(fields), 0, 1)
                        return self.last_load
                    if _contains(name, 34) or _contains(name, 44):
                        self.last_load = CsvLoadResult(False, "CSV header fields cannot be quoted or contain commas", line_number, 0, len(fields), 0, 1)
                        return self.last_load
                    for previous in range(field_index):
                        if fields[previous] == name:
                            self.last_load = CsvLoadResult(False, String("duplicate CSV field: ", name), line_number, 0, len(fields), 0, 1)
                            return self.last_load
                    if name == "key":
                        if key_field_index >= 0:
                            self.last_load = CsvLoadResult(False, "CSV contains more than one key field", line_number, 0, len(fields), 0, 1)
                            return self.last_load
                        key_field_index = field_index
                    header.append(name)
                if len(header) == 0 or (len(header) == 1 and key_field_index >= 0):
                    self.last_load = CsvLoadResult(False, "CSV must contain at least one numeric field", line_number, 0, len(header), 0, 1)
                    return self.last_load
                for field_index in range(len(header)):
                    if field_index != key_field_index:
                        temporary._append_field(header[field_index])
                header_found = True
                continue

            if len(fields) != len(header):
                self.last_load = CsvLoadResult(False, String("CSV row has ", len(fields), " fields; expected ", len(header)), line_number, 0, len(header), missing_values, 1)
                return self.last_load
            if temporary.row_count() >= WORKBENCH_MAX_ROWS:
                self.last_load = CsvLoadResult(False, String("CSV exceeds the ", WORKBENCH_MAX_ROWS, " row limit"), line_number, 0, len(header), missing_values, 1)
                return self.last_load

            var row_key = temporary.next_key
            if key_field_index >= 0:
                var parsed_key = _parse_key(fields[key_field_index])
                if parsed_key < 0:
                    self.last_load = CsvLoadResult(False, "CSV key must be a non-negative integer", line_number, 0, len(header), missing_values, 1)
                    return self.last_load
                row_key = parsed_key
                if row_key in seen_keys:
                    self.last_load = CsvLoadResult(False, "CSV keys must be unique non-negative integers", line_number, 0, len(header), missing_values, 1)
                    return self.last_load
                _ = seen_keys.add(row_key)
            temporary._append_row(row_key)
            if row_key >= temporary.next_key:
                if row_key == WORKBENCH_MAX_INT:
                    temporary.next_key = WORKBENCH_MAX_INT
                else:
                    temporary.next_key = row_key + 1
            var output_field = 0
            for field_index in range(len(header)):
                if field_index == key_field_index:
                    continue
                var token = fields[field_index]
                var is_missing = _is_blank(token) or token == "null"
                var parsed = _parse_float32(token)
                if not parsed.valid:
                    self.last_load = CsvLoadResult(False, String("malformed numeric value in field ", header[field_index]), line_number, 0, len(header), missing_values, 1)
                    return self.last_load
                if is_missing:
                    missing_values += 1
                temporary._set_value(temporary.row_count() - 1, output_field, parsed.value, not is_missing)
                output_field += 1

        if not header_found:
            self.last_load = CsvLoadResult(False, "CSV input has no header", 1, 0, 0, 0, 1)
            return self.last_load

        temporary._rebuild_visible()
        self.keys = temporary.keys.copy()
        self.field_names = temporary.field_names.copy()
        self.values = temporary.values.copy()
        self.valid = temporary.valid.copy()
        self.visible_rows = temporary.visible_rows.copy()
        self.selected = PlotSelection()
        self.filter_field = ""
        self.filter_threshold = 0.0
        self.filter_enabled = False
        self.sort_field = ""
        self.sort_descending = False
        self.next_key = temporary.next_key
        self.version += 1
        self.last_load = CsvLoadResult(True, "CSV loaded", 0, self.row_count(), self.field_count(), missing_values, 0)
        return self.last_load


def make_workbench_fixture(row_count: Int = -1) -> WorkbenchData:
    """Build the 48-row plot fixture as a numeric workbench dataset."""
    var source = make_plot_data_fixture(row_count)
    var result = WorkbenchData()
    for field_index in range(source.column_count()):
        var kind = source.column_kind_at(field_index)
        if _numeric_kind(kind):
            result._append_field(source.column_name(field_index))
    for row in range(source.row_count()):
        result._append_row(source.key_at(row))
        for field_index in range(source.column_count()):
            var name = source.column_name(field_index)
            var output_field = result.field_index(name)
            if output_field < 0:
                continue
            result._set_value(
                row,
                output_field,
                source.float_field_at(name, row),
                source.field_is_valid(name, row),
            )
        if source.key_at(row) >= result.next_key:
            result.next_key = source.key_at(row) + 1
    result.filter_field = "value" if result.field_index("value") >= 0 else result.field_name(0)
    result._rebuild_visible()
    result.last_load = CsvLoadResult(True, "fixture", 0, result.row_count(), result.field_count(), 0, 0)
    return result^
