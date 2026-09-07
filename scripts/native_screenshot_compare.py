#!/usr/bin/env python3
"""Compare a native offscreen capture with the software oracle under a policy."""

from __future__ import annotations

import json
import os
from pathlib import Path


def parse_p3(value: str) -> tuple[int, int, bytes]:
    tokens = value.split()
    if len(tokens) < 4 or tokens[0] != "P3":
        raise ValueError("software capture is not a P3 image")
    width, height, maximum = map(int, tokens[1:4])
    if maximum != 255:
        raise ValueError(f"unsupported software PPM max value: {maximum}")
    values = [int(token) for token in tokens[4:]]
    if len(values) != width * height * 3:
        raise ValueError("software PPM pixel count does not match dimensions")
    if any(value < 0 or value > 255 for value in values):
        raise ValueError("software PPM channel is outside 0..255")
    return width, height, bytes(values)


def read_p6(path: Path) -> tuple[int, int, bytes]:
    data = path.read_bytes()
    if not data.startswith(b"P6\n"):
        raise ValueError(f"expected binary P6 capture: {path}")
    header_end = data.find(b"\n255\n")
    if header_end < 0:
        raise ValueError(f"invalid P6 header: {path}")
    width, height = map(int, data[:header_end].split()[1:3])
    pixels = data[header_end + len(b"\n255\n") :]
    if len(pixels) != width * height * 3:
        raise ValueError("native PPM pixel count does not match dimensions")
    return width, height, pixels


def extract_software(output: str) -> tuple[int, int, bytes]:
    begin = "NATIVE_SCREENSHOT_SOFTWARE_BEGIN\n"
    end = "\nNATIVE_SCREENSHOT_SOFTWARE_END"
    start = output.find(begin)
    if start < 0:
        raise ValueError("native run did not emit a software screenshot oracle")
    start += len(begin)
    finish = output.find(end, start)
    if finish < 0:
        raise ValueError("native run did not close the software screenshot oracle")
    return parse_p3(output[start:finish])


def masked(policy: dict, x: int, y: int) -> bool:
    for mask in policy.get("masks", []):
        if (
            mask["x"] <= x < mask["x"] + mask["width"]
            and mask["y"] <= y < mask["y"] + mask["height"]
        ):
            return True
    return False


def main() -> None:
    output = Path(os.environ["MOXI_NATIVE_SCREENSHOT_OUTPUT"]).read_text()
    actual_path = Path(os.environ["MOXI_NATIVE_SCREENSHOT_ACTUAL"])
    policy_path = Path(os.environ["MOXI_NATIVE_SCREENSHOT_POLICY"])
    report_path = Path(os.environ["MOXI_NATIVE_SCREENSHOT_REPORT"])
    policy = json.loads(policy_path.read_text())
    expected_width, expected_height, expected = extract_software(output)
    actual_width, actual_height, actual = read_p6(actual_path)
    if (expected_width, expected_height) != (actual_width, actual_height):
        raise SystemExit("native screenshot dimensions differ from software oracle")
    if (actual_width, actual_height) != (policy["width"], policy["height"]):
        raise SystemExit("native screenshot dimensions differ from policy")

    max_delta = 0
    mismatch_count = 0
    compared_count = 0
    delta_sum = 0
    for index in range(0, len(actual), 3):
        pixel = index // 3
        x = pixel % actual_width
        y = pixel // actual_width
        if masked(policy, x, y):
            continue
        compared_count += 1
        delta = max(
            abs(actual[index + channel] - expected[index + channel])
            for channel in range(3)
        )
        max_delta = max(max_delta, delta)
        delta_sum += delta
        if delta > policy["max_channel_delta"]:
            mismatch_count += 1

    ratio = mismatch_count / compared_count if compared_count else 0.0
    report = {
        "schema_version": policy["schema_version"],
        "fixture": policy["fixture"],
        "renderer": policy["renderer"],
        "dimensions": {"width": actual_width, "height": actual_height},
        "masked_pixels": actual_width * actual_height - compared_count,
        "compared_pixels": compared_count,
        "mismatched_pixels": mismatch_count,
        "mismatch_ratio": ratio,
        "max_channel_delta": max_delta,
        "mean_channel_delta": delta_sum / compared_count if compared_count else 0.0,
        "policy": {
            "max_channel_delta": policy["max_channel_delta"],
            "max_mismatched_pixels": policy["max_mismatched_pixels"],
            "max_mismatch_ratio": policy["max_mismatch_ratio"],
            "masks": policy.get("masks", []),
        },
    }
    report_path.write_text(json.dumps(report, indent=2) + "\n")
    if mismatch_count > policy["max_mismatched_pixels"] or ratio > policy["max_mismatch_ratio"]:
        raise SystemExit(
            "native screenshot tolerance failed: "
            f"{mismatch_count} mismatches ({ratio:.4%}), max delta {max_delta}"
        )
    print(
        "Moxi native screenshot tolerance passed "
        f"({compared_count} pixels, {mismatch_count} mismatches, "
        f"max delta {max_delta}; report {report_path})"
    )


if __name__ == "__main__":
    main()
