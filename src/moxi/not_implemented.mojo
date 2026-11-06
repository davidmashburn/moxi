"""Informational composition for an intentionally unfinished feature."""

from .component import Component
from .column_view import ColumnView
from .geometry import Rect
from .style import default_label_style


comptime NOT_IMPLEMENTED_FEATURE_ID = 1
comptime NOT_IMPLEMENTED_STATUS_ID = 2
comptime NOT_IMPLEMENTED_EXPLANATION_ID = 3


struct NotImplemented(Component):
    """Pure, inert content; the host owns navigation and any working actions.

    Import from ``moxi.not_implemented``. Mount using distinct ComponentSlot
    namespaces. Intrinsic wrapped height participates in normal host overflow.
    This is not a loading, error, permission, or backend-capability fallback.
    """

    var feature_name: String
    var explanation: String

    def __init__(out self, feature_name: String, explanation: String = ""):
        self.feature_name = feature_name
        self.explanation = explanation

    def build(self, bounds: Rect) -> ColumnView:
        var view = ColumnView(bounds, 16.0, 8.0)
        var heading = default_label_style()
        heading.font_size = 28.0
        view.add_label_styled(NOT_IMPLEMENTED_FEATURE_ID, self.feature_name, 0.0, heading)
        view.add_label(NOT_IMPLEMENTED_STATUS_ID, "Not implemented yet", 0.0)
        if self.explanation != "":
            view.add_label(NOT_IMPLEMENTED_EXPLANATION_ID, self.explanation, 0.0)
        for index in range(view.child_count()):
            var id = view.child(index).id
            view.set_preferred_width(id, max(bounds.width - 32.0, 0.0))
            view.set_wrap_text(id)
            view.set_intrinsic_height(id)
        view.layout()
        return view^
