"""Focused import-path and API-lane contract test."""

from moxi import (
    BACKEND_HEADLESS,
    Rect,
    test_check,
)
from moxi.experimental_api import CapabilityDescriptor, CapabilityInvocation
from moxi.host_api import HostContract, host_contract
from moxi_plot.plot_api import Plot, PlotDataTable, PlotSpec


def main():
    var plot = Plot(Rect(0.0, 0.0, 100.0, 80.0))
    var table = PlotDataTable()
    var spec = PlotSpec()
    test_check(plot.series_count() == 0)
    test_check(table.row_count() == 0)
    test_check(spec.valid)
    var contract = host_contract(BACKEND_HEADLESS)
    test_check(contract.target == BACKEND_HEADLESS)
    var descriptor = CapabilityDescriptor("api.test", "focused import")
    var invocation = CapabilityInvocation("api-1", "api.test", 1)
    test_check(descriptor.name == "api.test")
    test_check(invocation.capability_name == "api.test")
    _ = Rect(0.0, 0.0, 1.0, 1.0)
    print("Moxi focused API-lane test passed")
