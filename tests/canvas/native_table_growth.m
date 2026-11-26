/* Real AppKit ABI growth triggers and ARC ownership, without VoiceOver. */
#import "../../native/macos_window.m"
#include <assert.h>
#include <malloc/malloc.h>
#include <objc/runtime.h>

typedef enum {
    GrowthPanel,
    GrowthButton,
    GrowthLabel,
    GrowthCheckbox,
    GrowthProgress,
    GrowthSlider,
    GrowthToggle,
    GrowthTextInput,
    GrowthImage,
    GrowthNativeWidget,
    GrowthScrollbar,
    GrowthSemantic,
    GrowthTriggerCount
} GrowthTrigger;

static void submit(GrowthTrigger trigger, int index) {
    switch (trigger) {
        case GrowthPanel:
            moxi_window_set_panel_at(index, 20, 20, 100, 100,
            0, 0, 1, 1, 0, 0, 0, 0, 0, 0);
            break;
        case GrowthButton:
            moxi_window_set_button_at(index, "High slot", 20, 20, 100, 40,
            0, 1, 0, 1, 1, 1, 1, 1, 0, 14, 0, 0, 0, 0, 1);
            break;
        case GrowthLabel:
            moxi_window_set_label_at(index, "Last label", 20, 70, 100, 30,
            1, 1, 1, 1, 14, 0);
            break;
        case GrowthCheckbox:
            moxi_window_set_checkbox_at(index, "Sparse check", 20, 20, 100, 30,
            0, 1, 0, 1, 1, 1, 1, 1, 5, 14, 1, 1, 1, 0, 1);
            break;
        case GrowthProgress:
            moxi_window_set_progress_at(index, "Sparse progress", 20, 20, 100, 30,
            0, 1, 0, 1, 1, 1, 1, 1, 5, 14, 0.75);
            break;
        case GrowthSlider:
            moxi_window_set_slider_at(index, "Sparse slider", 20, 20, 100, 30,
            0, 1, 0, 1, 1, 1, 1, 1, 5, 14, 0.75, 1, 1, 1, 0);
            break;
        case GrowthToggle:
            moxi_window_set_toggle_at(index, "Sparse toggle", 20, 20, 100, 30,
            0, 1, 0, 1, 1, 1, 1, 1, 5, 14, 1, 1, 1, 0, 1, 1);
            break;
        case GrowthTextInput:
            moxi_window_set_text_input_at(index, "Sparse input", 20, 20, 100, 30,
            0, 1, 0, 1, 1, 1, 1, 1, 5, 14, 0, 0, 3, 1, 3, "draft", 0, 1);
            break;
        case GrowthImage:
            moxi_window_set_image_at(index, 7, "Sparse image", 20, 20, 100, 30,
            0, 1, 0, 1, 1, 1, 1, 1, 5);
            break;
        case GrowthNativeWidget:
            moxi_window_set_native_widget_at(index, MOXI_ROLE_DIALOG, "Sparse widget",
            20, 20, 100, 30, 0, 1, 0, 1, 1, 1, 1, 1, 5, 14, 1, 0, 1, 1);
            break;
        case GrowthScrollbar:
            moxi_window_set_scrollbar_at(index, 20, 20, 10, 100, 20, 20, 10, 30,
            0, 1, 0, 1, 1, 1, 1, 1, 5, 1);
            break;
        case GrowthSemantic:
            moxi_window_set_accessibility_at(index, 90001, -1, MOXI_ROLE_BUTTON,
                "Semantic", "value", "hint", 10, 10, 30, 30,
                1, 0, 0, 0, 0, 0, 0, 0, 0, MOXI_ACTION_PRESS);
            break;
        case GrowthTriggerCount: assert(0); break;
    }
}

static uint64_t open_window(void) {
    uint64_t handle = moxi_window_create_instance();
    assert(handle && moxi_window_select_instance(handle));
    assert(moxi_current_context()->tableCapacity == MoxiBaselineTableCapacity);
    moxi_window_open("D03 table growth", 320, 240, 0, 0, 0, 0, 1, 0);
    moxi_window_begin_frame();
    moxi_window_ordered_paint_begin();
    return handle;
}

