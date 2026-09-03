"""Acceptance test for the capability-bus live demo walkthrough."""

from moxi import (
    App,
    DEMO_INTERACTION_ID,
    DEMO_TAB_DEMO,
    DemoBrowserState,
    DemoWalkthroughDriver,
    Rect,
    test_check,
)


def main():
    var app = App[DemoBrowserState](
        DemoBrowserState(),
        Rect(0.0, 0.0, 1180.0, 760.0),
    )
    var driver = DemoWalkthroughDriver()
    driver.start()
    test_check(driver.action_count() == 19)
    test_check(driver.bus.descriptor_count() == 10)

    var ticks = 0
    while driver.is_running() and ticks < 400:
        _ = driver.tick(app, 0.1)
        ticks += 1

    test_check(driver.is_finished())
    test_check(not driver.failed)
    test_check(ticks < 320)
    test_check(driver.counter_peak == 3)
    test_check(driver.max_scroll_offset > 0.0)
    test_check(driver.observed_selection)
    test_check(driver.observed_reorder)
    test_check(driver.observed_plot)
    test_check(driver.observed_metal)
    test_check(app.component.selected_id == DEMO_INTERACTION_ID)
    test_check(app.component.tab == DEMO_TAB_DEMO)
    test_check(app.component.interaction.component.scrollbar.offset == 0.0)
    test_check(driver.bus.total_invocations == 20)
    test_check(driver.bus.approved_invocations == 19)
    test_check(driver.bus.rejected_invocations == 1)
    test_check("approved and executed" in app.component.status)
    print("Moxi demo-walkthrough test passed")
