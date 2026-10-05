"""Resizable form using the provisional box contract and shared native paragraphs."""
from std.math import sin
from moxi.box_layout import BoxLayoutContext
from moxi.native_paragraph import NativeParagraph, draw_box_snapshot
from moxi.geometry import Point, Rect
from moxi.macos import MacOSRenderer, MacOSWindow, MacOSCanvasPainter
from moxi.window import WindowConfig
from moxi.style import Color
from moxi.event import NONE_KIND, WINDOW_RESIZED_KIND, POINTER_DOWN_KIND, POINTER_UP_KIND, POINTER_CANCEL_KIND, DRAG_BEGIN_KIND, TEXT_INPUT_KIND, KEY_DOWN_KIND, KEY_SPACE
from paragraph_layout_policy import ParagraphFormLayout


def main() raises:
    var context = BoxLayoutContext[NativeParagraph]()
    context.set_paragraph(1, "Dataset", 15)
    context.set_paragraph(2, "Annual observations — temperature and rainfall across regions", 24)
    var summary_text = String("Resize the window to wrap this paragraph. Click the chart or press Space to hide/show this summary; the chart takes the remaining height.")
    context.set_paragraph(3, summary_text, 16)
    context.set_box(4, "Temperature chart. Click to toggle summary.", 160)
    var policy = ParagraphFormLayout()
    var window = MacOSWindow()
    var renderer = MacOSRenderer()
    var painter = MacOSCanvasPainter()
    var config = WindowConfig("Moxi · Native paragraph layout", 760, 560)
    config.set_min_size(360, 360)
    window.open(config)
    var dirty = True
    var pressed = -1
    while window.is_open():
        if dirty:
            var size = window.size()
            var plan = policy.arrange(context, size)
            context.commit(plan)
            var snapshot = context.snapshot()
            renderer.begin_frame()
            draw_box_snapshot(renderer, snapshot)
            var chart = snapshot.bounds(4)
            painter.begin(chart.intersection(Rect(0, 0, size.width, size.height)))
            painter.fill_rect(chart, Color(0.12, 0.16, 0.24, 1), Color(0.25, 0.35, 0.46, 1), 1)
            for i in range(1, 121):
                var x0 = Float32(i - 1) / 120
                var x1 = Float32(i) / 120
                painter.line(
                    Point(chart.x + 16 + x0 * (chart.width - 32), chart.y + chart.height * (0.5 - 0.25 * sin(x0 * 12))),
                    Point(chart.x + 16 + x1 * (chart.width - 32), chart.y + chart.height * (0.5 - 0.25 * sin(x1 * 12))),
                    Color(0.35, 0.85, 0.75, 1), 2)
            painter.end()
            renderer.update_accessibility(snapshot.accessibility())
            renderer.end_frame()
            dirty = False
        window.wait_for_work(-1)
        window.pump()
        var event = window.poll_event()
        while event.kind != NONE_KIND:
            if event.kind == WINDOW_RESIZED_KIND:
                dirty = True
            var toggle = False
            if event.kind == POINTER_DOWN_KIND:
                pressed = context.snapshot().hit_test(event.position)
            elif event.kind == POINTER_UP_KIND:
                toggle = pressed == 4 and context.snapshot().hit_test(event.position) == 4
                pressed = -1
            elif event.kind == POINTER_CANCEL_KIND or event.kind == DRAG_BEGIN_KIND:
                pressed = -1
            elif event.kind == KEY_DOWN_KIND and event.key == KEY_SPACE:
                toggle = True
            elif event.kind == TEXT_INPUT_KIND and event.text == " ":
                toggle = True
            if toggle:
                policy.summary = not policy.summary
                if policy.summary:
                    context.set_paragraph(3, summary_text, 16)
                else:
                    context.remove(3)
                dirty = True
            event = window.poll_event()
