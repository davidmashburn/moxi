/* Real adapter limits, high slots, reset and window ownership. No VoiceOver. */
#import "../../native/macos_window.m"
#include <assert.h>
#include <objc/runtime.h>

int main(void) {
    @autoreleasepool {
        int capacity = moxi_window_command_capacity();
        assert(capacity == 4096);
        uint64_t a = moxi_window_create_instance();
        assert(moxi_window_select_instance(a));
        moxi_window_open("D03 capacity boundary", 320, 240, 0, 0, 0, 0, 1, 0);
        moxi_window_begin_frame();
        moxi_window_ordered_paint_begin();
        moxi_window_set_panel_at(capacity - 1, 20, 20, 100, 100,
            0, 0, 1, 1, 0, 0, 0, 0, 0, 0);
        moxi_window_ordered_paint(3, capacity - 1);
        moxi_window_set_button_at(capacity - 1, "High slot", 20, 20, 100, 40,
            0, 1, 0, 1, 1, 1, 1, 1, 0, 14, 0, 0, 0, 0, 1);
        moxi_window_ordered_paint(2, capacity - 1);
        moxi_window_set_label_at(capacity - 1, "Last label", 20, 70, 100, 30,
            1, 1, 1, 1, 14, 0);
        moxi_window_ordered_paint(1, capacity - 1);
        /* Exercise every other ordinary kind at a sparse high slot. The next
         * frame must release payloads and restore defaults across the holes. */
        int last = capacity - 1;
        moxi_window_set_checkbox_at(last, "Sparse check", 20, 20, 100, 30,
            0, 1, 0, 1, 1, 1, 1, 1, 5, 14, 1, 1, 1, 0, 1);
        moxi_window_set_progress_at(last, "Sparse progress", 20, 20, 100, 30,
            0, 1, 0, 1, 1, 1, 1, 1, 5, 14, 0.75);
        moxi_window_set_slider_at(last, "Sparse slider", 20, 20, 100, 30,
            0, 1, 0, 1, 1, 1, 1, 1, 5, 14, 0.75, 1, 1, 1, 0);
        moxi_window_set_toggle_at(last, "Sparse toggle", 20, 20, 100, 30,
            0, 1, 0, 1, 1, 1, 1, 1, 5, 14, 1, 1, 1, 0, 1, 1);
        moxi_window_set_text_input_at(last, "Sparse input", 20, 20, 100, 30,
            0, 1, 0, 1, 1, 1, 1, 1, 5, 14, 0, 0, 3, 1, 3, "draft", 0, 1);
        moxi_window_set_image_at(last, 7, "Sparse image", 20, 20, 100, 30,
            0, 1, 0, 1, 1, 1, 1, 1, 5);
        moxi_window_set_native_widget_at(last, MOXI_ROLE_DIALOG, "Sparse widget",
            20, 20, 100, 30, 0, 1, 0, 1, 1, 1, 1, 1, 5, 14, 1, 0, 1, 1);
        moxi_window_set_scrollbar_at(last, 20, 20, 10, 100, 20, 20, 10, 30,
            0, 1, 0, 1, 1, 1, 1, 1, 5, 1);
        assert(moxi_panel_count == capacity && moxi_button_count == capacity &&
               moxi_label_count == capacity && moxi_command_overflow_count == 0);
        moxi_window_begin_accessibility();
        moxi_window_set_accessibility_at(capacity - 1, 90001, -1,
            MOXI_ROLE_BUTTON, "Last semantic slot", "", "", 20, 20, 100, 40,
            1, 1, 1, 0, 0, 0, 0, 0, 0, 0);
        moxi_window_end_accessibility();
        assert(moxi_accessibility_count == capacity && moxi_accessibility_elements[capacity - 1]);
        moxi_window_set_label_at(capacity, "Rejected", 0, 0, 1, 1, 1, 1, 1, 1, 14, 0);
        moxi_window_set_accessibility_at(capacity, 90002, -1,
            MOXI_ROLE_BUTTON, "Rejected", "", "", 0, 0, 1, 1,
            1, 0, 0, 0, 0, 0, 0, 0, 0, 0);
        moxi_window_ordered_paint(1, capacity);
        assert(moxi_command_overflow_count == 3);
        assert(moxi_label_count == capacity && moxi_accessibility_count == capacity);
        for (int i = moxi_ordered_paint_count; i < capacity + MoxiCustomSliceCapacity; i++)
            moxi_window_ordered_paint(1, 0);
        assert(moxi_ordered_paint_count == capacity + MoxiCustomSliceCapacity);
        moxi_window_ordered_paint(1, 0);
        assert(moxi_command_overflow_count == 4);

        uint64_t b = moxi_window_create_instance();
        assert(moxi_window_select_instance(b));
        moxi_window_begin_frame();
        assert(moxi_command_overflow_count == 0 && moxi_label_count == 0);
        assert(moxi_window_select_instance(a));
        assert(moxi_command_overflow_count == 4 && moxi_label_count == capacity);
        moxi_window_begin_frame();
        moxi_window_begin_accessibility();
        assert(moxi_label_count == 0 && moxi_button_count == 0 && moxi_ordered_paint_count == 0);
        assert(moxi_label_texts[capacity - 1] == nil && moxi_label_paragraphs[capacity - 1] == nil);
        assert(moxi_button_texts[capacity - 1] == nil && moxi_accessibility_elements[capacity - 1] == nil);
        assert(moxi_command_overflow_count == 0);
        assert(moxi_checkbox_count == 0 && moxi_progress_count == 0 &&
            moxi_slider_count == 0 && moxi_toggle_count == 0 && moxi_text_input_count == 0 &&
            moxi_image_count == 0 && moxi_native_widget_count == 0 && moxi_scrollbar_count == 0);
        assert(moxi_checkbox_texts[last] == nil && moxi_progress_texts[last] == nil &&
            moxi_slider_slots[last].text == nil && moxi_toggle_slots[last].text == nil &&
            moxi_text_input_texts[last] == nil && moxi_text_input_compositions[last] == nil &&
            moxi_image_alt_texts[last] == nil && moxi_native_widget_slots[last].text == nil);
        assert(moxi_slider_slots[last].enabled && !moxi_slider_slots[last].focused &&
            moxi_toggle_slots[last].enabled && !moxi_toggle_slots[last].checked &&
            !moxi_scrollbar_slots[last].visible && moxi_image_resource_ids[last] == -1);
        assert(moxi_accessibility_ids[last] == -1 && moxi_accessibility_parent_ids[last] == -1);
        assert(moxi_text_input_selection_ends[last] == 0 && moxi_progress_values[last] == 0);
        /* Repopulate a small frame after shrink, with a semantic hole. */
        moxi_window_ordered_paint_begin();
        moxi_window_set_label_at(1, "Remounted", 20, 20, 100, 30, 1, 1, 1, 1, 14, 0);
        assert(moxi_label_count == 2 && moxi_label_texts[0] == nil &&
            NSEqualRects(moxi_label_frames[0], NSZeroRect) && !moxi_label_clip_enabled[1]);
        moxi_window_set_accessibility_at(2, 90003, -1, MOXI_ROLE_BUTTON,
            "Remounted", "new value", "", 20, 20, 100, 30, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0);
        assert(moxi_accessibility_ids[0] == -1 && moxi_accessibility_roles[0] == 0 &&
            moxi_accessibility_enabled[0]);
        moxi_window_end_accessibility();
        NSAccessibilityElement *remounted = moxi_accessibility_elements[2];
        NSMutableArray *priorChildren = moxi_accessibility_root_children;
        NSUInteger priorChildCount = priorChildren.count;
        moxi_window_begin_accessibility();
        moxi_window_set_accessibility_at(0, 90003, -1, MOXI_ROLE_BUTTON,
            "Remounted", "changed value", "", 20, 20, 100, 30, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0);
        moxi_window_end_accessibility();
        assert(moxi_accessibility_elements[0] == remounted && moxi_accessibility_elements[2] == nil);
        assert(priorChildren != moxi_accessibility_root_children && priorChildren.count == priorChildCount);
        moxi_window_begin_accessibility();
        moxi_window_end_accessibility();
        moxi_window_begin_accessibility();
        moxi_window_end_accessibility();
        assert(moxi_accessibility_count == 0 && moxi_previous_accessibility_count == 0 &&
            moxi_previous_accessibility_values[2] == nil && moxi_accessibility_root_children.count == 0);
        printf("D03 native capacity/reset/isolation: PASS; capacity=%d state_bytes=%zu\n",
            capacity, class_getInstanceSize(MoxiWindowState.class));
        moxi_window_destroy_instance(a);
        moxi_window_destroy_instance(b);
    }
}
