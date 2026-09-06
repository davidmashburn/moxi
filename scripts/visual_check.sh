#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

manifest_path="$repo_dir/tests/goldens/manifest.json"
artifact_dir="${MOXI_VISUAL_ARTIFACT_DIR:-$repo_dir/dist/visual-artifacts}"
update_goldens="${MOXI_UPDATE_GOLDENS:-0}"
temp_dir="$(mktemp -d)"
trap 'rm -rf "$temp_dir"' EXIT

mkdir -p "$artifact_dir/actual" "$artifact_dir/expected" "$artifact_dir/diff"
pixi run mojo run -I src tests/golden_render.mojo > "$temp_dir/golden.txt"

MOXI_GOLDEN_MANIFEST="$manifest_path" \
MOXI_GOLDEN_OUTPUT="$temp_dir/golden.txt" \
MOXI_GOLDEN_REPO="$repo_dir" \
MOXI_GOLDEN_ARTIFACTS="$artifact_dir" \
MOXI_UPDATE_GOLDENS="$update_goldens" \
python3 - <<'PY'
import json
import os
import shutil
import struct
from pathlib import Path


manifest_path = Path(os.environ["MOXI_GOLDEN_MANIFEST"])
output_path = Path(os.environ["MOXI_GOLDEN_OUTPUT"])
repo = Path(os.environ["MOXI_GOLDEN_REPO"])
artifacts = Path(os.environ["MOXI_GOLDEN_ARTIFACTS"])
update = os.environ.get("MOXI_UPDATE_GOLDENS", "0") == "1"


def parse_records(path):
    lines = path.read_text(encoding="utf-8").splitlines()
    records = {}
    index = 0
    while index < len(lines):
        line = lines[index]
        if not line.startswith("BEGIN "):
            index += 1
            continue
        header = line.split()
        if len(header) != 7:
            raise SystemExit(f"invalid golden header: {line!r}")
        name = header[1]
        record = {
            "scenario": header[2],
            "width": int(header[3]),
            "height": int(header[4]),
            "checksum": int(header[5]),
            "renderer": header[6],
        }
        index += 1
        image_lines = []
        while index < len(lines) and not lines[index].startswith("END "):
            image_lines.append(lines[index])
            index += 1
        if index == len(lines):
            raise SystemExit(f"missing END marker for {name}")
        record["ppm"] = "\n".join(image_lines) + "\n"
        records[name] = record
        index += 1
    return records


def parse_p3(value):
    tokens = value.split()
    if len(tokens) < 4 or tokens[0] != "P3":
        raise ValueError("golden output is not a P3 image")
    width, height, maximum = map(int, tokens[1:4])
    if maximum != 255:
        raise ValueError(f"unsupported PPM max value: {maximum}")
    values = list(map(int, tokens[4:]))
    expected = width * height * 3
    if len(values) != expected:
        raise ValueError(
            f"P3 pixel count mismatch: expected {expected}, got {len(values)}"
        )
    if any(value < 0 or value > 255 for value in values):
        raise ValueError("P3 pixel channel outside 0..255")
    pixels = bytes(values)
    return width, height, pixels


def p6(width, height, pixels):
    return f"P6\n{width} {height}\n255\n".encode("ascii") + pixels


def read_ppm(path):
    data = path.read_bytes()
    if not data.startswith(b"P6\n"):
        raise ValueError(f"expected binary P6 golden: {path}")
    header_end = data.find(b"\n255\n")
    if header_end < 0:
        raise ValueError(f"invalid P6 header: {path}")
    header = data[:header_end].split()
    width, height = map(int, header[1:3])
    pixels = data[header_end + len(b"\n255\n"):]
    if len(pixels) != width * height * 3:
        raise ValueError(f"P6 pixel count mismatch: {path}")
    return width, height, pixels


def diff_image(width, height, actual, expected):
    output = bytearray()
    for index in range(0, len(actual), 3):
        actual_pixel = actual[index:index + 3]
        expected_pixel = expected[index:index + 3]
        if actual_pixel == expected_pixel:
            output.extend((32, 32, 32))
            continue
        delta = max(abs(a - b) for a, b in zip(actual_pixel, expected_pixel))
        output.extend((min(255, 64 + delta), 16, 16))
    return p6(width, height, bytes(output))


manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
entries = manifest.get("entries", [])
records = parse_records(output_path)
expected_names = {entry["name"] for entry in entries}
actual_names = set(records)
if expected_names != actual_names:
    missing = sorted(expected_names - actual_names)
    extra = sorted(actual_names - expected_names)
    raise SystemExit(f"golden inventory mismatch; missing={missing}, extra={extra}")

failures = []
for entry in entries:
    name = entry["name"]
    record = records[name]
    if record["scenario"] != entry["scenario"]:
        failures.append(
            f"{name}: scenario {record['scenario']} != {entry['scenario']}"
        )
    if record["renderer"] != manifest["renderer"]:
        failures.append(f"{name}: renderer {record['renderer']} != {manifest['renderer']}")
    if record["width"] != entry["width"] or record["height"] != entry["height"]:
        failures.append(
            f"{name}: dimensions {record['width']}x{record['height']} != "
            f"{entry['width']}x{entry['height']}"
        )
    actual_width, actual_height, actual_pixels = parse_p3(record["ppm"])
    if (actual_width, actual_height) != (entry["width"], entry["height"]):
        failures.append(f"{name}: PPM dimensions do not match manifest")
    if record["checksum"] != entry["checksum"]:
        failures.append(f"{name}: checksum {record['checksum']} != {entry['checksum']}")

    image_path = repo / entry["image"]
    actual_bytes = p6(actual_width, actual_height, actual_pixels)
    if update:
        image_path.parent.mkdir(parents=True, exist_ok=True)
        image_path.write_bytes(actual_bytes)
        entry["checksum"] = record["checksum"]
        continue

    if not image_path.exists():
        failures.append(f"{name}: missing image {entry['image']}")
        continue
    expected_width, expected_height, expected_pixels = read_ppm(image_path)
    if (expected_width, expected_height) != (actual_width, actual_height):
        failures.append(f"{name}: expected image dimensions differ")
        continue
    if expected_pixels != actual_pixels:
        failures.append(f"{name}: pixel data differs")
        (artifacts / "actual" / f"{name}.ppm").write_bytes(actual_bytes)
        shutil.copyfile(image_path, artifacts / "expected" / f"{name}.ppm")
        (artifacts / "diff" / f"{name}.ppm").write_bytes(
            diff_image(actual_width, actual_height, actual_pixels, expected_pixels)
        )

if update:
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"Updated {len(entries)} software golden images")
elif failures:
    print("Software visual golden check failed:")
    for failure in failures:
        print(f"  - {failure}")
    print(f"Review actual/expected/diff artifacts in {artifacts}")
    raise SystemExit(1)
else:
    print(f"Software visual golden check passed ({len(entries)} images)")
PY
