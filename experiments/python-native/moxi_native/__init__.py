"""E04 experimental, copied stateless boundary. Separate from the stable facade."""
from __future__ import annotations

import json
import math
import re
from dataclasses import dataclass
from enum import Enum, IntEnum
from typing import Mapping

import numpy as np
from moxi import PlotSpec
from moxi.spec import Layer
from . import _core, formats
from ._build import BUILD

__version__ = "0.1.0"
MAX_ROWS = 4096
MAX_COLUMNS = 8
MAX_SPEC_BYTES = 16384
MAX_VALUE = 1_000_000
NAME = re.compile(r"[A-Za-z_][A-Za-z_0-9]{0,63}\Z")


class ColumnKind(str, Enum):
    NUMERIC = "numeric"
    CATEGORY = "category"
    STRING = "string"
    TIMESTAMP = "timestamp"


class RenderFormat(str, Enum):
    RGBA = "rgba"
    PNG = "png"
    SVG = "svg"
    PDF = "pdf"


class NativeOutput(IntEnum):
    RGBA = 0
    SVG = 1


class NativeStatus(IntEnum):
    OK = 0
    INVALID_SPEC = 1
    INVALID_COLUMNS = 2
    OUTPUT_LIMIT = 3
    RENDER_FAILED = 4


class Mark(str, Enum):
    LINE = "line"
    SCATTER = "scatter"


class CopyPolicy(str, Enum):
    COPY_PER_CALL = "copy-per-call"


class InputError(ValueError):
    """Malformed spec, dimensions, buffer or metadata."""


class UnsupportedError(InputError):
    """Valid concept outside the declared experimental slice."""


class NativeRenderError(RuntimeError):
    def __init__(self, status: NativeStatus):
        self.status = status
        super().__init__(f"Mojo render failed: {status.name}")


@dataclass(frozen=True)
class Column:
    values: np.ndarray
    validity: np.ndarray | None = None
    kind: ColumnKind = ColumnKind.NUMERIC
    categories: tuple[str, ...] | None = None

    def __post_init__(self):
        try:
            object.__setattr__(self, "kind", ColumnKind(self.kind))
        except (TypeError, ValueError) as exc:
            raise UnsupportedError("unsupported column kind") from exc


def capabilities() -> dict:
    return dict(version=__version__, abi_version=_core.abi_version(), build=dict(BUILD),
                backend="mojo-software-scene", experimental=True, abi3=False,
                formats=[f.value for f in RenderFormat], marks=[m.value for m in Mark],
                copy_policy=CopyPolicy.COPY_PER_CALL.value, retained_mojo_objects=False,
                numeric_dtypes=["float32", "float64", "int32", "int64"],
                nullable="bool validity mask; invalid rows omitted by the plot model",
                category=False, string=False, timestamp=False,
                runtime_compiler=False, bundled_mojo_runtime=True,
                coordinate_precision="float32 scene coordinates", max_rows=MAX_ROWS,
                max_columns=MAX_COLUMNS, max_side=1024, max_abs_value=MAX_VALUE,
                raster_text=False, pdf="raster RGB image of native RGBA on white",
                deployment="local experimental host wheel; production gate open")


def _columns(named_columns: Mapping[str, Column]) -> tuple:
    if not isinstance(named_columns, Mapping) or not 1 <= len(named_columns) <= MAX_COLUMNS:
        raise InputError("named_columns must contain 1..8 named Column values")
    packed = []
    rows = None
    for name, column in named_columns.items():
        if not isinstance(name, str) or not NAME.fullmatch(name):
            raise InputError("column names must be ASCII identifiers of length 1..64")
        if not isinstance(column, Column):
            raise InputError("each named column must be a Column")
        if column.kind is not ColumnKind.NUMERIC or column.categories is not None:
            raise UnsupportedError("category, string and timestamp metadata are not supported")
        values = column.values
        if not isinstance(values, np.ndarray) or isinstance(values, np.ma.MaskedArray):
            raise InputError("values must be a NumPy ndarray; use explicit validity for nulls")
        if values.ndim != 1 or not values.flags.c_contiguous or not values.dtype.isnative:
            raise InputError("values must be one-dimensional, native-endian and C-contiguous")
        if values.dtype not in (np.dtype('float32'), np.dtype('float64'), np.dtype('int32'), np.dtype('int64')):
            raise UnsupportedError("supported dtypes: float32, float64, int32, int64")
        if not 1 <= values.size <= MAX_ROWS or (rows is not None and values.size != rows):
            raise InputError("columns must have equal lengths in 1..4096")
        rows = values.size
        mask = column.validity
        if mask is None:
            mask = np.ones(rows, dtype=np.bool_)
        elif (not isinstance(mask, np.ndarray) or isinstance(mask, np.ma.MaskedArray) or
              mask.dtype != np.dtype('bool') or mask.ndim != 1 or
              not mask.flags.c_contiguous or mask.size != rows):
            raise InputError("validity must be a contiguous bool array matching the column")
        # Unconditionally own snapshots before native dispatch. Never zero-copy.
        mask = mask.copy()
        numbers = values.astype(np.float64, copy=True)
        numbers[~mask] = 0.0
        if not np.isfinite(numbers).all() or np.any(np.abs(numbers) > MAX_VALUE):
            raise InputError("valid numeric values must be finite and within +/-1000000")
        packed.append((name.encode('ascii'), numbers.tobytes(), mask.tobytes()))
    return tuple(packed)


