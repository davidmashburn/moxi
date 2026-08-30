"""Column-oriented plotting data with typed fields and stable row identity.

The compact ``x``/``y`` convenience columns remain available, while named
columns make the declarative plot specification field-aware. Snapshots are
immutable owned values at the API boundary. Views are zero-copy row-index
projections whose lifetime is tied to the borrowed source table; transforms
still materialize a new table when they change rows or column values.
"""

from std.collections import List
from std.memory import Pointer
from std.math import floor
from std.origin import Origin

from .plot_selection import PlotSelection


comptime COLUMN_FLOAT32 = 1
comptime COLUMN_INT64 = 2
comptime COLUMN_BOOL = 3
comptime COLUMN_STRING = 4
comptime COLUMN_TIMESTAMP = 5
comptime COLUMN_DURATION = 6
comptime COLUMN_FLOAT64 = 7
comptime COLUMN_CATEGORY = 8


def column_kind_name(kind: Int) -> String:
    if kind == COLUMN_INT64:
        return "int64"
    if kind == COLUMN_BOOL:
        return "bool"
    if kind == COLUMN_STRING:
        return "string"
    if kind == COLUMN_TIMESTAMP:
        return "timestamp"
    if kind == COLUMN_DURATION:
        return "duration"
    if kind == COLUMN_FLOAT64:
        return "float64"
    if kind == COLUMN_CATEGORY:
        return "category"
    return "float32"


struct PlotColumn:
    """One typed nullable column in a plot table."""

    var name: String
    var kind: Int
    var float_values: List[Float32]
    var float64_values: List[Float64]
    var int_values: List[Int64]
    var bool_values: List[Bool]
    var string_values: List[String]
    var category_indices: List[Int]
    var category_values: List[String]
    var valid: List[Bool]

    def __init__(out self, name: String, kind: Int):
        self.name = name
        self.kind = kind
        self.float_values = List[Float32]()
        self.float64_values = List[Float64]()
        self.int_values = List[Int64]()
        self.bool_values = List[Bool]()
        self.string_values = List[String]()
        self.category_indices = List[Int]()
        self.category_values = List[String]()
        self.valid = List[Bool]()

    def clone(self) -> PlotColumn:
        var result = PlotColumn(self.name, self.kind)
        result.float_values = self.float_values.copy()
        result.float64_values = self.float64_values.copy()
        result.int_values = self.int_values.copy()
        result.bool_values = self.bool_values.copy()
        result.string_values = self.string_values.copy()
        result.category_indices = self.category_indices.copy()
        result.category_values = self.category_values.copy()
        result.valid = self.valid.copy()
        return result^

    def append_default(mut self):
        if self.kind == COLUMN_INT64 or self.kind == COLUMN_TIMESTAMP or self.kind == COLUMN_DURATION:
            self.int_values.append(0)
        elif self.kind == COLUMN_BOOL:
            self.bool_values.append(False)
        elif self.kind == COLUMN_STRING:
            self.string_values.append("")
        elif self.kind == COLUMN_CATEGORY:
            self.category_indices.append(0)
        elif self.kind == COLUMN_FLOAT64:
            self.float64_values.append(0.0)
        else:
            self.float_values.append(0.0)
        self.valid.append(False)

    def row_count(self) -> Int:
        return len(self.valid)

    def category_index(mut self, value: String) -> Int:
        """Intern a category once and return its stable dictionary index."""
        for index in range(len(self.category_values)):
            if self.category_values[index] == value:
                return index
        self.category_values.append(value)
        return len(self.category_values) - 1

    def category_at(self, index: Int) -> String:
        if index < 0 or index >= len(self.category_values):
            return ""
        return self.category_values[index]


struct PlotDataSnapshot:
    """Immutable table value used by transforms and view projections."""

    var table: PlotDataTable

    def __init__(out self, table: PlotDataTable):
        var owned_copy = table.clone()
        self.table = owned_copy^

    def clone(self) -> PlotDataSnapshot:
        var owned_copy = self.table.clone()
        return PlotDataSnapshot(owned_copy^)

    def version(self) -> Int:
        return self.table.version

    def row_count(self) -> Int:
        return self.table.row_count()

    def key_at(self, index: Int) -> Int:
        return self.table.key_at(index)

    def row_is_valid(self, index: Int) -> Bool:
        return self.table.row_is_valid(index)

    def field_is_valid(self, field: String, index: Int) -> Bool:
        return self.table.field_is_valid(field, index)

    def float_at(self, field: String, index: Int) -> Float32:
        return self.table.float_field_at(field, index)

    def int_at(self, field: String, index: Int) -> Int64:
        return self.table.int_field_at(field, index)

    def bool_at(self, field: String, index: Int) -> Bool:
        return self.table.bool_field_at(field, index)

    def string_at(self, field: String, index: Int) -> String:
        return self.table.string_field_at(field, index)


struct PlotDataView[origin: Origin]:
    """A zero-copy stable row selection over a borrowed source table.

    The view owns only row indices. Its pointer carries the source origin, so
    Mojo keeps the table alive for the view and prevents unsafe mutation while
    an immutable view is live.
    """

    var source: Pointer[PlotDataTable, Self.origin]
    var row_indices: List[Int]

    def __init__(out self, ref[Self.origin] source: PlotDataTable):
        self.source = Pointer(to=source)
        self.row_indices = List[Int]()

    def clone(self) -> PlotDataView[Self.origin]:
        var result = PlotDataView[Self.origin](self.source[])
        result.row_indices = self.row_indices.copy()
        return result^

    def append(mut self, source_index: Int):
        if source_index >= 0 and source_index < self.source[].row_count():
            self.row_indices.append(source_index)

    def row_count(self) -> Int:
        return len(self.row_indices)

    def row_is_valid(self, index: Int) -> Bool:
        var source_index = self.source_index(index)
        return self.source[].row_is_valid(source_index)

    def field_is_valid(self, field: String, index: Int) -> Bool:
        var source_index = self.source_index(index)
        return self.source[].field_is_valid(field, source_index)

    def source_index(self, index: Int) -> Int:
        if index < 0 or index >= self.row_count():
            return -1
        return self.row_indices[index]

    def key_at(self, index: Int) -> Int:
        var source_index = self.source_index(index)
        return self.source[].key_at(source_index)

    def float_at(self, field: String, index: Int) -> Float32:
        var source_index = self.source_index(index)
        return self.source[].float_field_at(field, source_index)

    def int_at(self, field: String, index: Int) -> Int64:
        var source_index = self.source_index(index)
        return self.source[].int_field_at(field, source_index)

    def bool_at(self, field: String, index: Int) -> Bool:
        var source_index = self.source_index(index)
        return self.source[].bool_field_at(field, source_index)

    def string_at(self, field: String, index: Int) -> String:
        var source_index = self.source_index(index)
        return self.source[].string_field_at(field, source_index)


