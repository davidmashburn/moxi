"""Python Figure API and deterministic value-boundary renderer."""

from __future__ import annotations

import math
import struct
import zlib
from dataclasses import dataclass, field as dataclass_field
from html import escape
from pathlib import Path
from typing import Any, Dict, Iterable, List, Mapping, Optional, Sequence, Tuple, Union

from .data import DataTable
from .spec import PlotSpec

RGBA = Tuple[int, int, int, int]
ColorValue = Tuple[float, float, float, float]


@dataclass(frozen=True)
class BackendCapabilities:
    backend: str = "python-reference"
    png: bool = True
    svg: bool = True
    pdf: bool = True
    numpy: bool = True
    compiler_runtime: bool = False

    def as_dict(self) -> Dict[str, Any]:
        return {
            "backend": self.backend,
            "png": self.png,
            "svg": self.svg,
            "pdf": self.pdf,
            "numpy": self.numpy,
            "compiler_runtime": self.compiler_runtime,
        }


def _rgba(color: Iterable[float], opacity: float = 1.0) -> RGBA:
    values = list(color)
    return tuple(max(0, min(255, int(round(float(value) * 255.0)))) for value in (values[0], values[1], values[2], values[3] * opacity))  # type: ignore[return-value]


def _svg_color(color: Iterable[float], opacity: float = 1.0) -> str:
    values = list(color)
    return f"rgba({int(round(values[0]*255))},{int(round(values[1]*255))},{int(round(values[2]*255))},{max(0.0, min(1.0, values[3]*opacity)):g})"


def _domain(values: Sequence[float]) -> Tuple[float, float]:
    if not values:
        return 0.0, 1.0
    low, high = min(values), max(values)
    if low == high:
        padding = 1.0 if low == 0.0 else abs(low) * 0.1
        return low - padding, high + padding
    padding = (high - low) * 0.05
    return low - padding, high + padding


def _scale(value: float, low: float, high: float, pixels: float, invert: bool = False) -> float:
    ratio = 0.5 if high == low else (value - low) / (high - low)
    if invert:
        ratio = 1.0 - ratio
    return ratio * pixels


def _numeric_or_categories(values: Sequence[Any]) -> List[float]:
    try:
        return [float(value) for value in values]
    except (TypeError, ValueError):
        categories: List[Any] = []
        for value in values:
            if value not in categories:
                categories.append(value)
        return [float(categories.index(value)) for value in values]


def _finite_values(values: Sequence[Any]) -> List[float]:
    """Convert a column to finite numeric values, dropping null/non-finite rows."""
    result: List[float] = []
    for value in values:
        try:
            number = float(value)
        except (TypeError, ValueError):
            continue
        if math.isfinite(number):
            result.append(number)
    return result


@dataclass
class _Geometry:
    """Raw geometry plus the domains used to project one declarative layer."""

    kind: str
    x_domain: Tuple[float, float]
    y_domain: Tuple[float, float]
    points: List[Tuple[float, float]] = dataclass_field(default_factory=list)
    rects: List[Tuple[float, float, float, float, float]] = dataclass_field(default_factory=list)
    boxes: List[Tuple[float, float, float, float, float, float, float]] = dataclass_field(default_factory=list)
    errors: List[Tuple[float, float, float]] = dataclass_field(default_factory=list)
    polygons: List[List[Tuple[float, float]]] = dataclass_field(default_factory=list)
    segments: List[Tuple[float, float, float, float]] = dataclass_field(default_factory=list)
    colors: List[ColorValue] = dataclass_field(default_factory=list)
    opacities: List[float] = dataclass_field(default_factory=list)
    sizes: List[float] = dataclass_field(default_factory=list)


def _chunk(kind: bytes, payload: bytes) -> bytes:
    return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF)


def _png(width: int, height: int, pixels: bytes) -> bytes:
    rows = b"".join(b"\x00" + pixels[row * width * 4 : (row + 1) * width * 4] for row in range(height))
    return b"\x89PNG\r\n\x1a\n" + _chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)) + _chunk(b"IDAT", zlib.compress(rows, 9)) + _chunk(b"IEND", b"")


class _Raster:
    def __init__(self, width: int, height: int) -> None:
        self.width = width
        self.height = height
        self.pixels = bytearray([255, 255, 255, 255] * (width * height))

    def blend(self, x: int, y: int, color: RGBA) -> None:
        if x < 0 or y < 0 or x >= self.width or y >= self.height:
            return
        index = (y * self.width + x) * 4
        alpha = color[3] / 255.0
        inverse = 1.0 - alpha
        self.pixels[index] = int(color[0] * alpha + self.pixels[index] * inverse)
        self.pixels[index + 1] = int(color[1] * alpha + self.pixels[index + 1] * inverse)
        self.pixels[index + 2] = int(color[2] * alpha + self.pixels[index + 2] * inverse)
        self.pixels[index + 3] = min(255, int(color[3] + self.pixels[index + 3] * inverse))

    def rect(self, x: float, y: float, width: float, height: float, color: RGBA) -> None:
        for py in range(max(0, int(math.floor(y))), min(self.height, int(math.ceil(y + height)))):
            for px in range(max(0, int(math.floor(x))), min(self.width, int(math.ceil(x + width)))):
                self.blend(px, py, color)

    def circle(self, x: float, y: float, radius: float, color: RGBA) -> None:
        left, right = int(math.floor(x - radius)), int(math.ceil(x + radius))
        top, bottom = int(math.floor(y - radius)), int(math.ceil(y + radius))
        for py in range(top, bottom + 1):
            for px in range(left, right + 1):
                if (px + 0.5 - x) ** 2 + (py + 0.5 - y) ** 2 <= radius * radius:
                    self.blend(px, py, color)

    def line(self, start: Tuple[float, float], end: Tuple[float, float], width: float, color: RGBA) -> None:
        x0, y0 = start
        x1, y1 = end
        distance = max(1, int(math.ceil(math.hypot(x1 - x0, y1 - y0) * 2)))
        radius = max(0.5, width / 2.0)
        for index in range(distance + 1):
            amount = index / distance
            self.circle(x0 + (x1 - x0) * amount, y0 + (y1 - y0) * amount, radius, color)

    def polygon(self, points: Sequence[Tuple[float, float]], color: RGBA) -> None:
        """Fill a polygon with the same deterministic software raster path."""
        if len(points) < 3:
            return
        left = max(0, int(math.floor(min(point[0] for point in points))))
        right = min(self.width - 1, int(math.ceil(max(point[0] for point in points))))
        top = max(0, int(math.floor(min(point[1] for point in points))))
        bottom = min(self.height - 1, int(math.ceil(max(point[1] for point in points))))
        if left > right or top > bottom:
            return
        for py in range(top, bottom + 1):
            for px in range(left, right + 1):
                inside = False
                start = points[-1]
                for end in points:
                    x0, y0 = start
                    x1, y1 = end
                    crosses = (y0 > py + 0.5) != (y1 > py + 0.5)
                    if crosses:
                        intersection = (x1 - x0) * ((py + 0.5) - y0) / (y1 - y0) + x0
                        if px + 0.5 < intersection:
                            inside = not inside
                    start = end
                if inside:
                    self.blend(px, py, color)


