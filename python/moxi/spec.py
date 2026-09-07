"""Versioned PlotSpec compatibility contract.

The field order and names intentionally mirror ``src/moxi/plot_spec.mojo``.
Keeping this layer as ordinary Python values makes it safe to import from a
clean wheel without a Mojo compiler or a native extension.
"""

from __future__ import annotations

import json
from dataclasses import dataclass, field
from typing import Any, Dict, Iterable, List, Mapping, Optional

PLOT_SPEC_VERSION = 1
PLOT_MARKS = (
    "line",
    "scatter",
    "bar",
    "dot",
    "area",
    "rule",
    "error_bar",
    "rect",
    "text",
    "step",
    "tick",
    "interval",
    "bubble",
    "band",
    "column",
    "histogram",
    "density",
    "ecdf",
    "box",
    "heatmap",
    "hexbin",
    "regression",
)


def _color(value: Iterable[float]) -> List[float]:
    result = [float(item) for item in value]
    if len(result) != 4:
        raise ValueError("color must contain four RGBA values")
    if any(item < 0.0 or item > 1.0 for item in result):
        raise ValueError("color channels must be between 0 and 1")
    return result


@dataclass
class Layer:
    id: int
    mark: str
    label: str
    x: str
    y: str
    x2: str = ""
    y2: str = ""
    color_field: str = ""
    fill_field: str = ""
    stroke_field: str = ""
    size_field: str = ""
    opacity_field: str = ""
    text_field: str = ""
    stat_low_field: str = ""
    stat_high_field: str = ""
    median_field: str = ""
    line_width: float = 2.0
    size: float = 6.0
    opacity: float = 1.0
    tooltip: str = ""
    color: List[float] = field(default_factory=lambda: [0.25, 0.75, 1.0, 1.0])

    def as_dict(self) -> Dict[str, Any]:
        return {
            "id": self.id,
            "mark": self.mark,
            "label": self.label,
            "x": self.x,
            "y": self.y,
            "x2": self.x2,
            "y2": self.y2,
            "color_field": self.color_field,
            "fill_field": self.fill_field,
            "stroke_field": self.stroke_field,
            "size_field": self.size_field,
            "opacity_field": self.opacity_field,
            "text_field": self.text_field,
            "stat_low_field": self.stat_low_field,
            "stat_high_field": self.stat_high_field,
            "median_field": self.median_field,
            "line_width": self.line_width,
            "size": self.size,
            "opacity": self.opacity,
            "tooltip": self.tooltip,
            "color": list(self.color),
        }


@dataclass
class Encoding:
    layer: int
    channel: str
    field: str
    type: str = "quantitative"
    literal: str = ""
    has_literal: bool = False

    def as_dict(self) -> Dict[str, Any]:
        return {
            "layer": self.layer,
            "channel": self.channel,
            "field": self.field,
            "type": self.type,
            "literal": self.literal,
            "has_literal": self.has_literal,
        }


@dataclass
class Transform:
    kind: str
    field: str = ""
    second_field: str = ""
    output_field: str = ""
    value: float = 0.0
    second_value: float = 0.0
    descending: bool = False
    limit: int = 0
    window: int = 1
    mean: bool = False

    def as_dict(self) -> Dict[str, Any]:
        return {
            "kind": self.kind,
            "field": self.field,
            "second_field": self.second_field,
            "output_field": self.output_field,
            "value": self.value,
            "second_value": self.second_value,
            "descending": self.descending,
            "limit": self.limit,
            "window": self.window,
            "mean": self.mean,
        }


