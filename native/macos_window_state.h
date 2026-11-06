/* Instance-owned storage for the AppKit ABI. Included after slot types.
 * The current context is only a main-thread dispatch cursor; no draw/event
 * payload is shared. Cocoa callbacks save/restore it, including nested calls.
 */
@interface MoxiWindowState : NSObject {
@public
    BOOL retired;
    NSMenu *menu;
    NSInteger menuResult;
    NSAlert *dialog;
    /* Opt-in retained submission order; legacy hosts keep their original order. */
    BOOL moxi_ordered_paint_enabled;
    int moxi_ordered_paint_count;
    int moxi_ordered_paint_kinds[MOXI_MAX_DRAW_COMMANDS + 1];
    int moxi_ordered_paint_slots[MOXI_MAX_DRAW_COMMANDS + 1];
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
    NSString *moxi_label_texts[MOXI_MAX_DRAW_COMMANDS];
    id<MoxiParagraphDrawing> moxi_label_paragraphs[MOXI_MAX_DRAW_COMMANDS];
    NSRect moxi_label_frames[MOXI_MAX_DRAW_COMMANDS];
    float moxi_label_text_colors[MOXI_MAX_DRAW_COMMANDS][4];
    float moxi_label_font_sizes[MOXI_MAX_DRAW_COMMANDS];
    BOOL moxi_label_wraps[MOXI_MAX_DRAW_COMMANDS];
    BOOL moxi_label_clip_enabled[MOXI_MAX_DRAW_COMMANDS];
    NSRect moxi_label_clip_frames[MOXI_MAX_DRAW_COMMANDS];
    int moxi_button_count;
    NSString *moxi_button_texts[MOXI_MAX_DRAW_COMMANDS];
    NSRect moxi_button_frames[MOXI_MAX_DRAW_COMMANDS];
    float moxi_button_fill_colors[MOXI_MAX_DRAW_COMMANDS][4];
    float moxi_button_text_colors[MOXI_MAX_DRAW_COMMANDS][4];
    float moxi_button_radii[MOXI_MAX_DRAW_COMMANDS];
    float moxi_button_font_sizes[MOXI_MAX_DRAW_COMMANDS];
    BOOL moxi_button_wraps[MOXI_MAX_DRAW_COMMANDS];
    BOOL moxi_button_clip_enabled[MOXI_MAX_DRAW_COMMANDS];
    NSRect moxi_button_clip_frames[MOXI_MAX_DRAW_COMMANDS];
    BOOL moxi_button_focused[MOXI_MAX_DRAW_COMMANDS];
    BOOL moxi_button_hovered[MOXI_MAX_DRAW_COMMANDS];
    BOOL moxi_button_pressed[MOXI_MAX_DRAW_COMMANDS];
    BOOL moxi_button_enabled[MOXI_MAX_DRAW_COMMANDS];
    int moxi_checkbox_count;
    NSString *moxi_checkbox_texts[MOXI_MAX_DRAW_COMMANDS];
    NSRect moxi_checkbox_frames[MOXI_MAX_DRAW_COMMANDS];
    float moxi_checkbox_fill_colors[MOXI_MAX_DRAW_COMMANDS][4];
    float moxi_checkbox_text_colors[MOXI_MAX_DRAW_COMMANDS][4];
    float moxi_checkbox_radii[MOXI_MAX_DRAW_COMMANDS];
    float moxi_checkbox_font_sizes[MOXI_MAX_DRAW_COMMANDS];
    BOOL moxi_checkbox_clip_enabled[MOXI_MAX_DRAW_COMMANDS];
    NSRect moxi_checkbox_clip_frames[MOXI_MAX_DRAW_COMMANDS];
    BOOL moxi_checkbox_focused[MOXI_MAX_DRAW_COMMANDS];
    BOOL moxi_checkbox_hovered[MOXI_MAX_DRAW_COMMANDS];
    BOOL moxi_checkbox_pressed[MOXI_MAX_DRAW_COMMANDS];
    BOOL moxi_checkbox_enabled[MOXI_MAX_DRAW_COMMANDS];
    BOOL moxi_checkbox_checked[MOXI_MAX_DRAW_COMMANDS];
    int moxi_progress_count;
    NSString *moxi_progress_texts[MOXI_MAX_DRAW_COMMANDS];
    NSRect moxi_progress_frames[MOXI_MAX_DRAW_COMMANDS];
    float moxi_progress_fill_colors[MOXI_MAX_DRAW_COMMANDS][4];
    float moxi_progress_text_colors[MOXI_MAX_DRAW_COMMANDS][4];
    float moxi_progress_radii[MOXI_MAX_DRAW_COMMANDS];
    float moxi_progress_font_sizes[MOXI_MAX_DRAW_COMMANDS];
    float moxi_progress_values[MOXI_MAX_DRAW_COMMANDS];
    BOOL moxi_progress_clip_enabled[MOXI_MAX_DRAW_COMMANDS];
    NSRect moxi_progress_clip_frames[MOXI_MAX_DRAW_COMMANDS];
    int moxi_slider_count;
    MoxiSliderSlot moxi_slider_slots[MOXI_MAX_DRAW_COMMANDS];
    int moxi_toggle_count;
    MoxiToggleSlot moxi_toggle_slots[MOXI_MAX_DRAW_COMMANDS];
    int moxi_text_input_count;
    NSString *moxi_text_input_texts[MOXI_MAX_DRAW_COMMANDS];
    NSRect moxi_text_input_frames[MOXI_MAX_DRAW_COMMANDS];
    float moxi_text_input_fill_colors[MOXI_MAX_DRAW_COMMANDS][4];
    float moxi_text_input_text_colors[MOXI_MAX_DRAW_COMMANDS][4];
    float moxi_text_input_radii[MOXI_MAX_DRAW_COMMANDS];
    float moxi_text_input_font_sizes[MOXI_MAX_DRAW_COMMANDS];
    BOOL moxi_text_input_wraps[MOXI_MAX_DRAW_COMMANDS];
    BOOL moxi_text_input_clip_enabled[MOXI_MAX_DRAW_COMMANDS];
    NSRect moxi_text_input_clip_frames[MOXI_MAX_DRAW_COMMANDS];
    BOOL moxi_text_input_focused[MOXI_MAX_DRAW_COMMANDS];
    int moxi_text_input_cursors[MOXI_MAX_DRAW_COMMANDS];
    int moxi_text_input_selection_starts[MOXI_MAX_DRAW_COMMANDS];
    int moxi_text_input_selection_ends[MOXI_MAX_DRAW_COMMANDS];
    NSString *moxi_text_input_compositions[MOXI_MAX_DRAW_COMMANDS];
    int moxi_text_input_composition_selection_starts[MOXI_MAX_DRAW_COMMANDS];
    int moxi_text_input_composition_selection_ends[MOXI_MAX_DRAW_COMMANDS];
    int moxi_image_count;
    int moxi_image_resource_ids[MOXI_MAX_DRAW_COMMANDS];
    NSImage *moxi_image_resources[MOXI_MAX_DRAW_COMMANDS];
    int moxi_registered_image_ids[MOXI_MAX_DRAW_COMMANDS];
    NSImage *moxi_registered_images[MOXI_MAX_DRAW_COMMANDS];
    NSString *moxi_image_alt_texts[MOXI_MAX_DRAW_COMMANDS];
    NSRect moxi_image_frames[MOXI_MAX_DRAW_COMMANDS];
    float moxi_image_fill_colors[MOXI_MAX_DRAW_COMMANDS][4];
    float moxi_image_text_colors[MOXI_MAX_DRAW_COMMANDS][4];
    float moxi_image_radii[MOXI_MAX_DRAW_COMMANDS];
    BOOL moxi_image_clip_enabled[MOXI_MAX_DRAW_COMMANDS];
    NSRect moxi_image_clip_frames[MOXI_MAX_DRAW_COMMANDS];
    int moxi_active_text_input_index;
    int moxi_retained_text_editor_key;
    BOOL moxi_native_text_editor_seen;
    float moxi_surface_fill[4];
    int moxi_panel_count;
    NSRect moxi_panel_frames[MOXI_MAX_DRAW_COMMANDS];
    float moxi_panel_fills[MOXI_MAX_DRAW_COMMANDS][4];
    float moxi_panel_radii[MOXI_MAX_DRAW_COMMANDS];
    BOOL moxi_panel_clip_enabled[MOXI_MAX_DRAW_COMMANDS];
    NSRect moxi_panel_clip_frames[MOXI_MAX_DRAW_COMMANDS];
    int moxi_native_widget_count;
    MoxiNativeWidgetSlot moxi_native_widget_slots[MOXI_MAX_DRAW_COMMANDS];
    int moxi_scrollbar_count;
    MoxiScrollbarSlot moxi_scrollbar_slots[MOXI_MAX_DRAW_COMMANDS];
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
    int moxi_accessibility_ids[MOXI_MAX_DRAW_COMMANDS];
    int moxi_accessibility_parent_ids[MOXI_MAX_DRAW_COMMANDS];
    int moxi_accessibility_roles[MOXI_MAX_DRAW_COMMANDS];
    NSString *moxi_accessibility_labels[MOXI_MAX_DRAW_COMMANDS];
    NSString *moxi_accessibility_values[MOXI_MAX_DRAW_COMMANDS];
    NSString *moxi_accessibility_hints[MOXI_MAX_DRAW_COMMANDS];
    NSRect moxi_accessibility_frames[MOXI_MAX_DRAW_COMMANDS];
    BOOL moxi_accessibility_enabled[MOXI_MAX_DRAW_COMMANDS];
    BOOL moxi_accessibility_focused[MOXI_MAX_DRAW_COMMANDS];
    BOOL moxi_accessibility_selected[MOXI_MAX_DRAW_COMMANDS];
    BOOL moxi_accessibility_checked[MOXI_MAX_DRAW_COMMANDS];
    BOOL moxi_accessibility_expanded[MOXI_MAX_DRAW_COMMANDS];
    BOOL moxi_accessibility_has_value_range[MOXI_MAX_DRAW_COMMANDS];
    float moxi_accessibility_value_min[MOXI_MAX_DRAW_COMMANDS];
    float moxi_accessibility_value_max[MOXI_MAX_DRAW_COMMANDS];
    float moxi_accessibility_value_now[MOXI_MAX_DRAW_COMMANDS];
    int moxi_accessibility_actions[MOXI_MAX_DRAW_COMMANDS];
    NSAccessibilityElement *moxi_accessibility_elements[MOXI_MAX_DRAW_COMMANDS];
    NSMutableArray *moxi_accessibility_owned_elements;
    NSMutableArray *moxi_accessibility_root_children;
    /* Preserve AX identity only for this window's active semantic keys. */
    NSDictionary<NSNumber *, MoxiAccessibilityElement *> *moxi_retained_accessibility_elements;
    BOOL moxi_accessibility_focused_text_input;
    BOOL moxi_accessibility_has_previous_snapshot;
    int moxi_previous_accessibility_count;
    int moxi_previous_accessibility_ids[MOXI_MAX_DRAW_COMMANDS];
    int moxi_previous_accessibility_roles[MOXI_MAX_DRAW_COMMANDS];
    NSString *moxi_previous_accessibility_values[MOXI_MAX_DRAW_COMMANDS];
    BOOL moxi_previous_accessibility_checked[MOXI_MAX_DRAW_COMMANDS];
    BOOL moxi_previous_accessibility_expanded[MOXI_MAX_DRAW_COMMANDS];
    BOOL moxi_previous_accessibility_selected[MOXI_MAX_DRAW_COMMANDS];
    BOOL moxi_previous_accessibility_enabled[MOXI_MAX_DRAW_COMMANDS];
    BOOL moxi_previous_accessibility_focused[MOXI_MAX_DRAW_COMMANDS];
    BOOL moxi_previous_accessibility_has_value_range[MOXI_MAX_DRAW_COMMANDS];
    float moxi_previous_accessibility_value_min[MOXI_MAX_DRAW_COMMANDS];
    float moxi_previous_accessibility_value_max[MOXI_MAX_DRAW_COMMANDS];
    float moxi_previous_accessibility_value_now[MOXI_MAX_DRAW_COMMANDS];
}
@end
@implementation MoxiWindowState
- (instancetype)init {
    self = [super init];
    if (self) {
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
