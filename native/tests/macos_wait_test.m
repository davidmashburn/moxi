#import "../macos_window.m"
#include <assert.h>
#include <stdio.h>

static void check_callback_wait(int scenario,
    MoxiAccessibilityElement *button, MoxiAccessibilityElement *editor) {
    for (int i = 0; i < 3; ++i) {
        moxi_window_pump();
        while (moxi_window_poll_event() != MOXI_EVENT_NONE) {}
    }
    __block BOOL delivered = NO;
    __block BOOL fallbackFired = NO;
    NSTimer *callback = [NSTimer scheduledTimerWithTimeInterval:0.020
        repeats:NO block:^(NSTimer *timer) {
            (void)timer;
            delivered = YES;
            if (scenario == 0) {
                assert([button accessibilityPerformPress]);
            } else if (scenario == 1) {
                // Exercise the legacy AX setter still implemented by the host.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                [editor accessibilitySetValue:@"かな🙂"
                    forAttribute:NSAccessibilityValueAttribute];
#pragma clang diagnostic pop
            } else {
                moxi_window_close();
            }
        }];
    // Bound the regression even when a callback does not wake AppKit's wait.
    NSTimer *fallback = [NSTimer scheduledTimerWithTimeInterval:0.500
        repeats:NO block:^(NSTimer *timer) {
            (void)timer;
            fallbackFired = YES;
            NSEvent *event = [NSEvent otherEventWithType:
                NSEventTypeApplicationDefined location:NSZeroPoint
                modifierFlags:0 timestamp:0 windowNumber:0 context:nil
                subtype:0 data1:0 data2:0];
            [NSApp postEvent:event atStart:NO];
        }];
    int waits = 0;
    do {
        moxi_window_wait(scenario == 1 ? 10.0 : -1.0);
        ++waits;
    } while (!delivered && !fallbackFired && waits < 64);
    [callback invalidate];
    [fallback invalidate];
    assert(delivered && !fallbackFired);
    if (scenario == 0) {
        assert(moxi_window_poll_event() == MOXI_EVENT_ACTION);
        assert(moxi_window_event_target() == 41);
        assert(moxi_window_event_action() == MOXI_ACTION_PRESS);
    } else if (scenario == 1) {
        assert(moxi_window_poll_event() == MOXI_EVENT_TEXT_INPUT);
        assert(moxi_window_event_target() == 43);
        assert(moxi_window_event_selection_start() == 0);
        assert(moxi_window_event_selection_end() == 3);
        assert(moxi_window_event_codepoint_at(0) == 0x304b);
        assert(moxi_window_event_codepoint_at(1) == 0x306a);
        assert(moxi_window_event_codepoint_at(2) == 0x1f642);
        assert(moxi_window_event_codepoint_at(3) == -1);
    } else {
        assert(!moxi_window_is_open());
    }
}

int main(void) {
    @autoreleasepool {
        moxi_window_open("Moxi accessibility idle regression", 160, 100,
            0, 0, 0, 0, 0, 0);
        moxi_window_begin_accessibility();
        moxi_window_set_accessibility_at(0, 41, -1, MOXI_ROLE_BUTTON,
            "Probe button", "", "", 0, 0, 160, 40,
            1, 0, 0, 0, 0, 0, 0, 0, 0, MOXI_ACTION_PRESS);
        moxi_window_set_accessibility_at(1, 43, -1, MOXI_ROLE_TEXT_INPUT,
            "Probe editor", "A🙂日", "", 0, 40, 160, 40,
            1, 0, 0, 0, 0, 0, 3, 0, 0, 0);
        moxi_window_end_accessibility();
        MoxiAccessibilityElement *button =
            (MoxiAccessibilityElement *)moxi_accessibility_elements[0];
        MoxiAccessibilityElement *editor =
            (MoxiAccessibilityElement *)moxi_accessibility_elements[1];
        assert(button != nil && editor != nil);
        check_callback_wait(0, button, editor);
        check_callback_wait(1, button, editor);
        check_callback_wait(2, button, editor);
        puts("AppKit idle waits wake for AX actions, Unicode edits and close: pass");
    }
    return 0;
}
