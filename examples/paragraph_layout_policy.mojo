"""External-style custom policy for the provisional box protocol."""
from moxi.box_layout import BoxLayout, BoxLayoutContext, BoxMetrics, ParagraphPayload, PlacementPlan
from moxi.geometry import Rect, Size


struct ParagraphFormLayout(BoxLayout):
    var summary: Bool

    def __init__(out self, summary: Bool = True):
        self.summary = summary

    def measure[P: ParagraphPayload](self, mut context: BoxLayoutContext[P], width: Float32) raises -> BoxMetrics:
        var inner = max(Float32(0), width - 48)
        var label_width = min(Float32(112), inner * 0.3)
        var value_width = max(Float32(0), inner - label_width - 12)
        var label = context.measure(1, label_width)
        var value = context.measure(2, value_width)
        var baseline = max(label.metrics.first_baseline, value.metrics.first_baseline)
        var row_height = baseline + max(
            label.metrics.size.height - label.metrics.first_baseline,
            value.metrics.size.height - value.metrics.first_baseline)
        var height = 48 + row_height + 12
        if self.summary:
            height += context.measure(3, inner).metrics.size.height + 12
        height += context.measure(4, inner).metrics.size.height
        return BoxMetrics(Size(width, height), 24 + baseline, 24 + baseline)

    def arrange[P: ParagraphPayload](self, mut context: BoxLayoutContext[P], size: Size) raises -> PlacementPlan[P]:
        var required = self.measure(context, size.width)
        var plan = context.plan(size)
        var inner = max(Float32(0), size.width - 48)
        var label_width = min(Float32(112), inner * 0.3)
        var value_width = max(Float32(0), inner - label_width - 12)
        var label = context.measure(1, label_width)
        var value = context.measure(2, value_width)
        var baseline = required.first_baseline
        var label_y = baseline - label.metrics.first_baseline
        var value_y = baseline - value.metrics.first_baseline
        plan.place(label, Rect(24, label_y, label_width, label.metrics.size.height))
        plan.place(value, Rect(24 + label_width + 12, value_y, value_width, value.metrics.size.height))
        var y = max(label_y + label.metrics.size.height, value_y + value.metrics.size.height) + 12
        if self.summary:
            var summary = context.measure(3, inner)
            plan.place(summary, Rect(24, y, inner, summary.metrics.size.height))
            y += summary.metrics.size.height + 12
        var chart = context.measure(4, inner)
        plan.place(chart, Rect(24, y, inner, max(chart.metrics.size.height, size.height - y - 24)))
        return plan^
