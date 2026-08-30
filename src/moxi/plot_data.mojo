"""Small column-oriented data source for the first Moxi Plot slice."""

from std.collections import List


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
    var next_key: Int
    var version: Int

    def __init__(out self):
        self.keys = List[Int]()
        self.x_values = List[Float32]()
        self.y_values = List[Float32]()
        self.x_valid = List[Bool]()
        self.y_valid = List[Bool]()
        self.next_key = 0
        self.version = 0

    def row_count(self) -> Int:
        return len(self.keys)

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
        self.version += 1

    def rollover(mut self, maximum_rows: Int):
        """Keep the newest rows, useful for bounded streaming telemetry."""
        if maximum_rows < 0 or self.row_count() <= maximum_rows:
            return
        var start = self.row_count() - maximum_rows
        var next_keys = List[Int](capacity=maximum_rows)
        var next_x = List[Float32](capacity=maximum_rows)
        var next_y = List[Float32](capacity=maximum_rows)
        var next_x_valid = List[Bool](capacity=maximum_rows)
        var next_y_valid = List[Bool](capacity=maximum_rows)
        for index in range(start, self.row_count()):
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
        self.version += 1

    def csv(self) -> String:
        """Return a stable, renderer-independent data-table fallback."""
        var result = "key,x,y\n"
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
            result += "\n"
        return result
