/* Instance-owned storage for the AppKit ABI. Included after slot types.
 * The current context is only a main-thread dispatch cursor; no draw/event
 * payload is shared. Cocoa callbacks save/restore it, including nested calls.
 */
enum { MoxiCustomSliceCapacity = 64, MoxiOrderedCustomSlice = 101 };
typedef struct {
    int rectStart, rectEnd, lineStart, lineEnd;
    int circleStart, circleEnd, textStart, textEnd;
    int bitmapStart, bitmapEnd;
    BOOL clipEnabled;
    NSRect clip;
} MoxiCustomSlice;

/* Ordinary windows retain the pre-D03 1024-entry baseline. A valid writer
 * promotes the whole table set once; custom-paint storage is independent.
 * Fixed Objective-C layouts let ARC own every reference, including slot structs.
 */
enum { MoxiBaselineTableCapacity = 1024 };
@interface MoxiBaselineWindowTables : NSObject {
@public
#define MOXI_TABLE_VALUE(type, name) type name[MoxiBaselineTableCapacity];
#define MOXI_TABLE_OBJECT(type, name) MOXI_TABLE_VALUE(type, name)
#define MOXI_TABLE_COLOR(name) float name[MoxiBaselineTableCapacity][4];
#define MOXI_TABLE_ORDER(name) int name[MoxiBaselineTableCapacity + MoxiCustomSliceCapacity];
#include "macos_window_tables.def"
#undef MOXI_TABLE_VALUE
#undef MOXI_TABLE_OBJECT
#undef MOXI_TABLE_COLOR
#undef MOXI_TABLE_ORDER
}
@end
@implementation MoxiBaselineWindowTables
@end

@interface MoxiExpandedWindowTables : NSObject {
@public
#define MOXI_TABLE_VALUE(type, name) type name[MOXI_MAX_DRAW_COMMANDS];
#define MOXI_TABLE_OBJECT(type, name) MOXI_TABLE_VALUE(type, name)
#define MOXI_TABLE_COLOR(name) float name[MOXI_MAX_DRAW_COMMANDS][4];
#define MOXI_TABLE_ORDER(name) int name[MOXI_MAX_DRAW_COMMANDS + MoxiCustomSliceCapacity];
#include "macos_window_tables.def"
#undef MOXI_TABLE_VALUE
#undef MOXI_TABLE_OBJECT
#undef MOXI_TABLE_COLOR
#undef MOXI_TABLE_ORDER
}
@end
@implementation MoxiExpandedWindowTables
@end

