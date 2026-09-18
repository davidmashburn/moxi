"""App-local numerical workbench data and CSV contract tests."""

from std.collections import List

from moxi import test_check
from moxi_demo.workbench_data import (
    WorkbenchData,
    make_workbench_fixture,
)


def _csv_with_rows(row_count: Int) -> String:
    var lines = List[String](capacity=row_count + 1)
    lines.append("value")
    for row in range(row_count):
        lines.append(String(row))
    return "\n".join(lines)


def _wide_header(column_count: Int) -> String:
    var fields = List[String](capacity=column_count)
    for column in range(column_count):
        fields.append(String("field", column))
    return ",".join(fields)


def _oversized_csv() -> String:
    # Build just over the byte cap from reusable chunks so this test does not
    # append one codepoint at a time.  The loader must reject before parsing.
    var zeroes = List[String](capacity=1024)
    for _ in range(1024):
        zeroes.append("0")
    var chunk = "".join(zeroes)
    var chunks = List[String](capacity=32769)
    chunks.append("value\n")
    for _ in range(32768):
        chunks.append(chunk)
    return "".join(chunks)


def main() raises:
    var fixture = make_workbench_fixture()
    test_check(fixture.row_count() == 48)
    test_check(fixture.field_count() == 5)
    test_check(fixture.field_name(0) == "x")
    test_check(fixture.field_name(1) == "y")
    test_check(fixture.field_name(2) == "time")
    test_check(fixture.field_name(3) == "value")
    test_check(fixture.field_name(4) == "size")
    test_check(fixture.visible_count() == 48)
    test_check(fixture.key_at(0) == 0)
    test_check(fixture.key_at(47) == 47)
    test_check(fixture.value_is_valid("value", 0))
    test_check(fixture.value_at("value", 0) == 1.0)
    test_check(not fixture.value_is_valid("unknown", 0))
    test_check(fixture.value_at("unknown", 0) == 0.0)

    var first_key = fixture.key_at(0)
    test_check(fixture.select_key(first_key))
    test_check(fixture.is_selected_key(first_key))
    test_check(fixture.selected_count() == 1)
    test_check(fixture.set_filter("value", 6.0))
    test_check(fixture.visible_count() > 0)
    test_check(fixture.visible_count() < fixture.row_count())
    test_check(fixture.selection_contains_hidden())
    test_check(fixture.hidden_selected_count() == 1)
    test_check(fixture.selected_visible_count() == 0)
    test_check(fixture.sort_visible("value", True))
    test_check(fixture.visible_value_at("value", 0) >= fixture.visible_value_at("value", 1))
    fixture.clear_filter()
    test_check(fixture.visible_count() == fixture.row_count())
    test_check(fixture.selected_count() == 1)
    fixture.clear_sort()

    var exported = fixture.export_selected_csv()
    test_check(exported == "key,x,y,time,value,size\n0,0.0,1.0,1700000000.0,1.0,4.0\n")

    var imported = WorkbenchData()
    var loaded = imported.load_csv("key,a,b\n7,1.5,\n11,null,-2\n")
    test_check(loaded.accepted)
    test_check(loaded.rows == 2)
    test_check(loaded.columns == 2)
    test_check(loaded.missing_values == 2)
    test_check(imported.row_count() == 2)
    test_check(imported.key_at(0) == 7)
    test_check(imported.key_at(1) == 11)
    test_check(imported.value_is_valid("a", 0))
    test_check(not imported.value_is_valid("b", 0))
    test_check(imported.value_is_valid("b", 1))
    test_check(imported.value_at("b", 1) == -2.0)
    test_check(imported.select_key(11))
    test_check(imported.export_selected_csv() == "key,a,b\n11,,-2.0\n")

    var stable = WorkbenchData()
    var stable_result = stable.load_csv(
        "key,value\n10,2\n11,1\n12,2\n13,\n"
    )
    test_check(stable_result.accepted)
    test_check(stable.sort_visible("value"))
    test_check(stable.visible_key_at(0) == 11)
    test_check(stable.visible_key_at(1) == 10)
    test_check(stable.visible_key_at(2) == 12)
    test_check(stable.visible_key_at(3) == 13)
    test_check(stable.sort_visible("value", True))
    test_check(stable.visible_key_at(0) == 10)
    test_check(stable.visible_key_at(1) == 12)
    test_check(stable.visible_key_at(2) == 11)
    test_check(stable.visible_key_at(3) == 13)

    # Float32 values must survive selected CSV export and re-import exactly,
    # including scientific notation and the finite range boundaries.
    var roundtrip = WorkbenchData()
    var roundtrip_result = roundtrip.load_csv(
        "key,value\n"
        "7,0.00000123456789\n"
        "8,3.4028234e38\n"
        "9,-3.4028234e38\n"
        "10,1.1754944e-38\n"
        "11,1e-40\n"
        "12,1.4012985e-45\n"
        "13,-1.4012985e-45\n"
    )
    test_check(roundtrip_result.accepted)
    test_check(roundtrip.value_at("value", 4) != 0.0)
    test_check(roundtrip.value_at("value", 5) != 0.0)
    test_check(roundtrip.value_at("value", 6) != 0.0)
    for row in range(roundtrip.row_count()):
        test_check(roundtrip.select_key(roundtrip.key_at(row)))
    var roundtrip_export = roundtrip.export_selected_csv()
    var roundtrip_copy = WorkbenchData()
    var roundtrip_copy_result = roundtrip_copy.load_csv(roundtrip_export)
    test_check(roundtrip_copy_result.accepted)
    for row in range(roundtrip.row_count()):
        test_check(
            roundtrip.value_at("value", row)
            == roundtrip_copy.value_at("value", row)
        )
    var overflow = roundtrip_copy.load_csv("value\n3.5e38\n")
    test_check(not overflow.accepted)
    test_check(roundtrip_copy.row_count() == roundtrip.row_count())

    var wide = WorkbenchData()
    var wide_result = wide.load_csv(_wide_header(65))
    test_check(not wide_result.accepted)
    test_check(wide_result.columns == 65)

    var oversized = WorkbenchData()
    var oversized_result = oversized.load_csv(_oversized_csv())
    test_check(not oversized_result.accepted)
    test_check(oversized_result.message.count_codepoints() > 0)

    var old_key = imported.key_at(0)
    var old_rows = imported.row_count()
    var rejected = imported.load_csv("a,b\n1,not-a-number\n")
    test_check(not rejected.accepted)
    test_check(rejected.line == 2)
    test_check(imported.row_count() == old_rows)
    test_check(imported.key_at(0) == old_key)
    test_check(imported.selected_count() == 1)

    var duplicate = imported.load_csv("key,value\n4,1\n4,2\n")
    test_check(not duplicate.accepted)
    test_check(duplicate.line == 3)
    test_check(imported.row_count() == old_rows)

    var generated_keys = WorkbenchData()
    var generated_result = generated_keys.load_csv("value\n3\n4\n")
    test_check(generated_result.accepted)
    test_check(generated_keys.key_at(0) == 0)
    test_check(generated_keys.key_at(1) == 1)

    var invalid_header = generated_keys.load_csv("key\n1\n")
    test_check(not invalid_header.accepted)
    test_check(generated_keys.row_count() == 2)

    var no_header = WorkbenchData()
    var empty_result = no_header.load_csv("\n  \n")
    test_check(not empty_result.accepted)
    test_check(no_header.row_count() == 0)

    # Exercise the actual bounded path at the row limit and its first reject.
    var boundary = WorkbenchData()
    var accepted_boundary = boundary.load_csv(_csv_with_rows(100000))
    test_check(accepted_boundary.accepted)
    test_check(accepted_boundary.rows == 100000)
    test_check(boundary.row_count() == 100000)
    test_check(boundary.sort_visible("value", True))
    test_check(boundary.visible_value_at("value", 0) == 99999.0)
    var old_boundary_rows = boundary.row_count()
    var too_many = boundary.load_csv(_csv_with_rows(100001))
    test_check(not too_many.accepted)
    test_check(too_many.line == 100002)
    test_check(boundary.row_count() == old_boundary_rows)

    print("Moxi workbench-data test passed")