static void first_writers(void) {
    for (GrowthTrigger trigger = GrowthPanel; trigger < GrowthTriggerCount; ++trigger) {
        __weak NSObject *storage;
        @autoreleasepool {
            uint64_t handle = open_window();
            MoxiWindowState *owner = moxi_current_context();
            storage = owner->tableStorage;
            submit(trigger, -1);
            submit(trigger, MOXI_MAX_DRAW_COMMANDS);
            assert(owner->tableStorage == storage && owner->tableCapacity == MoxiBaselineTableCapacity);
            assert(moxi_command_overflow_count == 1);
            submit(trigger, MoxiBaselineTableCapacity - 1);
            assert(owner->tableStorage == storage);
            submit(trigger, MoxiBaselineTableCapacity);
            assert(owner->tableCapacity == MOXI_MAX_DRAW_COMMANDS && storage == nil);
            storage = owner->tableStorage;
            submit(trigger, MOXI_MAX_DRAW_COMMANDS - 1);
            assert(owner->tableStorage == storage && moxi_command_overflow_count == 1);
            moxi_window_begin_frame();
            assert(owner->tableStorage == storage && owner->tableCapacity == MOXI_MAX_DRAW_COMMANDS);
            moxi_window_close();
            assert(!moxi_window_is_open() && owner->tableStorage == storage);
            assert(moxi_window_destroy_instance(handle));
        }
        assert(storage == nil);
    }
    puts("every ordinary/semantic first writer, invalid indices and ARC storage release: PASS");
}

@interface GrowthParagraph : NSObject <MoxiParagraphDrawing>
@end
@implementation GrowthParagraph
- (void)drawAt:(NSPoint)origin color:(NSColor *)color { (void)origin; (void)color; }
@end