@interface MoxiWindowState : NSObject {
@public
    BOOL retired;
    /* Views borrow storage only from this strong owner; none escape the ABI.
     * Promotion rebinds them before releasing the old backing object. */
    NSObject *tableStorage;
    int tableCapacity;
#define MOXI_TABLE_VALUE(type, name) type *name;
#define MOXI_TABLE_OBJECT(type, name) type __strong *name;
#define MOXI_TABLE_COLOR(name) float (*name)[4];
#define MOXI_TABLE_ORDER(name) int *name;
#include "macos_window_tables.def"
#undef MOXI_TABLE_VALUE
#undef MOXI_TABLE_OBJECT
#undef MOXI_TABLE_COLOR
#undef MOXI_TABLE_ORDER
    NSMenu *menu;
    NSInteger menuResult;
    NSAlert *dialog;
    /* Opt-in retained submission order; legacy hosts keep their original order. */
    BOOL moxi_ordered_paint_enabled;
    int moxi_ordered_paint_count;
    int customSliceCount;
    MoxiCustomSlice customSlices[MoxiCustomSliceCapacity];
    NSWindow *moxi_window;
    MoxiWindowDelegate *moxi_delegate;
    MoxiCanvasView *moxi_canvas;
    BOOL moxi_window_opened;
    BOOL moxi_click_pending;
    float moxi_last_click_x;
    float moxi_last_click_y;
    BOOL moxi_mouse_is_down;
    BOOL moxi_mouse_dragging;
    float moxi_last_pointer_x;
    float moxi_last_pointer_y;
    MoxiQueuedEvent moxi_event_queue[MOXI_EVENT_QUEUE_CAPACITY];
    int moxi_event_queue_head;
    int moxi_event_queue_tail;
    int moxi_event_queue_count;
    BOOL moxi_waiting_for_event;
    int moxi_event_dropped_count;
    int moxi_event_kind;
    int moxi_event_key;
    int moxi_event_modifiers;
    int moxi_event_codepoint;
    NSString *moxi_event_text_value;
    int moxi_event_selection_start;
    int moxi_event_selection_end;
    float moxi_event_x;
    float moxi_event_y;
    float moxi_event_scroll_x;
    float moxi_event_scroll_y;
    int moxi_event_target;
    int moxi_event_action;
    uint64_t moxi_current_event_receipt_ns;
    int moxi_current_event_queue_depth;
    int moxi_interpreting_modifiers;
    NSString *moxi_marked_text;
    int moxi_marked_selection_start;
    int moxi_marked_selection_end;
    CGFloat moxi_last_canvas_width;
    CGFloat moxi_last_canvas_height;
    CGFloat moxi_last_canvas_scale;
    NSString *moxi_clipboard_value;
    BOOL moxi_native_timing_active;
    MoxiNativeTiming moxi_native_timing;
    FILE *moxi_native_timing_output;
    int moxi_label_count;
    int moxi_command_overflow_count;
    int moxi_button_count;
    int moxi_checkbox_count;
    int moxi_progress_count;
    int moxi_slider_count;
    int moxi_toggle_count;
    int moxi_text_input_count;
    int moxi_image_count;
    int moxi_active_text_input_index;
    int moxi_retained_text_editor_key;
    BOOL moxi_native_text_editor_seen;
    float moxi_surface_fill[4];
    int moxi_panel_count;
    int moxi_native_widget_count;
    int moxi_scrollbar_count;
    int moxi_custom_line_count;
    NSPoint moxi_custom_line_starts[MOXI_MAX_CUSTOM_LINES];
    NSPoint moxi_custom_line_ends[MOXI_MAX_CUSTOM_LINES];
    float moxi_custom_line_colors[MOXI_MAX_CUSTOM_LINES][4];
    float moxi_custom_line_widths[MOXI_MAX_CUSTOM_LINES];
    int moxi_custom_circle_count;
    NSPoint moxi_custom_circle_centers[MOXI_MAX_CUSTOM_CIRCLES];
    float moxi_custom_circle_radii[MOXI_MAX_CUSTOM_CIRCLES];
    float moxi_custom_circle_fills[MOXI_MAX_CUSTOM_CIRCLES][4];
    float moxi_custom_circle_strokes[MOXI_MAX_CUSTOM_CIRCLES][4];
    float moxi_custom_circle_stroke_widths[MOXI_MAX_CUSTOM_CIRCLES];
    int moxi_custom_rect_count;
    NSRect moxi_custom_rect_frames[MOXI_MAX_CUSTOM_RECTS];
    float moxi_custom_rect_fills[MOXI_MAX_CUSTOM_RECTS][4];
    float moxi_custom_rect_strokes[MOXI_MAX_CUSTOM_RECTS][4];
    float moxi_custom_rect_stroke_widths[MOXI_MAX_CUSTOM_RECTS];
    float moxi_custom_rect_radii[MOXI_MAX_CUSTOM_RECTS];
    int moxi_custom_text_count;
    NSString *moxi_custom_texts[MOXI_MAX_CUSTOM_TEXT];
    NSRect moxi_custom_text_frames[MOXI_MAX_CUSTOM_TEXT];
    float moxi_custom_text_colors[MOXI_MAX_CUSTOM_TEXT][4];
    float moxi_custom_text_font_sizes[MOXI_MAX_CUSTOM_TEXT];
    int moxi_custom_bitmap_count;
    NSBitmapImageRep *moxi_custom_bitmaps[MOXI_MAX_CUSTOM_BITMAPS];
    NSRect moxi_custom_bitmap_frames[MOXI_MAX_CUSTOM_BITMAPS];
    float moxi_custom_bitmap_opacities[MOXI_MAX_CUSTOM_BITMAPS];
    BOOL moxi_custom_bitmap_clip_enabled[MOXI_MAX_CUSTOM_BITMAPS];
    NSRect moxi_custom_bitmap_clip_frames[MOXI_MAX_CUSTOM_BITMAPS];
    BOOL moxi_custom_clip_enabled;
    NSRect moxi_custom_clip_frame;
    /* One retained custom layer per window. Command submission invalidates it;
     * begin_frame preserves commands so backing-size changes can rebuild it. */
    BOOL moxi_custom_paint_cache_enabled;
    BOOL moxi_custom_paint_cache_valid;
    NSBitmapImageRep *moxi_custom_paint_cache_bitmap;
    NSRect moxi_custom_paint_cache_bounds;
    CGFloat moxi_custom_paint_cache_scale;
    uint64_t moxi_custom_paint_cache_build_count;
    uint64_t moxi_custom_paint_cache_hit_count;
    BOOL moxi_current_clip_enabled;
    NSRect moxi_current_clip_frame;
    int moxi_accessibility_count;
    NSMutableArray *moxi_accessibility_owned_elements;
    NSMutableArray *moxi_accessibility_root_children;
    /* Preserve AX identity only for this window's active semantic keys. */
    NSDictionary<NSNumber *, MoxiAccessibilityElement *> *moxi_retained_accessibility_elements;
    BOOL moxi_accessibility_focused_text_input;
    BOOL moxi_accessibility_has_previous_snapshot;
    int moxi_previous_accessibility_count;
}
- (void)ensureTableCapacity:(int)required;
- (void)resetDrawSlots;
- (void)resetDrawSlotsFrom:(int)start initializing:(BOOL)initializing;
- (void)resetAccessibilitySlots;
- (void)resetAccessibilitySlotsFrom:(int)start initializing:(BOOL)initializing;
- (void)captureAccessibilitySnapshot;
@end
@implementation MoxiWindowState
/* Defaults remain available for sparse public slots and holes. Initialize a
 * new tail once; frame resets still touch only the prior per-kind counts. */