class Figure:
    """A data/spec pair with stable export methods."""

    def __init__(self, data: Any, spec: Union[PlotSpec, Mapping[str, Any], str], width: int = 640, height: int = 480, backend: str = "python-reference") -> None:
        self.data = DataTable(data)
        if isinstance(spec, PlotSpec):
            self.spec = spec
        elif isinstance(spec, str):
            self.spec = PlotSpec.from_json(spec)
        else:
            self.spec = PlotSpec.from_dict(spec)
        if not self.spec.validate():
            raise ValueError("invalid PlotSpec")
        self.width = max(1, int(width))
        self.height = max(1, int(height))
        self.backend = backend

    def capabilities(self) -> BackendCapabilities:
        return BackendCapabilities(backend=self.backend)

    def hit_test(self, x: float, y: float, tolerance: float = 8.0) -> Optional[Dict[str, Any]]:
        """Return the nearest visible mark anchor within ``tolerance`` pixels."""
        limit = max(0.0, float(tolerance))
        best_distance = limit * limit
        result: Optional[Dict[str, Any]] = None
        for layer in self.spec.layers:
            geometry = self._screen_geometry(layer)
            anchors = geometry.points
            for row_index, (px, py) in enumerate(anchors):
                distance = (px - float(x)) ** 2 + (py - float(y)) ** 2
                if distance <= best_distance:
                    best_distance = distance
                    result = {
                        "layer": layer.id,
                        "mark": layer.mark,
                        "row_index": row_index,
                        "x": px,
                        "y": py,
                    }
            for row_index, (left, top, right, bottom, _) in enumerate(geometry.rects):
                if left <= x <= right and top <= y <= bottom:
                    return {
                        "layer": layer.id,
                        "mark": layer.mark,
                        "row_index": row_index,
                        "x": (left + right) / 2.0,
                        "y": (top + bottom) / 2.0,
                    }
            for row_index, (x0, y0, x1, y1) in enumerate(geometry.segments):
                dx, dy = x1 - x0, y1 - y0
                denominator = dx * dx + dy * dy
                amount = ((float(x) - x0) * dx + (float(y) - y0) * dy) / denominator if denominator else 0.0
                amount = max(0.0, min(1.0, amount))
                nearest_x, nearest_y = x0 + amount * dx, y0 + amount * dy
                distance = (nearest_x - float(x)) ** 2 + (nearest_y - float(y)) ** 2
                if distance <= best_distance:
                    best_distance = distance
                    result = {
                        "layer": layer.id,
                        "mark": layer.mark,
                        "row_index": row_index,
                        "x": nearest_x,
                        "y": nearest_y,
                    }
        return result

    def accessibility(self) -> List[Dict[str, Any]]:
        """Return a stable tabular summary for headless accessibility clients."""
        rows: List[Dict[str, Any]] = [{
            "role": "chart",
            "label": self.spec.title or "Moxi plot",
            "layer_count": len(self.spec.layers),
        }]
        for layer in self.spec.layers:
            rows.append({
                "role": "mark",
                "layer": layer.id,
                "mark": layer.mark,
                "label": layer.label or layer.mark,
                "x_field": layer.x,
                "y_field": layer.y,
                "x2_field": layer.x2,
                "y2_field": layer.y2,
                "color_field": layer.color_field or layer.fill_field,
                "size_field": layer.size_field,
                "opacity_field": layer.opacity_field,
                "row_count": self.data.row_count,
            })
        return rows

    def _layout(self) -> Tuple[float, float, float, float, float, float, float, float]:
        return 54.0, 18.0, max(1.0, self.width - 72.0), max(1.0, self.height - 48.0), 0.0, 1.0, 0.0, 1.0

    def _transform_for_layer(self, layer: Any) -> Optional[Any]:
        """Return the transform matching this layer's recipe occurrence."""
        occurrence = 0
        for candidate in self.spec.layers:
            if candidate.mark == layer.mark:
                occurrence += 1
            if candidate.id == layer.id:
                break
        matches = [transform for transform in self.spec.transforms if transform.kind == layer.mark]
        if not matches:
            return None
        return matches[min(max(occurrence - 1, 0), len(matches) - 1)]

    def _histogram_geometry(self, transform: Any, density: bool = False) -> _Geometry:
        values = _finite_values(self.data.column(transform.field))
        bins = max(1, int(transform.limit))
        if not values:
            return _Geometry("line" if density else "bars", (0.0, 1.0), (0.0, 1.0))
        minimum, maximum = min(values), max(values)
        if minimum == maximum:
            minimum -= 0.5
            maximum += 0.5
        width = (maximum - minimum) / float(bins)
        if width <= 0.0:
            width = 1.0
        counts = [0] * bins
        for value in values:
            index = int(math.floor((value - minimum) / width))
            index = max(0, min(bins - 1, index))
            counts[index] += 1
        if density:
            points = []
            for index, count in enumerate(counts):
                lower = minimum + index * width
                points.append((lower, count / (len(values) * width)))
            maximum_y = max((point[1] for point in points), default=1.0)
            return _Geometry("line", (minimum, maximum), (0.0, maximum_y if maximum_y > 0.0 else 1.0), points=points)
        rects = []
        for index, count in enumerate(counts):
            lower = minimum + index * width
            upper = maximum if index == bins - 1 else lower + width
            rects.append((lower, 0.0, upper, float(count), float(count)))
        maximum_y = max(counts, default=1)
        return _Geometry("bars", (minimum, maximum), (0.0, float(maximum_y) if maximum_y > 0 else 1.0), rects=rects)

    def _ecdf_geometry(self, transform: Any) -> _Geometry:
        values = sorted(_finite_values(self.data.column(transform.field)))
        if not values:
            return _Geometry("line", (0.0, 1.0), (0.0, 1.0))
        points = [(value, (index + 1) / float(len(values))) for index, value in enumerate(values)]
        return _Geometry("line", _domain(values), (0.0, 1.0), points=points)

    def _regression_geometry(self, transform: Any) -> _Geometry:
        x_values = self.data.column(transform.field)
        y_values = self.data.column(transform.second_field)
        pairs = []
        for x_value, y_value in zip(x_values, y_values):
            try:
                x, y = float(x_value), float(y_value)
            except (TypeError, ValueError):
                continue
            if math.isfinite(x) and math.isfinite(y):
                pairs.append((x, y))
        if not pairs:
            return _Geometry("line", (0.0, 1.0), (0.0, 1.0))
        sum_x = sum(x for x, _ in pairs)
        sum_y = sum(y for _, y in pairs)
        sum_xx = sum(x * x for x, _ in pairs)
        sum_xy = sum(x * y for x, y in pairs)
        denominator = len(pairs) * sum_xx - sum_x * sum_x
        slope = (len(pairs) * sum_xy - sum_x * sum_y) / denominator if denominator else 0.0
        intercept = (sum_y - slope * sum_x) / float(len(pairs))
        minimum, maximum = min(x for x, _ in pairs), max(x for x, _ in pairs)
        if minimum == maximum:
            minimum -= 0.5
            maximum += 0.5
        samples = max(2, int(transform.limit))
        points = []
        for index in range(samples):
            fraction = index / float(samples - 1)
            x = minimum + fraction * (maximum - minimum)
            points.append((x, intercept + slope * x))
        return _Geometry("line", _domain([x for x, _ in pairs]), _domain([y for _, y in points]), points=points)

    def _box_geometry(self, transform: Any) -> _Geometry:
        values = self.data.column(transform.field)
        group_field = transform.second_field
        groups: List[Any] = []
        grouped: Dict[Any, List[float]] = {}
        group_values = self.data.columns.get(group_field, []) if group_field else []
        for index, value in enumerate(values):
            try:
                number = float(value)
            except (TypeError, ValueError):
                continue
            if not math.isfinite(number):
                continue
            group = group_values[index] if index < len(group_values) else "all"
            if group not in grouped:
                groups.append(group)
                grouped[group] = []
            grouped[group].append(number)
        boxes = []
        all_extrema: List[float] = []
        for group_index, group in enumerate(groups):
            ordered = sorted(grouped[group])
            if not ordered:
                continue
            low, high = ordered[0], ordered[-1]
            q1 = ordered[int((len(ordered) - 1) * 0.25)]
            median = ordered[int((len(ordered) - 1) * 0.50)]
            q3 = ordered[int((len(ordered) - 1) * 0.75)]
            boxes.append((float(group_index), float(group_index) + 0.8, q1, q3, low, high, median))
            all_extrema.extend((low, high))
        if not boxes:
            return _Geometry("box", (0.0, 1.0), (0.0, 1.0))
        return _Geometry("box", (-0.2, max(1.0, float(len(boxes)) - 0.2)), _domain(all_extrema), boxes=boxes)

    def _heatmap_geometry(self, transform: Any, kind: str) -> _Geometry:
        x_values = self.data.column(transform.field)
        y_values = self.data.column(transform.second_field)
        pairs = []
        for x_value, y_value in zip(x_values, y_values):
            try:
                x, y = float(x_value), float(y_value)
            except (TypeError, ValueError):
                continue
            if math.isfinite(x) and math.isfinite(y):
                pairs.append((x, y))
        bins_x, bins_y = max(1, int(transform.limit)), max(1, int(transform.window))
        if not pairs:
            return _Geometry(kind, (0.0, 1.0), (0.0, 1.0))
        minimum_x, maximum_x = min(x for x, _ in pairs), max(x for x, _ in pairs)
        minimum_y, maximum_y = min(y for _, y in pairs), max(y for _, y in pairs)
        if minimum_x == maximum_x:
            minimum_x -= 0.5
            maximum_x += 0.5
        if minimum_y == maximum_y:
            minimum_y -= 0.5
            maximum_y += 0.5
        width_x = (maximum_x - minimum_x) / float(bins_x)
        width_y = (maximum_y - minimum_y) / float(bins_y)
        counts = [0] * (bins_x * bins_y)
        for x, y in pairs:
            index_x = max(0, min(bins_x - 1, int(math.floor((x - minimum_x) / width_x))))
            index_y = max(0, min(bins_y - 1, int(math.floor((y - minimum_y) / width_y))))
            counts[index_y * bins_x + index_x] += 1
        maximum_count = max(counts, default=1)
        rects = []
        for index_y in range(bins_y):
            for index_x in range(bins_x):
                count = counts[index_y * bins_x + index_x]
                if count == 0:
                    continue
                lower_x = minimum_x + index_x * width_x
                lower_y = minimum_y + index_y * width_y
                rects.append((lower_x, lower_y, lower_x + width_x, lower_y + width_y, float(count) / maximum_count))
        return _Geometry(kind, (minimum_x, maximum_x), (minimum_y, maximum_y), rects=rects)

    def _error_geometry(self, layer: Any) -> _Geometry:
        x_values = _numeric_or_categories(self.data.column(layer.x))
        raw_y_values = self.data.column(layer.y)
        endpoints = self.data.columns.get(layer.y2, []) if layer.y2 else []
        rows = []
        for index, (x, raw_y) in enumerate(zip(x_values, raw_y_values)):
            try:
                y = float(raw_y)
            except (TypeError, ValueError):
                continue
            if math.isfinite(y):
                rows.append((index, x, y))
        if not rows:
            return _Geometry("errors", (0.0, 1.0), (0.0, 1.0))
        y_min, y_max = min(y for _, _, y in rows), max(y for _, _, y in rows)
        if endpoints:
            valid_endpoints = _finite_values(endpoints)
            if valid_endpoints:
                y_min, y_max = min(y_min, min(valid_endpoints)), max(y_max, max(valid_endpoints))
        span = max((y_max - y_min) * 0.03, 1.0e-6)
        errors = []
        centers = []
        for index, x, y in rows:
            try:
                endpoint = float(endpoints[index]) if index < len(endpoints) else float("nan")
            except (TypeError, ValueError):
                endpoint = float("nan")
            lower, upper = (min(y, endpoint), max(y, endpoint)) if math.isfinite(endpoint) else (y - span, y + span)
            errors.append((x_values[index], lower, upper))
            centers.append((x, y))
        all_y = [value for _, lower, upper in errors for value in (lower, upper)]
        return _Geometry("errors", _domain([x for _, x, _ in rows]), _domain(all_y), points=centers, errors=errors)

    def _row_style(self, layer: Any, row_index: int) -> Tuple[ColorValue, float, float]:
        """Resolve the portable per-row visual channels used by catalog marks."""
        color: ColorValue = tuple(float(value) for value in layer.color)  # type: ignore[assignment]
        color_field = layer.fill_field or layer.color_field or layer.stroke_field
        values = self.data.columns.get(color_field, []) if color_field else []
        if values and row_index < len(values):
            raw_value = values[row_index]
            numeric_values = _finite_values(values)
            if len(numeric_values) == len(values) and numeric_values:
                low, high = min(numeric_values), max(numeric_values)
                try:
                    numeric = float(raw_value)
                except (TypeError, ValueError):
                    numeric = (low + high) * 0.5
                fraction = 0.5 if high == low else (numeric - low) / (high - low)
                fraction = max(0.0, min(1.0, fraction))
                color = (fraction, 0.35, 1.0 - fraction, 1.0)
            else:
                categories: List[str] = []
                for value in values:
                    key = repr(value)
                    if key not in categories:
                        categories.append(key)
                category = repr(raw_value)
                palette = (
                    (0.25, 0.75, 1.0, 1.0),
                    (1.0, 0.45, 0.30, 1.0),
                    (0.40, 0.85, 0.55, 1.0),
                    (0.95, 0.65, 0.20, 1.0),
                    (0.75, 0.45, 1.0, 1.0),
                    (1.0, 0.75, 0.35, 1.0),
                )
                color = palette[categories.index(category) % len(palette)]
        opacity = 1.0
        opacity_values = self.data.columns.get(layer.opacity_field, []) if layer.opacity_field else []
        if row_index < len(opacity_values):
            try:
                opacity = max(0.0, min(1.0, float(opacity_values[row_index])))
            except (TypeError, ValueError):
                pass
        size = float(layer.size)
        size_values = self.data.columns.get(layer.size_field, []) if layer.size_field else []
        if row_index < len(size_values):
            try:
                candidate = float(size_values[row_index])
                if math.isfinite(candidate) and candidate > 0.0:
                    size = candidate
            except (TypeError, ValueError):
                pass
        return color, opacity, size

    def _group_values(self, layer: Any, count: int) -> List[Any]:
        field = layer.color_field or layer.fill_field
        values = self.data.columns.get(field, []) if field else []
        return [values[index] if index < len(values) else "all" for index in range(count)]

    @staticmethod
    def _step(values: Sequence[float], fallback: float = 1.0) -> float:
        unique = sorted(set(values))
        gaps = [right - left for left, right in zip(unique, unique[1:]) if right > left]
        return min(gaps) if gaps else max(fallback, 1.0)

    @staticmethod
    def _sector(start: float, end: float, outer: float, inner: float = 0.0) -> List[Tuple[float, float]]:
        span = max(1, int(math.ceil(abs(end - start) * 10.0)))
        points = [(0.0, 0.0)] if inner <= 0.0 else []
        for index in range(span + 1):
            angle = start + (end - start) * index / float(span)
            points.append((math.cos(angle) * outer, math.sin(angle) * outer))
        if inner > 0.0:
            for index in range(span, -1, -1):
                angle = start + (end - start) * index / float(span)
                points.append((math.cos(angle) * inner, math.sin(angle) * inner))
        return points

    def _catalog_geometry(self, layer: Any) -> _Geometry:
        """Produce static geometry while retaining the shared row boundary.

        These layouts intentionally consume ordinary columns.  They are not a
        claim of upstream nested-array parity; they are the deterministic,
        renderer-neutral geometry that lets the same PlotSpec exercise Python,
        Mojo, export, hit testing, and accessibility paths.
        """
        x_values = _numeric_or_categories(self.data.column(layer.x))
        y_values = _numeric_or_categories(self.data.column(layer.y))
        count = min(len(x_values), len(y_values))
        if count == 0:
            return _Geometry("points", (0.0, 1.0), (0.0, 1.0))
        mark = layer.mark
        x2_values = _numeric_or_categories(self.data.columns[layer.x2]) if layer.x2 and layer.x2 in self.data.columns else []
        y2_values = _numeric_or_categories(self.data.columns[layer.y2]) if layer.y2 and layer.y2 in self.data.columns else []
        colors: List[ColorValue] = []
        opacities: List[float] = []
        sizes: List[float] = []

        def style(index: int) -> None:
            color, opacity, size = self._row_style(layer, index)
            colors.append(color)
            opacities.append(opacity)
            sizes.append(size)

        if mark in {"grouped_bar", "stacked_bar"}:
            groups = self._group_values(layer, count)
            unique_groups: List[str] = []
            for value in groups:
                key = repr(value)
                if key not in unique_groups:
                    unique_groups.append(key)
            x_step = self._step(x_values, fallback=1.0)
            outer = x_step * 0.82
            rects: List[Tuple[float, float, float, float, float]] = []
            points: List[Tuple[float, float]] = []
            positive: Dict[float, float] = {}
            negative: Dict[float, float] = {}
            for index in range(count):
                group_index = unique_groups.index(repr(groups[index]))
                if mark == "grouped_bar":
                    slot = outer / max(1.0, float(len(unique_groups)))
                    left = x_values[index] - outer * 0.5 + slot * group_index + slot * 0.08
                    right = x_values[index] - outer * 0.5 + slot * (group_index + 1) - slot * 0.08
                    bottom, top = 0.0, y_values[index]
                else:
                    slot = outer
                    left, right = x_values[index] - slot * 0.5, x_values[index] + slot * 0.5
                    key = x_values[index]
                    if y_values[index] >= 0.0:
                        bottom = positive.get(key, 0.0)
                        top = bottom + y_values[index]
                        positive[key] = top
                    else:
                        top = negative.get(key, 0.0)
                        bottom = top + y_values[index]
                        negative[key] = bottom
                rects.append((left, bottom, right, top, 1.0))
                points.append(((left + right) * 0.5, (bottom + top) * 0.5))
                style(index)
            stacked_extrema = list(y_values[:count])
            stacked_extrema.extend(positive.values())
            stacked_extrema.extend(negative.values())
            return _Geometry("bars", _domain(x_values), _domain([0.0] + stacked_extrema), points=points, rects=rects, colors=colors, opacities=opacities, sizes=sizes)

        if mark == "waterfall":
            width = self._step(x_values, fallback=1.0) * 0.72
            rects, points = [], []
            running = 0.0
            extrema = [0.0]
            for index in range(count):
                bottom = running
                running += y_values[index]
                top = running
                rects.append((x_values[index] - width * 0.5, min(bottom, top), x_values[index] + width * 0.5, max(bottom, top), 1.0))
                points.append((x_values[index], (bottom + top) * 0.5))
                extrema.extend((bottom, top))
                style(index)
            return _Geometry("bars", _domain(x_values), _domain(extrema), points=points, rects=rects, colors=colors, opacities=opacities, sizes=sizes)

        if mark == "candlestick":
            width = self._step(x_values, fallback=1.0) * 0.62
            opens = y2_values if y2_values else (
                _numeric_or_categories(self.data.columns[layer.median_field])
                if layer.median_field and layer.median_field in self.data.columns else y_values
            )
            low_values = _numeric_or_categories(self.data.columns[layer.stat_low_field]) if layer.stat_low_field and layer.stat_low_field in self.data.columns else []
            high_values = _numeric_or_categories(self.data.columns[layer.stat_high_field]) if layer.stat_high_field and layer.stat_high_field in self.data.columns else []
            rects, segments, points, extrema = [], [], [], []
            for index in range(count):
                opened = opens[index] if index < len(opens) else y_values[index]
                closed = y_values[index]
                low = low_values[index] if index < len(low_values) else min(opened, closed)
                high = high_values[index] if index < len(high_values) else max(opened, closed)
                rects.append((x_values[index] - width * 0.5, min(opened, closed), x_values[index] + width * 0.5, max(opened, closed), 1.0))
                segments.append((x_values[index], low, x_values[index], high))
                points.append((x_values[index], closed))
                extrema.extend((low, high))
                style(index)
            return _Geometry("candlestick", _domain(x_values), _domain(extrema), points=points, rects=rects, segments=segments, colors=colors, opacities=opacities, sizes=sizes)

        if mark in {"gantt", "span_chart"}:
            y_step = self._step(y_values, fallback=1.0)
            x_step = self._step(x_values + x2_values[:count], fallback=1.0)
            rects, points = [], []
            x_domain_values = list(x_values)
            y_domain_values = list(y_values)
            for index in range(count):
                if index < len(x2_values):
                    left, right = sorted((x_values[index], x2_values[index]))
                    top, bottom = y_values[index] - y_step * 0.32, y_values[index] + y_step * 0.32
                elif index < len(y2_values):
                    left, right = x_values[index] - x_step * 0.32, x_values[index] + x_step * 0.32
                    top, bottom = sorted((y_values[index], y2_values[index]))
                else:
                    left, right = x_values[index] - x_step * 0.36, x_values[index] + x_step * 0.36
                    top, bottom = y_values[index] - y_step * 0.32, y_values[index] + y_step * 0.32
                rects.append((left, top, right, bottom, 1.0))
                points.append(((left + right) * 0.5, (top + bottom) * 0.5))
                x_domain_values.extend((left, right))
                y_domain_values.extend((top, bottom))
                style(index)
            return _Geometry("bars", _domain(x_domain_values), _domain(y_domain_values), points=points, rects=rects, colors=colors, opacities=opacities, sizes=sizes)

        if mark == "lollipop":
            endpoints = [(x_values[index], 0.0, y_values[index]) for index in range(count)]
            for index in range(count):
                style(index)
            return _Geometry("errors", _domain(x_values), _domain([0.0] + y_values), points=list(zip(x_values[:count], y_values[:count])), errors=endpoints, colors=colors, opacities=opacities, sizes=sizes)

        if mark in {"pie", "donut", "nightingale", "polar", "polar_bar", "radialbar", "gauge"}:
            values = [max(0.0, value) for value in y_values[:count]]
            total = sum(values) or float(max(1, count))
            start = -3.0 * math.pi / 4.0 if mark == "gauge" else -math.pi / 2.0
            span = 1.5 * math.pi if mark == "gauge" else 2.0 * math.pi
            polygons, points = [], []
            for index, value in enumerate(values):
                fraction = value / total if sum(values) else 1.0 / max(1.0, float(count))
                end = start + span * fraction
                normalized = value / max(values or [1.0])
                outer = 1.0 if mark in {"pie", "donut"} else 0.35 + 0.65 * normalized
                inner = 0.45 if mark in {"donut", "gauge", "radialbar"} else 0.0
                polygons.append(self._sector(start, end, outer, inner))
                middle = (start + end) * 0.5
                points.append((math.cos(middle) * (outer + inner) * 0.5, math.sin(middle) * (outer + inner) * 0.5))
                style(index)
                start = end
            return _Geometry("polygons", (-1.1, 1.1), (-1.1, 1.1), points=points, polygons=polygons, colors=colors, opacities=opacities, sizes=sizes)

        if mark == "radar":
            maximum = max(max(y_values[:count]), 1.0)
            points = []
            for index, value in enumerate(y_values[:count]):
                angle = -math.pi / 2.0 + 2.0 * math.pi * index / max(1.0, float(count))
                radius = max(0.0, value) / maximum
                points.append((math.cos(angle) * radius, math.sin(angle) * radius))
            if points:
                colors.append(self._row_style(layer, 0)[0])
                opacities.append(self._row_style(layer, 0)[1])
                sizes.append(self._row_style(layer, 0)[2])
            return _Geometry("polygons", (-1.1, 1.1), (-1.1, 1.1), points=points, polygons=[points] if len(points) >= 3 else [], colors=colors, opacities=opacities, sizes=sizes)

        if mark == "calendar_heatmap":
            x_step = self._step(x_values, fallback=1.0)
            y_step = self._step(y_values, fallback=1.0)
            rects, points = [], []
            for index in range(count):
                rects.append((x_values[index] - x_step * 0.42, y_values[index] - y_step * 0.42, x_values[index] + x_step * 0.42, y_values[index] + y_step * 0.42, max(0.05, min(1.0, abs(y_values[index])))))
                points.append((x_values[index], y_values[index]))
                style(index)
            return _Geometry("calendar", _domain(x_values), _domain(y_values), points=points, rects=rects, colors=colors, opacities=opacities, sizes=sizes)

        if mark in {"graph", "sankey", "arc_diagram", "chord", "barbs", "effect_scatter"} and (x2_values or y2_values):
            segments, points = [], []
            x_domain_values, y_domain_values = list(x_values), list(y_values)
            for index in range(count):
                end_x = x2_values[index] if index < len(x2_values) else x_values[index]
                end_y = y2_values[index] if index < len(y2_values) else y_values[index]
                if mark == "barbs" and not (x2_values or y2_values):
                    end_x += 0.5
                segments.append((x_values[index], y_values[index], end_x, end_y))
                points.append((x_values[index], y_values[index]))
                x_domain_values.append(end_x)
                y_domain_values.append(end_y)
                style(index)
            return _Geometry("segments", _domain(x_domain_values), _domain(y_domain_values), points=points, segments=segments, colors=colors, opacities=opacities, sizes=sizes)

        if mark in {"beeswarm", "punchcard"}:
            points = []
            seen: Dict[float, int] = {}
            jitter = self._step(x_values, fallback=1.0) * 0.12
            for index in range(count):
                offset = seen.get(x_values[index], 0)
                seen[x_values[index]] = offset + 1
                points.append((x_values[index] + (offset % 2) * jitter * (1 if offset % 4 < 2 else -1), y_values[index]))
                style(index)
            return _Geometry("points", _domain([point[0] for point in points]), _domain(y_values), points=points, colors=colors, opacities=opacities, sizes=sizes)

        line_marks = {
            "violin", "ridgeline", "parallel", "contour", "contourf",
            "tricontour", "corrplot", "bump", "tree", "streamgraph",
        }
        if mark in line_marks:
            for index in range(count):
                style(index)
            return _Geometry("line", _domain(x_values), _domain(y_values), points=list(zip(x_values[:count], y_values[:count])), colors=colors, opacities=opacities, sizes=sizes)

        # Remaining catalog rows still receive one stable anchor and retain
        # every resolved visual channel for renderers that support markers.
        for index in range(count):
            style(index)
        return _Geometry("points", _domain(x_values), _domain(y_values), points=list(zip(x_values[:count], y_values[:count])), colors=colors, opacities=opacities, sizes=sizes)

    def _raw_geometry(self, layer: Any) -> _Geometry:
        transform = self._transform_for_layer(layer)
        if transform is not None:
            if layer.mark == "histogram":
                return self._histogram_geometry(transform)
            if layer.mark == "density":
                return self._histogram_geometry(transform, density=True)
            if layer.mark == "ecdf":
                return self._ecdf_geometry(transform)
            if layer.mark == "regression":
                return self._regression_geometry(transform)
            if layer.mark == "box":
                return self._box_geometry(transform)
            if layer.mark in {"heatmap", "hexbin"}:
                return self._heatmap_geometry(transform, layer.mark)
        if layer.mark == "error_bar":
            return self._error_geometry(layer)
        if layer.mark in {
            "grouped_bar", "stacked_bar", "pie", "donut", "lollipop", "waterfall",
            "candlestick", "bullet", "gantt", "span_chart", "beeswarm", "violin",
            "ridgeline", "nightingale", "polar", "polar_bar", "radialbar", "gauge",
            "radar", "population_pyramid", "parallel", "contour", "contourf",
            "tricontour", "corrplot", "calendar_heatmap", "punchcard", "marimekko",
            "funnel", "bump", "effect_scatter", "arc_diagram", "graph", "sankey",
            "sunburst", "tree", "treemap", "barbs", "chord", "streamgraph",
        }:
            return self._catalog_geometry(layer)
        x_values = _numeric_or_categories(self.data.column(layer.x))
        y_values = _numeric_or_categories(self.data.column(layer.y))
        points = list(zip(x_values, y_values))
        kind = "line" if layer.mark in {"line", "step"} else "points"
        return _Geometry(kind, _domain(x_values), _domain(y_values), points=points)

    def _screen_geometry(self, layer: Any) -> _Geometry:
        raw = self._raw_geometry(layer)
        left, top, plot_width, plot_height, *_ = self._layout()

        def project(x: float, y: float) -> Tuple[float, float]:
            return (left + _scale(x, raw.x_domain[0], raw.x_domain[1], plot_width), top + _scale(y, raw.y_domain[0], raw.y_domain[1], plot_height, True))

        result = _Geometry(raw.kind, raw.x_domain, raw.y_domain)
        result.points = [project(x, y) for x, y in raw.points]
        result.colors = list(raw.colors)
        result.opacities = list(raw.opacities)
        result.sizes = list(raw.sizes)
        for x0, y0, x1, y1, weight in raw.rects:
            first, second = project(x0, y0), project(x1, y1)
            result.rects.append((min(first[0], second[0]), min(first[1], second[1]), max(first[0], second[0]), max(first[1], second[1]), weight))
        result.polygons = [[project(x, y) for x, y in polygon] for polygon in raw.polygons]
        result.segments = []
        for x0, y0, x1, y1 in raw.segments:
            start, end = project(x0, y0), project(x1, y1)
            result.segments.append((start[0], start[1], end[0], end[1]))
        for x0, x1, q1, q3, low, high, median in raw.boxes:
            sx0 = project(x0, q1)[0]
            sx1 = project(x1, q3)[0]
            result.boxes.append((sx0, sx1, project(x0, q1)[1], project(x1, q3)[1], project(x0, low)[1], project(x0, high)[1], project(x0, median)[1]))
        if raw.kind == "errors":
            for x, lower, upper in raw.errors:
                sx = project(x, lower)[0]
                result.errors.append((sx, project(x, lower)[1], project(x, upper)[1]))
        return result

    def _points(self, layer: Any) -> List[Tuple[float, float]]:
        return self._screen_geometry(layer).points

    @staticmethod
    def _geometry_color(geometry: _Geometry, layer: Any, index: int) -> ColorValue:
        if index < len(geometry.colors):
            return geometry.colors[index]
        return tuple(float(value) for value in layer.color)  # type: ignore[return-value]

    @staticmethod
    def _geometry_opacity(geometry: _Geometry, layer: Any, index: int) -> float:
        channel_opacity = geometry.opacities[index] if index < len(geometry.opacities) else 1.0
        return max(0.0, min(1.0, float(layer.opacity) * channel_opacity))

    @classmethod
    def _svg_style(cls, geometry: _Geometry, layer: Any, index: int) -> str:
        return _svg_color(cls._geometry_color(geometry, layer, index), cls._geometry_opacity(geometry, layer, index))

    @classmethod
    def _rgba_style(cls, geometry: _Geometry, layer: Any, index: int) -> RGBA:
        return _rgba(cls._geometry_color(geometry, layer, index), cls._geometry_opacity(geometry, layer, index))

    @classmethod
    def _geometry_size(cls, geometry: _Geometry, layer: Any, index: int) -> float:
        return geometry.sizes[index] if index < len(geometry.sizes) else float(layer.size)

    def to_svg(self) -> bytes:
        left, top, plot_width, plot_height, *_ = self._layout()
        parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{self.width}" height="{self.height}" viewBox="0 0 {self.width} {self.height}">', '<rect width="100%" height="100%" fill="white"/>', f'<g data-moxi="plot" data-version="{self.spec.version}">']
        parts.append(f'<line x1="{left:g}" y1="{top+plot_height:g}" x2="{left+plot_width:g}" y2="{top+plot_height:g}" stroke="#667085"/>')
        parts.append(f'<line x1="{left:g}" y1="{top:g}" x2="{left:g}" y2="{top+plot_height:g}" stroke="#667085"/>')
        for layer in self.spec.layers:
            geometry = self._screen_geometry(layer)
            points = geometry.points
            color = _svg_color(layer.color, layer.opacity)
            if geometry.kind == "line" and len(points) > 1:
                points_text = " ".join(f"{x:g},{y:g}" for x, y in points)
                parts.append(f'<polyline points="{points_text}" fill="none" stroke="{self._svg_style(geometry, layer, 0)}" stroke-width="{layer.line_width:g}" data-mark="{layer.mark}"/>')
            elif layer.mark == "area" and points:
                path = "M " + " L ".join(f"{x:g} {y:g}" for x, y in points) + f" L {points[-1][0]:g} {top+plot_height:g} L {points[0][0]:g} {top+plot_height:g} Z"
                parts.append(f'<path d="{path}" fill="{color}" stroke="none" data-mark="area"/>')
            elif geometry.kind == "errors":
                for index, (x, lower, upper) in enumerate(geometry.errors):
                    error_color = self._svg_style(geometry, layer, index)
                    parts.append(f'<line x1="{x:g}" y1="{lower:g}" x2="{x:g}" y2="{upper:g}" stroke="{error_color}" stroke-width="{layer.line_width:g}" data-mark="{layer.mark}"/>')
                    parts.append(f'<line x1="{x-4:g}" y1="{lower:g}" x2="{x+4:g}" y2="{lower:g}" stroke="{error_color}" stroke-width="{layer.line_width:g}"/>')
                    parts.append(f'<line x1="{x-4:g}" y1="{upper:g}" x2="{x+4:g}" y2="{upper:g}" stroke="{error_color}" stroke-width="{layer.line_width:g}"/>')
            elif geometry.kind == "box" and geometry.boxes:
                for x0, x1, q1, q3, low, high, median in geometry.boxes:
                    parts.append(f'<line x1="{(x0+x1)/2:g}" y1="{low:g}" x2="{(x0+x1)/2:g}" y2="{high:g}" stroke="#24324a" data-mark="box-whisker"/>')
                    parts.append(f'<rect x="{x0:g}" y="{min(q1, q3):g}" width="{max(1.0, x1-x0):g}" height="{abs(q3-q1):g}" fill="{color}" data-mark="box"/>')
                    parts.append(f'<line x1="{x0:g}" y1="{median:g}" x2="{x1:g}" y2="{median:g}" stroke="#24324a" data-mark="box-median"/>')
            elif geometry.polygons:
                for index, polygon in enumerate(geometry.polygons):
                    if len(polygon) < 3:
                        continue
                    polygon_text = " ".join(f"{x:g},{y:g}" for x, y in polygon)
                    parts.append(f'<polygon points="{polygon_text}" fill="{self._svg_style(geometry, layer, index)}" data-mark="{layer.mark}"/>')
            elif geometry.segments and geometry.rects:
                for index, (x0, y0, x1, y1) in enumerate(geometry.segments):
                    parts.append(f'<line x1="{x0:g}" y1="{y0:g}" x2="{x1:g}" y2="{y1:g}" stroke="{self._svg_style(geometry, layer, index)}" stroke-width="{layer.line_width:g}" data-mark="{layer.mark}"/>')
                for index, (x0, y0, x1, y1, _) in enumerate(geometry.rects):
                    parts.append(f'<rect x="{x0:g}" y="{y0:g}" width="{max(1.0, x1-x0):g}" height="{max(1.0, y1-y0):g}" fill="{self._svg_style(geometry, layer, index)}" data-mark="{layer.mark}"/>')
            elif geometry.segments:
                for index, (x0, y0, x1, y1) in enumerate(geometry.segments):
                    parts.append(f'<line x1="{x0:g}" y1="{y0:g}" x2="{x1:g}" y2="{y1:g}" stroke="{self._svg_style(geometry, layer, index)}" stroke-width="{layer.line_width:g}" data-mark="{layer.mark}"/>')
            elif geometry.rects and layer.mark in {"heatmap", "hexbin"}:
                for x0, y0, x1, y1, weight in geometry.rects:
                    parts.append(f'<rect x="{x0:g}" y="{y0:g}" width="{max(1.0, x1-x0):g}" height="{max(1.0, y1-y0):g}" fill="{color}" opacity="{max(0.05, min(1.0, weight)):g}" data-mark="{layer.mark}"/>')
            elif geometry.rects:
                for index, (x0, y0, x1, y1, _) in enumerate(geometry.rects):
                    parts.append(f'<rect x="{x0:g}" y="{y0:g}" width="{max(1.0, x1-x0):g}" height="{max(1.0, y1-y0):g}" fill="{self._svg_style(geometry, layer, index)}" data-mark="{layer.mark}"/>')
            elif layer.mark in {"bar", "column", "histogram"}:
                bar_width = max(2.0, plot_width / max(1, len(points)) * 0.7)
                baseline = top + plot_height
                for x, y in points:
                    parts.append(f'<rect x="{x-bar_width/2:g}" y="{min(y, baseline):g}" width="{bar_width:g}" height="{abs(baseline-y):g}" fill="{color}" data-mark="{layer.mark}"/>')
            elif layer.mark == "box":
                for x, y in points:
                    height = max(4.0, plot_height / 12.0)
                    parts.append(f'<rect x="{x-7:g}" y="{y-height/2:g}" width="14" height="{height:g}" fill="{color}" data-mark="box"/>')
                    parts.append(f'<line x1="{x-9:g}" y1="{y:g}" x2="{x+9:g}" y2="{y:g}" stroke="#24324a"/>')
            elif layer.mark == "heatmap":
                for index, (x, y) in enumerate(points):
                    cell = max(3.0, min(18.0, plot_width / max(1, len(points))))
                    parts.append(f'<rect x="{x-cell/2:g}" y="{y-cell/2:g}" width="{cell:g}" height="{cell:g}" fill="{color}" opacity="{max(0.2, min(1.0, (index+1)/max(1,len(points)))):g}" data-mark="heatmap"/>')
            else:
                for index, (x, y) in enumerate(points):
                    point_color = self._svg_style(geometry, layer, index)
                    radius = max(1.0, self._geometry_size(geometry, layer, index) / 2.0)
                    parts.append(f'<circle cx="{x:g}" cy="{y:g}" r="{radius:g}" fill="{point_color}" data-mark="{layer.mark}"/>')
        if self.spec.title:
            parts.append(f'<text x="{self.width/2:g}" y="18" text-anchor="middle" fill="#101828">{escape(self.spec.title)}</text>')
        parts.append("</g></svg>")
        return "".join(parts).encode("utf-8")

    def to_rgba(self) -> bytes:
        raster = _Raster(self.width, self.height)
        left, top, plot_width, plot_height, *_ = self._layout()
        axis = (102, 112, 133, 255)
        raster.line((left, top + plot_height), (left + plot_width, top + plot_height), 1.0, axis)
        raster.line((left, top), (left, top + plot_height), 1.0, axis)
        for layer in self.spec.layers:
            geometry = self._screen_geometry(layer)
            points = geometry.points
            color = _rgba(layer.color, layer.opacity)
            if geometry.kind == "line":
                line_color = self._rgba_style(geometry, layer, 0)
                for start, end in zip(points, points[1:]):
                    raster.line(start, end, layer.line_width, line_color)
            elif geometry.kind == "errors":
                for index, (x, lower, upper) in enumerate(geometry.errors):
                    error_color = self._rgba_style(geometry, layer, index)
                    raster.line((x, lower), (x, upper), layer.line_width, error_color)
                    raster.line((x - 4, lower), (x + 4, lower), layer.line_width, error_color)
                    raster.line((x - 4, upper), (x + 4, upper), layer.line_width, error_color)
            elif geometry.kind == "box" and geometry.boxes:
                for x0, x1, q1, q3, low, high, median in geometry.boxes:
                    center = (x0 + x1) / 2.0
                    raster.line((center, low), (center, high), 1.0, (36, 50, 74, 255))
                    raster.rect(x0, min(q1, q3), max(1.0, x1 - x0), abs(q3 - q1), color)
                    raster.line((x0, median), (x1, median), 1.0, (36, 50, 74, 255))
            elif geometry.polygons:
                for index, polygon in enumerate(geometry.polygons):
                    raster.polygon(polygon, self._rgba_style(geometry, layer, index))
            elif geometry.segments and geometry.rects:
                for index, (x0, y0, x1, y1) in enumerate(geometry.segments):
                    raster.line((x0, y0), (x1, y1), layer.line_width, self._rgba_style(geometry, layer, index))
                for index, (x0, y0, x1, y1, _) in enumerate(geometry.rects):
                    raster.rect(x0, y0, max(1.0, x1 - x0), max(1.0, y1 - y0), self._rgba_style(geometry, layer, index))
            elif geometry.segments:
                for index, (x0, y0, x1, y1) in enumerate(geometry.segments):
                    raster.line((x0, y0), (x1, y1), layer.line_width, self._rgba_style(geometry, layer, index))
            elif geometry.rects and layer.mark in {"heatmap", "hexbin"}:
                for x0, y0, x1, y1, weight in geometry.rects:
                    rgba = (color[0], color[1], color[2], max(8, int(color[3] * max(0.05, min(1.0, weight)))))
                    raster.rect(x0, y0, max(1.0, x1 - x0), max(1.0, y1 - y0), rgba)
            elif geometry.rects:
                for index, (x0, y0, x1, y1, _) in enumerate(geometry.rects):
                    raster.rect(x0, y0, max(1.0, x1 - x0), max(1.0, y1 - y0), self._rgba_style(geometry, layer, index))
            elif layer.mark in {"bar", "column", "histogram"}:
                baseline = top + plot_height
                width = max(2.0, plot_width / max(1, len(points)) * 0.7)
                for x, y in points:
                    raster.rect(x - width / 2, min(y, baseline), width, abs(baseline - y), color)
            elif layer.mark == "area" and points:
                baseline = top + plot_height
                for start, end in zip(points, points[1:]):
                    raster.line(start, end, layer.line_width, color)
                    raster.line((start[0], baseline), start, 1.0, color)
                    raster.line((end[0], baseline), end, 1.0, color)
            elif layer.mark == "box":
                for x, y in points:
                    raster.rect(x - 7, y - 5, 14, 10, color)
                    raster.line((x - 9, y), (x + 9, y), 1.0, (36, 50, 74, 255))
            elif layer.mark == "heatmap":
                for index, (x, y) in enumerate(points):
                    cell = max(3.0, min(18.0, plot_width / max(1, len(points))))
                    rgba = (color[0], color[1], color[2], max(50, int(color[3] * (index + 1) / max(1, len(points)))))
                    raster.rect(x - cell / 2, y - cell / 2, cell, cell, rgba)
            else:
                for index, (x, y) in enumerate(points):
                    raster.circle(x, y, max(1.0, self._geometry_size(geometry, layer, index) / 2.0), self._rgba_style(geometry, layer, index))
        return bytes(raster.pixels)

    def to_png(self) -> bytes:
        return _png(self.width, self.height, self.to_rgba())

    def to_pdf(self) -> bytes:
        # Compact vector PDF. SVG remains the canonical structural
        # representation, but the PDF contains the same core geometry rather
        # than being a blank transport envelope.
        left, top, plot_width, plot_height, *_ = self._layout()
        commands = [
            "q 1 1 1 rg 0 0 %g %g re f Q" % (self.width, self.height),
            "0.4 0.44 0.52 RG 1 w %g %g m %g %g l S" % (left, self.height - top - plot_height, left + plot_width, self.height - top - plot_height),
            "0.4 0.44 0.52 RG 1 w %g %g m %g %g l S" % (left, self.height - top, left, self.height - top - plot_height),
        ]
        for layer in self.spec.layers:
            geometry = self._screen_geometry(layer)
            points = geometry.points
            red, green, blue, alpha = layer.color
            color = f"{red:g} {green:g} {blue:g} rg"
            stroke = f"{red:g} {green:g} {blue:g} RG"
            if geometry.kind == "line" and len(points) > 1:
                path = f"{points[0][0]:g} {self.height-points[0][1]:g} m " + " ".join(f"{x:g} {self.height-y:g} l" for x, y in points[1:])
                line_color = self._geometry_color(geometry, layer, 0)
                line_stroke = f"{line_color[0]:g} {line_color[1]:g} {line_color[2]:g} RG"
                commands.append(f"{line_stroke} {layer.line_width:g} w {path} S")
            elif geometry.kind == "errors":
                for x, lower, upper in geometry.errors:
                    commands.append(f"{stroke} {layer.line_width:g} w {x:g} {self.height-lower:g} m {x:g} {self.height-upper:g} l S")
            elif geometry.kind == "box" and geometry.boxes:
                for x0, x1, q1, q3, low, high, median in geometry.boxes:
                    center = (x0 + x1) / 2.0
                    commands.append(f"{stroke} 1 w {center:g} {self.height-low:g} m {center:g} {self.height-high:g} l S")
                    commands.append(f"{color} {x0:g} {self.height-max(q1, q3):g} {max(1.0, x1-x0):g} {abs(q3-q1):g} re f")
                    commands.append(f"{stroke} 1 w {x0:g} {self.height-median:g} m {x1:g} {self.height-median:g} l S")
            elif geometry.polygons:
                for index, polygon in enumerate(geometry.polygons):
                    if len(polygon) < 3:
                        continue
                    polygon_color = self._geometry_color(geometry, layer, index)
                    fill = f"{polygon_color[0]:g} {polygon_color[1]:g} {polygon_color[2]:g} rg"
                    path = f"{polygon[0][0]:g} {self.height-polygon[0][1]:g} m " + " ".join(f"{x:g} {self.height-y:g} l" for x, y in polygon[1:]) + " h"
                    commands.append(f"{fill} {path} f")
            elif geometry.segments and geometry.rects:
                for index, (x0, y0, x1, y1) in enumerate(geometry.segments):
                    segment_color = self._geometry_color(geometry, layer, index)
                    stroke_color = f"{segment_color[0]:g} {segment_color[1]:g} {segment_color[2]:g} RG"
                    commands.append(f"{stroke_color} {layer.line_width:g} w {x0:g} {self.height-y0:g} m {x1:g} {self.height-y1:g} l S")
                for index, (x0, y0, x1, y1, _) in enumerate(geometry.rects):
                    rect_color = self._geometry_color(geometry, layer, index)
                    fill = f"{rect_color[0]:g} {rect_color[1]:g} {rect_color[2]:g} rg"
                    commands.append(f"{fill} {x0:g} {self.height-y1:g} {max(1.0, x1-x0):g} {max(1.0, y1-y0):g} re f")
            elif geometry.segments:
                for index, (x0, y0, x1, y1) in enumerate(geometry.segments):
                    segment_color = self._geometry_color(geometry, layer, index)
                    stroke_color = f"{segment_color[0]:g} {segment_color[1]:g} {segment_color[2]:g} RG"
                    commands.append(f"{stroke_color} {layer.line_width:g} w {x0:g} {self.height-y0:g} m {x1:g} {self.height-y1:g} l S")
            elif geometry.rects:
                for index, (x0, y0, x1, y1, _) in enumerate(geometry.rects):
                    rect_color = self._geometry_color(geometry, layer, index)
                    fill = f"{rect_color[0]:g} {rect_color[1]:g} {rect_color[2]:g} rg"
                    commands.append(f"{fill} {x0:g} {self.height-y1:g} {max(1.0, x1-x0):g} {max(1.0, y1-y0):g} re f")
            elif layer.mark in {"bar", "column", "histogram"}:
                baseline = top + plot_height
                bar_width = max(2.0, plot_width / max(1, len(points)) * 0.7)
                for x, y in points:
                    commands.append(f"{color} {x-bar_width/2:g} {self.height-max(y, baseline):g} {bar_width:g} {abs(baseline-y):g} re f")
            else:
                for index, (x, y) in enumerate(points):
                    radius = max(1.0, self._geometry_size(geometry, layer, index) / 2.0)
                    point_color = self._geometry_color(geometry, layer, index)
                    fill = f"{point_color[0]:g} {point_color[1]:g} {point_color[2]:g} rg"
                    commands.append(f"{fill} {x-radius:g} {self.height-y-radius:g} {radius*2:g} {radius*2:g} re f")
        content = "\n".join(commands) + "\n"
        objects = [b"<< /Type /Catalog /Pages 2 0 R >>", b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>", f"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 {self.width} {self.height}] /Contents 4 0 R >>".encode(), f"<< /Length {len(content.encode())} >>\nstream\n{content}endstream".encode()]
        output = bytearray(b"%PDF-1.4\n")
        offsets = [0]
        for index, obj in enumerate(objects, start=1):
            offsets.append(len(output))
            output.extend(f"{index} 0 obj\n".encode() + obj + b"\nendobj\n")
        startxref = len(output)
        output.extend(f"xref\n0 {len(objects)+1}\n0000000000 65535 f \n".encode())
        output.extend(b"".join(f"{offset:010d} 00000 n \n".encode() for offset in offsets[1:]))
        output.extend(f"trailer\n<< /Size {len(objects)+1} /Root 1 0 R >>\nstartxref\n{startxref}\n%%EOF\n".encode())
        return bytes(output)

    def to_numpy(self) -> Any:
        try:
            import numpy as np
        except ImportError as exc:  # pragma: no cover - depends on environment
            raise ImportError("install moxi[numpy] to use Figure.to_numpy()") from exc
        return np.frombuffer(self.to_rgba(), dtype=np.uint8).reshape((self.height, self.width, 4)).copy()

    def save(self, path: Union[str, Path], format: Optional[str] = None) -> Path:
        target = Path(path)
        kind = (format or target.suffix.lstrip(".") or "png").lower()
        payload = {"svg": self.to_svg, "png": self.to_png, "pdf": self.to_pdf, "rgba": self.to_rgba}.get(kind)
        if payload is None:
            raise ValueError(f"unsupported export format: {kind}")
        target.write_bytes(payload())
        return target


def plot(data: Any, spec: Union[PlotSpec, Mapping[str, Any], str], *, width: int = 640, height: int = 480, backend: str = "python-reference") -> Figure:
    return Figure(data, spec, width=width, height=height, backend=backend)


def render(spec_json: Union[str, PlotSpec, Mapping[str, Any]], named_columns: Any, width: int, height: int, format: str = "rgba") -> bytes:
    figure = Figure(named_columns, spec_json, width=width, height=height)
    kind = format.lower()
    if kind == "svg":
        return figure.to_svg()
    if kind == "png":
        return figure.to_png()
    if kind == "pdf":
        return figure.to_pdf()
    if kind in {"rgba", "raw_rgba", "numpy"}:
        return figure.to_rgba()
    raise ValueError(f"unsupported render format: {format}")
