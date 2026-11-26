"""Unbounded numeric inputs, replay order and finite raster working storage."""

from std.math import abs
from moxi import Color, Point, test_check, fractal_preset_geometry
from moxi.fractal import FractalBranchRun, FractalCursor, FractalLocalSegment, FractalSegment, FractalState, _local_segments
from moxi.natural import Natural
from moxi.raster import RasterImage
from std.collections import List


def check_huge_line(start: Point, end: Point, sample: Point):
    var forward = RasterImage(32, 32)
    var reverse = RasterImage(32, 32)
    test_check(forward.stroke_line(start, end, Color(1, 0, 0, 1)))
    test_check(reverse.stroke_line(end, start, Color(1, 0, 0, 1)))
    test_check(forward.pixels[(Int(sample.y) * 32 + Int(sample.x)) * 4 + 3] > 0)
    for index in range(len(forward.pixels)):
        test_check(forward.pixels[index] == reverse.pixels[index])


def check_cursor_cache():
    # Translation-only branches keep every ancestor distinguishable at depth 300.
    var local = List[FractalLocalSegment]()
    local.append(FractalLocalSegment(Point(0, 1), Point(1, 1)))
    local.append(FractalLocalSegment(Point(0, 2), Point(1, 2)))
    var start = Point(0, 0)
    var end = Point(1, 0)
    var cursor = FractalCursor(Natural(300), start, end)
    for _ in range(300):
        test_check(not cursor.step(local, start, end))
    test_check(cursor.level == 300)
    test_check(len(cursor.ancestors) == 256)
    test_check(cursor.ancestor_count == 256)
    test_check(cursor.step(local, start, end))
    test_check(cursor.leaf.start.y == 300)
    test_check(cursor.level == 299)
    test_check(cursor.ancestor_count == 255)
    test_check(not cursor.step(local, start, end))
    test_check(cursor.step(local, start, end))
    test_check(cursor.leaf.start.y == 301)
    test_check(cursor.level == 298)
    test_check(len(cursor.ancestors) == 256)

    # Seed a distant address instead of enumerating 2**256 leaves. Its next carry
    # crosses the entire cache and must restart at the root with the new address.
    var distant = FractalCursor(Natural(300), start, end)
    distant.address.append(FractalBranchRun(0, 44))
    distant.address.append(FractalBranchRun(1, 256))
    for _ in range(300):
        test_check(not distant.step(local, start, end))
    test_check(distant.step(local, start, end))
    test_check(distant.leaf.start.y == 556)
    test_check(distant.level == 0)
    test_check(distant.ancestor_count == 0)
    test_check(distant.segment.start.y == 0)
    test_check(len(distant.address) == 2 and distant.address[0].count == 43)
    for _ in range(300):
        test_check(not distant.step(local, start, end))
    test_check(distant.step(local, start, end))
    test_check(distant.leaf.start.y == 301)
    test_check(len(distant.ancestors) == 256)


def check_pixel_cutoff(depth: Natural):
    var local = List[FractalLocalSegment]()
    local.append(FractalLocalSegment(Point(0, 0), Point(0.25, 0)))
    local.append(FractalLocalSegment(Point(0.25, 0), Point(0.75, 0)))
    var start = Point(0, 0)
    var end = Point(2, 0)
    var cursor = FractalCursor(depth, start, end)
    var leaves = List[FractalSegment]()
    for _ in range(7):
        if cursor.step(local, start, end):
            leaves.append(cursor.leaf)
    test_check(cursor.finished and len(leaves) == 3)
    test_check(leaves[0].start.x == 0 and leaves[0].end.x == 0.5)
    test_check(leaves[1].start.x == 0.5 and leaves[1].end.x == 0.75)
    test_check(leaves[2].start.x == 0.75 and leaves[2].end.x == 1.25)

    # The diagonal exceeds one pixel even though each axis is under a pixel.
    end = Point(0.75, 0.75)
    cursor = FractalCursor(depth, start, end)
    test_check(not cursor.step(local, start, end))
    for _ in range(3):
        _ = cursor.step(local, start, end)
    test_check(cursor.finished and cursor.emitted == 2)
    for endpoint in [Point(0.5, 0.5), start]:
        cursor = FractalCursor(depth, start, endpoint)
        test_check(cursor.step(local, start, endpoint))
        test_check(cursor.finished and cursor.emitted == 1)
        test_check(cursor.leaf.end.x == endpoint.x and cursor.leaf.end.y == endpoint.y)

    # A collapsed child beside a full-length child produces a long, thin tree.
    local = [FractalLocalSegment(start, start), FractalLocalSegment(start, Point(1, 0))]
    cursor = FractalCursor(Natural(1000), start, Point(1, 0))
    for _ in range(4000):
        if cursor.finished:
            break
        _ = cursor.step(local, start, Point(1, 0))
        test_check(len(cursor.address) <= 2)
    test_check(cursor.finished and cursor.emitted == 1001)


def check_colored_replay():
    var state = FractalState()
    state.random_colors = True
    _ = state.set_depth(4)
    state.reset_render_progress()
    while not state.render_complete():
        _ = state.advance_render(1)
    var first = state.raster.pixels.copy()
    state.reset_render_progress()
    while not state.render_complete():
        _ = state.advance_render(128)
    test_check(first == state.raster.pixels)
    var first_red = -1
    for i in range(0, len(first), 4):
        if first[i + 3] > 0:
            if first_red == -1:
                first_red = Int(first[i])
            elif first_red != Int(first[i]):
                return
    test_check(False)  # Expected multiple colors across visible leaves.