- (void)resetDrawSlots {
    [self resetDrawSlotsFrom:0 initializing:NO];
}
- (void)resetDrawSlotsFrom:(int)start initializing:(BOOL)initializing {
    int labelLimit = initializing ? tableCapacity : moxi_label_count;
    for (int i = start; i < labelLimit; ++i) {
        moxi_label_texts[i] = nil;
        moxi_label_paragraphs[i] = nil;
        moxi_label_frames[i] = NSZeroRect;
        moxi_copy_color(moxi_label_text_colors[i], 1.0, 1.0, 1.0, 1.0);
        moxi_label_font_sizes[i] = 24.0;
        moxi_label_wraps[i] = NO;
        moxi_label_badges[i] = NO;
        moxi_label_padding[i] = 0.0;
        moxi_label_clip_enabled[i] = NO;
        moxi_label_clip_frames[i] = NSZeroRect;
    }
    int buttonLimit = initializing ? tableCapacity : moxi_button_count;
    for (int i = start; i < buttonLimit; ++i) {
        moxi_button_texts[i] = nil;
        moxi_button_frames[i] = NSZeroRect;
        moxi_copy_color(moxi_button_fill_colors[i], 0.18, 0.48, 0.92, 1.0);
        moxi_copy_color(moxi_button_text_colors[i], 1.0, 1.0, 1.0, 1.0);
        moxi_button_radii[i] = 10.0;
        moxi_button_font_sizes[i] = 16.0;
        moxi_button_wraps[i] = NO;
        moxi_button_clip_enabled[i] = NO;
        moxi_button_clip_frames[i] = NSZeroRect;
        moxi_button_focused[i] = NO;
        moxi_button_hovered[i] = NO;
        moxi_button_pressed[i] = NO;
        moxi_button_enabled[i] = YES;
    }
    int checkboxLimit = initializing ? tableCapacity : moxi_checkbox_count;
    for (int i = start; i < checkboxLimit; ++i) {
        moxi_checkbox_texts[i] = nil;
        moxi_checkbox_frames[i] = NSZeroRect;
        moxi_copy_color(moxi_checkbox_fill_colors[i], 0.07, 0.09, 0.14, 1.0);
        moxi_copy_color(moxi_checkbox_text_colors[i], 1.0, 1.0, 1.0, 1.0);
        moxi_checkbox_radii[i] = 5.0;
        moxi_checkbox_font_sizes[i] = 16.0;
        moxi_checkbox_clip_enabled[i] = NO;
        moxi_checkbox_clip_frames[i] = NSZeroRect;
        moxi_checkbox_focused[i] = NO;
        moxi_checkbox_hovered[i] = NO;
        moxi_checkbox_pressed[i] = NO;
        moxi_checkbox_enabled[i] = YES;
        moxi_checkbox_checked[i] = NO;
    }
    int progressLimit = initializing ? tableCapacity : moxi_progress_count;
    for (int i = start; i < progressLimit; ++i) {
        moxi_progress_texts[i] = nil;
        moxi_progress_frames[i] = NSZeroRect;
        moxi_copy_color(moxi_progress_fill_colors[i], 0.10, 0.14, 0.22, 1.0);
        moxi_copy_color(moxi_progress_text_colors[i], 1.0, 1.0, 1.0, 1.0);
        moxi_progress_radii[i] = 8.0;
        moxi_progress_font_sizes[i] = 14.0;
        moxi_progress_values[i] = 0.0;
        moxi_progress_clip_enabled[i] = NO;
        moxi_progress_clip_frames[i] = NSZeroRect;
    }
    int sliderLimit = initializing ? tableCapacity : moxi_slider_count;
    for (int i = start; i < sliderLimit; ++i) {
        moxi_slider_slots[i].text = nil;
        moxi_slider_slots[i].frame = NSZeroRect;
        moxi_copy_color(moxi_slider_slots[i].fill, 0.10, 0.14, 0.22, 1.0);
        moxi_copy_color(moxi_slider_slots[i].textColor, 0.35, 0.72, 1.0, 1.0);
        moxi_slider_slots[i].radius = 8.0;
        moxi_slider_slots[i].fontSize = 14.0;
        moxi_slider_slots[i].value = 0.0;
        moxi_slider_slots[i].focused = NO;
        moxi_slider_slots[i].hovered = NO;
        moxi_slider_slots[i].pressed = NO;
        moxi_slider_slots[i].enabled = YES;
        moxi_slider_slots[i].clipEnabled = NO;
        moxi_slider_slots[i].clipFrame = NSZeroRect;
    }
    int toggleLimit = initializing ? tableCapacity : moxi_toggle_count;
    for (int i = start; i < toggleLimit; ++i) {
        moxi_toggle_slots[i].text = nil;
        moxi_toggle_slots[i].frame = NSZeroRect;
        moxi_copy_color(moxi_toggle_slots[i].fill, 0.14, 0.18, 0.28, 1.0);
        moxi_copy_color(moxi_toggle_slots[i].textColor, 1.0, 1.0, 1.0, 1.0);
        moxi_toggle_slots[i].radius = 10.0;
        moxi_toggle_slots[i].fontSize = 16.0;
        moxi_toggle_slots[i].focused = NO;
        moxi_toggle_slots[i].hovered = NO;
        moxi_toggle_slots[i].pressed = NO;
        moxi_toggle_slots[i].enabled = YES;
        moxi_toggle_slots[i].checked = NO;
        moxi_toggle_slots[i].radio = NO;
        moxi_toggle_slots[i].clipEnabled = NO;
        moxi_toggle_slots[i].clipFrame = NSZeroRect;
    }
    int textInputLimit = initializing ? tableCapacity : moxi_text_input_count;
    for (int i = start; i < textInputLimit; ++i) {
        moxi_text_input_texts[i] = nil;
        moxi_text_input_frames[i] = NSZeroRect;
        moxi_copy_color(moxi_text_input_fill_colors[i], 0.07, 0.09, 0.14, 1.0);
        moxi_copy_color(moxi_text_input_text_colors[i], 1.0, 1.0, 1.0, 1.0);
        moxi_text_input_radii[i] = 8.0;
        moxi_text_input_font_sizes[i] = 18.0;
        moxi_text_input_wraps[i] = NO;
        moxi_text_input_clip_enabled[i] = NO;
        moxi_text_input_clip_frames[i] = NSZeroRect;
        moxi_text_input_focused[i] = NO;
        moxi_text_input_cursors[i] = 0;
        moxi_text_input_selection_starts[i] = 0;
        moxi_text_input_selection_ends[i] = 0;
        moxi_text_input_compositions[i] = nil;
        moxi_text_input_composition_selection_starts[i] = 0;
        moxi_text_input_composition_selection_ends[i] = 0;
    }
    int imageLimit = initializing ? tableCapacity : moxi_image_count;
    for (int i = start; i < imageLimit; ++i) {
        moxi_image_alt_texts[i] = nil;
        moxi_image_resources[i] = nil;
        moxi_image_nearest[i] = NO;
        moxi_image_resource_ids[i] = -1;
        moxi_image_frames[i] = NSZeroRect;
        moxi_image_clip_enabled[i] = NO;
        moxi_image_clip_frames[i] = NSZeroRect;
        moxi_copy_color(moxi_image_fill_colors[i], 0.12, 0.15, 0.22, 1.0);
        moxi_copy_color(moxi_image_text_colors[i], 1.0, 1.0, 1.0, 1.0);
        moxi_image_radii[i] = 4.0;
    }
    int panelLimit = initializing ? tableCapacity : moxi_panel_count;
    for (int i = start; i < panelLimit; ++i) {
        moxi_panel_frames[i] = NSZeroRect;
        moxi_copy_color(moxi_panel_fills[i], 0.16, 0.20, 0.30, 1.0);
        moxi_panel_radii[i] = 0.0;
        moxi_panel_clip_enabled[i] = NO;
        moxi_panel_clip_frames[i] = NSZeroRect;
    }
    int nativeWidgetLimit = initializing ? tableCapacity : moxi_native_widget_count;
    for (int i = start; i < nativeWidgetLimit; ++i) {
        moxi_native_widget_slots[i].text = nil;
        moxi_native_widget_slots[i].frame = NSZeroRect;
        moxi_copy_color(moxi_native_widget_slots[i].fill, 0.12, 0.15, 0.22, 1.0);
        moxi_copy_color(moxi_native_widget_slots[i].textColor, 1.0, 1.0, 1.0, 1.0);
        moxi_native_widget_slots[i].radius = 6.0;
        moxi_native_widget_slots[i].fontSize = 14.0;
        moxi_native_widget_slots[i].kind = 18;
        moxi_native_widget_slots[i].focused = NO;
        moxi_native_widget_slots[i].enabled = YES;
        moxi_native_widget_slots[i].selected = NO;
        moxi_native_widget_slots[i].expanded = NO;
        moxi_native_widget_slots[i].clipEnabled = NO;
        moxi_native_widget_slots[i].clipFrame = NSZeroRect;
    }
    int scrollbarLimit = initializing ? tableCapacity : moxi_scrollbar_count;
    for (int i = start; i < scrollbarLimit; ++i) {
        moxi_scrollbar_slots[i].track = NSZeroRect;
        moxi_scrollbar_slots[i].thumb = NSZeroRect;
        moxi_copy_color(moxi_scrollbar_slots[i].trackColor, 0.055, 0.075, 0.125, 0.72);
        moxi_copy_color(moxi_scrollbar_slots[i].thumbColor, 0.48, 0.79, 1.0, 0.94);
        moxi_scrollbar_slots[i].radius = 4.0;
        moxi_scrollbar_slots[i].visible = NO;
        moxi_scrollbar_slots[i].clipEnabled = NO;
        moxi_scrollbar_slots[i].clipFrame = NSZeroRect;
    }
}
- (void)resetAccessibilitySlots {
    [self resetAccessibilitySlotsFrom:0 initializing:NO];
}
- (void)resetAccessibilitySlotsFrom:(int)start initializing:(BOOL)initializing {
    int limit = initializing ? tableCapacity : moxi_accessibility_count;
    for (int i = start; i < limit; i++) {
        moxi_accessibility_ids[i] = -1;
        moxi_accessibility_parent_ids[i] = -1;
        moxi_accessibility_roles[i] = 0;
        moxi_accessibility_labels[i] = nil;
        moxi_accessibility_values[i] = nil;
        moxi_accessibility_hints[i] = nil;
        moxi_accessibility_frames[i] = NSZeroRect;
        moxi_accessibility_enabled[i] = YES;
        moxi_accessibility_focused[i] = NO;
        moxi_accessibility_selected[i] = NO;
        moxi_accessibility_checked[i] = NO;
        moxi_accessibility_expanded[i] = NO;
        moxi_accessibility_has_value_range[i] = NO;
        moxi_accessibility_value_min[i] = 0.0;
        moxi_accessibility_value_max[i] = 0.0;
        moxi_accessibility_value_now[i] = 0.0;
        moxi_accessibility_actions[i] = 0;
        moxi_accessibility_elements[i] = nil;
    }
}
- (void)captureAccessibilitySnapshot {
    for (int i = moxi_accessibility_count; i < moxi_previous_accessibility_count; ++i) {
        moxi_previous_accessibility_values[i] = nil;
    }
    moxi_accessibility_has_previous_snapshot = moxi_accessibility_count > 0;
    moxi_previous_accessibility_count = moxi_accessibility_count;
    for (int i = 0; i < moxi_accessibility_count; i++) {
        moxi_previous_accessibility_ids[i] = moxi_accessibility_ids[i];
        moxi_previous_accessibility_roles[i] = moxi_accessibility_roles[i];
        moxi_previous_accessibility_values[i] = moxi_accessibility_values[i] == nil
            ? @""
            : [moxi_accessibility_values[i] copy];
        moxi_previous_accessibility_checked[i] = moxi_accessibility_checked[i];
        moxi_previous_accessibility_expanded[i] = moxi_accessibility_expanded[i];
        moxi_previous_accessibility_selected[i] = moxi_accessibility_selected[i];
        moxi_previous_accessibility_enabled[i] = moxi_accessibility_enabled[i];
        moxi_previous_accessibility_focused[i] = moxi_accessibility_focused[i];
        moxi_previous_accessibility_has_value_range[i] =
            moxi_accessibility_has_value_range[i];
        moxi_previous_accessibility_value_min[i] = moxi_accessibility_value_min[i];
        moxi_previous_accessibility_value_max[i] = moxi_accessibility_value_max[i];
        moxi_previous_accessibility_value_now[i] = moxi_accessibility_value_now[i];
    }
}
- (void)ensureTableCapacity:(int)required {
    if (required <= tableCapacity) return;
    NSCAssert(required <= MOXI_MAX_DRAW_COMMANDS, @"Invalid native table capacity");
    MoxiBaselineWindowTables *previous = (MoxiBaselineWindowTables *)tableStorage;
    MoxiExpandedWindowTables *next = [MoxiExpandedWindowTables new];
    /* Assignment preserves ARC ownership for object arrays and slot structs.
     * Only colors and integer ordering arrays are copied as raw bytes. */
    for (int i = 0; i < MoxiBaselineTableCapacity; ++i) {
#define MOXI_TABLE_VALUE(type, name) next->name[i] = previous->name[i];
#define MOXI_TABLE_OBJECT(type, name) MOXI_TABLE_VALUE(type, name)
#define MOXI_TABLE_COLOR(name)
#define MOXI_TABLE_ORDER(name)
#include "macos_window_tables.def"
#undef MOXI_TABLE_VALUE
#undef MOXI_TABLE_OBJECT
#undef MOXI_TABLE_COLOR
#undef MOXI_TABLE_ORDER
    }
#define MOXI_TABLE_VALUE(type, name)
#define MOXI_TABLE_OBJECT(type, name)
#define MOXI_TABLE_COLOR(name) memcpy(next->name, previous->name, sizeof(previous->name));
#define MOXI_TABLE_ORDER(name) MOXI_TABLE_COLOR(name)
#include "macos_window_tables.def"
#undef MOXI_TABLE_VALUE
#undef MOXI_TABLE_OBJECT
#undef MOXI_TABLE_COLOR
#undef MOXI_TABLE_ORDER
#define MOXI_TABLE_VALUE(type, name) name = next->name;
#define MOXI_TABLE_OBJECT(type, name) MOXI_TABLE_VALUE(type, name)
#define MOXI_TABLE_COLOR(name) name = next->name;
#define MOXI_TABLE_ORDER(name) name = next->name;
#include "macos_window_tables.def"
#undef MOXI_TABLE_VALUE
#undef MOXI_TABLE_OBJECT
#undef MOXI_TABLE_COLOR
#undef MOXI_TABLE_ORDER
    tableStorage = next;
    tableCapacity = MOXI_MAX_DRAW_COMMANDS;
    [self resetDrawSlotsFrom:MoxiBaselineTableCapacity initializing:YES];
    [self resetAccessibilitySlotsFrom:MoxiBaselineTableCapacity initializing:YES];
    for (int i = MoxiBaselineTableCapacity; i < tableCapacity; ++i)
        moxi_registered_image_ids[i] = -1;
}
- (instancetype)init {
    self = [super init];
    if (self) {
        MoxiBaselineWindowTables *initial = [MoxiBaselineWindowTables new];
#define MOXI_TABLE_VALUE(type, name) name = initial->name;
#define MOXI_TABLE_OBJECT(type, name) MOXI_TABLE_VALUE(type, name)
#define MOXI_TABLE_COLOR(name) name = initial->name;
#define MOXI_TABLE_ORDER(name) name = initial->name;
#include "macos_window_tables.def"
#undef MOXI_TABLE_VALUE
#undef MOXI_TABLE_OBJECT
#undef MOXI_TABLE_COLOR
#undef MOXI_TABLE_ORDER
        tableStorage = initial;
        tableCapacity = MoxiBaselineTableCapacity;
        [self resetDrawSlotsFrom:0 initializing:YES];
        [self resetAccessibilitySlotsFrom:0 initializing:YES];
        for (int i = 0; i < tableCapacity; ++i) moxi_registered_image_ids[i] = -1;
        moxi_ordered_paint_enabled = NO;
        moxi_ordered_paint_count = 0;
        moxi_retained_text_editor_key = -1;
    }
    return self;
}
@end