def _spec(spec_json: str, fields: set[str]) -> bytes:
    if not isinstance(spec_json, str):
        raise InputError("spec_json must be a PlotSpec JSON string")
    if len(spec_json) > MAX_SPEC_BYTES:
        raise InputError("spec_json exceeds 16384 bytes")
    try:
        if len(spec_json.encode('utf-8')) > MAX_SPEC_BYTES:
            raise InputError("spec_json exceeds 16384 bytes")
        # No duplicate keys or NaN/Infinity: the native parser must see one meaning.
        def pairs(items):
            value = {}
            for key, item in items:
                if key in value:
                    raise InputError("duplicate JSON key")
                value[key] = item
            return value
        def nonfinite(value):
            raise InputError("nonfinite JSON number")
        raw = json.loads(spec_json, object_pairs_hook=pairs, parse_constant=nonfinite)
        if not isinstance(raw, dict) or type(raw.get('version')) is not int or raw['version'] != 1:
            raise InputError("PlotSpec version must be integer 1")
        if 'title' in raw and not isinstance(raw['title'], str):
            raise InputError("title must be a string")
        spec = PlotSpec.from_dict(raw)
        if not spec.validate() or not 1 <= len(spec.layers) <= 4:
            raise InputError("invalid PlotSpec or layer count (1..4)")
        canonical = spec.as_dict()
        if set(raw) - set(canonical):
            raise UnsupportedError("unknown PlotSpec members")
        if (spec.composition != 'layer' or any(spec.facet.values()) or spec.transforms or
                spec.scales or spec.annotations or spec.interactions or
                spec.shared_scales != PlotSpec().shared_scales):
            raise UnsupportedError("only untransformed layered line/scatter specs are supported")
        # The scalar-only bridge deliberately does not promise rich text parsing.
        if not spec.title.isascii() or any(ord(c) < 32 for c in spec.title):
            raise UnsupportedError("title must be printable ASCII")
        for layer in spec.layers:
            Mark(layer.mark)
            if layer.x not in fields or layer.y not in fields:
                raise InputError("layer references a missing named column")
            default = Layer(id=layer.id, mark=layer.mark, label="", x="x", y="y")
            allowed = {'id', 'mark', 'label', 'x', 'y', 'color', 'line_width', 'size', 'opacity'}
            for key, value in layer.as_dict().items():
                if key not in allowed and value != default.as_dict()[key]:
                    raise UnsupportedError(f"unsupported layer field: {key}")
            if type(layer.id) is not int or not 0 < layer.id < 10000:
                raise InputError("layer id must be an integer in 1..9999")
            if not isinstance(layer.label, str) or not layer.label.isascii() or any(ord(c) < 32 for c in layer.label):
                raise UnsupportedError("label must be printable ASCII")
            scalars = [*layer.color, layer.opacity, layer.size, layer.line_width]
            if any(type(v) not in (int, float) or not math.isfinite(v) for v in scalars):
                raise InputError("style values must be finite numbers")
            if any(not 0 <= v <= 1 for v in layer.color) or not (0 < layer.size <= 64 and 0 < layer.line_width <= 64):
                raise InputError("colors must be in 0..1; sizes in (0,64]")
        # add_line/add_scatter emit redundant x/y encodings; accept only those.
        by_id = {layer.id: layer for layer in spec.layers}
        for encoding in spec.encodings:
            layer = by_id[encoding.layer]
            if (encoding.channel not in ('x', 'y') or
                    encoding.field != getattr(layer, encoding.channel) or
                    encoding.has_literal or encoding.type != 'quantitative'):
                raise UnsupportedError("only matching quantitative x/y encodings are supported")
        encoded = spec.to_json().encode('utf-8')
        if len(encoded) > MAX_SPEC_BYTES:
            raise InputError("normalized spec exceeds 16384 bytes")
        return encoded
    except (InputError, UnsupportedError):
        raise
    except (ValueError, TypeError, KeyError, AttributeError, OverflowError, RecursionError) as exc:
        raise InputError("malformed or unsupported PlotSpec") from exc


def render(spec_json: str, named_columns: Mapping[str, Column], width: int, height: int,
           format: RenderFormat | str = RenderFormat.RGBA) -> bytes:
    """Copy validated inputs; return owned bytes. No retained native state."""
    if type(width) is not int or type(height) is not int or not (64 <= width <= 1024 and 64 <= height <= 1024):
        raise InputError("width and height must be integers in 64..1024")
    try:
        kind = RenderFormat(format)
    except (TypeError, ValueError) as exc:
        raise UnsupportedError("unsupported output format") from exc
    columns = _columns(named_columns)
    encoded = _spec(spec_json, set(named_columns))
    native_kind = NativeOutput.SVG if kind is RenderFormat.SVG else NativeOutput.RGBA
    status, data = _core.render(encoded, columns, width, height, native_kind)
    status = NativeStatus(status)
    if status is not NativeStatus.OK:
        raise NativeRenderError(status)
    if kind is RenderFormat.PNG:
        return formats.png(data, width, height)
    if kind is RenderFormat.PDF:
        return formats.pdf(data, width, height)
    return data