class PlotSpec:
    """Build or inspect a renderer-neutral declarative plot specification."""

    def __init__(self, title: str = "") -> None:
        self.version = PLOT_SPEC_VERSION
        self.title = str(title)
        self.layers: List[Layer] = []
        self.encodings: List[Encoding] = []
        self.transforms: List[Transform] = []
        self.scales: List[Dict[str, Any]] = []
        self.interactions: List[Dict[str, Any]] = []
        self.annotations: List[Dict[str, Any]] = []
        self.composition = "layer"
        self.facet = {"row": "", "column": ""}
        self.shared_scales = {"x": True, "y": True}
        self._next_layer_id = 1
        self._next_annotation_id = 1

    def _add_layer(
        self,
        mark: str,
        label: str,
        x: str,
        y: str,
        color: Iterable[float],
    ) -> int:
        if mark not in PLOT_MARKS:
            raise ValueError(f"unknown mark: {mark}")
        if not x or not y:
            raise ValueError("x and y fields are required")
        layer_id = self._next_layer_id
        self._next_layer_id += 1
        self.layers.append(Layer(layer_id, mark, str(label), x, y, color=_color(color)))
        self.encodings.extend(
            [
                Encoding(layer_id, "x", x),
                Encoding(layer_id, "y", y),
            ]
        )
        return layer_id

    def add_layer(
        self,
        mark: str,
        label: str = "",
        x_field: str = "x",
        y_field: str = "y",
        color: Iterable[float] = (0.25, 0.75, 1.0, 1.0),
    ) -> int:
        return self._add_layer(mark, label, x_field, y_field, color)

    def add_line(self, label: str = "", x_field: str = "x", y_field: str = "y", color: Iterable[float] = (0.25, 0.75, 1.0, 1.0)) -> int:
        return self._add_layer("line", label, x_field, y_field, color)

    def add_scatter(self, label: str = "", x_field: str = "x", y_field: str = "y", color: Iterable[float] = (1.0, 0.45, 0.30, 1.0)) -> int:
        return self._add_layer("scatter", label, x_field, y_field, color)

    def add_bar(self, label: str = "", x_field: str = "x", y_field: str = "y", color: Iterable[float] = (0.40, 0.85, 0.55, 1.0)) -> int:
        return self._add_layer("bar", label, x_field, y_field, color)

    def add_area(self, label: str = "", x_field: str = "x", y_field: str = "y", color: Iterable[float] = (0.30, 0.65, 0.95, 0.55)) -> int:
        return self._add_layer("area", label, x_field, y_field, color)

    def add_box(self, label: str, value_field: str, group_field: str = "", color: Iterable[float] = (0.40, 0.85, 0.55, 0.90)) -> int:
        layer_id = self._add_layer("box", label, group_field or "group", "y", color)
        layer = self.layers[-1]
        layer.y2 = "y2"
        layer.stat_low_field = "low"
        layer.stat_high_field = "high"
        layer.median_field = "median"
        self.transforms.append(Transform("box", field=value_field, second_field=group_field))
        return layer_id

    def add_heatmap(self, label: str, x_field: str, y_field: str, x_bins: int = 16, y_bins: int = 12, color: Iterable[float] = (0.25, 0.65, 1.0, 0.90)) -> int:
        layer_id = self._add_layer("heatmap", label, "x", "y", color)
        layer = self.layers[-1]
        layer.x2 = "x2"
        layer.y2 = "y2"
        layer.color_field = "count"
        self.transforms.append(Transform("heatmap", field=x_field, second_field=y_field, limit=max(1, x_bins), window=max(1, y_bins)))
        return layer_id

    def add_histogram(self, label: str, field: str, bins: int = 10, color: Iterable[float] = (0.30, 0.70, 0.95, 0.85)) -> int:
        layer_id = self._add_layer("histogram", label, "x", "y", color)
        self.layers[-1].x2 = "x2"
        self.transforms.append(Transform("histogram", field=field, limit=max(1, bins)))
        return layer_id

    def add_density(self, label: str, field: str, bins: int = 24, color: Iterable[float] = (0.55, 0.45, 1.0, 1.0)) -> int:
        layer_id = self._add_layer("density", label, "x", "y", color)
        self.transforms.append(Transform("density", field=field, limit=max(1, bins)))
        return layer_id

    def add_ecdf(self, label: str, field: str, color: Iterable[float] = (0.95, 0.65, 0.20, 1.0)) -> int:
        layer_id = self._add_layer("ecdf", label, "x", "y", color)
        self.transforms.append(Transform("ecdf", field=field))
        return layer_id

    def encode(self, layer_id: int, channel: str, field: str, type: str = "quantitative") -> bool:
        if not field or not any(layer.id == layer_id for layer in self.layers):
            return False
        for encoding in self.encodings:
            if encoding.layer == layer_id and encoding.channel == channel:
                encoding.field = field
                encoding.type = type
                return True
        self.encodings.append(Encoding(layer_id, channel, field, type))
        return True

    def set_scale(self, channel: str, kind: str = "linear", power: float = 2.0, ticks: int = 5, reverse: bool = False) -> None:
        self.scales.append({"channel": channel, "kind": kind, "power": power, "ticks": ticks, "reverse": reverse})

    def set_facet(self, row: str, column: str = "") -> None:
        self.composition = "facet"
        self.facet = {"row": row, "column": column}

    def add_annotation(self, text: str, x: float, y: float, data_space: bool = True) -> int:
        ident = self._next_annotation_id
        self._next_annotation_id += 1
        self.annotations.append({"id": ident, "text": text, "x": x, "y": y, "data_space": data_space})
        return ident

    def add_interaction(self, kind: str, *, x_only: bool = False, y_only: bool = False, crosshair: bool = False, tooltip: bool = False, additive: bool = False) -> bool:
        self.interactions.append({"kind": kind, "x_only": x_only, "y_only": y_only, "crosshair": crosshair, "tooltip": tooltip, "additive": additive})
        return True

    def add_hover(self) -> bool:
        return self.add_interaction("hover", crosshair=True, tooltip=True)

    def add_brush(self) -> bool:
        return self.add_interaction("brush")

    def add_pan_zoom(self, x_only: bool = False, y_only: bool = False) -> bool:
        return self.add_interaction("pan_zoom", x_only=x_only, y_only=y_only)

    def add_click_select(self) -> bool:
        return self.add_interaction("click_select", additive=True)

    def add_keyboard(self) -> bool:
        return self.add_interaction("keyboard")

    def as_dict(self) -> Dict[str, Any]:
        return {
            "version": self.version,
            "title": self.title,
            "composition": self.composition,
            "facet": dict(self.facet),
            "shared_scales": dict(self.shared_scales),
            "layers": [layer.as_dict() for layer in self.layers],
            "encodings": [encoding.as_dict() for encoding in self.encodings],
            "transforms": [transform.as_dict() for transform in self.transforms],
            "scales": list(self.scales),
            "interactions": list(self.interactions),
            "annotations": list(self.annotations),
        }

    def to_json(self) -> str:
        return json.dumps(self.as_dict(), separators=(",", ":"), ensure_ascii=False)

    @classmethod
    def from_json(cls, value: str) -> "PlotSpec":
        raw = json.loads(value)
        if not isinstance(raw, dict):
            raise ValueError("PlotSpec JSON must be an object")
        result = cls(str(raw.get("title", "")))
        result.version = int(raw.get("version", -1))
        result.composition = str(raw.get("composition", "layer"))
        result.facet = dict(raw.get("facet", result.facet))
        result.shared_scales = dict(raw.get("shared_scales", result.shared_scales))
        result.layers = [Layer(**item) for item in raw.get("layers", [])]
        result.encodings = [Encoding(**item) for item in raw.get("encodings", [])]
        result.transforms = [Transform(**item) for item in raw.get("transforms", [])]
        result.scales = list(raw.get("scales", []))
        result.interactions = list(raw.get("interactions", []))
        result.annotations = list(raw.get("annotations", []))
        result._next_layer_id = max((layer.id for layer in result.layers), default=0) + 1
        result._next_annotation_id = max((int(item.get("id", 0)) for item in result.annotations), default=0) + 1
        return result

    def validate(self) -> bool:
        if self.version != PLOT_SPEC_VERSION or self.composition not in {"layer", "horizontal", "vertical", "facet"}:
            return False
        if self.composition == "facet" and not self.facet.get("row"):
            return False
        layer_ids = set()
        for layer in self.layers:
            if layer.id in layer_ids or layer.mark not in PLOT_MARKS or not layer.x or not layer.y:
                return False
            layer_ids.add(layer.id)
            if not (0.0 <= layer.opacity <= 1.0 and layer.size > 0.0 and layer.line_width > 0.0):
                return False
            if len(layer.color) != 4:
                return False
        for encoding in self.encodings:
            if encoding.layer not in layer_ids or not encoding.channel or (not encoding.field and not encoding.has_literal):
                return False
        return True

    @classmethod
    def from_dict(cls, value: Mapping[str, Any]) -> "PlotSpec":
        return cls.from_json(json.dumps(value))