enum { MoxiWindowCapacity = 8 };
static MoxiWindowState *moxi_contexts[MoxiWindowCapacity];
static uint64_t moxi_context_ids[MoxiWindowCapacity];
static uint64_t moxi_next_context_id = 1;
static MoxiWindowState *moxi_active_context;
static MoxiWindowState *moxi_legacy_context;

/* A retained C return avoids autorelease accumulation in Mojo's manual loop. */
static MoxiWindowState *moxi_current_context(void) __attribute__((ns_returns_retained));
static MoxiWindowState *moxi_current_context(void) {
    NSCAssert([NSThread isMainThread], @"Moxi AppKit requires the main thread");
    if (moxi_active_context == nil) {
        if (moxi_legacy_context == nil) moxi_legacy_context = [MoxiWindowState new];
        moxi_active_context = moxi_legacy_context;
    }
    return moxi_active_context;
}
static void moxi_restore_context(MoxiWindowState *__strong *previous) {
    moxi_active_context = *previous;
}
#define MOXI_CALLBACK_SCOPE(fallback) \
    MoxiWindowState *owner = self.moxiOwner; \
    if (owner == nil || owner->retired) { fallback; } \
    __attribute__((cleanup(moxi_restore_context))) \
    MoxiWindowState *previousContext = moxi_active_context; \
    moxi_active_context = owner

