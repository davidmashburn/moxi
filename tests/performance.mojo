"""Deterministic performance accounting contract test."""

from moxi import (
    FRAME_BUDGET_60_HZ_MS,
    PerformanceCounters,
    PerformanceReport,
    test_check,
)


def main():
    var counters = PerformanceCounters()
    counters.record_frame(10, 20, 3, 4, 100)
    counters.record_frame(2, 4, 1, 2, 50)
    test_check(counters.frames == 2)
    test_check(counters.total_operations() == 46)
    test_check(counters.average_operations() == 23.0)
    var report = PerformanceReport(counters, 20.0)
    test_check(report.average_frame_ms() == 10.0)
    test_check(report.frames_per_second() == 100.0)
    test_check(report.target_budget_ms(60) == FRAME_BUDGET_60_HZ_MS)
    test_check(report.meets_frame_budget(60))
    var slow = PerformanceReport(counters, 40.0)
    test_check(not slow.meets_frame_budget(60))
    print("Moxi performance test passed")
