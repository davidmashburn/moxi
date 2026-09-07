"""Python Figure API and deterministic value-boundary renderer."""

from __future__ import annotations

import math
import struct
import zlib
from dataclasses import dataclass
from html import escape
from pathlib import Path
from typing import Any, Dict, Iterable, List, Mapping, Optional, Sequence, Tuple, Union

from .data import DataTable
from .spec import PlotSpec

RGBA = Tuple[int, int, int, int]


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

    def _layout(self) -> Tuple[float, float, float, float, float, float, float, float]:
        return 54.0, 18.0, max(1.0, self.width - 72.0), max(1.0, self.height - 48.0), 0.0, 1.0, 0.0, 1.0

    def _points(self, layer: Any) -> List[Tuple[float, float]]:
        x_values = _numeric_or_categories(self.data.column(layer.x))
        y_values = _numeric_or_categories(self.data.column(layer.y))
        x_low, x_high = _domain(x_values)
        y_low, y_high = _domain(y_values)
        left, top, plot_width, plot_height, *_ = self._layout()
        return [(left + _scale(x, x_low, x_high, plot_width), top + _scale(y, y_low, y_high, plot_height, True)) for x, y in zip(x_values, y_values)]

    def to_svg(self) -> bytes:
        left, top, plot_width, plot_height, *_ = self._layout()
        parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{self.width}" height="{self.height}" viewBox="0 0 {self.width} {self.height}">', '<rect width="100%" height="100%" fill="white"/>', f'<g data-moxi="plot" data-version="{self.spec.version}">']
        parts.append(f'<line x1="{left:g}" y1="{top+plot_height:g}" x2="{left+plot_width:g}" y2="{top+plot_height:g}" stroke="#667085"/>')
        parts.append(f'<line x1="{left:g}" y1="{top:g}" x2="{left:g}" y2="{top+plot_height:g}" stroke="#667085"/>')
        for layer in self.spec.layers:
            points = self._points(layer)
            color = _svg_color(layer.color, layer.opacity)
            if layer.mark in {"line", "step", "density", "ecdf", "regression"} and len(points) > 1:
                points_text = " ".join(f"{x:g},{y:g}" for x, y in points)
                parts.append(f'<polyline points="{points_text}" fill="none" stroke="{color}" stroke-width="{layer.line_width:g}" data-mark="{layer.mark}"/>')
            elif layer.mark == "area" and points:
                path = "M " + " L ".join(f"{x:g} {y:g}" for x, y in points) + f" L {points[-1][0]:g} {top+plot_height:g} L {points[0][0]:g} {top+plot_height:g} Z"
                parts.append(f'<path d="{path}" fill="{color}" stroke="none" data-mark="area"/>')
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
                for x, y in points:
                    parts.append(f'<circle cx="{x:g}" cy="{y:g}" r="{max(1.0, layer.size/2):g}" fill="{color}" data-mark="{layer.mark}"/>')
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
            points = self._points(layer)
            color = _rgba(layer.color, layer.opacity)
            if layer.mark in {"line", "step", "density", "ecdf", "regression"}:
                for start, end in zip(points, points[1:]):
                    raster.line(start, end, layer.line_width, color)
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
                for x, y in points:
                    raster.circle(x, y, max(1.0, layer.size / 2), color)
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
            points = self._points(layer)
            red, green, blue, alpha = layer.color
            color = f"{red:g} {green:g} {blue:g} rg"
            stroke = f"{red:g} {green:g} {blue:g} RG"
            if layer.mark in {"line", "step", "density", "ecdf", "regression"} and len(points) > 1:
                path = f"{points[0][0]:g} {self.height-points[0][1]:g} m " + " ".join(f"{x:g} {self.height-y:g} l" for x, y in points[1:])
                commands.append(f"{stroke} {layer.line_width:g} w {path} S")
            elif layer.mark in {"bar", "column", "histogram"}:
                baseline = top + plot_height
                bar_width = max(2.0, plot_width / max(1, len(points)) * 0.7)
                for x, y in points:
                    commands.append(f"{color} {x-bar_width/2:g} {self.height-max(y, baseline):g} {bar_width:g} {abs(baseline-y):g} re f")
            else:
                for x, y in points:
                    radius = max(1.0, layer.size / 2.0)
                    commands.append(f"{color} {x-radius:g} {self.height-y-radius:g} {radius*2:g} {radius*2:g} re f")
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