/* Zero means capacity exhausted. IDs never alias a retired instance. */
uint64_t moxi_window_create_instance(void) {
    NSCAssert([NSThread isMainThread], @"Moxi AppKit requires the main thread");
    if (moxi_next_context_id == 0) return 0;
    for (int i = 0; i < MoxiWindowCapacity; ++i) {
        if (moxi_contexts[i] == nil) {
            moxi_contexts[i] = [MoxiWindowState new];
            moxi_context_ids[i] = moxi_next_context_id++;
            return moxi_context_ids[i];
        }
    }
    return 0;
}
int moxi_window_select_instance(uint64_t handle) {
    NSCAssert([NSThread isMainThread], @"Moxi AppKit requires the main thread");
    for (int i = 0; i < MoxiWindowCapacity; ++i) {
        if (handle != 0 && moxi_context_ids[i] == handle && moxi_contexts[i] != nil) {
            moxi_active_context = moxi_contexts[i];
            return 1;
        }
    }
    return 0;
}

/* The common path does not send a message or allocate. Validated writers call
 * before taking a slot address; callbacks never retain pointers across growth. */
static void moxi_ensure_table_capacity(int required) {
    MoxiWindowState *owner = moxi_current_context();
    if (required > owner->tableCapacity) [owner ensureTableCapacity:required];
}