def main():
    check_colored_replay()
    var number = Natural(7)
    test_check(not number.parse(""))
    test_check(not number.parse("-1"))
    test_check(not number.parse("1x"))
    test_check(number == 7)
    test_check(number.parse("0000"))
    number.decrement()
    test_check(number == 0)
    test_check(number.parse("9223372036854775807"))
    test_check(number.bounded_value(Int.MAX) == Int.MAX)
    number.increment()
    test_check(number.text() == "9223372036854775808")
    test_check(number.bounded_value(Int.MAX) == Int.MAX)
    number.decrement()
    test_check(number.text() == "9223372036854775807")
    test_check(number.parse("99999999999999999999999999999999999999999999999999"))
    var independent = number
    independent.increment()
    test_check(number.text() == "99999999999999999999999999999999999999999999999999")
    test_check(independent.text() == "100000000000000000000000000000000000000000000000000")
    independent.decrement()
    test_check(number == independent)

    var huge = Natural()
    var spelling = String("1")
    for _ in range(1000):
        spelling += "0"
    test_check(huge.parse(spelling))
    check_pixel_cutoff(huge)
    var state = FractalState()
    test_check(state.set_depth(huge))
    test_check(state.depth_input.text == spelling)
    # A length-preserving generator still yields before reaching this depth.
    state.local_segments = [FractalLocalSegment(Point(0, 0), Point(1, 0))]
    for _ in range(100):
        test_check(not state.advance_render())
    test_check(not state.render_complete())
    test_check(len(state.cursor.address) == 1 and state.cursor.address[0].count > 256)
    test_check(len(state.cursor.ancestors) == 256)
    test_check(state.cursor.emitted == 0)
    test_check(len(state.raster.pixels) == 920 * 620 * 4)
    test_check(state.set_depth(0))
    test_check(state.advance_render(1))
    test_check(state.render_complete())
    test_check(state.cursor.emitted == 1)
    check_cursor_cache()

    # Independent breadth expansion checks all leaf addresses and their order.
    for preset in range(27):
        var geometry = fractal_preset_geometry(preset)
        var local = _local_segments(geometry)
        var expected = List[FractalSegment]()
        expected.append(FractalSegment(geometry.baseline_start, geometry.baseline_end))
        for _ in range(3):
            var expanded = List[FractalSegment]()
            for parent in expected:
                var dx = parent.end.x - parent.start.x
                var dy = parent.end.y - parent.start.y
                if dx * dx + dy * dy < 1:
                    expanded.append(parent)
                    continue
                for child in local:
                    expanded.append(FractalSegment(
                        Point(parent.start.x + dx * child.start.x - dy * child.start.y,
                              parent.start.y + dy * child.start.x + dx * child.start.y),
                        Point(parent.start.x + dx * child.end.x - dy * child.end.y,
                              parent.start.y + dy * child.end.x + dx * child.end.y),
                    ))
            expected = expanded^
        var cursor = FractalCursor(Natural(3), geometry.baseline_start, geometry.baseline_end)
        var index = 0
        while not cursor.finished:
            if cursor.step(local, geometry.baseline_start, geometry.baseline_end):
                test_check(index < len(expected))
                test_check(abs(cursor.leaf.start.x - expected[index].start.x) < 0.001)
                test_check(abs(cursor.leaf.start.y - expected[index].start.y) < 0.001)
                test_check(abs(cursor.leaf.end.x - expected[index].end.x) < 0.001)
                test_check(abs(cursor.leaf.end.y - expected[index].end.y) < 0.001)
                index += 1
        test_check(index == len(expected))

    var image = RasterImage(32, 32)
    test_check(image.stroke_line(Point(-1e30, 4), Point(1e30, 4), Color(1, 0, 0, 1)))
    test_check(image.pixels[(4 * 32 + 0) * 4 + 3] > 0)
    test_check(image.pixels[(4 * 32 + 31) * 4 + 3] > 0)
    test_check(image.stroke_line(Point(8, -1e30), Point(8, 1e30), Color(0, 1, 0, 1)))
    test_check(image.pixels[(31 * 32 + 8) * 4 + 3] > 0)
    # Clip enormous oblique lines from the original equation in both directions.
    # These cross the top/right sides and the zero-valued bottom/left sides.
    check_huge_line(Point(-1e30, -1e30), Point(1e30, 1e30), Point(16, 16))
    check_huge_line(Point(-2e30, -1e30), Point(2e30, 1e30), Point(16, 8))
    check_huge_line(Point(-1e30, -2e30), Point(1e30, 2e30), Point(8, 16))
    check_huge_line(Point(-1e30, 1e30), Point(1e30, -1e30), Point(0, 0))
    var corner = RasterImage(32, 32)
    test_check(corner.stroke_line(Point(-1e30, 1e30), Point(1e30, -1e30), Color(1, 0, 0, 1)))
    for pixel in range(1, 32 * 32):
        test_check(corner.pixels[pixel * 4 + 3] == 0)
    var checksum = image.pixels[0]
    test_check(image.stroke_line(Point(-50, -50), Point(-5, -5), Color(1, 1, 1, 1)))
    test_check(image.pixels[0] == checksum)
    var overflow = Float32(1e38) * Float32(1e38)
    test_check(not image.stroke_line(Point(overflow, 0), Point(0, 0), Color(1, 1, 1, 1)))
    var copy = image
    copy.pixels[0] = 255
    test_check(image.pixels[0] == checksum)
    print("Moxi fractal numeric and raster contracts passed")
