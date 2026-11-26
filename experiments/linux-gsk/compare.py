"""Measure aligned native screenshots and the geometric Moxi chart oracle."""
import argparse
import json
import struct
from pathlib import Path
from PIL import Image, ImageChops, ImageStat


def rgb(path):
    with Image.open(path) as image:
        return image.convert("RGB")


def difference(left, right):
    assert left.size == right.size
    diff = ImageChops.difference(left, right)
    maxima = ImageChops.lighter(ImageChops.lighter(*diff.split()[:2]), diff.split()[2])
    bins = maxima.histogram()
    pixels = sum(bins)
    return {"pixels": pixels, "mean_abs_channel": round(sum(ImageStat.Stat(diff).mean) / 3, 4),
            "exact_pct": round(100 * bins[0] / pixels, 4),
            "within_8_pct": round(100 * sum(bins[:9]) / pixels, 4)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    args = parser.parse_args()
    root = args.directory

    def states(mode):
        return json.loads((root / mode / "states.json").read_text())

    def published_nodes(mode):
        frames = {}
        for line in (root / mode / "trace.jsonl").read_text().splitlines():
            record = json.loads(line)
            if record["type"] == "frame":
                frames[record["frame"]] = record["nodes"]
        return {s["state"]: frames[s["frame"]] for s in states(mode)}

    reference = published_nodes("oracle")
    semantic_counts = {}
    for mode in ("ngl", "fallback", "scale2"):
        actual = published_nodes(mode)
        for name, packet in actual.items():
            assert packet == reference[name], f"{mode}/{name}: semantic nodes differ"
        semantic_counts[mode] = {name: len(packet) for name, packet in actual.items()}

    observed = {}
    for ref, state in zip(states("oracle"), states("ngl"), strict=True):
        name = state["state"]
        assert (name, state["viewport"], state["chart"]) == (ref["state"], ref["viewport"], ref["chart"])
        observed[name] = difference(rgb(root / "oracle" / (name + ".png")),
                                    rgb(root / "ngl" / (name + ".png")))
    initial = states("ngl")[0]
    x, y, w, h = initial["chart"]
    dx, dy = initial["canvas_offset"]
    left, top = round(x + dx), round(y + dy)
    chart = rgb(root / "ngl/initial.png").crop((left, top, left + int(w), top + int(h)))
    oracle = rgb(root / "chart.ppm")
    observed["chart"] = difference(chart, oracle)
    # The series is small compared with its background. Measure teal stroke
    # coverage separately so an entirely missing plot cannot pass the RGB gate.
    def stroke(image):
        return {(i % image.width, i // image.width)
                for i, (r, g, b) in enumerate(struct.iter_unpack("BBB", image.tobytes())) if g > 120 and g-r > 60 and b-r > 45}

    native_ink, oracle_ink = stroke(chart), stroke(oracle)
    assert oracle_ink
    observed["chart"]["stroke_iou"] = round(len(native_ink & oracle_ink) /
                                             len(native_ink | oracle_ink), 4)
    observed["fallback"] = difference(rgb(root / "oracle/initial.png"), rgb(root / "fallback/initial.png"))
    print(json.dumps({"pixel_comparisons": observed, "matching_semantic_nodes": semantic_counts}, indent=2))
    assert observed["chart"]["stroke_iou"] >= 0.65
    assert all(item["within_8_pct"] >= 97 for item in observed.values())


if __name__ == "__main__":
    main()
