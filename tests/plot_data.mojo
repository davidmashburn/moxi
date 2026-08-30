"""Stable-key plot data source contract test."""

from moxi import PlotDataTable, test_check


def main():
    var data = PlotDataTable()
    var first = data.append(0.0, 1.0)
    var second = data.append(1.0, 2.0)
    test_check(first == 0)
    test_check(second == 1)
    test_check(data.row_count() == 2)
    test_check(data.row_index(1) == 1)
    test_check(not data.append_with_key(1, 4.0, 5.0))
    test_check(data.patch_key(1, 3.0, 4.0))
    test_check(data.y_at(1) == 4.0)
    test_check(data.patch(0, 0.0, 0.0, True, False))
    test_check(not data.row_is_valid(0))
    test_check(data.csv().count_codepoints() > 10)
    _ = data.append(2.0, 3.0)
    _ = data.append(3.0, 4.0)
    data.rollover(2)
    test_check(data.row_count() == 2)
    test_check(data.key_at(0) == 2)
    test_check(data.version >= 7)
    print("Moxi plot-data test passed")
