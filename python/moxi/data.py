"""Small columnar adapter used by the Python reference renderer."""

from __future__ import annotations

from collections.abc import Mapping, Sequence
from typing import Any, Dict, List


class DataTable:
    def __init__(self, data: Any) -> None:
        if hasattr(data, "to_dict") and data.__class__.__module__.startswith("pandas"):
            data = data.to_dict(orient="list")
        elif hasattr(data, "columns") and hasattr(data, "__getitem__"):
            data = {str(column): list(data[column]) for column in data.columns}
        elif hasattr(data, "shape") and hasattr(data, "tolist"):
            shape = tuple(data.shape)
            if len(shape) != 2:
                raise ValueError("NumPy input must be a two-dimensional array")
            rows = data.tolist()
            data = {str(index): [row[index] for row in rows] for index in range(shape[1])}
        if isinstance(data, Mapping):
            self.columns: Dict[str, List[Any]] = {str(key): list(value) for key, value in data.items()}
        elif isinstance(data, Sequence) and not isinstance(data, (str, bytes, bytearray)):
            rows = list(data)
            if not rows:
                self.columns = {}
            elif isinstance(rows[0], Mapping):
                names = list(rows[0].keys())
                self.columns = {str(name): [row.get(name) for row in rows] for name in names}
            else:
                self.columns = {str(index): list(column) for index, column in enumerate(zip(*rows))}
        else:
            raise TypeError("data must be a mapping, a sequence of rows, NumPy array, or pandas DataFrame")
        lengths = {len(values) for values in self.columns.values()}
        if len(lengths) > 1:
            raise ValueError("all columns must have equal length")

    @property
    def row_count(self) -> int:
        return len(next(iter(self.columns.values()))) if self.columns else 0

    def column(self, name: str) -> List[Any]:
        if name not in self.columns:
            raise KeyError(f"unknown data field: {name}")
        return self.columns[name]

    def numeric(self, name: str) -> List[float]:
        return [float(value) for value in self.column(name)]
