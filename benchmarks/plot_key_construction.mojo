"""Bounded key-order construction comparison; milliseconds exclude key setup."""

from std.collections import List
from std.ffi import external_call
from moxi import test_check
from moxi_plot import PlotDataTable


def run_case(rows: Int, order: Int, batch: Bool):
    var keys = List[Int]()
    for index in range(rows):
        var key = index
        if order == 1:
            key = rows - 1 - index
        elif order == 2:
            # Coprime to all measured powers of ten: a deterministic permutation.
            key = (index * 7919) % rows
        elif order == 3:
            key = ((index * 7919) % rows) * 100003
        keys.append(key)
    var started = external_call["moxi_benchmark_time_ns", Int64]()
    var table = PlotDataTable()
    if batch:
        # Include temporary input columns in the measured construction cost.
        var xs = List[Float32]()
        var ys = List[Float32]()
        var valid = List[Bool]()
        for index in range(rows):
            xs.append(Float32(index))
            ys.append(1.0)
            valid.append(True)
        test_check(table.append_rows(keys, xs, ys, valid, valid))
    else:
        for index in range(rows):
            test_check(table.append_with_key(keys[index], Float32(index), 1.0))
    var elapsed = external_call["moxi_benchmark_time_ns", Int64]() - started
    test_check(table.row_count() == rows)
    test_check(table.key_at(rows - 1) == keys[rows - 1])
    print(rows, order, batch, Float64(elapsed) / 1000000.0)


def main():
    print("rows order batch milliseconds; order=0 monotone,1 reversed,2 shuffled,3 sparse-shuffled")
    var sizes: List[Int] = [1000, 10000, 100000]
    for repetition in range(3):
        print("repetition", repetition)
        for rows in sizes:
            for order in range(4):
                run_case(rows, order, False)
                run_case(rows, order, True)