static void live_payloads(void) {
    __weak NSObject *oldStorage;
    __weak NSObject *expandedStorage;
    __weak id<MoxiParagraphDrawing> paragraph;
    __weak NSImage *image;
    __weak NSString *sliderText;
    __weak NSString *toggleText;
    __weak NSString *widgetText;
    @autoreleasepool {
        uint64_t a = open_window();
        MoxiWindowState *owner = moxi_current_context();
        oldStorage = owner->tableStorage;
        for (GrowthTrigger trigger = GrowthPanel; trigger < GrowthTriggerCount; ++trigger)
            submit(trigger, 0);
        moxi_window_end_accessibility();
        NSAccessibilityElement *element = moxi_accessibility_elements[0];
        moxi_window_begin_accessibility();
        submit(GrowthSemantic, 0);
        moxi_window_end_accessibility();
        assert(moxi_accessibility_elements[0] == element);
        moxi_label_paragraphs[0] = [GrowthParagraph new];
        paragraph = moxi_label_paragraphs[0];
        moxi_registered_image_ids[0] = 7;
        moxi_registered_images[0] = [[NSImage alloc] initWithSize:NSMakeSize(2, 2)];
        moxi_image_resources[0] = moxi_registered_images[0];
        image = moxi_registered_images[0];
        /* Only the slot structs own these heap strings across promotion. */
        moxi_slider_slots[0].text = [[NSMutableString alloc] initWithString:@"Owned slider payload"];
        moxi_toggle_slots[0].text = [[NSMutableString alloc] initWithString:@"Owned toggle payload"];
        moxi_native_widget_slots[0].text = [[NSMutableString alloc] initWithString:@"Owned widget payload"];
        sliderText = moxi_slider_slots[0].text;
        toggleText = moxi_toggle_slots[0].text;
        widgetText = moxi_native_widget_slots[0].text;
        moxi_window_ordered_paint(3, 0);
        moxi_window_ordered_paint(2, 0);
        moxi_window_text_editor_key(90001);
        moxi_window_set_text_input_at(0, "Japanese editor", 20, 20, 200, 30,
            0, 0, 0, 1, 1, 1, 1, 1, 5, 14, 0, 1, 3, 1, 3, "draft", 0, 1);
        NSTextField *editor = moxi_canvas.nativeTextEditor;
        NSTextView *fieldEditor = (NSTextView *)[moxi_window fieldEditor:YES forObject:editor];
        [fieldEditor setMarkedText:@"かな" selectedRange:NSMakeRange(1, 0)
            replacementRange:NSMakeRange(NSNotFound, 0)];
        assert(fieldEditor.hasMarkedText);
        NSRange marked = fieldEditor.markedRange;
        moxi_text_input_texts[0] = editor.stringValue;
        moxi_canvas.nativeTextEditorValue = editor.stringValue;
        NSArray *texts = @[moxi_label_texts[0], moxi_button_texts[0], moxi_checkbox_texts[0],
            moxi_progress_texts[0],
            moxi_text_input_texts[0], moxi_text_input_compositions[0], moxi_image_alt_texts[0],
            moxi_accessibility_labels[0],
            moxi_accessibility_values[0], moxi_accessibility_hints[0], moxi_previous_accessibility_values[0]];
        NSRect frame = moxi_text_input_frames[0];
        MoxiCanvasView *canvas = moxi_canvas;
        uint64_t b = open_window();
        NSObject *bStorage = moxi_current_context()->tableStorage;
        assert(moxi_window_select_instance(a));
        submit(GrowthPanel, MOXI_MAX_DRAW_COMMANDS - 1);
        expandedStorage = owner->tableStorage;
        assert(oldStorage == nil && expandedStorage != nil);
        assert(paragraph != nil && moxi_label_paragraphs[0] == paragraph);
        assert(image != nil && moxi_image_resources[0] == image && moxi_registered_images[0] == image);
        assert(sliderText != nil && moxi_slider_slots[0].text == sliderText);
        assert(toggleText != nil && moxi_toggle_slots[0].text == toggleText);
        assert(widgetText != nil && moxi_native_widget_slots[0].text == widgetText);
        NSArray *after = @[moxi_label_texts[0], moxi_button_texts[0], moxi_checkbox_texts[0],
            moxi_progress_texts[0],
            moxi_text_input_texts[0], moxi_text_input_compositions[0], moxi_image_alt_texts[0],
            moxi_accessibility_labels[0],
            moxi_accessibility_values[0], moxi_accessibility_hints[0], moxi_previous_accessibility_values[0]];
        for (NSUInteger i = 0; i < texts.count; ++i) assert(texts[i] == after[i]);
        assert(moxi_accessibility_elements[0] == element && moxi_previous_accessibility_ids[0] == 90001);
        assert(moxi_ordered_paint_count == 2 && moxi_ordered_paint_kinds[1] == 2 && moxi_ordered_paint_slots[1] == 0);
        assert(moxi_retained_text_editor_key == 90001 && moxi_active_text_input_index == 0);
        assert(moxi_canvas.nativeTextEditor == editor && NSEqualRects(moxi_text_input_frames[0], frame));
        /* Reusing the editor after rebinding must preserve actual marked text. */
        assert(moxi_window_select_instance(b));
        [canvas showNativeTextEditorForIndex:0];
        assert(moxi_current_context()->tableStorage == bStorage);
        assert(moxi_current_context()->tableCapacity == MoxiBaselineTableCapacity);
        assert(canvas.nativeTextEditor == editor && fieldEditor.hasMarkedText && NSEqualRanges(fieldEditor.markedRange, marked));
        assert(moxi_window_select_instance(a));
        int hole = MOXI_MAX_DRAW_COMMANDS - 2;
        assert(moxi_label_texts[hole] == nil && moxi_accessibility_ids[hole] == -1);
        assert(moxi_button_enabled[hole] && moxi_slider_slots[hole].enabled);
        assert(moxi_toggle_slots[hole].enabled && moxi_image_resource_ids[hole] == -1);
        assert(moxi_registered_image_ids[hole] == -1 && moxi_native_widget_slots[hole].enabled);
        assert(moxi_label_font_sizes[hole] == 24 && moxi_text_input_font_sizes[hole] == 18);
        assert(moxi_window_select_instance(b));
        submit(GrowthLabel, MOXI_MAX_DRAW_COMMANDS - 1);
        bStorage = moxi_current_context()->tableStorage;
        assert(bStorage != expandedStorage && moxi_current_context()->tableCapacity == MOXI_MAX_DRAW_COMMANDS);
        assert(moxi_label_count == MOXI_MAX_DRAW_COMMANDS && moxi_panel_count == 0);
        assert(moxi_window_select_instance(a));
        assert(moxi_label_count == 1 && moxi_panel_count == MOXI_MAX_DRAW_COMMANDS);
        assert(moxi_canvas == canvas && moxi_canvas.nativeTextEditor == editor);
        assert(moxi_window_select_instance(b));
        [canvas.window close];
        assert(moxi_current_context()->tableStorage == bStorage && moxi_window_is_open());
        assert(moxi_window_select_instance(a) && !moxi_window_is_open());
        assert(moxi_window_destroy_instance(a));
        assert(moxi_window_select_instance(b) && moxi_window_is_open());
        assert(moxi_current_context()->tableStorage == bStorage);
        assert(moxi_window_destroy_instance(b));
    }
    assert(paragraph == nil);
    assert(image == nil);
    assert(sliderText == nil && toggleText == nil && widgetText == nil);
    assert(expandedStorage == nil);
    puts("mid-frame payloads, marked editor, semantic identity, sparse defaults and concurrent owners: PASS");
}