struct PlotDataTable:
    """A numeric x/y table with stable row keys and bounded mutations.

    The initial plot contract deliberately starts with two numeric columns.
    Keeping keys, validity, and a monotonically increasing version here gives
    renderers and future transforms an explicit cache boundary without making
    the plot specification own a window or a backend.
    """

    var keys: List[Int]
    var x_values: List[Float32]
    var y_values: List[Float32]
    var x_valid: List[Bool]
    var y_valid: List[Bool]
    var columns: List[PlotColumn]
    var next_key: Int
    var version: Int

    def __init__(out self):
        self.keys = List[Int]()
        self.x_values = List[Float32]()
        self.y_values = List[Float32]()
        self.x_valid = List[Bool]()
        self.y_valid = List[Bool]()
        self.columns = List[PlotColumn]()
        self.next_key = 0
        self.version = 0

    def clone(self) -> PlotDataTable:
        var result = PlotDataTable()
        result.keys = self.keys.copy()
        result.x_values = self.x_values.copy()
        result.y_values = self.y_values.copy()
        result.x_valid = self.x_valid.copy()
        result.y_valid = self.y_valid.copy()
        for index in range(len(self.columns)):
            var column = self.columns[index].clone()
            result.columns.append(column^)
        result.next_key = self.next_key
        result.version = self.version
        return result^

    def row_count(self) -> Int:
        return len(self.keys)

    def column_count(self) -> Int:
        return len(self.columns) + 2

    def column_name(self, index: Int) -> String:
        if index == 0:
            return "x"
        if index == 1:
            return "y"
        var column_index = index - 2
        if column_index < 0 or column_index >= len(self.columns):
            return ""
        return self.columns[column_index].name

    def column_kind_at(self, index: Int) -> Int:
        if index == 0 or index == 1:
            return COLUMN_FLOAT32
        var column_index = index - 2
        if column_index < 0 or column_index >= len(self.columns):
            return 0
        return self.columns[column_index].kind

    def column_index(self, name: String) -> Int:
        if name == "x" or name == "y":
            return -1
        for index in range(len(self.columns)):
            if self.columns[index].name == name:
                return index
        return -1

    def field_kind(self, name: String) -> Int:
        if name == "x" or name == "y":
            return COLUMN_FLOAT32
        var index = self.column_index(name)
        if index == -1:
            return 0
        return self.columns[index].kind

    def add_column(mut self, name: String, kind: Int) -> Bool:
        """Add a typed nullable field, initialized missing for existing rows."""
        if name.count_codepoints() == 0 or name == "x" or name == "y":
            return False
        if self.column_index(name) != -1:
            return False
        var safe_kind = kind
        if safe_kind < COLUMN_FLOAT32 or safe_kind > COLUMN_CATEGORY:
            safe_kind = COLUMN_FLOAT32
        var column = PlotColumn(name, safe_kind)
        for _ in range(self.row_count()):
            column.append_default()
        self.columns.append(column^)
        self.version += 1
        return True

    def add_float_column(mut self, name: String) -> Bool:
        return self.add_column(name, COLUMN_FLOAT32)

    def add_int_column(mut self, name: String) -> Bool:
        return self.add_column(name, COLUMN_INT64)

    def add_bool_column(mut self, name: String) -> Bool:
        return self.add_column(name, COLUMN_BOOL)

    def add_string_column(mut self, name: String) -> Bool:
        return self.add_column(name, COLUMN_STRING)

    def add_timestamp_column(mut self, name: String) -> Bool:
        return self.add_column(name, COLUMN_TIMESTAMP)

    def add_duration_column(mut self, name: String) -> Bool:
        return self.add_column(name, COLUMN_DURATION)

    def add_float64_column(mut self, name: String) -> Bool:
        return self.add_column(name, COLUMN_FLOAT64)

    def add_category_column(mut self, name: String) -> Bool:
        return self.add_column(name, COLUMN_CATEGORY)

    def _append_missing_columns(mut self):
        for index in range(len(self.columns)):
            self.columns[index].append_default()

    def _field_index_is_valid(self, name: String, row: Int) -> Bool:
        if row < 0 or row >= self.row_count():
            return False
        if name == "x":
            return self.x_valid[row]
        if name == "y":
            return self.y_valid[row]
        var index = self.column_index(name)
        return index != -1 and self.columns[index].valid[row]

    def field_is_valid(self, name: String, row: Int) -> Bool:
        return self._field_index_is_valid(name, row)

    def row_is_valid_fields(self, x_field: String, y_field: String, row: Int) -> Bool:
        return self._field_index_is_valid(x_field, row) and self._field_index_is_valid(y_field, row)

    def float_field_at(self, name: String, row: Int) -> Float32:
        if row < 0 or row >= self.row_count():
            return 0.0
        if name == "x":
            return self.x_values[row]
        if name == "y":
            return self.y_values[row]
        var index = self.column_index(name)
        if index == -1:
            return 0.0
        if self.columns[index].kind == COLUMN_FLOAT32:
            return self.columns[index].float_values[row]
        if self.columns[index].kind == COLUMN_FLOAT64:
            return Float32(self.columns[index].float64_values[row])
        if self.columns[index].kind == COLUMN_INT64 or self.columns[index].kind == COLUMN_TIMESTAMP or self.columns[index].kind == COLUMN_DURATION:
            return Float32(self.columns[index].int_values[row])
        if self.columns[index].kind == COLUMN_BOOL:
            return 1.0 if self.columns[index].bool_values[row] else 0.0
        if self.columns[index].kind == COLUMN_CATEGORY:
            return Float32(self.columns[index].category_indices[row])
        return 0.0

    def int_field_at(self, name: String, row: Int) -> Int64:
        if row < 0 or row >= self.row_count():
            return 0
        var index = self.column_index(name)
        if index == -1:
            return Int64(self.float_field_at(name, row))
        if self.columns[index].kind == COLUMN_INT64 or self.columns[index].kind == COLUMN_TIMESTAMP or self.columns[index].kind == COLUMN_DURATION:
            return self.columns[index].int_values[row]
        if self.columns[index].kind == COLUMN_CATEGORY:
            return Int64(self.columns[index].category_indices[row])
        return Int64(self.float_field_at(name, row))

    def bool_field_at(self, name: String, row: Int) -> Bool:
        if row < 0 or row >= self.row_count():
            return False
        var index = self.column_index(name)
        if index == -1:
            return self.float_field_at(name, row) != 0.0
        if self.columns[index].kind != COLUMN_BOOL:
            return self.float_field_at(name, row) != 0.0
        return self.columns[index].bool_values[row]

    def string_field_at(self, name: String, row: Int) -> String:
        if row < 0 or row >= self.row_count():
            return ""
        var index = self.column_index(name)
        if index == -1:
            return String(self.float_field_at(name, row))
        if self.columns[index].kind == COLUMN_STRING:
            return self.columns[index].string_values[row]
        if self.columns[index].kind == COLUMN_BOOL:
            return "true" if self.columns[index].bool_values[row] else "false"
        if self.columns[index].kind == COLUMN_INT64 or self.columns[index].kind == COLUMN_TIMESTAMP or self.columns[index].kind == COLUMN_DURATION:
            return String(self.columns[index].int_values[row])
        if self.columns[index].kind == COLUMN_FLOAT64:
            return String(self.columns[index].float64_values[row])
        if self.columns[index].kind == COLUMN_CATEGORY:
            return self.columns[index].category_at(self.columns[index].category_indices[row])
        return String(self.columns[index].float_values[row])

    def category_position(self, name: String, row: Int) -> Int:
        """Return a stable ordinal position for string or category fields."""
        if row < 0 or row >= self.row_count():
            return 0
        var kind = self.field_kind(name)
        if kind == COLUMN_CATEGORY:
            var index = self.column_index(name)
            return self.columns[index].category_indices[row]
        if kind != COLUMN_STRING:
            return Int(self.float_field_at(name, row))
        var value = self.string_field_at(name, row)
        var position = 0
        for source_row in range(row):
            if self.field_is_valid(name, source_row):
                var previous = self.string_field_at(name, source_row)
                if previous == value:
                    return position
                var first_seen = True
                for earlier in range(source_row):
                    if self.field_is_valid(name, earlier) and self.string_field_at(name, earlier) == previous:
                        first_seen = False
                        break
                if first_seen:
                    position += 1
        return position

    def category_value_at(self, name: String, position: Int) -> String:
        """Return the first source label at an ordinal position."""
        for row in range(self.row_count()):
            if not self.field_is_valid(name, row):
                continue
            var value = self.string_field_at(name, row)
            if self.category_position(name, row) == position:
                return value
        return ""

    def set_float_field(mut self, name: String, row: Int, value: Float32, valid: Bool = True) -> Bool:
        if row < 0 or row >= self.row_count():
            return False
        if name == "x":
            self.x_values[row] = value
            self.x_valid[row] = valid
            self.version += 1
            return True
        if name == "y":
            self.y_values[row] = value
            self.y_valid[row] = valid
            self.version += 1
            return True
        var index = self.column_index(name)
        if index == -1 or self.columns[index].kind != COLUMN_FLOAT32:
            return False
        self.columns[index].float_values[row] = value
        self.columns[index].valid[row] = valid
        self.version += 1
        return True

    def set_float64_field(mut self, name: String, row: Int, value: Float64, valid: Bool = True) -> Bool:
        """Set a nullable 64-bit floating-point field."""
        if row < 0 or row >= self.row_count():
            return False
        var index = self.column_index(name)
        if index == -1 or self.columns[index].kind != COLUMN_FLOAT64:
            return False
        self.columns[index].float64_values[row] = value
        self.columns[index].valid[row] = valid
        self.version += 1
        return True

    def set_int_field(mut self, name: String, row: Int, value: Int64, valid: Bool = True) -> Bool:
        if row < 0 or row >= self.row_count():
            return False
        var index = self.column_index(name)
        if index == -1:
            return False
        if self.columns[index].kind != COLUMN_INT64 and self.columns[index].kind != COLUMN_TIMESTAMP and self.columns[index].kind != COLUMN_DURATION:
            return False
        self.columns[index].int_values[row] = value
        self.columns[index].valid[row] = valid
        self.version += 1
        return True

    def set_bool_field(mut self, name: String, row: Int, value: Bool, valid: Bool = True) -> Bool:
        if row < 0 or row >= self.row_count():
            return False
        var index = self.column_index(name)
        if index == -1 or self.columns[index].kind != COLUMN_BOOL:
            return False
        self.columns[index].bool_values[row] = value
        self.columns[index].valid[row] = valid
        self.version += 1
        return True

    def set_string_field(mut self, name: String, row: Int, value: String, valid: Bool = True) -> Bool:
        if row < 0 or row >= self.row_count():
            return False
        var index = self.column_index(name)
        if index == -1 or (self.columns[index].kind != COLUMN_STRING and self.columns[index].kind != COLUMN_CATEGORY):
            return False
        if self.columns[index].kind == COLUMN_CATEGORY:
            var category = self.columns[index].category_index(value)
            self.columns[index].category_indices[row] = category
        else:
            self.columns[index].string_values[row] = value
        self.columns[index].valid[row] = valid
        self.version += 1
        return True

    def set_category_field(mut self, name: String, row: Int, value: String, valid: Bool = True) -> Bool:
        """Set a dictionary-encoded categorical field."""
        var index = self.column_index(name)
        if index == -1 or self.columns[index].kind != COLUMN_CATEGORY:
            return False
        return self.set_string_field(name, row, value, valid)

    def snapshot(self) -> PlotDataSnapshot:
        var frozen = self.clone()
        return PlotDataSnapshot(frozen^)

    def view(self, start: Int = 0, end: Int = -1) -> PlotDataView[origin_of(self)]:
        var result = PlotDataView[origin_of(self)](self)
        var first = start if start > 0 else 0
        var last = end if end >= 0 else self.row_count()
        if last > self.row_count():
            last = self.row_count()
        for index in range(first, last):
            result.append(index)
        return result^

    def replace(mut self, other: PlotDataTable):
        """Replace all rows and fields while preserving mutation isolation."""
        self.keys = other.keys.copy()
        self.x_values = other.x_values.copy()
        self.y_values = other.y_values.copy()
        self.x_valid = other.x_valid.copy()
        self.y_valid = other.y_valid.copy()
        self.columns = List[PlotColumn]()
        for index in range(len(other.columns)):
            var column = other.columns[index].clone()
            self.columns.append(column^)
        self.next_key = other.next_key
        self.version += 1

    def select_rows(self, rows: List[Int]) -> PlotDataTable:
        """Materialize a stable-key subset for a deterministic transform."""
        var result = PlotDataTable()
        for column_index in range(len(self.columns)):
            _ = result.add_column(
                self.columns[column_index].name,
                self.columns[column_index].kind,
            )
        for row in rows:
            if row < 0 or row >= self.row_count():
                continue
            _ = result.append_with_key(
                self.keys[row],
                self.x_values[row],
                self.y_values[row],
                self.x_valid[row],
                self.y_valid[row],
            )
            for column_index in range(len(self.columns)):
                var name = self.columns[column_index].name
                var kind = self.columns[column_index].kind
                var valid = self.columns[column_index].valid[row]
                if kind == COLUMN_STRING:
                    _ = result.set_string_field(
                        name,
                        result.row_count() - 1,
                        self.columns[column_index].string_values[row],
                        valid,
                    )
                elif kind == COLUMN_BOOL:
                    _ = result.set_bool_field(
                        name,
                        result.row_count() - 1,
                        self.columns[column_index].bool_values[row],
                        valid,
                    )
                elif kind == COLUMN_INT64 or kind == COLUMN_TIMESTAMP or kind == COLUMN_DURATION:
                    _ = result.set_int_field(
                        name,
                        result.row_count() - 1,
                        self.columns[column_index].int_values[row],
                        valid,
                    )
                elif kind == COLUMN_FLOAT64:
                    _ = result.set_float64_field(
                        name,
                        result.row_count() - 1,
                        self.columns[column_index].float64_values[row],
                        valid,
                    )
                elif kind == COLUMN_CATEGORY:
                    _ = result.set_category_field(
                        name,
                        result.row_count() - 1,
                        self.columns[column_index].category_at(
                            self.columns[column_index].category_indices[row]
                        ),
                        valid,
                    )
                else:
                    _ = result.set_float_field(
                        name,
                        result.row_count() - 1,
                        self.columns[column_index].float_values[row],
                        valid,
                    )
        return result^

    def filter_keys(self, selection: PlotSelection) -> PlotDataTable:
        """Materialize a cross-filtered table using stable row identity."""
        var rows = List[Int]()
        for row in range(self.row_count()):
            if selection.contains(self.key_at(row)):
                rows.append(row)
        return self.select_rows(rows)

    def filter_greater(self, field: String, threshold: Float32) -> PlotDataTable:
        var rows = List[Int]()
        for row in range(self.row_count()):
            if self.field_is_valid(field, row) and self.float_field_at(field, row) > threshold:
                rows.append(row)
        return self.select_rows(rows)

    def filter_between(
        self,
        field: String,
        minimum: Float32,
        maximum: Float32,
    ) -> PlotDataTable:
        var rows = List[Int]()
        for row in range(self.row_count()):
            if not self.field_is_valid(field, row):
                continue
            var value = self.float_field_at(field, row)
            if value >= minimum and value <= maximum:
                rows.append(row)
        return self.select_rows(rows)

    def sort_by(self, field: String, descending: Bool = False) -> PlotDataTable:
        var rows = List[Int]()
        for row in range(self.row_count()):
            rows.append(row)
        for next_index in range(1, len(rows)):
            var candidate = rows[next_index]
            var candidate_value = self.float_field_at(field, candidate)
            var insert_at = next_index
            while insert_at > 0:
                var previous = rows[insert_at - 1]
                var previous_value = self.float_field_at(field, previous)
                var should_move = (
                    previous_value < candidate_value
                    if descending
                    else previous_value > candidate_value
                )
                if not should_move:
                    break
                rows[insert_at] = previous
                insert_at -= 1
            rows[insert_at] = candidate
        return self.select_rows(rows)

    def limit_rows(self, maximum_rows: Int) -> PlotDataTable:
        var rows = List[Int]()
        var limit = maximum_rows if maximum_rows >= 0 else 0
        if limit > self.row_count():
            limit = self.row_count()
        for row in range(limit):
            rows.append(row)
        return self.select_rows(rows)

    def sample_rows(self, maximum_rows: Int) -> PlotDataTable:
        """Take a deterministic evenly spaced sample without changing keys."""
        var limit = maximum_rows if maximum_rows >= 0 else 0
        if limit >= self.row_count():
            return self.clone()
        var rows = List[Int]()
        if limit == 0:
            return self.select_rows(rows)
        for sample_index in range(limit):
            var source_index = Int(
                Float32(sample_index) * Float32(self.row_count()) / Float32(limit)
            )
            if source_index >= self.row_count():
                source_index = self.row_count() - 1
            rows.append(source_index)
        return self.select_rows(rows)

    def calculate_constant(
        self,
        output_field: String,
        value: Float32,
    ) -> PlotDataTable:
        """Add a deterministic numeric calculated field to every row."""
        var result = self.clone()
        if result.field_kind(output_field) == 0:
            _ = result.add_float_column(output_field)
        if result.field_kind(output_field) != COLUMN_FLOAT32:
            return result^
        for row in range(result.row_count()):
            _ = result.set_float_field(output_field, row, value)
        return result^

    def bin_field(
        self,
        field: String,
        output_field: String,
        width: Float32,
    ) -> PlotDataTable:
        """Add a lower-bound numeric bin field while preserving source rows."""
        var result = self.clone()
        var safe_width = width if width > 0.0 else 1.0
        if result.field_kind(output_field) == 0:
            _ = result.add_float_column(output_field)
        if result.field_kind(output_field) != COLUMN_FLOAT32:
            return result^
        for row in range(result.row_count()):
            if self.field_is_valid(field, row):
                var value = self.float_field_at(field, row)
                var lower = Float32(floor(value / safe_width)) * safe_width
                _ = result.set_float_field(output_field, row, lower)
            else:
                _ = result.set_float_field(output_field, row, 0.0, False)
        return result^

    def rolling_mean(
        self,
        field: String,
        output_field: String,
        window: Int,
    ) -> PlotDataTable:
        """Add a bounded trailing mean over valid numeric values."""
        var result = self.clone()
        var safe_window = window if window > 0 else 1
        if result.field_kind(output_field) == 0:
            _ = result.add_float_column(output_field)
        if result.field_kind(output_field) != COLUMN_FLOAT32:
            return result^
        for row in range(result.row_count()):
            var start = row - safe_window + 1
            if start < 0:
                start = 0
            var total: Float32 = 0.0
            var count = 0
            for source_row in range(start, row + 1):
                if self.field_is_valid(field, source_row):
                    total += self.float_field_at(field, source_row)
                    count += 1
            if count > 0:
                _ = result.set_float_field(output_field, row, total / Float32(count))
            else:
                _ = result.set_float_field(output_field, row, 0.0, False)
        return result^

    def impute(self, field: String, value: Float32) -> PlotDataTable:
        """Fill missing numeric values with a declared constant."""
        var result = self.clone()
        for row in range(result.row_count()):
            if not result.field_is_valid(field, row):
                if result.field_kind(field) == COLUMN_FLOAT32:
                    _ = result.set_float_field(field, row, value, True)
                elif result.field_kind(field) == COLUMN_FLOAT64:
                    _ = result.set_float64_field(field, row, Float64(value), True)
        return result^

    def stack(self, field: String, output_field: String) -> PlotDataTable:
        """Add a cumulative stack boundary for an ordered numeric field."""
        var result = self.clone()
        if result.field_kind(output_field) == 0:
            _ = result.add_float_column(output_field)
        if result.field_kind(output_field) != COLUMN_FLOAT32:
            return result^
        var total: Float32 = 0.0
        for row in range(result.row_count()):
            if self.field_is_valid(field, row):
                total += self.float_field_at(field, row)
                _ = result.set_float_field(output_field, row, total)
            else:
                _ = result.set_float_field(output_field, row, 0.0, False)
        return result^

    def aggregate(
        self,
        group_field: String,
        value_field: String,
        output_field: String,
        mean: Bool = False,
    ) -> PlotDataTable:
        """Aggregate valid numeric rows by a stable string/category key."""
        var groups = List[String]()
        var totals = List[Float32]()
        var counts = List[Int]()
        var keys = List[Int]()
        for row in range(self.row_count()):
            var value_is_count = value_field.count_codepoints() == 0
            if not self.field_is_valid(group_field, row) or (not value_is_count and not self.field_is_valid(value_field, row)):
                continue
            var group = self.string_field_at(group_field, row)
            var group_index = -1
            for index in range(len(groups)):
                if groups[index] == group:
                    group_index = index
                    break
            if group_index == -1:
                groups.append(group)
                totals.append(1.0 if value_is_count else self.float_field_at(value_field, row))
                counts.append(1)
                keys.append(self.key_at(row))
            else:
                totals[group_index] += 1.0 if value_is_count else self.float_field_at(value_field, row)
                counts[group_index] += 1
        var result = PlotDataTable()
        _ = result.add_category_column(group_field)
        _ = result.add_float_column(output_field)
        for group_index in range(len(groups)):
            var aggregate_value = totals[group_index]
            if mean:
                aggregate_value /= Float32(counts[group_index])
            _ = result.append_with_key(
                keys[group_index],
                Float32(group_index),
                aggregate_value,
            )
            _ = result.set_category_field(
                group_field,
                group_index,
                groups[group_index],
            )
            _ = result.set_float_field(
                output_field,
                group_index,
                aggregate_value,
            )
        return result^

    def histogram(
        self,
        field: String,
        bins: Int = 10,
        x2_field: String = "x2",
    ) -> PlotDataTable:
        """Build a deterministic equal-width histogram from one numeric field.

        The returned table uses ``x``/``x2`` for the bin extent and ``y`` for
        the count. A ``count`` column is retained so a declarative layer can
        choose count, density, or a color encoding without rescanning input.
        """
        var safe_bins = bins if bins > 0 else 1
        var found = False
        var minimum: Float32 = 0.0
        var maximum: Float32 = 0.0
        for row in range(self.row_count()):
            if not self.field_is_valid(field, row):
                continue
            var value = self.float_field_at(field, row)
            if not found:
                minimum = value
                maximum = value
                found = True
            else:
                if value < minimum:
                    minimum = value
                if value > maximum:
                    maximum = value
        var result = PlotDataTable()
        _ = result.add_float_column(x2_field)
        _ = result.add_float_column("count")
        if not found:
            return result^
        if maximum == minimum:
            minimum -= 0.5
            maximum += 0.5
        var width = (maximum - minimum) / Float32(safe_bins)
        if width <= 0.0:
            width = 1.0
        var counts = List[Int](capacity=safe_bins)
        for _ in range(safe_bins):
            counts.append(0)
        for row in range(self.row_count()):
            if not self.field_is_valid(field, row):
                continue
            var bin_index = Int(floor((self.float_field_at(field, row) - minimum) / width))
            if bin_index < 0:
                bin_index = 0
            if bin_index >= safe_bins:
                bin_index = safe_bins - 1
            counts[bin_index] += 1
        for bin_index in range(safe_bins):
            var lower = minimum + Float32(bin_index) * width
            var upper = lower + width
            if bin_index == safe_bins - 1:
                upper = maximum
            _ = result.append_with_key(
                bin_index,
                lower,
                Float32(counts[bin_index]),
            )
            _ = result.set_float_field(
                x2_field,
                bin_index,
                upper,
            )
            _ = result.set_float_field(
                "count",
                bin_index,
                Float32(counts[bin_index]),
            )
        return result^

    def density(
        self,
        field: String,
        bins: Int = 24,
    ) -> PlotDataTable:
        """Return a histogram-derived probability density estimate."""
        var result = self.histogram(field, bins)
        var valid_count = 0
        for row in range(self.row_count()):
            if self.field_is_valid(field, row):
                valid_count += 1
        if valid_count == 0:
            return result^
        for row in range(result.row_count()):
            var width = result.float_field_at("x2", row) - result.x_at(row)
            if width <= 0.0:
                width = 1.0
            var value = result.float_field_at("count", row) / (
                Float32(valid_count) * width
            )
            _ = result.set_float_field("y", row, value)
        return result^

    def ecdf(self, field: String) -> PlotDataTable:
        """Build an empirical cumulative distribution with stable source keys."""
        var rows = List[Int]()
        for row in range(self.row_count()):
            if self.field_is_valid(field, row):
                rows.append(row)
        for next_index in range(1, len(rows)):
            var candidate = rows[next_index]
            var candidate_value = self.float_field_at(field, candidate)
            var insert_at = next_index
            while insert_at > 0:
                var previous = rows[insert_at - 1]
                if self.float_field_at(field, previous) <= candidate_value:
                    break
                rows[insert_at] = previous
                insert_at -= 1
            rows[insert_at] = candidate
        var result = PlotDataTable()
        for order in range(len(rows)):
            var source_row = rows[order]
            _ = result.append_with_key(
                self.key_at(source_row),
                self.float_field_at(field, source_row),
                Float32(order + 1) / Float32(len(rows)),
            )
        return result^

    def box_summary(
        self,
        value_field: String,
        group_field: String = "",
    ) -> PlotDataTable:
        """Summarize values as Tukey-style quartiles and whisker extents."""
        var groups = List[String]()
        for row in range(self.row_count()):
            if not self.field_is_valid(value_field, row):
                continue
            var group = "all"
            if group_field.count_codepoints() > 0 and self.field_is_valid(group_field, row):
                group = self.string_field_at(group_field, row)
            var found_group = False
            for index in range(len(groups)):
                if groups[index] == group:
                    found_group = True
                    break
            if not found_group:
                groups.append(group)
        var result = PlotDataTable()
        _ = result.add_category_column("group")
        _ = result.add_float_column("x2")
        _ = result.add_float_column("y2")
        _ = result.add_float_column("low")
        _ = result.add_float_column("high")
        _ = result.add_float_column("median")
        _ = result.add_float_column("count")
        for group_index in range(len(groups)):
            var values = List[Float32]()
            for row in range(self.row_count()):
                if not self.field_is_valid(value_field, row):
                    continue
                var group = "all"
                if group_field.count_codepoints() > 0 and self.field_is_valid(group_field, row):
                    group = self.string_field_at(group_field, row)
                if group == groups[group_index]:
                    values.append(self.float_field_at(value_field, row))
            for next_index in range(1, len(values)):
                var candidate = values[next_index]
                var insert_at = next_index
                while insert_at > 0 and values[insert_at - 1] > candidate:
                    values[insert_at] = values[insert_at - 1]
                    insert_at -= 1
                values[insert_at] = candidate
            if len(values) == 0:
                continue
            var low = values[0]
            var high = values[len(values) - 1]
            var q1_index = Int(Float32(len(values) - 1) * 0.25)
            var median_index = Int(Float32(len(values) - 1) * 0.5)
            var q3_index = Int(Float32(len(values) - 1) * 0.75)
            var q1 = values[q1_index]
            var median = values[median_index]
            var q3 = values[q3_index]
            var key = group_index
            _ = result.append_with_key(
                key,
                Float32(group_index),
                q1,
            )
            _ = result.set_category_field("group", group_index, groups[group_index])
            _ = result.set_float_field("x2", group_index, Float32(group_index) + 0.8)
            _ = result.set_float_field("y2", group_index, q3)
            _ = result.set_float_field("low", group_index, low)
            _ = result.set_float_field("high", group_index, high)
            _ = result.set_float_field("median", group_index, median)
            _ = result.set_float_field("count", group_index, Float32(len(values)))
        return result^

    def heatmap(
        self,
        x_field: String,
        y_field: String,
        x_bins: Int = 16,
        y_bins: Int = 12,
    ) -> PlotDataTable:
        """Build a dense rectangular bin table for heatmap or hexbin recipes."""
        var safe_x_bins = x_bins if x_bins > 0 else 1
        var safe_y_bins = y_bins if y_bins > 0 else 1
        var found = False
        var minimum_x: Float32 = 0.0
        var maximum_x: Float32 = 0.0
        var minimum_y: Float32 = 0.0
        var maximum_y: Float32 = 0.0
        for row in range(self.row_count()):
            if not self.row_is_valid_fields(x_field, y_field, row):
                continue
            var x = self.float_field_at(x_field, row)
            var y = self.float_field_at(y_field, row)
            if not found:
                minimum_x = x
                maximum_x = x
                minimum_y = y
                maximum_y = y
                found = True
            else:
                if x < minimum_x:
                    minimum_x = x
                if x > maximum_x:
                    maximum_x = x
                if y < minimum_y:
                    minimum_y = y
                if y > maximum_y:
                    maximum_y = y
        var result = PlotDataTable()
        _ = result.add_float_column("x2")
        _ = result.add_float_column("y2")
        _ = result.add_float_column("count")
        if not found:
            return result^
        if minimum_x == maximum_x:
            minimum_x -= 0.5
            maximum_x += 0.5
        if minimum_y == maximum_y:
            minimum_y -= 0.5
            maximum_y += 0.5
        var x_width = (maximum_x - minimum_x) / Float32(safe_x_bins)
        var y_width = (maximum_y - minimum_y) / Float32(safe_y_bins)
        if x_width <= 0.0:
            x_width = 1.0
        if y_width <= 0.0:
            y_width = 1.0
        var counts = List[Int](capacity=safe_x_bins * safe_y_bins)
        for _ in range(safe_x_bins * safe_y_bins):
            counts.append(0)
        for row in range(self.row_count()):
            if not self.row_is_valid_fields(x_field, y_field, row):
                continue
            var x_index = Int(floor((self.float_field_at(x_field, row) - minimum_x) / x_width))
            var y_index = Int(floor((self.float_field_at(y_field, row) - minimum_y) / y_width))
            if x_index < 0:
                x_index = 0
            if x_index >= safe_x_bins:
                x_index = safe_x_bins - 1
            if y_index < 0:
                y_index = 0
            if y_index >= safe_y_bins:
                y_index = safe_y_bins - 1
            counts[y_index * safe_x_bins + x_index] += 1
        for y_index in range(safe_y_bins):
            for x_index in range(safe_x_bins):
                var cell_key = y_index * safe_x_bins + x_index
                var lower_x = minimum_x + Float32(x_index) * x_width
                var lower_y = minimum_y + Float32(y_index) * y_width
                _ = result.append_with_key(
                    cell_key,
                    lower_x,
                    lower_y,
                )
                _ = result.set_float_field("x2", cell_key, lower_x + x_width)
                _ = result.set_float_field("y2", cell_key, lower_y + y_width)
                _ = result.set_float_field(
                    "count",
                    cell_key,
                    Float32(counts[cell_key]),
                )
        return result^

    def regression(
        self,
        x_field: String,
        y_field: String,
        samples: Int = 32,
    ) -> PlotDataTable:
        """Fit an ordinary least-squares line and sample it into a table."""
        var count = 0
        var sum_x: Float32 = 0.0
        var sum_y: Float32 = 0.0
        var sum_xx: Float32 = 0.0
        var sum_xy: Float32 = 0.0
        var minimum_x: Float32 = 0.0
        var maximum_x: Float32 = 0.0
        for row in range(self.row_count()):
            if not self.row_is_valid_fields(x_field, y_field, row):
                continue
            var x = self.float_field_at(x_field, row)
            var y = self.float_field_at(y_field, row)
            if count == 0:
                minimum_x = x
                maximum_x = x
            else:
                if x < minimum_x:
                    minimum_x = x
                if x > maximum_x:
                    maximum_x = x
            count += 1
            sum_x += x
            sum_y += y
            sum_xx += x * x
            sum_xy += x * y
        var result = PlotDataTable()
        if count == 0:
            return result^
        var denominator = Float32(count) * sum_xx - sum_x * sum_x
        var slope: Float32 = 0.0
        if denominator != 0.0:
            slope = (Float32(count) * sum_xy - sum_x * sum_y) / denominator
        var intercept = (sum_y - slope * sum_x) / Float32(count)
        var safe_samples = samples if samples > 1 else 2
        if minimum_x == maximum_x:
            minimum_x -= 0.5
            maximum_x += 0.5
        for sample in range(safe_samples):
            var fraction = Float32(sample) / Float32(safe_samples - 1)
            var x = minimum_x + fraction * (maximum_x - minimum_x)
            _ = result.append_with_key(sample, x, intercept + slope * x)
        return result^

    def append(mut self, x: Float32, y: Float32) -> Int:
        """Append a valid row and return its stable generated key."""
        var key = self.next_key
        self.next_key += 1
        _ = self.append_with_key(key, x, y)
        return key

    def append_with_key(
        mut self,
        key: Int,
        x: Float32,
        y: Float32,
        x_is_valid: Bool = True,
        y_is_valid: Bool = True,
    ) -> Bool:
        """Append a row unless its stable key already exists."""
        if key < 0 or self.row_index(key) != -1:
            return False
        self.keys.append(key)
        self.x_values.append(x)
        self.y_values.append(y)
        self.x_valid.append(x_is_valid)
        self.y_valid.append(y_is_valid)
        self._append_missing_columns()
        if key >= self.next_key:
            self.next_key = key + 1
        self.version += 1
        return True

    def row_index(self, key: Int) -> Int:
        for index in range(len(self.keys)):
            if self.keys[index] == key:
                return index
        return -1

    def key_at(self, index: Int) -> Int:
        if index < 0 or index >= self.row_count():
            return -1
        return self.keys[index]

    def x_at(self, index: Int) -> Float32:
        if index < 0 or index >= self.row_count():
            return 0.0
        return self.x_values[index]

    def y_at(self, index: Int) -> Float32:
        if index < 0 or index >= self.row_count():
            return 0.0
        return self.y_values[index]

    def row_is_valid(self, index: Int) -> Bool:
        if index < 0 or index >= self.row_count():
            return False
        return self.x_valid[index] and self.y_valid[index]

    def patch(
        mut self,
        index: Int,
        x: Float32,
        y: Float32,
        x_is_valid: Bool = True,
        y_is_valid: Bool = True,
    ) -> Bool:
        """Replace one row while preserving its key and position."""
        if index < 0 or index >= self.row_count():
            return False
        self.x_values[index] = x
        self.y_values[index] = y
        self.x_valid[index] = x_is_valid
        self.y_valid[index] = y_is_valid
        self.version += 1
        return True

    def patch_key(
        mut self,
        key: Int,
        x: Float32,
        y: Float32,
        x_is_valid: Bool = True,
        y_is_valid: Bool = True,
    ) -> Bool:
        var index = self.row_index(key)
        if index == -1:
            return False
        return self.patch(index, x, y, x_is_valid, y_is_valid)

    def clear(mut self):
        if self.row_count() == 0:
            return
        self.keys = List[Int]()
        self.x_values = List[Float32]()
        self.y_values = List[Float32]()
        self.x_valid = List[Bool]()
        self.y_valid = List[Bool]()
        for index in range(len(self.columns)):
            self.columns[index].float_values = List[Float32]()
            self.columns[index].float64_values = List[Float64]()
            self.columns[index].int_values = List[Int64]()
            self.columns[index].bool_values = List[Bool]()
            self.columns[index].string_values = List[String]()
            self.columns[index].category_indices = List[Int]()
            self.columns[index].category_values = List[String]()
            self.columns[index].valid = List[Bool]()
        self.version += 1

    def rollover(mut self, maximum_rows: Int):
        """Keep the newest rows, useful for bounded streaming telemetry."""
        var old_count = self.row_count()
        if maximum_rows < 0 or old_count <= maximum_rows:
            return
        var start = old_count - maximum_rows
        var next_keys = List[Int](capacity=maximum_rows)
        var next_x = List[Float32](capacity=maximum_rows)
        var next_y = List[Float32](capacity=maximum_rows)
        var next_x_valid = List[Bool](capacity=maximum_rows)
        var next_y_valid = List[Bool](capacity=maximum_rows)
        for index in range(start, old_count):
            next_keys.append(self.keys[index])
            next_x.append(self.x_values[index])
            next_y.append(self.y_values[index])
            next_x_valid.append(self.x_valid[index])
            next_y_valid.append(self.y_valid[index])
        self.keys = next_keys^
        self.x_values = next_x^
        self.y_values = next_y^
        self.x_valid = next_x_valid^
        self.y_valid = next_y_valid^
        for column_index in range(len(self.columns)):
            var next_valid = List[Bool](capacity=maximum_rows)
            if self.columns[column_index].kind == COLUMN_INT64 or self.columns[column_index].kind == COLUMN_TIMESTAMP or self.columns[column_index].kind == COLUMN_DURATION:
                var next_values = List[Int64](capacity=maximum_rows)
                for index in range(start, old_count):
                    next_values.append(self.columns[column_index].int_values[index])
                    next_valid.append(self.columns[column_index].valid[index])
                self.columns[column_index].int_values = next_values^
            elif self.columns[column_index].kind == COLUMN_BOOL:
                var next_values = List[Bool](capacity=maximum_rows)
                for index in range(start, old_count):
                    next_values.append(self.columns[column_index].bool_values[index])
                    next_valid.append(self.columns[column_index].valid[index])
                self.columns[column_index].bool_values = next_values^
            elif self.columns[column_index].kind == COLUMN_STRING:
                var next_values = List[String](capacity=maximum_rows)
                for index in range(start, old_count):
                    next_values.append(self.columns[column_index].string_values[index])
                    next_valid.append(self.columns[column_index].valid[index])
                self.columns[column_index].string_values = next_values^
            elif self.columns[column_index].kind == COLUMN_FLOAT64:
                var next_values = List[Float64](capacity=maximum_rows)
                for index in range(start, old_count):
                    next_values.append(self.columns[column_index].float64_values[index])
                    next_valid.append(self.columns[column_index].valid[index])
                self.columns[column_index].float64_values = next_values^
            elif self.columns[column_index].kind == COLUMN_CATEGORY:
                var next_values = List[Int](capacity=maximum_rows)
                for index in range(start, old_count):
                    next_values.append(self.columns[column_index].category_indices[index])
                    next_valid.append(self.columns[column_index].valid[index])
                self.columns[column_index].category_indices = next_values^
            else:
                var next_values = List[Float32](capacity=maximum_rows)
                for index in range(start, old_count):
                    next_values.append(self.columns[column_index].float_values[index])
                    next_valid.append(self.columns[column_index].valid[index])
                self.columns[column_index].float_values = next_values^
            self.columns[column_index].valid = next_valid^
        self.version += 1

    def csv(self) -> String:
        """Return a stable, renderer-independent data-table fallback."""
        var result = "key,x,y\n"
        for column_index in range(len(self.columns)):
            result += self.columns[column_index].name
            result += "," if column_index + 1 < len(self.columns) else "\n"
        for index in range(self.row_count()):
            result += String(self.keys[index], ",")
            if self.x_valid[index]:
                result += String(self.x_values[index])
            else:
                result += "null"
            result += ","
            if self.y_valid[index]:
                result += String(self.y_values[index])
            else:
                result += "null"
            for column_index in range(len(self.columns)):
                result += ","
                if not self.columns[column_index].valid[index]:
                    result += "null"
                elif self.columns[column_index].kind == COLUMN_STRING:
                    result += String("\"", self.columns[column_index].string_values[index], "\"")
                elif self.columns[column_index].kind == COLUMN_CATEGORY:
                    result += String(
                        "\"",
                        self.columns[column_index].category_at(
                            self.columns[column_index].category_indices[index]
                        ),
                        "\"",
                    )
                elif self.columns[column_index].kind == COLUMN_FLOAT64:
                    result += String(self.columns[column_index].float64_values[index])
                elif self.columns[column_index].kind == COLUMN_FLOAT32:
                    result += String(self.columns[column_index].float_values[index])
                elif self.columns[column_index].kind == COLUMN_BOOL:
                    result += "true" if self.columns[column_index].bool_values[index] else "false"
                else:
                    result += String(self.columns[column_index].int_values[index])
            result += "\n"
        return result
