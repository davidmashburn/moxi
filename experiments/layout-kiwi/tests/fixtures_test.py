#!/usr/bin/env python3
"""Small stdlib contract check for the standalone Kiwi fixture runner."""

from __future__ import annotations

import json
import math
import pathlib
import sys
from typing import Any


def fail(message: str) -> None:
    raise AssertionError(message)


def expect(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def close(actual: float, expected: float, message: str) -> None:
    if not math.isfinite(actual) or abs(actual - expected) > 0.01:
        fail(f"{message}: expected {expected}, got {actual}")


def rect_close(actual: dict[str, Any], expected: tuple[float, float, float, float], label: str) -> None:
    for key, value in zip(("x", "y", "width", "height"), expected):
        close(float(actual[key]), value, f"{label}.{key}")


def fixture_map(document: dict[str, Any]) -> dict[str, dict[str, Any]]:
    fixtures = document.get("fixtures")
    expect(isinstance(fixtures, list), "fixtures must be an array")
    result = {item.get("name"): item for item in fixtures if isinstance(item, dict)}
    required = {"csv_column", "aligned_form", "splitter", "wrapped_text", "weighted_row", "retention"}
    expect(required <= result.keys(), f"missing fixtures: {sorted(required - result.keys())}")
    return result


def check_csv(csv: dict[str, Any]) -> None:
    phases = {phase["name"]: phase for phase in csv["phases"]}
    expected = {
        "cold_h600_no_summary",
        "resize_h800_no_summary",
        "insert_summary_h600",
        "overflow_h150_summary",
        "unchanged_h150_summary",
    }
    expect(set(phases) == expected, "CSV phase names changed")
    cold = phases["cold_h600_no_summary"]["rects"]
    resize = phases["resize_h800_no_summary"]["rects"]
    inserted = phases["insert_summary_h600"]["rects"]
    overflow = phases["overflow_h150_summary"]["rects"]
    unchanged = phases["unchanged_h150_summary"]["rects"]
    rect_close(cold["root"], (0, 0, 800, 600), "CSV cold root")
    rect_close(cold["header"], (10, 10, 780, 40), "CSV cold header")
    rect_close(cold["chart"], (10, 58, 780, 532), "CSV cold chart")
    rect_close(resize["root"], (0, 0, 800, 800), "CSV resize root")
    close(resize["chart"]["height"] - cold["chart"]["height"], 200, "CSV chart growth")
    rect_close(inserted["summary"], (10, 58, 780, 40), "CSV inserted summary")
    rect_close(inserted["chart"], (10, 106, 780, 484), "CSV inserted chart")
    close(cold["chart"]["height"] - inserted["chart"]["height"], 48, "CSV summary shrink")
    expect(phases["overflow_h150_summary"]["overflow"] is True, "CSV overflow flag")
    rect_close(overflow["root"], (0, 0, 800, 150), "CSV overflow root")
    rect_close(overflow["chart"], (10, 106, 780, 160), "CSV overflow chart minimum")
    expect(overflow == unchanged, "CSV unchanged phase changed geometry")


def check_form(form: dict[str, Any]) -> None:
    normal = form["normal"]["rects"]
    narrow = form["narrow"]
    expect(len(normal) == 6, "form rect count")
    close(normal[0]["width"], 40, "form label A natural width")
    close(normal[1]["width"], 90, "form label B natural width")
    close(normal[0]["x"] + normal[0]["width"], normal[1]["x"] + normal[1]["width"], "form label trailing edge")
    close(normal[2]["x"], normal[3]["x"], "form field leading edge")
    close(normal[2]["width"], 180, "form preferred field width")
    close(normal[4]["width"], normal[5]["width"], "form equal buttons")
    close(normal[4]["width"], 100, "form preferred button width")
    expect(narrow["field_compressed"] and narrow["buttons_compressed"], "form preferred compression")
    expect(narrow["rects"][2]["width"] >= 80 and narrow["rects"][4]["width"] >= 60, "form required minima")
    conflict = form["minimum_conflict"]
    expect(conflict["rejected"] is True, "form required conflict was not rejected")
    expect("form.viewport.right" in conflict["author_ids"], "form conflict author ID")


def check_splitter(splitter: dict[str, Any]) -> None:
    drags = {item["requested_left_width"]: item for item in splitter["drag_suggestions"]}
    close(drags[50]["actual_left_width"], 100, "splitter lower bound")
    close(drags[50]["actual_right_width"], 492, "splitter lower drag remainder")
    close(drags[700]["actual_left_width"], 472, "splitter upper bound")
    close(drags[700]["actual_right_width"], 120, "splitter upper drag remainder")
    expect(splitter["unrelated_y"] == [42, 117], "splitter unrelated y moved")
    expect(splitter["priority_probe"]["actual"] == 1, "splitter numeric strength probe")


def check_text(text: dict[str, Any]) -> None:
    expect(text["model"] == {"advance_factor": 0.56, "line_height_factor": 1.25, "minimum_line_height": 16}, "text model")
    expect(text["pass_order"] == ["allocation", "measurement", "height_constraint_refresh", "publication"], "text pass order")
    cases = {case["name"]: case for case in text["cases"]}
    expect(cases["ascii20_width95"]["measurement"]["line_count"] == 2, "ASCII 20 wrapping")
    expect(cases["ascii30_width95"]["measurement"]["line_count"] == 3, "ASCII 30 wrapping")
    expect(cases["ascii30_width95"]["overflow"] is True, "text overflow")
    expect(cases["ascii20_width89_59"]["measurement"]["line_count"] == 3, "text threshold below")
    expect(cases["ascii20_width89_61"]["measurement"]["line_count"] == 2, "text threshold above")
    close(cases["ascii20_font24_width95"]["measurement"]["line_height"], 30, "font line height")
    close(cases["ascii20_font12_width95"]["measurement"]["line_height"], 16, "minimum line height")
    expect(all(case["convergence_iterations"] <= 4 for case in cases.values()), "text convergence bound")


def check_parity(document: dict[str, Any]) -> None:
    arrays = document["rect_arrays"]
    expected = {
        "row-weighted-fill-min-max": [(0, 0, 300, 40), (0, 0, 60, 40), (70, 0, 230, 40)],
        "column-content-header-fill-body": [(0, 0, 300, 200), (10, 10, 280, 20), (10, 35, 280, 155)],
        "wrapped-text-at-offered-width": [(0, 0, 200, 60), (0, 0, 95, 40), (105, 0, 95, 60)],
    }
    for name, rects in expected.items():
        expect(len(arrays[name]) == len(rects), f"{name} rect count")
        for index, (actual, wanted) in enumerate(zip(arrays[name], rects)):
            rect_close(actual, wanted, f"{name}[{index}]")


def main() -> int:
    if len(sys.argv) != 2:
        print(f"usage: {pathlib.Path(sys.argv[0]).name} FIXTURES_JSON", file=sys.stderr)
        return 2
    path = pathlib.Path(sys.argv[1])
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
        expect(len(lines) == 1 and lines[0].strip(), "runner output must be one JSON line")

        def reject_constant(value: str) -> None:
            raise ValueError(f"non-finite JSON constant {value}")

        document = json.loads(lines[0], parse_constant=reject_constant)
        expect(document["schema"] == "moxi.layout.kiwi-fixtures.v1", "schema")
        expect(document["backend"] == "kiwi-cpp", "backend")
        expect(document["ok"] is True, "runner reported failure")
        expect(document["assertions"]["failed"] == 0, "fixture assertions failed")
        expect(document["assertions"]["total"] >= document["assertions"]["passed"], "assertion counts")
        fixtures = fixture_map(document)
        check_csv(fixtures["csv_column"])
        check_form(fixtures["aligned_form"])
        check_splitter(fixtures["splitter"])
        check_text(fixtures["wrapped_text"])
        weighted = fixtures["weighted_row"]
        expect(weighted["allocation_policy"] == "clamp_then_redistribute", "weighted allocation policy")
        check_parity(document)
        retention = fixtures["retention"]["variable_entry_counts"]
        expect(retention["after_remove"] >= retention["before_churn"], "retention churn count")
        expect(retention["after_reset"] == 0, "retention reset count")
    except (OSError, ValueError, KeyError, TypeError, AssertionError) as error:
        print(f"fixtures contract failed: {error}", file=sys.stderr)
        return 1
    print(f"validated {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