static void ordered_and_registry(void) {
    uint64_t handle = open_window();
    MoxiWindowState *owner = moxi_current_context();
    __weak NSObject *baseline = owner->tableStorage;
    for (int i = 0; i < MoxiBaselineTableCapacity + MoxiCustomSliceCapacity; ++i)
        moxi_window_ordered_paint(3, 0);
    assert(owner->tableStorage == baseline);
    /* A custom slice may independently be the first entry beyond the baseline. */
    assert(moxi_window_ordered_custom_slice());
    assert(baseline == nil && owner->tableCapacity == MOXI_MAX_DRAW_COMMANDS);
    assert(moxi_ordered_paint_kinds[0] == 3 && moxi_ordered_paint_kinds[moxi_ordered_paint_count - 1] == MoxiOrderedCustomSlice);
    assert(moxi_window_destroy_instance(handle));

    handle = open_window();
    owner = moxi_current_context();
    baseline = owner->tableStorage;
    for (int i = 0; i <= MoxiBaselineTableCapacity + MoxiCustomSliceCapacity; ++i)
        moxi_window_ordered_paint(3, 0);
    assert(baseline == nil && owner->tableCapacity == MOXI_MAX_DRAW_COMMANDS);
    assert(moxi_window_destroy_instance(handle));

    handle = open_window();
    owner = moxi_current_context();
    baseline = owner->tableStorage;
    for (int i = 0; i < MoxiBaselineTableCapacity; ++i) moxi_window_register_image(i, "");
    moxi_window_register_image(0, "");
    assert(owner->tableStorage == baseline);
    for (int i = MoxiBaselineTableCapacity; i < MOXI_MAX_DRAW_COMMANDS; ++i)
        moxi_window_register_image(i, "");
    assert(baseline == nil && owner->tableCapacity == MOXI_MAX_DRAW_COMMANDS);
    for (int i = 0; i < MOXI_MAX_DRAW_COMMANDS; ++i) assert(moxi_registered_image_ids[i] == i);
    moxi_window_register_image(MOXI_MAX_DRAW_COMMANDS, "");
    assert(moxi_registered_image_ids[MOXI_MAX_DRAW_COMMANDS - 1] == MOXI_MAX_DRAW_COMMANDS - 1);
    assert(moxi_command_overflow_count == 0);
    assert(moxi_window_destroy_instance(handle));
    puts("ordinary/custom ordered entry and full image registry growth, replacement and saturation: PASS");
}

static void memory_costs(void) {
    uint64_t handle = open_window();
    MoxiWindowState *owner = moxi_current_context();
    size_t state = class_getInstanceSize(MoxiWindowState.class);
    size_t baseline = class_getInstanceSize(owner->tableStorage.class);
    size_t stateAllocation = malloc_size((__bridge const void *)owner);
    size_t baselineAllocation = malloc_size((__bridge const void *)owner->tableStorage);
    assert(state + baseline < 22388720 + 2048); /* historical 1024-slot baseline */
    double start = moxi_native_timing_now_ns() / 1e6;
    submit(GrowthPanel, MoxiBaselineTableCapacity);
    double growth = moxi_native_timing_now_ns() / 1e6 - start;
    size_t expanded = class_getInstanceSize(owner->tableStorage.class);
    size_t expandedAllocation = malloc_size((__bridge const void *)owner->tableStorage);
    printf("storage_bytes state=%zu baseline=%zu expanded=%zu total_small=%zu total_large=%zu\n",
        state, baseline, expanded, state + baseline, state + expanded);
    printf("allocator_bytes state=%zu baseline=%zu expanded=%zu total_small=%zu total_large=%zu\n",
        stateAllocation, baselineAllocation, expandedAllocation,
        stateAllocation + baselineAllocation, stateAllocation + expandedAllocation);
    printf("promotion_ms %.6f\n", growth);
    assert(moxi_window_destroy_instance(handle));
}

int main(void) {
    @autoreleasepool {
        first_writers();
        live_payloads();
        ordered_and_registry();
        memory_costs();
    }
    puts("D03 demand-grown native table storage: PASS");
}
