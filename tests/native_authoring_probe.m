#include "../native/macos_window.m"
#include <assert.h>
#include <stdlib.h>

static MoxiAccessibilityElement *probe_button;
static MoxiAccessibilityElement *probe_editor;

void moxi_probe_capture_ax(int button, int editor) {
    // Publish actual native snapshot entries, then retain the callback objects.
    moxi_window_begin_accessibility();
    moxi_window_set_accessibility_at(0, button, -1, MOXI_ROLE_BUTTON,
        "Button", "", "", 0, 0, 100, 30,
        1, 0, 0, 0, 0, 0, 0, 0, 0, MOXI_ACTION_PRESS);
    moxi_window_set_accessibility_at(1, editor, -1, MOXI_ROLE_TEXT_INPUT,
        "Editor", "fresh", "", 0, 30, 100, 30,
        1, 1, 0, 0, 0, 0, 0, 0, 0, 0);
    probe_button = [[MoxiAccessibilityElement alloc] init];
    probe_button.moxiIdentifier = button;
    probe_button.accessibilityEnabled = YES;
    probe_editor = [[MoxiAccessibilityElement alloc] init];
    probe_editor.moxiIdentifier = editor;
    probe_editor.accessibilityEnabled = YES;
}

void moxi_probe_late_ax_callbacks(void) {
    (void)[probe_button accessibilityPerformPress];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [probe_editor accessibilitySetValue:@"late AX" forAttribute:NSAccessibilityValueAttribute];
#pragma clang diagnostic pop
}

void moxi_probe_init(void) {
    moxi_reset_event_queue();
    moxi_canvas = [[MoxiCanvasView alloc] initWithFrame:NSMakeRect(0, 0, 600, 900)];
}
void moxi_probe_enqueue(int kind, int key, int target, float x, float y) {
    if (kind == MOXI_EVENT_ACTION) {
        moxi_queue_semantic_action(target, MOXI_ACTION_PRESS);
    } else if (kind == MOXI_EVENT_TEXT_INPUT || kind == MOXI_EVENT_COMPOSITION_UPDATE) {
        if (target >= 0) moxi_queue_text_event_for_target(target, kind, @"queued", 0, 1000000);
        else moxi_queue_text_event(kind, @"queued", 0, 1000000);
    } else if (kind == MOXI_EVENT_KEY_DOWN) {
        moxi_queue_key_event(key);
    } else {
        moxi_enqueue_event(kind, key, 0, -1, nil, -1, -1, x, y, 0, 0);
    }
}
void moxi_probe_seed_gesture(void) {
    moxi_marked_text = @"old IME";
    moxi_mouse_is_down = YES;
    moxi_mouse_dragging = YES;
}
int moxi_probe_gesture_clear(void) {
    return moxi_marked_text == nil && !moxi_mouse_is_down && !moxi_mouse_dragging;
}

int moxi_probe_published(int target) {
    for (int i = 0; i < moxi_accessibility_count; ++i) {
        if (moxi_accessibility_ids[i] == target) return 1;
    }
    return 0;
}

void moxi_probe_queue_wrap(void) {
    moxi_reset_event_queue();
    // Exercise in-place compaction across the circular queue boundary.
    moxi_event_queue_head = MOXI_EVENT_QUEUE_CAPACITY - 2;
    moxi_event_queue_tail = moxi_event_queue_head;
    moxi_enqueue_event(MOXI_EVENT_TEXT_INPUT, 0, 0, -1, @"old", -1, -1, 0, 0, 0, 0);
    moxi_enqueue_event(MOXI_EVENT_WINDOW_RESIZED, 0, 0, -1, nil, -1, -1, 101, 0, 0, 0);
    moxi_enqueue_event(MOXI_EVENT_TEXT_INPUT, 0, 0, -1, @"old", -1, -1, 0, 0, 0, 0);
    moxi_enqueue_event(MOXI_EVENT_WINDOW_RESIZED, 0, 0, -1, nil, -1, -1, 202, 0, 0, 0);
    moxi_window_opened = NO;
    moxi_window_reset_input();
    assert(!moxi_window_opened && moxi_event_queue_count == 2);
    assert(moxi_window_poll_event() == MOXI_EVENT_WINDOW_RESIZED && moxi_event_x == 101);
    assert(moxi_window_poll_event() == MOXI_EVENT_WINDOW_RESIZED && moxi_event_x == 202);
    assert(moxi_event_queue_count == 0);
}

int moxi_probe_open_requested(void) {
    return getenv("MOXI_AUTHORING_OPEN_WINDOW") != NULL;
}

// Invoke the same modern/legacy focus setters used by accessibility clients.
void moxi_probe_ax_focus(int target, int focused, int legacy) {
    MoxiAccessibilityElement *element = [[MoxiAccessibilityElement alloc] init];
    element.moxiIdentifier = target;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if (legacy) {
        [element accessibilitySetValue:@(focused != 0) forAttribute:NSAccessibilityFocusedAttribute];
    } else {
        [element setAccessibilityFocused:focused != 0];
    }
#pragma clang diagnostic pop
}

void moxi_probe_ax_focus_contract(void) {
    moxi_reset_event_queue();
    moxi_probe_capture_ax(101, 102);
    moxi_accessibility_focused[1] = NO;
    moxi_accessibility_build_elements();
    assert(moxi_event_queue_count == 0); // Publication is not input.
    assert(![probe_editor accessibilityPerformPress]);
    assert(moxi_event_queue_count == 0); // Fields are not pressable buttons.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    assert([probe_editor accessibilityIsAttributeSettable:NSAccessibilityFocusedAttribute]);
    assert(![probe_button accessibilityIsAttributeSettable:NSAccessibilityFocusedAttribute]);
    assert(![probe_editor accessibilityIsAttributeSettable:NSAccessibilityTitleAttribute]);
    [probe_editor accessibilitySetValue:@"ignored" forAttribute:NSAccessibilityTitleAttribute];
    [probe_editor setAccessibilityFocused:YES];
    assert(![probe_editor isAccessibilityFocused]); // Model hasn't accepted it yet.
    assert(moxi_window_poll_event() == MOXI_EVENT_FOCUS);
    assert(moxi_event_target == 102 && moxi_event_key == 1);
    [probe_editor accessibilitySetValue:@NO forAttribute:NSAccessibilityFocusedAttribute];
    assert(moxi_window_poll_event() == MOXI_EVENT_FOCUS);
    assert(moxi_event_target == 102 && moxi_event_key == 0);
    moxi_accessibility_focused[1] = YES;
    moxi_accessibility_build_elements();
    assert([probe_editor isAccessibilityFocused] && moxi_event_queue_count == 0);
    moxi_accessibility_enabled[1] = NO;
    assert(![probe_editor accessibilityIsAttributeSettable:NSAccessibilityFocusedAttribute]);
    [probe_editor setAccessibilityFocused:YES];
    [probe_editor accessibilitySetValue:@YES forAttribute:NSAccessibilityFocusedAttribute];
    [probe_editor accessibilitySetValue:@"ignored" forAttribute:NSAccessibilityValueAttribute];
    assert(moxi_event_queue_count == 0);
    moxi_window_begin_accessibility(); // Retire both captured objects.
    [probe_editor setAccessibilityFocused:YES];
    [probe_editor accessibilitySetValue:@YES forAttribute:NSAccessibilityFocusedAttribute];
    assert(![probe_editor isAccessibilityFocused] && moxi_event_queue_count == 0);
#pragma clang diagnostic pop
}