#define moxi_ordered_paint_enabled (moxi_current_context()->moxi_ordered_paint_enabled)
#define moxi_ordered_paint_count (moxi_current_context()->moxi_ordered_paint_count)
#define moxi_ordered_paint_kinds (moxi_current_context()->moxi_ordered_paint_kinds)
#define moxi_ordered_paint_slots (moxi_current_context()->moxi_ordered_paint_slots)
#define moxi_window (moxi_current_context()->moxi_window)
#define moxi_delegate (moxi_current_context()->moxi_delegate)
#define moxi_canvas (moxi_current_context()->moxi_canvas)
#define moxi_window_opened (moxi_current_context()->moxi_window_opened)
#define moxi_click_pending (moxi_current_context()->moxi_click_pending)
#define moxi_last_click_x (moxi_current_context()->moxi_last_click_x)
#define moxi_last_click_y (moxi_current_context()->moxi_last_click_y)
#define moxi_mouse_is_down (moxi_current_context()->moxi_mouse_is_down)
#define moxi_mouse_dragging (moxi_current_context()->moxi_mouse_dragging)
#define moxi_last_pointer_x (moxi_current_context()->moxi_last_pointer_x)
#define moxi_last_pointer_y (moxi_current_context()->moxi_last_pointer_y)
#define moxi_event_queue (moxi_current_context()->moxi_event_queue)
#define moxi_event_queue_head (moxi_current_context()->moxi_event_queue_head)
#define moxi_event_queue_tail (moxi_current_context()->moxi_event_queue_tail)
#define moxi_event_queue_count (moxi_current_context()->moxi_event_queue_count)
#define moxi_waiting_for_event (moxi_current_context()->moxi_waiting_for_event)
#define moxi_event_dropped_count (moxi_current_context()->moxi_event_dropped_count)
#define moxi_event_kind (moxi_current_context()->moxi_event_kind)
#define moxi_event_key (moxi_current_context()->moxi_event_key)
#define moxi_event_modifiers (moxi_current_context()->moxi_event_modifiers)
#define moxi_event_codepoint (moxi_current_context()->moxi_event_codepoint)
#define moxi_event_text_value (moxi_current_context()->moxi_event_text_value)
#define moxi_event_selection_start (moxi_current_context()->moxi_event_selection_start)
#define moxi_event_selection_end (moxi_current_context()->moxi_event_selection_end)
#define moxi_event_x (moxi_current_context()->moxi_event_x)
#define moxi_event_y (moxi_current_context()->moxi_event_y)
#define moxi_event_scroll_x (moxi_current_context()->moxi_event_scroll_x)
#define moxi_event_scroll_y (moxi_current_context()->moxi_event_scroll_y)
#define moxi_event_target (moxi_current_context()->moxi_event_target)
#define moxi_event_action (moxi_current_context()->moxi_event_action)
#define moxi_current_event_receipt_ns (moxi_current_context()->moxi_current_event_receipt_ns)
#define moxi_current_event_queue_depth (moxi_current_context()->moxi_current_event_queue_depth)
#define moxi_interpreting_modifiers (moxi_current_context()->moxi_interpreting_modifiers)
#define moxi_marked_text (moxi_current_context()->moxi_marked_text)
#define moxi_marked_selection_start (moxi_current_context()->moxi_marked_selection_start)
#define moxi_marked_selection_end (moxi_current_context()->moxi_marked_selection_end)
#define moxi_last_canvas_width (moxi_current_context()->moxi_last_canvas_width)
#define moxi_last_canvas_height (moxi_current_context()->moxi_last_canvas_height)
#define moxi_last_canvas_scale (moxi_current_context()->moxi_last_canvas_scale)
#define moxi_clipboard_value (moxi_current_context()->moxi_clipboard_value)
#define moxi_native_timing_active (moxi_current_context()->moxi_native_timing_active)
#define moxi_native_timing (moxi_current_context()->moxi_native_timing)
#define moxi_native_timing_output (moxi_current_context()->moxi_native_timing_output)
#define moxi_label_count (moxi_current_context()->moxi_label_count)
#define moxi_command_overflow_count (moxi_current_context()->moxi_command_overflow_count)
#define moxi_label_texts (moxi_current_context()->moxi_label_texts)
#define moxi_label_paragraphs (moxi_current_context()->moxi_label_paragraphs)
#define moxi_label_frames (moxi_current_context()->moxi_label_frames)
#define moxi_label_fills (moxi_current_context()->moxi_label_fills)
#define moxi_label_radii (moxi_current_context()->moxi_label_radii)
#define moxi_label_badges (moxi_current_context()->moxi_label_badges)
#define moxi_label_padding (moxi_current_context()->moxi_label_padding)
#define moxi_label_text_colors (moxi_current_context()->moxi_label_text_colors)
#define moxi_label_font_sizes (moxi_current_context()->moxi_label_font_sizes)
#define moxi_label_wraps (moxi_current_context()->moxi_label_wraps)
#define moxi_label_clip_enabled (moxi_current_context()->moxi_label_clip_enabled)
#define moxi_label_clip_frames (moxi_current_context()->moxi_label_clip_frames)
#define moxi_button_count (moxi_current_context()->moxi_button_count)
#define moxi_button_texts (moxi_current_context()->moxi_button_texts)
#define moxi_button_frames (moxi_current_context()->moxi_button_frames)
#define moxi_button_fill_colors (moxi_current_context()->moxi_button_fill_colors)
#define moxi_button_text_colors (moxi_current_context()->moxi_button_text_colors)
#define moxi_button_radii (moxi_current_context()->moxi_button_radii)
#define moxi_button_borders (moxi_current_context()->moxi_button_borders)
#define moxi_button_border_widths (moxi_current_context()->moxi_button_border_widths)
#define moxi_button_font_sizes (moxi_current_context()->moxi_button_font_sizes)
#define moxi_button_wraps (moxi_current_context()->moxi_button_wraps)
#define moxi_button_clip_enabled (moxi_current_context()->moxi_button_clip_enabled)
#define moxi_button_clip_frames (moxi_current_context()->moxi_button_clip_frames)
#define moxi_button_focused (moxi_current_context()->moxi_button_focused)
#define moxi_button_hovered (moxi_current_context()->moxi_button_hovered)
#define moxi_button_pressed (moxi_current_context()->moxi_button_pressed)
#define moxi_button_enabled (moxi_current_context()->moxi_button_enabled)
#define moxi_checkbox_count (moxi_current_context()->moxi_checkbox_count)
#define moxi_checkbox_texts (moxi_current_context()->moxi_checkbox_texts)
#define moxi_checkbox_frames (moxi_current_context()->moxi_checkbox_frames)
#define moxi_checkbox_fill_colors (moxi_current_context()->moxi_checkbox_fill_colors)
#define moxi_checkbox_text_colors (moxi_current_context()->moxi_checkbox_text_colors)
#define moxi_checkbox_radii (moxi_current_context()->moxi_checkbox_radii)
#define moxi_checkbox_font_sizes (moxi_current_context()->moxi_checkbox_font_sizes)
#define moxi_checkbox_clip_enabled (moxi_current_context()->moxi_checkbox_clip_enabled)
#define moxi_checkbox_clip_frames (moxi_current_context()->moxi_checkbox_clip_frames)
#define moxi_checkbox_focused (moxi_current_context()->moxi_checkbox_focused)
#define moxi_checkbox_hovered (moxi_current_context()->moxi_checkbox_hovered)
#define moxi_checkbox_pressed (moxi_current_context()->moxi_checkbox_pressed)
#define moxi_checkbox_enabled (moxi_current_context()->moxi_checkbox_enabled)
#define moxi_checkbox_checked (moxi_current_context()->moxi_checkbox_checked)
#define moxi_progress_count (moxi_current_context()->moxi_progress_count)
#define moxi_progress_texts (moxi_current_context()->moxi_progress_texts)
#define moxi_progress_frames (moxi_current_context()->moxi_progress_frames)
#define moxi_progress_fill_colors (moxi_current_context()->moxi_progress_fill_colors)
#define moxi_progress_text_colors (moxi_current_context()->moxi_progress_text_colors)
#define moxi_progress_radii (moxi_current_context()->moxi_progress_radii)
#define moxi_progress_font_sizes (moxi_current_context()->moxi_progress_font_sizes)
#define moxi_progress_values (moxi_current_context()->moxi_progress_values)
#define moxi_progress_clip_enabled (moxi_current_context()->moxi_progress_clip_enabled)
#define moxi_progress_clip_frames (moxi_current_context()->moxi_progress_clip_frames)
#define moxi_slider_count (moxi_current_context()->moxi_slider_count)
#define moxi_slider_slots (moxi_current_context()->moxi_slider_slots)
#define moxi_toggle_count (moxi_current_context()->moxi_toggle_count)
#define moxi_toggle_slots (moxi_current_context()->moxi_toggle_slots)
#define moxi_text_input_count (moxi_current_context()->moxi_text_input_count)
#define moxi_text_input_texts (moxi_current_context()->moxi_text_input_texts)
#define moxi_text_input_frames (moxi_current_context()->moxi_text_input_frames)
#define moxi_text_input_fill_colors (moxi_current_context()->moxi_text_input_fill_colors)
#define moxi_text_input_text_colors (moxi_current_context()->moxi_text_input_text_colors)
#define moxi_text_input_radii (moxi_current_context()->moxi_text_input_radii)
#define moxi_text_input_font_sizes (moxi_current_context()->moxi_text_input_font_sizes)
#define moxi_text_input_wraps (moxi_current_context()->moxi_text_input_wraps)
#define moxi_text_input_clip_enabled (moxi_current_context()->moxi_text_input_clip_enabled)
#define moxi_text_input_clip_frames (moxi_current_context()->moxi_text_input_clip_frames)
#define moxi_text_input_focused (moxi_current_context()->moxi_text_input_focused)
#define moxi_text_input_cursors (moxi_current_context()->moxi_text_input_cursors)
#define moxi_text_input_selection_starts (moxi_current_context()->moxi_text_input_selection_starts)
#define moxi_text_input_selection_ends (moxi_current_context()->moxi_text_input_selection_ends)
#define moxi_text_input_compositions (moxi_current_context()->moxi_text_input_compositions)
#define moxi_text_input_composition_selection_starts (moxi_current_context()->moxi_text_input_composition_selection_starts)
#define moxi_text_input_composition_selection_ends (moxi_current_context()->moxi_text_input_composition_selection_ends)
#define moxi_image_count (moxi_current_context()->moxi_image_count)
#define moxi_image_resource_ids (moxi_current_context()->moxi_image_resource_ids)
#define moxi_image_resources (moxi_current_context()->moxi_image_resources)
#define moxi_image_nearest (moxi_current_context()->moxi_image_nearest)
#define moxi_registered_image_ids (moxi_current_context()->moxi_registered_image_ids)
#define moxi_registered_images (moxi_current_context()->moxi_registered_images)
#define moxi_image_alt_texts (moxi_current_context()->moxi_image_alt_texts)
#define moxi_image_frames (moxi_current_context()->moxi_image_frames)
#define moxi_image_fill_colors (moxi_current_context()->moxi_image_fill_colors)
#define moxi_image_text_colors (moxi_current_context()->moxi_image_text_colors)
#define moxi_image_radii (moxi_current_context()->moxi_image_radii)
#define moxi_image_clip_enabled (moxi_current_context()->moxi_image_clip_enabled)
#define moxi_image_clip_frames (moxi_current_context()->moxi_image_clip_frames)
#define moxi_active_text_input_index (moxi_current_context()->moxi_active_text_input_index)
#define moxi_retained_text_editor_key (moxi_current_context()->moxi_retained_text_editor_key)
#define moxi_native_text_editor_seen (moxi_current_context()->moxi_native_text_editor_seen)
#define moxi_surface_fill (moxi_current_context()->moxi_surface_fill)
#define moxi_panel_count (moxi_current_context()->moxi_panel_count)
#define moxi_panel_frames (moxi_current_context()->moxi_panel_frames)
#define moxi_panel_fills (moxi_current_context()->moxi_panel_fills)
#define moxi_panel_radii (moxi_current_context()->moxi_panel_radii)
#define moxi_panel_clip_enabled (moxi_current_context()->moxi_panel_clip_enabled)
#define moxi_panel_clip_frames (moxi_current_context()->moxi_panel_clip_frames)
#define moxi_native_widget_count (moxi_current_context()->moxi_native_widget_count)
#define moxi_native_widget_slots (moxi_current_context()->moxi_native_widget_slots)
#define moxi_scrollbar_count (moxi_current_context()->moxi_scrollbar_count)
#define moxi_scrollbar_slots (moxi_current_context()->moxi_scrollbar_slots)
#define moxi_custom_line_count (moxi_current_context()->moxi_custom_line_count)
#define moxi_custom_line_starts (moxi_current_context()->moxi_custom_line_starts)
#define moxi_custom_line_ends (moxi_current_context()->moxi_custom_line_ends)
#define moxi_custom_line_colors (moxi_current_context()->moxi_custom_line_colors)
#define moxi_custom_line_widths (moxi_current_context()->moxi_custom_line_widths)
#define moxi_custom_circle_count (moxi_current_context()->moxi_custom_circle_count)
#define moxi_custom_circle_centers (moxi_current_context()->moxi_custom_circle_centers)
#define moxi_custom_circle_radii (moxi_current_context()->moxi_custom_circle_radii)
#define moxi_custom_circle_fills (moxi_current_context()->moxi_custom_circle_fills)
#define moxi_custom_circle_strokes (moxi_current_context()->moxi_custom_circle_strokes)
#define moxi_custom_circle_stroke_widths (moxi_current_context()->moxi_custom_circle_stroke_widths)
#define moxi_custom_rect_count (moxi_current_context()->moxi_custom_rect_count)
#define moxi_custom_rect_frames (moxi_current_context()->moxi_custom_rect_frames)
#define moxi_custom_rect_fills (moxi_current_context()->moxi_custom_rect_fills)
#define moxi_custom_rect_strokes (moxi_current_context()->moxi_custom_rect_strokes)
#define moxi_custom_rect_stroke_widths (moxi_current_context()->moxi_custom_rect_stroke_widths)
#define moxi_custom_rect_radii (moxi_current_context()->moxi_custom_rect_radii)
#define moxi_custom_text_count (moxi_current_context()->moxi_custom_text_count)
#define moxi_custom_texts (moxi_current_context()->moxi_custom_texts)
#define moxi_custom_text_frames (moxi_current_context()->moxi_custom_text_frames)
#define moxi_custom_text_colors (moxi_current_context()->moxi_custom_text_colors)
#define moxi_custom_text_font_sizes (moxi_current_context()->moxi_custom_text_font_sizes)
#define moxi_custom_bitmap_count (moxi_current_context()->moxi_custom_bitmap_count)
#define moxi_custom_bitmaps (moxi_current_context()->moxi_custom_bitmaps)
#define moxi_custom_bitmap_frames (moxi_current_context()->moxi_custom_bitmap_frames)
#define moxi_custom_bitmap_opacities (moxi_current_context()->moxi_custom_bitmap_opacities)
#define moxi_custom_bitmap_clip_enabled (moxi_current_context()->moxi_custom_bitmap_clip_enabled)
#define moxi_custom_bitmap_clip_frames (moxi_current_context()->moxi_custom_bitmap_clip_frames)
#define moxi_custom_clip_enabled (moxi_current_context()->moxi_custom_clip_enabled)
#define moxi_custom_clip_frame (moxi_current_context()->moxi_custom_clip_frame)
#define moxi_custom_paint_cache_enabled (moxi_current_context()->moxi_custom_paint_cache_enabled)
#define moxi_custom_paint_cache_valid (moxi_current_context()->moxi_custom_paint_cache_valid)
#define moxi_custom_paint_cache_bitmap (moxi_current_context()->moxi_custom_paint_cache_bitmap)
#define moxi_custom_paint_cache_bounds (moxi_current_context()->moxi_custom_paint_cache_bounds)
#define moxi_custom_paint_cache_scale (moxi_current_context()->moxi_custom_paint_cache_scale)
#define moxi_custom_paint_cache_build_count (moxi_current_context()->moxi_custom_paint_cache_build_count)
#define moxi_custom_paint_cache_hit_count (moxi_current_context()->moxi_custom_paint_cache_hit_count)
#define moxi_current_clip_enabled (moxi_current_context()->moxi_current_clip_enabled)
#define moxi_current_clip_frame (moxi_current_context()->moxi_current_clip_frame)
#define moxi_accessibility_count (moxi_current_context()->moxi_accessibility_count)
#define moxi_accessibility_ids (moxi_current_context()->moxi_accessibility_ids)
#define moxi_accessibility_parent_ids (moxi_current_context()->moxi_accessibility_parent_ids)
#define moxi_accessibility_roles (moxi_current_context()->moxi_accessibility_roles)
#define moxi_accessibility_labels (moxi_current_context()->moxi_accessibility_labels)
#define moxi_accessibility_values (moxi_current_context()->moxi_accessibility_values)
#define moxi_accessibility_hints (moxi_current_context()->moxi_accessibility_hints)
#define moxi_accessibility_frames (moxi_current_context()->moxi_accessibility_frames)
#define moxi_accessibility_enabled (moxi_current_context()->moxi_accessibility_enabled)
#define moxi_accessibility_focused (moxi_current_context()->moxi_accessibility_focused)
#define moxi_accessibility_selected (moxi_current_context()->moxi_accessibility_selected)
#define moxi_accessibility_checked (moxi_current_context()->moxi_accessibility_checked)
#define moxi_accessibility_expanded (moxi_current_context()->moxi_accessibility_expanded)
#define moxi_accessibility_has_value_range (moxi_current_context()->moxi_accessibility_has_value_range)
#define moxi_accessibility_value_min (moxi_current_context()->moxi_accessibility_value_min)
#define moxi_accessibility_value_max (moxi_current_context()->moxi_accessibility_value_max)
#define moxi_accessibility_value_now (moxi_current_context()->moxi_accessibility_value_now)
#define moxi_accessibility_actions (moxi_current_context()->moxi_accessibility_actions)
#define moxi_accessibility_elements (moxi_current_context()->moxi_accessibility_elements)
#define moxi_accessibility_owned_elements (moxi_current_context()->moxi_accessibility_owned_elements)
#define moxi_accessibility_root_children (moxi_current_context()->moxi_accessibility_root_children)
#define moxi_retained_accessibility_elements (moxi_current_context()->moxi_retained_accessibility_elements)
#define moxi_accessibility_focused_text_input (moxi_current_context()->moxi_accessibility_focused_text_input)
#define moxi_accessibility_has_previous_snapshot (moxi_current_context()->moxi_accessibility_has_previous_snapshot)
#define moxi_previous_accessibility_count (moxi_current_context()->moxi_previous_accessibility_count)
#define moxi_previous_accessibility_ids (moxi_current_context()->moxi_previous_accessibility_ids)
#define moxi_previous_accessibility_roles (moxi_current_context()->moxi_previous_accessibility_roles)
#define moxi_previous_accessibility_values (moxi_current_context()->moxi_previous_accessibility_values)
#define moxi_previous_accessibility_checked (moxi_current_context()->moxi_previous_accessibility_checked)
#define moxi_previous_accessibility_expanded (moxi_current_context()->moxi_previous_accessibility_expanded)
#define moxi_previous_accessibility_selected (moxi_current_context()->moxi_previous_accessibility_selected)
#define moxi_previous_accessibility_enabled (moxi_current_context()->moxi_previous_accessibility_enabled)
#define moxi_previous_accessibility_focused (moxi_current_context()->moxi_previous_accessibility_focused)
#define moxi_previous_accessibility_has_value_range (moxi_current_context()->moxi_previous_accessibility_has_value_range)
#define moxi_previous_accessibility_value_min (moxi_current_context()->moxi_previous_accessibility_value_min)
#define moxi_previous_accessibility_value_max (moxi_current_context()->moxi_previous_accessibility_value_max)
#define moxi_previous_accessibility_value_now (moxi_current_context()->moxi_previous_accessibility_value_now)
