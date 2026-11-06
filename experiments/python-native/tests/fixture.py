"""One canonical fixture shared by tests, timing and the evidence sequence."""
import numpy as np
from moxi import PlotSpec
from moxi_native import Column

WIDTH, HEIGHT = 320, 240


def canonical():
    spec = PlotSpec('E04 native boundary')
    spec.add_line('signal', 'sample', 'value', (0.15, 0.45, 0.85, 1.0))
    spec.add_scatter('observations', 'sample', 'value', (0.85, 0.25, 0.15, 1.0))
    columns = {'sample': Column(np.array([0, 1, 2, 3, 4, 5], dtype=np.float64)),
               'value': Column(np.array([1, 3, 2, 5, 4, 6], dtype=np.float64))}
    return spec, columns
