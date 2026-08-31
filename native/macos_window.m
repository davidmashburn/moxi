#import <Cocoa/Cocoa.h>

@interface MoxiWindowDelegate : NSObject <NSWindowDelegate>
@end

@interface MoxiCanvasView : NSView <NSTextInputClient>
@end

@interface MoxiAccessibilityElement : NSAccessibilityElement
@property(nonatomic) int moxiIdentifier;
@property(nonatomic, strong) NSMutableArray *moxiChildren;
@end

#define MOXI_MAX_DRAW_COMMANDS 128
#define MOXI_EVENT_QUEUE_CAPACITY 64

#define MOXI_EVENT_NONE 0
#define MOXI_EVENT_POINTER_DOWN 1
#define MOXI_EVENT_KEY_DOWN 2
#define MOXI_EVENT_TEXT_INPUT 3
#define MOXI_EVENT_WINDOW_RESIZED 4
#define MOXI_EVENT_POINTER_UP 5
#define MOXI_EVENT_POINTER_MOVE 6
#define MOXI_EVENT_CLICK 7
#define MOXI_EVENT_COMPOSITION_UPDATE 8
#define MOXI_EVENT_COMPOSITION_END 9
#define MOXI_EVENT_SCROLL 11
#define MOXI_EVENT_DRAG_BEGIN 12
#define MOXI_EVENT_DRAG_UPDATE 13
#define MOXI_EVENT_DROP 14
#define MOXI_EVENT_POINTER_CANCEL 19
#define MOXI_EVENT_ACTION 20

#define MOXI_MOD_SHIFT 1
#define MOXI_MOD_COMMAND 2
#define MOXI_MOD_CONTROL 4
#define MOXI_MOD_OPTION 8

#define MOXI_KEY_TAB 9
#define MOXI_KEY_ENTER 13
#define MOXI_KEY_ESCAPE 27
#define MOXI_KEY_SPACE 32
#define MOXI_KEY_BACKSPACE 8
#define MOXI_KEY_DELETE 127
#define MOXI_KEY_LEFT 1000
#define MOXI_KEY_RIGHT 1001
#define MOXI_KEY_UP 1002
#define MOXI_KEY_DOWN 1003
#define MOXI_KEY_HOME 1004
#define MOXI_KEY_END 1005
#define MOXI_KEY_C 99
#define MOXI_KEY_V 118
#define MOXI_KEY_X 120

#define MOXI_ACTION_PRESS 1
#define MOXI_ACTION_INCREMENT 2
#define MOXI_ACTION_DECREMENT 4
#define MOXI_ACTION_SELECT 8
#define MOXI_ACTION_EXPAND 16
#define MOXI_ACTION_COLLAPSE 32

#define MOXI_ROLE_LABEL 1
#define MOXI_ROLE_BUTTON 2
#define MOXI_ROLE_TEXT_INPUT 3
#define MOXI_ROLE_SPACER 4
#define MOXI_ROLE_CONTAINER 5
#define MOXI_ROLE_CHECKBOX 6
#define MOXI_ROLE_PROGRESS_INDICATOR 7
#define MOXI_ROLE_SLIDER 8
#define MOXI_ROLE_SWITCH 9
#define MOXI_ROLE_RADIO 10
#define MOXI_ROLE_IMAGE 11
#define MOXI_ROLE_TEXT_AREA 12
#define MOXI_ROLE_COMBO_BOX 13
#define MOXI_ROLE_LIST 14
#define MOXI_ROLE_TABLE 15
#define MOXI_ROLE_TREE 16
#define MOXI_ROLE_MENU 17
#define MOXI_ROLE_DIALOG 18
#define MOXI_ROLE_TAB_GROUP 19
#define MOXI_ROLE_CANVAS 20
#define MOXI_ROLE_SEPARATOR 21

static NSWindow *moxi_window;
static MoxiWindowDelegate *moxi_delegate;
static MoxiCanvasView *moxi_canvas;
static BOOL moxi_window_opened;
static NSTask *moxi_demo_task;

static BOOL moxi_click_pending;
static float moxi_last_click_x;
static float moxi_last_click_y;
static BOOL moxi_mouse_is_down;
static BOOL moxi_mouse_dragging;
static float moxi_last_pointer_x;
static float moxi_last_pointer_y;

typedef struct {
    int kind;
    int key;
    int modifiers;
    int codepoint;
    int selectionStart;
    int selectionEnd;
    float x;
    float y;
    float scrollX;
    float scrollY;
    int target;
    int action;
    NSString *text;
} MoxiQueuedEvent;

typedef struct {
    NSString *text;
    NSRect frame;
    float fill[4];
    float textColor[4];
    float radius;
    float fontSize;
    float value;
    BOOL focused;
    BOOL hovered;
    BOOL pressed;
    BOOL enabled;
    BOOL clipEnabled;
    NSRect clipFrame;
} MoxiSliderSlot;

typedef struct {
    NSString *text;
    NSRect frame;
    float fill[4];
    float textColor[4];
    float radius;
    float fontSize;
    BOOL focused;
    BOOL hovered;
    BOOL pressed;
    BOOL enabled;
    BOOL checked;
    BOOL radio;
    BOOL clipEnabled;
    NSRect clipFrame;
} MoxiToggleSlot;

static MoxiQueuedEvent moxi_event_queue[MOXI_EVENT_QUEUE_CAPACITY];
static int moxi_event_queue_head;
static int moxi_event_queue_tail;
static int moxi_event_queue_count;
static int moxi_event_dropped_count;
static int moxi_event_kind;
static int moxi_event_key;
static int moxi_event_modifiers;
static int moxi_event_codepoint;
static NSString *moxi_event_text_value;
static int moxi_event_selection_start;
static int moxi_event_selection_end;
static float moxi_event_x;
static float moxi_event_y;
static float moxi_event_scroll_x;
static float moxi_event_scroll_y;
static int moxi_event_target;
static int moxi_event_action;
static int moxi_interpreting_modifiers;
static NSString *moxi_marked_text;
static int moxi_marked_selection_start;
static int moxi_marked_selection_end;

static CGFloat moxi_last_canvas_width;
static CGFloat moxi_last_canvas_height;
static NSString *moxi_clipboard_value;

static int moxi_label_count;
static int moxi_command_overflow_count;
static NSString *moxi_label_texts[MOXI_MAX_DRAW_COMMANDS];
static NSRect moxi_label_frames[MOXI_MAX_DRAW_COMMANDS];
static float moxi_label_text_colors[MOXI_MAX_DRAW_COMMANDS][4];
static float moxi_label_font_sizes[MOXI_MAX_DRAW_COMMANDS];
static BOOL moxi_label_wraps[MOXI_MAX_DRAW_COMMANDS];
static BOOL moxi_label_clip_enabled[MOXI_MAX_DRAW_COMMANDS];
static NSRect moxi_label_clip_frames[MOXI_MAX_DRAW_COMMANDS];

static int moxi_button_count;
static NSString *moxi_button_texts[MOXI_MAX_DRAW_COMMANDS];
static NSRect moxi_button_frames[MOXI_MAX_DRAW_COMMANDS];
static float moxi_button_fill_colors[MOXI_MAX_DRAW_COMMANDS][4];
static float moxi_button_text_colors[MOXI_MAX_DRAW_COMMANDS][4];
static float moxi_button_radii[MOXI_MAX_DRAW_COMMANDS];
static float moxi_button_font_sizes[MOXI_MAX_DRAW_COMMANDS];
static BOOL moxi_button_wraps[MOXI_MAX_DRAW_COMMANDS];
static BOOL moxi_button_clip_enabled[MOXI_MAX_DRAW_COMMANDS];
static NSRect moxi_button_clip_frames[MOXI_MAX_DRAW_COMMANDS];
static BOOL moxi_button_focused[MOXI_MAX_DRAW_COMMANDS];
static BOOL moxi_button_hovered[MOXI_MAX_DRAW_COMMANDS];
static BOOL moxi_button_pressed[MOXI_MAX_DRAW_COMMANDS];
static BOOL moxi_button_enabled[MOXI_MAX_DRAW_COMMANDS];

static int moxi_checkbox_count;
static NSString *moxi_checkbox_texts[MOXI_MAX_DRAW_COMMANDS];
static NSRect moxi_checkbox_frames[MOXI_MAX_DRAW_COMMANDS];
static float moxi_checkbox_fill_colors[MOXI_MAX_DRAW_COMMANDS][4];
static float moxi_checkbox_text_colors[MOXI_MAX_DRAW_COMMANDS][4];
static float moxi_checkbox_radii[MOXI_MAX_DRAW_COMMANDS];
static float moxi_checkbox_font_sizes[MOXI_MAX_DRAW_COMMANDS];
static BOOL moxi_checkbox_clip_enabled[MOXI_MAX_DRAW_COMMANDS];
static NSRect moxi_checkbox_clip_frames[MOXI_MAX_DRAW_COMMANDS];
static BOOL moxi_checkbox_focused[MOXI_MAX_DRAW_COMMANDS];
static BOOL moxi_checkbox_hovered[MOXI_MAX_DRAW_COMMANDS];
static BOOL moxi_checkbox_pressed[MOXI_MAX_DRAW_COMMANDS];
static BOOL moxi_checkbox_enabled[MOXI_MAX_DRAW_COMMANDS];
static BOOL moxi_checkbox_checked[MOXI_MAX_DRAW_COMMANDS];

static int moxi_progress_count;
static NSString *moxi_progress_texts[MOXI_MAX_DRAW_COMMANDS];
static NSRect moxi_progress_frames[MOXI_MAX_DRAW_COMMANDS];
static float moxi_progress_fill_colors[MOXI_MAX_DRAW_COMMANDS][4];
static float moxi_progress_text_colors[MOXI_MAX_DRAW_COMMANDS][4];
static float moxi_progress_radii[MOXI_MAX_DRAW_COMMANDS];
static float moxi_progress_font_sizes[MOXI_MAX_DRAW_COMMANDS];
static float moxi_progress_values[MOXI_MAX_DRAW_COMMANDS];
static BOOL moxi_progress_clip_enabled[MOXI_MAX_DRAW_COMMANDS];
static NSRect moxi_progress_clip_frames[MOXI_MAX_DRAW_COMMANDS];

static int moxi_slider_count;
static MoxiSliderSlot moxi_slider_slots[MOXI_MAX_DRAW_COMMANDS];
static int moxi_toggle_count;
static MoxiToggleSlot moxi_toggle_slots[MOXI_MAX_DRAW_COMMANDS];

static int moxi_text_input_count;
static NSString *moxi_text_input_texts[MOXI_MAX_DRAW_COMMANDS];
static NSRect moxi_text_input_frames[MOXI_MAX_DRAW_COMMANDS];
static float moxi_text_input_fill_colors[MOXI_MAX_DRAW_COMMANDS][4];
static float moxi_text_input_text_colors[MOXI_MAX_DRAW_COMMANDS][4];
static float moxi_text_input_radii[MOXI_MAX_DRAW_COMMANDS];
static float moxi_text_input_font_sizes[MOXI_MAX_DRAW_COMMANDS];
static BOOL moxi_text_input_wraps[MOXI_MAX_DRAW_COMMANDS];
static BOOL moxi_text_input_clip_enabled[MOXI_MAX_DRAW_COMMANDS];
static NSRect moxi_text_input_clip_frames[MOXI_MAX_DRAW_COMMANDS];
static BOOL moxi_text_input_focused[MOXI_MAX_DRAW_COMMANDS];
static int moxi_text_input_cursors[MOXI_MAX_DRAW_COMMANDS];
static int moxi_text_input_selection_starts[MOXI_MAX_DRAW_COMMANDS];
static int moxi_text_input_selection_ends[MOXI_MAX_DRAW_COMMANDS];
static NSString *moxi_text_input_compositions[MOXI_MAX_DRAW_COMMANDS];
static int moxi_text_input_composition_selection_starts[MOXI_MAX_DRAW_COMMANDS];
static int moxi_text_input_composition_selection_ends[MOXI_MAX_DRAW_COMMANDS];

static int moxi_image_count;
static int moxi_image_resource_ids[MOXI_MAX_DRAW_COMMANDS];
static NSImage *moxi_image_resources[MOXI_MAX_DRAW_COMMANDS];
static int moxi_registered_image_ids[MOXI_MAX_DRAW_COMMANDS];
static NSImage *moxi_registered_images[MOXI_MAX_DRAW_COMMANDS];
static NSString *moxi_image_alt_texts[MOXI_MAX_DRAW_COMMANDS];
static NSRect moxi_image_frames[MOXI_MAX_DRAW_COMMANDS];
static float moxi_image_fill_colors[MOXI_MAX_DRAW_COMMANDS][4];
static float moxi_image_text_colors[MOXI_MAX_DRAW_COMMANDS][4];
static float moxi_image_radii[MOXI_MAX_DRAW_COMMANDS];
static BOOL moxi_image_clip_enabled[MOXI_MAX_DRAW_COMMANDS];
static NSRect moxi_image_clip_frames[MOXI_MAX_DRAW_COMMANDS];
static int moxi_active_text_input_index;

static float moxi_surface_fill[4];
static int moxi_panel_count;
static NSRect moxi_panel_frames[MOXI_MAX_DRAW_COMMANDS];
static float moxi_panel_fills[MOXI_MAX_DRAW_COMMANDS][4];
static float moxi_panel_radii[MOXI_MAX_DRAW_COMMANDS];
static BOOL moxi_panel_clip_enabled[MOXI_MAX_DRAW_COMMANDS];
static NSRect moxi_panel_clip_frames[MOXI_MAX_DRAW_COMMANDS];

typedef struct {
    NSString *text;
    NSRect frame;
    float fill[4];
    float textColor[4];
    float radius;
    float fontSize;
    int kind;
    BOOL focused;
    BOOL enabled;
    BOOL selected;
    BOOL expanded;
    BOOL clipEnabled;
    NSRect clipFrame;
} MoxiNativeWidgetSlot;

static int moxi_native_widget_count;
static MoxiNativeWidgetSlot moxi_native_widget_slots[MOXI_MAX_DRAW_COMMANDS];

static BOOL moxi_current_clip_enabled;
static NSRect moxi_current_clip_frame;

static int moxi_accessibility_count;
static int moxi_accessibility_ids[MOXI_MAX_DRAW_COMMANDS];
static int moxi_accessibility_parent_ids[MOXI_MAX_DRAW_COMMANDS];
static int moxi_accessibility_roles[MOXI_MAX_DRAW_COMMANDS];
static NSString *moxi_accessibility_labels[MOXI_MAX_DRAW_COMMANDS];
static NSString *moxi_accessibility_values[MOXI_MAX_DRAW_COMMANDS];
static NSString *moxi_accessibility_hints[MOXI_MAX_DRAW_COMMANDS];
static NSRect moxi_accessibility_frames[MOXI_MAX_DRAW_COMMANDS];
static BOOL moxi_accessibility_enabled[MOXI_MAX_DRAW_COMMANDS];
static BOOL moxi_accessibility_focused[MOXI_MAX_DRAW_COMMANDS];
static BOOL moxi_accessibility_selected[MOXI_MAX_DRAW_COMMANDS];
static int moxi_accessibility_actions[MOXI_MAX_DRAW_COMMANDS];
static NSAccessibilityElement *moxi_accessibility_elements[MOXI_MAX_DRAW_COMMANDS];
static NSMutableArray *moxi_accessibility_owned_elements;
static NSMutableArray *moxi_accessibility_root_children;
static BOOL moxi_accessibility_focused_text_input;
static BOOL moxi_accessibility_has_previous_snapshot;
static int moxi_previous_accessibility_count;
static int moxi_previous_accessibility_ids[MOXI_MAX_DRAW_COMMANDS];
static int moxi_previous_accessibility_roles[MOXI_MAX_DRAW_COMMANDS];
static NSString *moxi_previous_accessibility_values[MOXI_MAX_DRAW_COMMANDS];

static void moxi_queue_accessibility_click(int id);
static void moxi_queue_semantic_action(int target, int action);

static void moxi_copy_color(float destination[4], float red, float green, float blue, float alpha) {
    destination[0] = red;
    destination[1] = green;
    destination[2] = blue;
    destination[3] = alpha;
}

static NSColor *moxi_color(const float color[4]) {
    return [NSColor colorWithCalibratedRed:color[0]
                                     green:color[1]
                                      blue:color[2]
                                     alpha:color[3]];
}

static void moxi_begin_clip(BOOL enabled, NSRect frame) {
    if (enabled) {
        [NSGraphicsContext saveGraphicsState];
        NSRectClip(frame);
    }
}

static void moxi_end_clip(BOOL enabled) {
    if (enabled) {
        [NSGraphicsContext restoreGraphicsState];
    }
}

static NSAccessibilityRole moxi_accessibility_role(int role) {
    switch (role) {
        case MOXI_ROLE_BUTTON:
            return NSAccessibilityButtonRole;
        case MOXI_ROLE_TEXT_INPUT:
            return NSAccessibilityTextFieldRole;
        case MOXI_ROLE_CONTAINER:
            return NSAccessibilityGroupRole;
        case MOXI_ROLE_CHECKBOX:
            return NSAccessibilityCheckBoxRole;
        case MOXI_ROLE_PROGRESS_INDICATOR:
            return NSAccessibilityProgressIndicatorRole;
        case MOXI_ROLE_SLIDER:
            return NSAccessibilitySliderRole;
        case MOXI_ROLE_SWITCH:
            return NSAccessibilityCheckBoxRole;
        case MOXI_ROLE_RADIO:
            return NSAccessibilityRadioButtonRole;
        case MOXI_ROLE_IMAGE:
            return NSAccessibilityImageRole;
        case MOXI_ROLE_TEXT_AREA:
            return NSAccessibilityTextAreaRole;
        case MOXI_ROLE_COMBO_BOX:
            return NSAccessibilityComboBoxRole;
        case MOXI_ROLE_LIST:
            return NSAccessibilityListRole;
        case MOXI_ROLE_TABLE:
            return NSAccessibilityTableRole;
        case MOXI_ROLE_TREE:
            return NSAccessibilityOutlineRole;
        case MOXI_ROLE_MENU:
            return NSAccessibilityMenuRole;
        case MOXI_ROLE_DIALOG:
            return NSAccessibilityGroupRole;
        case MOXI_ROLE_TAB_GROUP:
            return NSAccessibilityTabGroupRole;
        case MOXI_ROLE_CANVAS:
            return NSAccessibilityGroupRole;
        case MOXI_ROLE_SEPARATOR:
            return NSAccessibilitySplitterRole;
        case MOXI_ROLE_LABEL:
        default:
            return NSAccessibilityStaticTextRole;
    }
}

static NSAccessibilityElement *moxi_accessibility_element_for_id(int id) {
    for (int i = 0; i < moxi_accessibility_count; i++) {
        if (moxi_accessibility_ids[i] == id) {
            return moxi_accessibility_elements[i];
        }
    }
    return nil;
}

static int moxi_accessibility_index_for_id(int id) {
    for (int i = 0; i < moxi_accessibility_count; i++) {
        if (moxi_accessibility_ids[i] == id) {
            return i;
        }
    }
    return -1;
}

static int moxi_previous_accessibility_index_for_id(int id) {
    if (!moxi_accessibility_has_previous_snapshot) {
        return -1;
    }
    for (int i = 0; i < moxi_previous_accessibility_count; i++) {
        if (moxi_previous_accessibility_ids[i] == id) {
            return i;
        }
    }
    return -1;
}

static void moxi_accessibility_capture_previous(void) {
    moxi_accessibility_has_previous_snapshot = moxi_accessibility_count > 0;
    moxi_previous_accessibility_count = moxi_accessibility_count;
    for (int i = 0; i < moxi_accessibility_count; i++) {
        moxi_previous_accessibility_ids[i] = moxi_accessibility_ids[i];
        moxi_previous_accessibility_roles[i] = moxi_accessibility_roles[i];
        moxi_previous_accessibility_values[i] = moxi_accessibility_values[i] == nil
            ? @""
            : [moxi_accessibility_values[i] copy];
    }
}

static void moxi_accessibility_reset_storage(void) {
    moxi_accessibility_count = 0;
    moxi_accessibility_focused_text_input = NO;
    moxi_accessibility_owned_elements = [[NSMutableArray alloc] initWithCapacity:MOXI_MAX_DRAW_COMMANDS];
    moxi_accessibility_root_children = [[NSMutableArray alloc] initWithCapacity:MOXI_MAX_DRAW_COMMANDS];
    for (int i = 0; i < MOXI_MAX_DRAW_COMMANDS; i++) {
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
        moxi_accessibility_actions[i] = 0;
        moxi_accessibility_elements[i] = nil;
    }
}

static void moxi_accessibility_build_elements(void) {
    if (moxi_canvas == nil) {
        return;
    }
    [moxi_accessibility_owned_elements removeAllObjects];
    [moxi_accessibility_root_children removeAllObjects];

    for (int i = 0; i < moxi_accessibility_count; i++) {
        NSRect screenFrame = NSAccessibilityFrameInView(
            moxi_canvas,
            moxi_accessibility_frames[i]
        );
        NSString *label = moxi_accessibility_labels[i] == nil
            ? @""
            : moxi_accessibility_labels[i];
        MoxiAccessibilityElement *element = [[MoxiAccessibilityElement alloc] init];
        element.moxiChildren = [[NSMutableArray alloc] init];
        [element setAccessibilityElement:YES];
        [element setAccessibilityFrame:screenFrame];
        [element setAccessibilityRole:moxi_accessibility_role(moxi_accessibility_roles[i])];
        [element setAccessibilityLabel:label];
        [element setAccessibilityParent:nil];
        element.moxiIdentifier = moxi_accessibility_ids[i];
        moxi_accessibility_elements[i] = element;
        [moxi_accessibility_owned_elements addObject:element];
        [element setAccessibilityIdentifier:[NSString stringWithFormat:@"moxi-%d", moxi_accessibility_ids[i]]];
        [element setAccessibilityEnabled:moxi_accessibility_enabled[i]];
        [element setAccessibilityFocused:moxi_accessibility_focused[i]];
        [element setAccessibilitySelected:moxi_accessibility_selected[i]];
        if (moxi_accessibility_values[i] != nil) {
            [element setAccessibilityValue:moxi_accessibility_values[i]];
        }
        if (moxi_accessibility_hints[i] != nil &&
            [moxi_accessibility_hints[i] length] > 0) {
            [element setAccessibilityHelp:moxi_accessibility_hints[i]];
        }
    }

    for (int i = 0; i < moxi_accessibility_count; i++) {
        NSAccessibilityElement *element = moxi_accessibility_elements[i];
        int parentID = moxi_accessibility_parent_ids[i];
        NSAccessibilityElement *parent = moxi_accessibility_element_for_id(parentID);
        if (parent == nil) {
            [element setAccessibilityParent:moxi_canvas];
            [moxi_accessibility_root_children addObject:element];
        } else {
            [element setAccessibilityParent:parent];
            if ([parent isKindOfClass:[MoxiAccessibilityElement class]]) {
                MoxiAccessibilityElement *parentElement =
                    (MoxiAccessibilityElement *)parent;
                [parentElement.moxiChildren addObject:element];
            }
        }
    }
    [moxi_canvas setNeedsDisplay:YES];

    if (moxi_accessibility_has_previous_snapshot) {
        for (int i = 0; i < moxi_accessibility_count; i++) {
            int previous = moxi_previous_accessibility_index_for_id(
                moxi_accessibility_ids[i]
            );
            if (previous < 0 ||
                moxi_previous_accessibility_roles[previous] != moxi_accessibility_roles[i]) {
                continue;
            }
            NSString *previousValue = moxi_previous_accessibility_values[previous] == nil
                ? @""
                : moxi_previous_accessibility_values[previous];
            NSString *currentValue = moxi_accessibility_values[i] == nil
                ? @""
                : moxi_accessibility_values[i];
            if (![previousValue isEqualToString:currentValue]) {
                NSAccessibilityPostNotification(
                    moxi_accessibility_elements[i],
                    NSAccessibilityValueChangedNotification
                );
            }
        }
    }
    moxi_accessibility_has_previous_snapshot = NO;
}

static NSUInteger moxi_utf16_index_for_codepoint(NSString *text, int cursor) {
    NSUInteger index = 0;
    int codepoints = 0;
    NSUInteger length = [text length];
    while (index < length && codepoints < cursor) {
        unichar value = [text characterAtIndex:index];
        if (value >= 0xD800 && value <= 0xDBFF && index + 1 < length) {
            unichar low = [text characterAtIndex:index + 1];
            if (low >= 0xDC00 && low <= 0xDFFF) {
                index += 2;
                codepoints += 1;
                continue;
            }
        }
        index += 1;
        codepoints += 1;
    }
    return index;
}

static int moxi_first_codepoint(NSString *text) {
    if ([text length] == 0) {
        return -1;
    }
    unichar high = [text characterAtIndex:0];
    if (high >= 0xD800 && high <= 0xDBFF && [text length] > 1) {
        unichar low = [text characterAtIndex:1];
        if (low >= 0xDC00 && low <= 0xDFFF) {
            return 0x10000 + ((high - 0xD800) << 10) + (low - 0xDC00);
        }
    }
    return (int)high;
}

static BOOL moxi_has_pending_events(void) {
    return moxi_event_queue_count > 0;
}

static void moxi_reset_event_queue(void) {
    for (int i = 0; i < MOXI_EVENT_QUEUE_CAPACITY; i++) {
        moxi_event_queue[i].kind = MOXI_EVENT_NONE;
        moxi_event_queue[i].key = 0;
        moxi_event_queue[i].modifiers = 0;
        moxi_event_queue[i].codepoint = -1;
        moxi_event_queue[i].selectionStart = -1;
        moxi_event_queue[i].selectionEnd = -1;
        moxi_event_queue[i].x = 0.0;
        moxi_event_queue[i].y = 0.0;
        moxi_event_queue[i].scrollX = 0.0;
        moxi_event_queue[i].scrollY = 0.0;
        moxi_event_queue[i].target = -1;
        moxi_event_queue[i].action = -1;
        moxi_event_queue[i].text = nil;
    }
    moxi_event_queue_head = 0;
    moxi_event_queue_tail = 0;
    moxi_event_queue_count = 0;
    moxi_event_dropped_count = 0;
    moxi_event_kind = MOXI_EVENT_NONE;
    moxi_event_key = 0;
    moxi_event_modifiers = 0;
    moxi_event_codepoint = -1;
    moxi_event_selection_start = -1;
    moxi_event_selection_end = -1;
    moxi_event_text_value = nil;
    moxi_event_x = 0.0;
    moxi_event_y = 0.0;
    moxi_event_scroll_x = 0.0;
    moxi_event_scroll_y = 0.0;
    moxi_event_target = -1;
    moxi_event_action = -1;
}

static BOOL moxi_enqueue_event(
    int kind,
    int key,
    int modifiers,
    int codepoint,
    NSString *text,
    int selectionStart,
    int selectionEnd,
    float x,
    float y,
    float scrollX,
    float scrollY
) {
    if (moxi_event_queue_count >= MOXI_EVENT_QUEUE_CAPACITY) {
        moxi_event_dropped_count += 1;
        return NO;
    }
    MoxiQueuedEvent *queued = &moxi_event_queue[moxi_event_queue_tail];
    queued->kind = kind;
    queued->key = key;
    queued->modifiers = modifiers;
    queued->codepoint = codepoint;
    queued->selectionStart = selectionStart;
    queued->selectionEnd = selectionEnd;
    queued->x = x;
    queued->y = y;
    queued->scrollX = scrollX;
    queued->scrollY = scrollY;
    queued->target = -1;
    queued->action = -1;
    queued->text = text == nil ? nil : [text copy];
    moxi_event_queue_tail =
        (moxi_event_queue_tail + 1) % MOXI_EVENT_QUEUE_CAPACITY;
    moxi_event_queue_count += 1;
    return YES;
}

static void moxi_queue_event(int kind) {
    moxi_enqueue_event(
        kind,
        moxi_event_key,
        moxi_event_modifiers,
        moxi_event_codepoint,
        moxi_event_text_value,
        moxi_event_selection_start,
        moxi_event_selection_end,
        moxi_event_x,
        moxi_event_y,
        0.0,
        0.0
    );
}

static void moxi_queue_accessibility_click(int id) {
    if (moxi_canvas == nil) {
        return;
    }
    for (int i = 0; i < moxi_accessibility_count; i++) {
        if (moxi_accessibility_ids[i] == id &&
            (moxi_accessibility_actions[i] & MOXI_ACTION_PRESS) != 0 &&
            moxi_accessibility_enabled[i]) {
            NSRect frame = moxi_accessibility_frames[i];
            moxi_event_x = NSMidX(frame);
            moxi_event_y = NSMidY(frame);
            moxi_last_click_x = moxi_event_x;
            moxi_last_click_y = moxi_event_y;
            moxi_queue_event(MOXI_EVENT_CLICK);
            return;
        }
    }
}

static void moxi_queue_semantic_action(int target, int action) {
    if (moxi_canvas == nil || target < 0) {
        return;
    }
    if (moxi_event_queue_count >= MOXI_EVENT_QUEUE_CAPACITY) {
        moxi_event_dropped_count += 1;
        return;
    }
    MoxiQueuedEvent *queued = &moxi_event_queue[moxi_event_queue_tail];
    queued->kind = MOXI_EVENT_ACTION;
    queued->key = 0;
    queued->modifiers = 0;
    queued->codepoint = -1;
    queued->selectionStart = -1;
    queued->selectionEnd = -1;
    queued->x = 0.0;
    queued->y = 0.0;
    queued->scrollX = 0.0;
    queued->scrollY = 0.0;
    queued->target = target;
    queued->action = action;
    queued->text = nil;
    moxi_event_queue_tail =
        (moxi_event_queue_tail + 1) % MOXI_EVENT_QUEUE_CAPACITY;
    moxi_event_queue_count += 1;
}

static int moxi_event_modifiers_for_flags(NSEventModifierFlags flags) {
    int modifiers = 0;
    if ((flags & NSEventModifierFlagShift) != 0) {
        modifiers |= MOXI_MOD_SHIFT;
    }
    if ((flags & NSEventModifierFlagCommand) != 0) {
        modifiers |= MOXI_MOD_COMMAND;
    }
    if ((flags & NSEventModifierFlagControl) != 0) {
        modifiers |= MOXI_MOD_CONTROL;
    }
    if ((flags & NSEventModifierFlagOption) != 0) {
        modifiers |= MOXI_MOD_OPTION;
    }
    return modifiers;
}

static void moxi_reset_commands(void) {
    moxi_label_count = 0;
    moxi_button_count = 0;
    moxi_checkbox_count = 0;
    moxi_progress_count = 0;
    moxi_text_input_count = 0;
    moxi_image_count = 0;
    moxi_slider_count = 0;
    moxi_toggle_count = 0;
    moxi_command_overflow_count = 0;
    moxi_current_clip_enabled = NO;
    moxi_current_clip_frame = NSZeroRect;
    moxi_active_text_input_index = -1;
    moxi_panel_count = 0;
    moxi_native_widget_count = 0;
    moxi_copy_color(moxi_surface_fill, 0.08, 0.10, 0.16, 1.0);
    for (int i = 0; i < MOXI_MAX_DRAW_COMMANDS; i++) {
        moxi_label_texts[i] = nil;
        moxi_button_texts[i] = nil;
        moxi_checkbox_texts[i] = nil;
        moxi_progress_texts[i] = nil;
        moxi_text_input_texts[i] = nil;
        moxi_image_alt_texts[i] = nil;
        moxi_image_resources[i] = nil;
        moxi_image_resource_ids[i] = -1;
        moxi_label_frames[i] = NSZeroRect;
        moxi_button_frames[i] = NSZeroRect;
        moxi_checkbox_frames[i] = NSZeroRect;
        moxi_progress_frames[i] = NSZeroRect;
        moxi_text_input_frames[i] = NSZeroRect;
        moxi_image_frames[i] = NSZeroRect;
        moxi_image_clip_enabled[i] = NO;
        moxi_image_clip_frames[i] = NSZeroRect;
        moxi_panel_frames[i] = NSZeroRect;
        moxi_copy_color(moxi_panel_fills[i], 0.16, 0.20, 0.30, 1.0);
        moxi_panel_radii[i] = 0.0;
        moxi_panel_clip_enabled[i] = NO;
        moxi_panel_clip_frames[i] = NSZeroRect;
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

        moxi_copy_color(moxi_label_text_colors[i], 1.0, 1.0, 1.0, 1.0);
        moxi_label_font_sizes[i] = 24.0;
        moxi_label_wraps[i] = NO;
        moxi_label_clip_enabled[i] = NO;
        moxi_label_clip_frames[i] = NSZeroRect;

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

        moxi_copy_color(moxi_progress_fill_colors[i], 0.10, 0.14, 0.22, 1.0);
        moxi_copy_color(moxi_progress_text_colors[i], 1.0, 1.0, 1.0, 1.0);
        moxi_progress_radii[i] = 8.0;
        moxi_progress_font_sizes[i] = 14.0;
        moxi_progress_values[i] = 0.0;
        moxi_progress_clip_enabled[i] = NO;
        moxi_progress_clip_frames[i] = NSZeroRect;

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

        moxi_copy_color(moxi_image_fill_colors[i], 0.12, 0.15, 0.22, 1.0);
        moxi_copy_color(moxi_image_text_colors[i], 1.0, 1.0, 1.0, 1.0);
        moxi_image_radii[i] = 4.0;
    }
}

static NSUInteger moxi_advance_codepoint(NSString *text, NSUInteger index) {
    if (index + 1 < [text length]) {
        unichar high = [text characterAtIndex:index];
        unichar low = [text characterAtIndex:index + 1];
        if (high >= 0xD800 && high <= 0xDBFF && low >= 0xDC00 && low <= 0xDFFF) {
            return index + 2;
        }
    }
    return index + 1;
}

static int moxi_codepoint_index_for_utf16(NSString *text, NSUInteger target) {
    NSUInteger index = 0;
    int codepoints = 0;
    NSUInteger length = [text length];
    if (target > length) {
        target = length;
    }
    while (index < target) {
        NSUInteger next = moxi_advance_codepoint(text, index);
        if (next > target) {
            index = target;
            break;
        }
        index = next;
        codepoints += 1;
    }
    return codepoints;
}

static NSString *moxi_input_string(id value) {
    if ([value isKindOfClass:[NSAttributedString class]]) {
        return [(NSAttributedString *)value string];
    }
    if ([value isKindOfClass:[NSString class]]) {
        return (NSString *)value;
    }
    return @"";
}

static void moxi_queue_text_event(
    int kind,
    NSString *text,
    int selectionStart,
    int selectionEnd
) {
    moxi_enqueue_event(
        kind,
        0,
        moxi_interpreting_modifiers,
        moxi_first_codepoint(text),
        text,
        selectionStart,
        selectionEnd,
        0.0,
        0.0,
        0.0,
        0.0
    );
}

static void moxi_queue_key_event(int key) {
    moxi_event_key = key;
    moxi_event_modifiers = moxi_interpreting_modifiers;
    moxi_queue_event(MOXI_EVENT_KEY_DOWN);
}

static void moxi_clear_marked_text(void) {
    moxi_marked_text = nil;
    moxi_marked_selection_start = 0;
    moxi_marked_selection_end = 0;
}

static NSString *moxi_active_text_input_text(void) {
    if (moxi_active_text_input_index < 0 ||
        moxi_active_text_input_index >= moxi_text_input_count ||
        moxi_text_input_texts[moxi_active_text_input_index] == nil) {
        return @"";
    }
    return moxi_text_input_texts[moxi_active_text_input_index];
}

static NSRange moxi_active_selected_range(void) {
    if (moxi_active_text_input_index < 0 ||
        moxi_active_text_input_index >= moxi_text_input_count) {
        return NSMakeRange(0, 0);
    }
    NSString *text = moxi_active_text_input_text();
    NSUInteger start = moxi_utf16_index_for_codepoint(
        text,
        moxi_text_input_selection_starts[moxi_active_text_input_index]
    );
    NSUInteger end = moxi_utf16_index_for_codepoint(
        text,
        moxi_text_input_selection_ends[moxi_active_text_input_index]
    );
    return NSMakeRange(start, end - start);
}

static NSRect moxi_active_caret_rect_at_utf16(NSUInteger cursor) {
    if (moxi_canvas == nil ||
        moxi_canvas.window == nil ||
        moxi_active_text_input_index < 0 ||
        moxi_active_text_input_index >= moxi_text_input_count) {
        return NSZeroRect;
    }
    NSString *text = moxi_active_text_input_text();
    cursor = MIN(cursor, [text length]);
    NSString *prefix = [text substringToIndex:cursor];
    NSDictionary *attributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:
            moxi_text_input_font_sizes[moxi_active_text_input_index]],
    };
    NSRect frame = moxi_text_input_frames[moxi_active_text_input_index];
    CGFloat x = frame.origin.x + 10.0 + [prefix sizeWithAttributes:attributes].width;
    NSRect localRect = NSMakeRect(x, frame.origin.y + 6.0, 1.0, frame.size.height - 12.0);
    NSRect windowRect = [moxi_canvas convertRect:localRect toView:nil];
    return [moxi_canvas.window convertRectToScreen:windowRect];
}

void moxi_clipboard_set(const char *text) {
    @autoreleasepool {
        NSString *value = text == NULL
            ? @""
            : [NSString stringWithUTF8String:text];
        if (value == nil) {
            value = @"";
        }
        NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
        [pasteboard clearContents];
        [pasteboard setString:value forType:NSPasteboardTypeString];
        moxi_clipboard_value = value;
    }
}

int moxi_clipboard_codepoint_at(int target) {
    @autoreleasepool {
        if (target < 0) {
            return -1;
        }
        NSString *value = [[NSPasteboard generalPasteboard]
            stringForType:NSPasteboardTypeString];
        if (value == nil) {
            value = @"";
        }
        moxi_clipboard_value = value;

        NSUInteger index = 0;
        int current = 0;
        while (index < [value length] && current < target) {
            index = moxi_advance_codepoint(value, index);
            current += 1;
        }
        if (current != target || index >= [value length]) {
            return -1;
        }
        unichar high = [value characterAtIndex:index];
        if (high >= 0xD800 && high <= 0xDBFF && index + 1 < [value length]) {
            unichar low = [value characterAtIndex:index + 1];
            if (low >= 0xDC00 && low <= 0xDFFF) {
                return 0x10000 + ((high - 0xD800) << 10) + (low - 0xDC00);
            }
        }
        return (int)high;
    }
}

@implementation MoxiAccessibilityElement
- (NSArray *)accessibilityChildren {
    return self.moxiChildren == nil ? @[] : self.moxiChildren;
}

- (NSArray *)accessibilityChildrenInNavigationOrder {
    return [self accessibilityChildren];
}

- (id)accessibilityAttributeValue:(NSAccessibilityAttributeName)attribute {
    if ([attribute isEqualToString:NSAccessibilityChildrenAttribute] ||
        [attribute isEqualToString:NSAccessibilityChildrenInNavigationOrderAttribute]) {
        return [self accessibilityChildren];
    }
    return [super accessibilityAttributeValue:attribute];
}

- (NSArray *)accessibilityActionNames {
    int index = moxi_accessibility_index_for_id(self.moxiIdentifier);
    if (index < 0 || !self.accessibilityEnabled) {
        return @[];
    }
    int actions = moxi_accessibility_actions[index];
    NSMutableArray *names = [NSMutableArray array];
    if ((actions & MOXI_ACTION_PRESS) != 0) {
        [names addObject:@"AXPress"];
    }
    if ((actions & MOXI_ACTION_INCREMENT) != 0) {
        [names addObject:@"AXIncrement"];
    }
    if ((actions & MOXI_ACTION_DECREMENT) != 0) {
        [names addObject:@"AXDecrement"];
    }
    if ((actions & MOXI_ACTION_SELECT) != 0) {
        [names addObject:@"AXPick"];
    }
    if ((actions & MOXI_ACTION_EXPAND) != 0) {
        [names addObject:@"AXExpand"];
    }
    if ((actions & MOXI_ACTION_COLLAPSE) != 0) {
        [names addObject:@"AXCollapse"];
    }
    return names;
}

- (void)accessibilityPerformAction:(NSString *)action {
    int index = moxi_accessibility_index_for_id(self.moxiIdentifier);
    if (index < 0 || !self.accessibilityEnabled) {
        return;
    }
    int actions = moxi_accessibility_actions[index];
    if ([action isEqualToString:@"AXPress"] &&
        (actions & MOXI_ACTION_PRESS) != 0) {
        moxi_queue_accessibility_click(self.moxiIdentifier);
    } else if ([action isEqualToString:@"AXPick"] &&
               (actions & MOXI_ACTION_SELECT) != 0) {
        moxi_queue_accessibility_click(self.moxiIdentifier);
    } else if ([action isEqualToString:@"AXIncrement"] &&
               (actions & MOXI_ACTION_INCREMENT) != 0) {
        moxi_queue_semantic_action(self.moxiIdentifier, MOXI_ACTION_INCREMENT);
    } else if ([action isEqualToString:@"AXDecrement"] &&
               (actions & MOXI_ACTION_DECREMENT) != 0) {
        moxi_queue_semantic_action(self.moxiIdentifier, MOXI_ACTION_DECREMENT);
    } else if ([action isEqualToString:@"AXExpand"] &&
               (actions & MOXI_ACTION_EXPAND) != 0) {
        moxi_queue_semantic_action(self.moxiIdentifier, MOXI_ACTION_EXPAND);
    } else if ([action isEqualToString:@"AXCollapse"] &&
               (actions & MOXI_ACTION_COLLAPSE) != 0) {
        moxi_queue_semantic_action(self.moxiIdentifier, MOXI_ACTION_COLLAPSE);
    }
}

- (BOOL)accessibilityPerformPress {
    int index = moxi_accessibility_index_for_id(self.moxiIdentifier);
    if (index >= 0 &&
        (moxi_accessibility_actions[index] & MOXI_ACTION_PRESS) != 0 &&
        self.accessibilityEnabled) {
        moxi_queue_accessibility_click(self.moxiIdentifier);
        return YES;
    }
    return NO;
}
@end

@implementation MoxiWindowDelegate
- (void)windowWillClose:(NSNotification *)notification {
    moxi_window_opened = NO;
    [NSApp stop:nil];
}
@end

@implementation MoxiCanvasView
- (BOOL)isFlipped {
    return YES;
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (BOOL)isAccessibilityElement {
    return YES;
}

- (NSAccessibilityRole)accessibilityRole {
    return NSAccessibilityGroupRole;
}

- (NSString *)accessibilityLabel {
    return @"Moxi content";
}

- (NSArray *)accessibilityChildren {
    return moxi_accessibility_root_children == nil
        ? @[]
        : moxi_accessibility_root_children;
}

- (NSArray *)accessibilityChildrenInNavigationOrder {
    return [self accessibilityChildren];
}

- (id)accessibilityFocusedUIElement {
    for (int i = 0; i < moxi_accessibility_count; i++) {
        if (moxi_accessibility_focused[i]) {
            return moxi_accessibility_elements[i];
        }
    }
    return nil;
}

- (id)accessibilityHitTest:(NSPoint)point {
    for (int i = 0; i < moxi_accessibility_count; i++) {
        if (NSPointInRect(point, [moxi_accessibility_elements[i] accessibilityFrame])) {
            return moxi_accessibility_elements[i];
        }
    }
    return self;
}

static void moxi_draw_native_widget(MoxiNativeWidgetSlot slot) {
    moxi_begin_clip(slot.clipEnabled, slot.clipFrame);
    NSRect frame = slot.frame;
    float fill[4] = {
        slot.fill[0], slot.fill[1], slot.fill[2], slot.fill[3]
    };
    if (!slot.enabled) {
        fill[0] = 0.30;
        fill[1] = 0.33;
        fill[2] = 0.40;
    } else if (slot.selected) {
        fill[0] += (1.0 - fill[0]) * 0.14;
        fill[1] += (1.0 - fill[1]) * 0.14;
        fill[2] += (1.0 - fill[2]) * 0.14;
    }
    if (slot.kind != 17) {
        [moxi_color(fill) setFill];
        [[NSBezierPath bezierPathWithRoundedRect:frame
                                          xRadius:slot.radius
                                          yRadius:slot.radius] fill];
    }

    if (slot.kind == 17) {
        [moxi_color(slot.textColor) setStroke];
        NSBezierPath *separator = [NSBezierPath bezierPath];
        [separator moveToPoint:NSMakePoint(NSMinX(frame), NSMidY(frame))];
        [separator lineToPoint:NSMakePoint(NSMaxX(frame), NSMidY(frame))];
        [separator setLineWidth:1.0];
        [separator stroke];
    } else if (slot.kind == 10) {
        NSDictionary *attributes = @{
            NSFontAttributeName: [NSFont systemFontOfSize:slot.fontSize],
            NSForegroundColorAttributeName: moxi_color(slot.textColor),
        };
        [slot.text drawInRect:NSMakeRect(
            NSMinX(frame) + 10.0,
            NSMinY(frame),
            MAX(0.0, frame.size.width - 30.0),
            frame.size.height
        ) withAttributes:attributes];
        [moxi_color(slot.textColor) setFill];
        NSBezierPath *arrow = [NSBezierPath bezierPath];
        [arrow moveToPoint:NSMakePoint(NSMaxX(frame) - 18.0, NSMidY(frame) - 3.0)];
        [arrow lineToPoint:NSMakePoint(NSMaxX(frame) - 8.0, NSMidY(frame) - 3.0)];
        [arrow lineToPoint:NSMakePoint(NSMaxX(frame) - 13.0, NSMidY(frame) + 4.0)];
        [arrow closePath];
        [arrow fill];
    } else {
        NSDictionary *attributes = @{
            NSFontAttributeName: [NSFont systemFontOfSize:slot.fontSize],
            NSForegroundColorAttributeName: moxi_color(slot.textColor),
        };
        CGFloat inset = (slot.kind == 15 || slot.kind == 16) ? 12.0 : 8.0;
        [slot.text drawInRect:NSInsetRect(frame, inset, 3.0)
                  withAttributes:attributes];
        if (slot.kind == 11 || slot.kind == 12 || slot.kind == 13 || slot.kind == 14) {
            [[NSColor colorWithCalibratedWhite:1.0 alpha:0.12] setStroke];
            NSBezierPath *row = [NSBezierPath bezierPath];
            CGFloat rowHeight = MAX(12.0, frame.size.height / 4.0);
            for (int rowIndex = 1; rowIndex < 4; rowIndex++) {
                CGFloat y = NSMinY(frame) + rowHeight * rowIndex;
                [row moveToPoint:NSMakePoint(NSMinX(frame) + 6.0, y)];
                [row lineToPoint:NSMakePoint(NSMaxX(frame) - 6.0, y)];
            }
            if (slot.kind == 12) {
                CGFloat columnWidth = frame.size.width / 3.0;
                for (int column = 1; column < 3; column++) {
                    CGFloat x = NSMinX(frame) + columnWidth * column;
                    [row moveToPoint:NSMakePoint(x, NSMinY(frame) + 4.0)];
                    [row lineToPoint:NSMakePoint(x, NSMaxY(frame) - 4.0)];
                }
            }
            [row setLineWidth:1.0];
            [row stroke];
        } else if (slot.kind == 13) {
            [moxi_color(slot.textColor) setStroke];
            NSBezierPath *disclosure = [NSBezierPath bezierPath];
            [disclosure moveToPoint:NSMakePoint(NSMinX(frame) + 8.0, NSMinY(frame) + 10.0)];
            [disclosure lineToPoint:NSMakePoint(NSMinX(frame) + 14.0, NSMinY(frame) + 15.0)];
            [disclosure lineToPoint:NSMakePoint(NSMinX(frame) + 8.0, NSMinY(frame) + 20.0)];
            [disclosure setLineWidth:1.5];
            [disclosure stroke];
        } else if (slot.kind == 16) {
            [moxi_color(slot.textColor) setStroke];
            NSBezierPath *tabLine = [NSBezierPath bezierPath];
            [tabLine moveToPoint:NSMakePoint(NSMinX(frame), NSMinY(frame) + 26.0)];
            [tabLine lineToPoint:NSMakePoint(NSMaxX(frame), NSMinY(frame) + 26.0)];
            [tabLine setLineWidth:2.0];
            [tabLine stroke];
        }
    }
    if (slot.focused) {
        [[NSColor keyboardFocusIndicatorColor] setStroke];
        NSBezierPath *focus = [NSBezierPath bezierPathWithRoundedRect:
            NSInsetRect(frame, 1.0, 1.0)
            xRadius:slot.radius
            yRadius:slot.radius];
        [focus setLineWidth:1.5];
        [focus stroke];
    }
    moxi_end_clip(slot.clipEnabled);
}

- (void)drawRect:(NSRect)dirtyRect {
    [moxi_color(moxi_surface_fill) setFill];
    NSRectFill(self.bounds);

    for (int i = 0; i < moxi_panel_count; i++) {
        moxi_begin_clip(moxi_panel_clip_enabled[i], moxi_panel_clip_frames[i]);
        [moxi_color(moxi_panel_fills[i]) setFill];
        [[NSBezierPath bezierPathWithRoundedRect:moxi_panel_frames[i]
                                          xRadius:moxi_panel_radii[i]
                                          yRadius:moxi_panel_radii[i]] fill];
        moxi_end_clip(moxi_panel_clip_enabled[i]);
    }

    for (int i = 0; i < moxi_image_count; i++) {
        moxi_begin_clip(moxi_image_clip_enabled[i], moxi_image_clip_frames[i]);
        NSRect frame = moxi_image_frames[i];
        [moxi_color(moxi_image_fill_colors[i]) setFill];
        [[NSBezierPath bezierPathWithRoundedRect:frame
                                          xRadius:moxi_image_radii[i]
                                          yRadius:moxi_image_radii[i]] fill];
        NSImage *image = moxi_image_resources[i];
        if (image != nil) {
            [image drawInRect:frame
                     fromRect:NSZeroRect
                    operation:NSCompositingOperationSourceOver
                     fraction:1.0
               respectFlipped:YES
                        hints:nil];
        } else {
            NSDictionary *imageAttributes = @{
                NSFontAttributeName: [NSFont systemFontOfSize:14.0],
                NSForegroundColorAttributeName: moxi_color(moxi_image_text_colors[i]),
            };
            [moxi_image_alt_texts[i] drawInRect:frame withAttributes:imageAttributes];
        }
        moxi_end_clip(moxi_image_clip_enabled[i]);
    }

    for (int i = 0; i < moxi_label_count; i++) {
        moxi_begin_clip(moxi_label_clip_enabled[i], moxi_label_clip_frames[i]);
        NSMutableParagraphStyle *labelParagraph = [[NSMutableParagraphStyle alloc] init];
        labelParagraph.lineBreakMode = moxi_label_wraps[i]
            ? NSLineBreakByCharWrapping
            : NSLineBreakByClipping;
        NSDictionary *attributes = @{
            NSFontAttributeName: [NSFont systemFontOfSize:moxi_label_font_sizes[i]
                                                       weight:NSFontWeightSemibold],
            NSForegroundColorAttributeName: moxi_color(moxi_label_text_colors[i]),
            NSParagraphStyleAttributeName: labelParagraph,
        };
        [moxi_label_texts[i] drawInRect:moxi_label_frames[i]
                          withAttributes:attributes];
        moxi_end_clip(moxi_label_clip_enabled[i]);
    }

    for (int i = 0; i < moxi_button_count; i++) {
        moxi_begin_clip(moxi_button_clip_enabled[i], moxi_button_clip_frames[i]);
        float fill[4] = {
            moxi_button_fill_colors[i][0],
            moxi_button_fill_colors[i][1],
            moxi_button_fill_colors[i][2],
            moxi_button_fill_colors[i][3],
        };
        if (!moxi_button_enabled[i]) {
            fill[0] = 0.30;
            fill[1] = 0.33;
            fill[2] = 0.40;
        } else if (moxi_button_pressed[i]) {
            fill[0] *= 0.78;
            fill[1] *= 0.78;
            fill[2] *= 0.78;
        } else if (moxi_button_hovered[i]) {
            fill[0] += (1.0 - fill[0]) * 0.12;
            fill[1] += (1.0 - fill[1]) * 0.12;
            fill[2] += (1.0 - fill[2]) * 0.12;
        }
        [moxi_color(fill) setFill];
        [[NSBezierPath bezierPathWithRoundedRect:moxi_button_frames[i]
                                          xRadius:moxi_button_radii[i]
                                          yRadius:moxi_button_radii[i]] fill];
        if (moxi_button_focused[i]) {
            [[NSColor keyboardFocusIndicatorColor] setStroke];
            NSBezierPath *focusPath = [NSBezierPath bezierPathWithRoundedRect:
                NSInsetRect(moxi_button_frames[i], 1.0, 1.0)
                xRadius:moxi_button_radii[i]
                yRadius:moxi_button_radii[i]];
            [focusPath setLineWidth:2.0];
            [focusPath stroke];
        }
        float textColor[4] = {
            moxi_button_text_colors[i][0],
            moxi_button_text_colors[i][1],
            moxi_button_text_colors[i][2],
            moxi_button_text_colors[i][3],
        };
        if (!moxi_button_enabled[i]) {
            textColor[0] = 0.70;
            textColor[1] = 0.72;
            textColor[2] = 0.78;
        }
        NSDictionary *buttonAttributes = @{
            NSFontAttributeName: [NSFont systemFontOfSize:moxi_button_font_sizes[i]
                                                       weight:NSFontWeightSemibold],
            NSForegroundColorAttributeName: moxi_color(textColor),
        };
        NSMutableParagraphStyle *buttonParagraph = [[NSMutableParagraphStyle alloc] init];
        buttonParagraph.lineBreakMode = moxi_button_wraps[i]
            ? NSLineBreakByCharWrapping
            : NSLineBreakByClipping;
        buttonAttributes = @{
            NSFontAttributeName: [NSFont systemFontOfSize:moxi_button_font_sizes[i]
                                                       weight:NSFontWeightSemibold],
            NSForegroundColorAttributeName: moxi_color(textColor),
            NSParagraphStyleAttributeName: buttonParagraph,
        };
        [moxi_button_texts[i] drawInRect:moxi_button_frames[i]
                          withAttributes:buttonAttributes];
        moxi_end_clip(moxi_button_clip_enabled[i]);
    }

    for (int i = 0; i < moxi_checkbox_count; i++) {
        moxi_begin_clip(
            moxi_checkbox_clip_enabled[i],
            moxi_checkbox_clip_frames[i]
        );
        NSRect frame = moxi_checkbox_frames[i];
        CGFloat boxSize = MIN(18.0, MAX(12.0, frame.size.height - 8.0));
        NSRect box = NSMakeRect(
            frame.origin.x,
            frame.origin.y + (frame.size.height - boxSize) * 0.5,
            boxSize,
            boxSize
        );
        float fill[4] = {
            moxi_checkbox_fill_colors[i][0],
            moxi_checkbox_fill_colors[i][1],
            moxi_checkbox_fill_colors[i][2],
            moxi_checkbox_fill_colors[i][3],
        };
        if (!moxi_checkbox_enabled[i]) {
            fill[0] = 0.30;
            fill[1] = 0.33;
            fill[2] = 0.40;
        } else if (moxi_checkbox_checked[i]) {
            fill[0] = 0.18;
            fill[1] = 0.48;
            fill[2] = 0.92;
        } else if (moxi_checkbox_pressed[i]) {
            fill[0] *= 0.78;
            fill[1] *= 0.78;
            fill[2] *= 0.78;
        } else if (moxi_checkbox_hovered[i]) {
            fill[0] += (1.0 - fill[0]) * 0.12;
            fill[1] += (1.0 - fill[1]) * 0.12;
            fill[2] += (1.0 - fill[2]) * 0.12;
        }
        [moxi_color(fill) setFill];
        [[NSBezierPath bezierPathWithRoundedRect:box
                                          xRadius:moxi_checkbox_radii[i]
                                          yRadius:moxi_checkbox_radii[i]] fill];
        if (moxi_checkbox_checked[i]) {
            [[NSColor whiteColor] setStroke];
            NSBezierPath *check = [NSBezierPath bezierPath];
            [check moveToPoint:NSMakePoint(
                NSMinX(box) + box.size.width * 0.22,
                NSMidY(box)
            )];
            [check lineToPoint:NSMakePoint(
                NSMinX(box) + box.size.width * 0.44,
                NSMinY(box) + box.size.height * 0.76
            )];
            [check lineToPoint:NSMakePoint(
                NSMaxX(box) - box.size.width * 0.18,
                NSMinY(box) + box.size.height * 0.24
            )];
            [check setLineWidth:2.0];
            [check stroke];
        }
        if (moxi_checkbox_focused[i]) {
            [[NSColor keyboardFocusIndicatorColor] setStroke];
            NSBezierPath *focusPath = [NSBezierPath bezierPathWithRoundedRect:
                NSInsetRect(box, -2.0, -2.0)
                xRadius:moxi_checkbox_radii[i]
                yRadius:moxi_checkbox_radii[i]];
            [focusPath setLineWidth:1.5];
            [focusPath stroke];
        }
        float textColor[4] = {
            moxi_checkbox_text_colors[i][0],
            moxi_checkbox_text_colors[i][1],
            moxi_checkbox_text_colors[i][2],
            moxi_checkbox_text_colors[i][3],
        };
        if (!moxi_checkbox_enabled[i]) {
            textColor[0] = 0.70;
            textColor[1] = 0.72;
            textColor[2] = 0.78;
        }
        NSDictionary *checkboxAttributes = @{
            NSFontAttributeName: [NSFont systemFontOfSize:moxi_checkbox_font_sizes[i]],
            NSForegroundColorAttributeName: moxi_color(textColor),
        };
        NSRect textFrame = NSMakeRect(
            frame.origin.x + boxSize + 10.0,
            frame.origin.y,
            MAX(0.0, frame.size.width - boxSize - 10.0),
            frame.size.height
        );
        [moxi_checkbox_texts[i] drawInRect:textFrame
                             withAttributes:checkboxAttributes];
        moxi_end_clip(moxi_checkbox_clip_enabled[i]);
    }

    for (int i = 0; i < moxi_progress_count; i++) {
        moxi_begin_clip(
            moxi_progress_clip_enabled[i],
            moxi_progress_clip_frames[i]
        );
        NSRect frame = moxi_progress_frames[i];
        CGFloat trackHeight = MIN(18.0, MAX(10.0, frame.size.height - 8.0));
        NSRect track = NSMakeRect(
            frame.origin.x,
            frame.origin.y + (frame.size.height - trackHeight) * 0.5,
            frame.size.width,
            trackHeight
        );
        [moxi_color(moxi_progress_fill_colors[i]) setFill];
        [[NSBezierPath bezierPathWithRoundedRect:track
                                          xRadius:moxi_progress_radii[i]
                                          yRadius:moxi_progress_radii[i]] fill];
        CGFloat progress = MIN(1.0, MAX(0.0, moxi_progress_values[i]));
        NSRect fill = NSMakeRect(
            track.origin.x,
            track.origin.y,
            track.size.width * progress,
            track.size.height
        );
        if (fill.size.width > 0.0) {
            [[NSColor colorWithCalibratedRed:0.18
                                       green:0.48
                                        blue:0.92
                                       alpha:1.0] setFill];
            [[NSBezierPath bezierPathWithRoundedRect:fill
                                              xRadius:moxi_progress_radii[i]
                                              yRadius:moxi_progress_radii[i]] fill];
        }
        NSDictionary *progressAttributes = @{
            NSFontAttributeName: [NSFont systemFontOfSize:moxi_progress_font_sizes[i]
                                                       weight:NSFontWeightSemibold],
            NSForegroundColorAttributeName: moxi_color(moxi_progress_text_colors[i]),
        };
        [moxi_progress_texts[i] drawInRect:track
                            withAttributes:progressAttributes];
        moxi_end_clip(moxi_progress_clip_enabled[i]);
    }

    for (int i = 0; i < moxi_slider_count; i++) {
        MoxiSliderSlot slot = moxi_slider_slots[i];
        moxi_begin_clip(slot.clipEnabled, slot.clipFrame);
        NSRect frame = slot.frame;
        CGFloat labelWidth = MIN(80.0, MAX(0.0, frame.size.width * 0.25));
        CGFloat trackWidth = MAX(0.0, frame.size.width - labelWidth - 12.0);
        CGFloat trackHeight = MIN(10.0, MAX(6.0, frame.size.height - 12.0));
        NSRect track = NSMakeRect(
            frame.origin.x + labelWidth + 12.0,
            frame.origin.y + (frame.size.height - trackHeight) * 0.5,
            trackWidth,
            trackHeight
        );
        float trackColor[4] = {
            slot.fill[0], slot.fill[1], slot.fill[2], slot.fill[3]
        };
        if (!slot.enabled) {
            trackColor[0] = 0.30;
            trackColor[1] = 0.33;
            trackColor[2] = 0.40;
        }
        [moxi_color(trackColor) setFill];
        [[NSBezierPath bezierPathWithRoundedRect:track
                                          xRadius:trackHeight * 0.5
                                          yRadius:trackHeight * 0.5] fill];
        CGFloat progress = MIN(1.0, MAX(0.0, slot.value));
        NSRect fill = NSMakeRect(
            track.origin.x,
            track.origin.y,
            track.size.width * progress,
            track.size.height
        );
        if (fill.size.width > 0.0) {
            [moxi_color(slot.textColor) setFill];
            [[NSBezierPath bezierPathWithRoundedRect:fill
                                              xRadius:trackHeight * 0.5
                                              yRadius:trackHeight * 0.5] fill];
        }
        CGFloat knobX = track.origin.x + track.size.width * progress;
        CGFloat knobSize = MAX(14.0, trackHeight + 6.0);
        NSRect knob = NSMakeRect(
            knobX - knobSize * 0.5,
            frame.origin.y + (frame.size.height - knobSize) * 0.5,
            knobSize,
            knobSize
        );
        [moxi_color(slot.textColor) setFill];
        [[NSBezierPath bezierPathWithOvalInRect:knob] fill];
        NSDictionary *sliderAttributes = @{
            NSFontAttributeName: [NSFont systemFontOfSize:slot.fontSize],
            NSForegroundColorAttributeName: moxi_color(slot.textColor),
        };
        [slot.text drawInRect:NSMakeRect(
            frame.origin.x,
            frame.origin.y,
            labelWidth,
            frame.size.height
        ) withAttributes:sliderAttributes];
        if (slot.focused) {
            [[NSColor keyboardFocusIndicatorColor] setStroke];
            NSBezierPath *focusPath = [NSBezierPath bezierPathWithRoundedRect:
                NSInsetRect(frame, 1.0, 1.0)
                xRadius:slot.radius
                yRadius:slot.radius];
            [focusPath setLineWidth:1.5];
            [focusPath stroke];
        }
        moxi_end_clip(slot.clipEnabled);
    }

    for (int i = 0; i < moxi_toggle_count; i++) {
        MoxiToggleSlot slot = moxi_toggle_slots[i];
        moxi_begin_clip(slot.clipEnabled, slot.clipFrame);
        NSRect frame = slot.frame;
        float textColor[4] = {
            slot.textColor[0], slot.textColor[1], slot.textColor[2], slot.textColor[3]
        };
        if (!slot.enabled) {
            textColor[0] = 0.70;
            textColor[1] = 0.72;
            textColor[2] = 0.78;
        }
        if (slot.radio) {
            CGFloat size = MIN(18.0, MAX(12.0, frame.size.height - 8.0));
            NSRect circle = NSMakeRect(
                frame.origin.x,
                frame.origin.y + (frame.size.height - size) * 0.5,
                size,
                size
            );
            [moxi_color(slot.fill) setFill];
            [[NSBezierPath bezierPathWithOvalInRect:circle] fill];
            [moxi_color(textColor) setStroke];
            NSBezierPath *outline = [NSBezierPath bezierPathWithOvalInRect:
                NSInsetRect(circle, 1.0, 1.0)];
            [outline setLineWidth:1.5];
            [outline stroke];
            if (slot.checked) {
                NSRect dot = NSInsetRect(circle, size * 0.30, size * 0.30);
                [moxi_color(textColor) setFill];
                [[NSBezierPath bezierPathWithOvalInRect:dot] fill];
            }
            NSDictionary *radioAttributes = @{
                NSFontAttributeName: [NSFont systemFontOfSize:slot.fontSize],
                NSForegroundColorAttributeName: moxi_color(textColor),
            };
            [slot.text drawInRect:NSMakeRect(
                frame.origin.x + size + 10.0,
                frame.origin.y,
                MAX(0.0, frame.size.width - size - 10.0),
                frame.size.height
            ) withAttributes:radioAttributes];
        } else {
            CGFloat width = MIN(42.0, MAX(30.0, frame.size.height * 1.55));
            CGFloat height = MIN(22.0, MAX(16.0, frame.size.height - 6.0));
            NSRect track = NSMakeRect(
                frame.origin.x,
                frame.origin.y + (frame.size.height - height) * 0.5,
                width,
                height
            );
            float trackColor[4] = {
                slot.fill[0], slot.fill[1], slot.fill[2], slot.fill[3]
            };
            if (slot.checked) {
                trackColor[0] = slot.textColor[0];
                trackColor[1] = slot.textColor[1];
                trackColor[2] = slot.textColor[2];
            }
            if (!slot.enabled) {
                trackColor[0] = 0.30;
                trackColor[1] = 0.33;
                trackColor[2] = 0.40;
            }
            [moxi_color(trackColor) setFill];
            [[NSBezierPath bezierPathWithRoundedRect:track
                                              xRadius:height * 0.5
                                              yRadius:height * 0.5] fill];
            CGFloat inset = 3.0;
            CGFloat knobSize = height - inset * 2.0;
            CGFloat knobX = slot.checked
                ? NSMaxX(track) - inset - knobSize
                : NSMinX(track) + inset;
            NSRect knob = NSMakeRect(
                knobX,
                NSMinY(track) + inset,
                knobSize,
                knobSize
            );
            [[NSColor whiteColor] setFill];
            [[NSBezierPath bezierPathWithOvalInRect:knob] fill];
            NSDictionary *switchAttributes = @{
                NSFontAttributeName: [NSFont systemFontOfSize:slot.fontSize],
                NSForegroundColorAttributeName: moxi_color(textColor),
            };
            [slot.text drawInRect:NSMakeRect(
                frame.origin.x + width + 10.0,
                frame.origin.y,
                MAX(0.0, frame.size.width - width - 10.0),
                frame.size.height
            ) withAttributes:switchAttributes];
        }
        if (slot.focused) {
            [[NSColor keyboardFocusIndicatorColor] setStroke];
            NSBezierPath *focusPath = [NSBezierPath bezierPathWithRoundedRect:
                NSInsetRect(frame, 1.0, 1.0)
                xRadius:slot.radius
                yRadius:slot.radius];
            [focusPath setLineWidth:1.5];
            [focusPath stroke];
        }
        moxi_end_clip(slot.clipEnabled);
    }

    for (int i = 0; i < moxi_text_input_count; i++) {
        moxi_begin_clip(
            moxi_text_input_clip_enabled[i],
            moxi_text_input_clip_frames[i]
        );
        NSRect frame = moxi_text_input_frames[i];
        [moxi_color(moxi_text_input_fill_colors[i]) setFill];
        [[NSBezierPath bezierPathWithRoundedRect:frame
                                          xRadius:moxi_text_input_radii[i]
                                          yRadius:moxi_text_input_radii[i]] fill];

        NSMutableParagraphStyle *textParagraph = [[NSMutableParagraphStyle alloc] init];
        textParagraph.lineBreakMode = moxi_text_input_wraps[i]
            ? NSLineBreakByCharWrapping
            : NSLineBreakByClipping;
        NSDictionary *textAttributes = @{
            NSFontAttributeName: [NSFont systemFontOfSize:moxi_text_input_font_sizes[i]],
            NSForegroundColorAttributeName: moxi_color(moxi_text_input_text_colors[i]),
            NSParagraphStyleAttributeName: textParagraph,
        };
        NSRect textFrame = NSInsetRect(frame, 10.0, 0.0);

        NSString *text = moxi_text_input_texts[i];
        NSUInteger selectionStart = moxi_utf16_index_for_codepoint(
            text,
            moxi_text_input_selection_starts[i]
        );
        NSUInteger selectionEnd = moxi_utf16_index_for_codepoint(
            text,
            moxi_text_input_selection_ends[i]
        );
        if (selectionEnd > selectionStart) {
            NSString *prefix = [text substringToIndex:selectionStart];
            NSString *selected = [text substringWithRange:NSMakeRange(
                selectionStart,
                selectionEnd - selectionStart
            )];
            CGFloat startX = textFrame.origin.x + [prefix sizeWithAttributes:textAttributes].width;
            CGFloat selectionWidth = [selected sizeWithAttributes:textAttributes].width;
            NSRect selectionFrame = NSMakeRect(
                startX,
                frame.origin.y + 5.0,
                selectionWidth,
                frame.size.height - 10.0
            );
            [[NSColor selectedTextBackgroundColor] setFill];
            NSRectFill(selectionFrame);
        }
        [moxi_text_input_texts[i] drawInRect:textFrame withAttributes:textAttributes];

        NSString *composition = moxi_text_input_compositions[i];
        if (composition != nil && [composition length] > 0) {
            NSUInteger cursor = moxi_utf16_index_for_codepoint(
                text,
                moxi_text_input_cursors[i]
            );
            NSString *prefix = [text substringToIndex:cursor];
            CGFloat compositionX = textFrame.origin.x +
                [prefix sizeWithAttributes:textAttributes].width;
            NSUInteger compositionStart = moxi_utf16_index_for_codepoint(
                composition,
                moxi_text_input_composition_selection_starts[i]
            );
            NSUInteger compositionEnd = moxi_utf16_index_for_codepoint(
                composition,
                moxi_text_input_composition_selection_ends[i]
            );
            NSDictionary *compositionAttributes = @{
                NSFontAttributeName: [NSFont systemFontOfSize:moxi_text_input_font_sizes[i]],
                NSForegroundColorAttributeName: moxi_color(moxi_text_input_text_colors[i]),
                NSUnderlineStyleAttributeName: @(NSUnderlineStyleSingle),
                NSUnderlineColorAttributeName: [NSColor systemOrangeColor],
            };
            if (compositionEnd > compositionStart) {
                NSString *selected = [composition substringWithRange:NSMakeRange(
                    compositionStart,
                    compositionEnd - compositionStart
                )];
                NSString *markedPrefix = [composition substringToIndex:compositionStart];
                CGFloat selectedX = compositionX +
                    [markedPrefix sizeWithAttributes:compositionAttributes].width;
                CGFloat selectedWidth = [selected sizeWithAttributes:compositionAttributes].width;
                NSRect selectedFrame = NSMakeRect(
                    selectedX,
                    frame.origin.y + 5.0,
                    selectedWidth,
                    frame.size.height - 10.0
                );
                [[NSColor selectedTextBackgroundColor] setFill];
                NSRectFill(selectedFrame);
            }
            [composition drawAtPoint:NSMakePoint(compositionX, textFrame.origin.y)
                       withAttributes:compositionAttributes];
            if (moxi_text_input_focused[i] && selectionEnd == selectionStart) {
                NSUInteger markedCursor = compositionEnd;
                NSString *markedPrefix = [composition substringToIndex:markedCursor];
                CGFloat caretX = compositionX +
                    [markedPrefix sizeWithAttributes:compositionAttributes].width;
                [[NSColor whiteColor] setStroke];
                NSBezierPath *caret = [NSBezierPath bezierPath];
                [caret moveToPoint:NSMakePoint(caretX, frame.origin.y + 8.0)];
                [caret lineToPoint:NSMakePoint(caretX, NSMaxY(frame) - 8.0)];
                [caret setLineWidth:1.5];
                [caret stroke];
            }
        }

        if (selectionEnd > selectionStart) {
            NSString *prefix = [text substringToIndex:selectionStart];
            NSString *selected = [text substringWithRange:NSMakeRange(
                selectionStart,
                selectionEnd - selectionStart
            )];
            CGFloat startX = textFrame.origin.x + [prefix sizeWithAttributes:textAttributes].width;
            NSDictionary *selectedAttributes = @{
                NSFontAttributeName: [NSFont systemFontOfSize:moxi_text_input_font_sizes[i]],
                NSForegroundColorAttributeName: [NSColor selectedTextColor],
            };
            [selected drawAtPoint:NSMakePoint(startX, textFrame.origin.y)
                    withAttributes:selectedAttributes];
        }

        if (moxi_text_input_focused[i] &&
            selectionEnd == selectionStart &&
            (composition == nil || [composition length] == 0)) {
            [[NSColor keyboardFocusIndicatorColor] setStroke];
            NSBezierPath *focusPath = [NSBezierPath bezierPathWithRoundedRect:
                NSInsetRect(frame, 1.0, 1.0)
                xRadius:moxi_text_input_radii[i]
                yRadius:moxi_text_input_radii[i]];
            [focusPath setLineWidth:2.0];
            [focusPath stroke];

            NSUInteger cursor = moxi_utf16_index_for_codepoint(
                text,
                moxi_text_input_cursors[i]
            );
            NSString *prefix = [text substringToIndex:cursor];
            CGFloat advance = [prefix sizeWithAttributes:textAttributes].width;
            CGFloat caretX = textFrame.origin.x + advance;
            CGFloat caretTop = frame.origin.y + 8.0;
            CGFloat caretBottom = NSMaxY(frame) - 8.0;
            [[NSColor whiteColor] setStroke];
            NSBezierPath *caret = [NSBezierPath bezierPath];
            [caret moveToPoint:NSMakePoint(caretX, caretTop)];
            [caret lineToPoint:NSMakePoint(caretX, caretBottom)];
            [caret setLineWidth:1.5];
            [caret stroke];
        }
        moxi_end_clip(moxi_text_input_clip_enabled[i]);
    }

    for (int i = 0; i < moxi_native_widget_count; i++) {
        moxi_draw_native_widget(moxi_native_widget_slots[i]);
    }
}

- (void)mouseDown:(NSEvent *)event {
    NSPoint point = [self convertPoint:[event locationInWindow] fromView:nil];
    moxi_last_click_x = point.x;
    moxi_last_click_y = point.y;
    moxi_click_pending = YES;
    moxi_event_x = point.x;
    moxi_event_y = point.y;
    moxi_last_pointer_x = point.x;
    moxi_last_pointer_y = point.y;
    moxi_mouse_is_down = YES;
    moxi_mouse_dragging = NO;
    moxi_queue_event(MOXI_EVENT_POINTER_DOWN);
}

- (void)mouseUp:(NSEvent *)event {
    NSPoint point = [self convertPoint:[event locationInWindow] fromView:nil];
    moxi_event_x = point.x;
    moxi_event_y = point.y;
    if (moxi_mouse_dragging) {
        moxi_queue_event(MOXI_EVENT_DROP);
    } else {
        moxi_queue_event(MOXI_EVENT_POINTER_UP);
    }
    moxi_mouse_is_down = NO;
    moxi_mouse_dragging = NO;
}

- (void)mouseDragged:(NSEvent *)event {
    if (!moxi_mouse_is_down) {
        return;
    }
    NSPoint point = [self convertPoint:[event locationInWindow] fromView:nil];
    moxi_event_x = point.x;
    moxi_event_y = point.y;
    if (!moxi_mouse_dragging) {
        moxi_mouse_dragging = YES;
        moxi_queue_event(MOXI_EVENT_DRAG_BEGIN);
    }
    moxi_queue_event(MOXI_EVENT_DRAG_UPDATE);
    moxi_last_pointer_x = point.x;
    moxi_last_pointer_y = point.y;
}

- (void)mouseExited:(NSEvent *)event {
    if (moxi_mouse_is_down) {
        moxi_queue_event(MOXI_EVENT_POINTER_CANCEL);
        moxi_mouse_is_down = NO;
        moxi_mouse_dragging = NO;
    }
}

- (void)mouseMoved:(NSEvent *)event {
    NSPoint point = [self convertPoint:[event locationInWindow] fromView:nil];
    moxi_event_x = point.x;
    moxi_event_y = point.y;
    moxi_queue_event(MOXI_EVENT_POINTER_MOVE);
}

- (void)scrollWheel:(NSEvent *)event {
    NSPoint point = [self convertPoint:[event locationInWindow] fromView:nil];
    moxi_enqueue_event(
        MOXI_EVENT_SCROLL,
        0,
        moxi_interpreting_modifiers,
        -1,
        nil,
        -1,
        -1,
        point.x,
        point.y,
        (float)[event scrollingDeltaX],
        (float)[event scrollingDeltaY]
    );
}

- (void)insertText:(id)string replacementRange:(NSRange)replacementRange {
    NSString *value = moxi_input_string(string);
    moxi_clear_marked_text();
    if ([value length] > 0) {
        int replacementStart = -1;
        int replacementEnd = -1;
        if (replacementRange.location != NSNotFound) {
            NSString *current = moxi_active_text_input_text();
            NSUInteger start = MIN(replacementRange.location, [current length]);
            NSUInteger maxEnd = [current length];
            NSUInteger requestedEnd = NSMaxRange(replacementRange);
            NSUInteger end = MIN(requestedEnd, maxEnd);
            replacementStart = moxi_codepoint_index_for_utf16(current, start);
            replacementEnd = moxi_codepoint_index_for_utf16(current, end);
        }
        moxi_queue_text_event(
            MOXI_EVENT_TEXT_INPUT,
            value,
            replacementStart,
            replacementEnd
        );
    }
}

- (void)setMarkedText:(id)string
       selectedRange:(NSRange)selectedRange
    replacementRange:(NSRange)replacementRange {
    NSString *value = moxi_input_string(string);
    NSUInteger selectedLocation = selectedRange.location == NSNotFound
        ? 0
        : selectedRange.location;
    NSUInteger selectedEnd = selectedLocation;
    if (selectedRange.location != NSNotFound) {
        selectedEnd = MIN([value length], NSMaxRange(selectedRange));
    }
    int selectionStart = moxi_codepoint_index_for_utf16(value, selectedLocation);
    int selectionEnd = moxi_codepoint_index_for_utf16(value, selectedEnd);
    moxi_marked_text = [value copy];
    moxi_marked_selection_start = selectionStart;
    moxi_marked_selection_end = selectionEnd;
    moxi_queue_text_event(
        MOXI_EVENT_COMPOSITION_UPDATE,
        value,
        selectionStart,
        selectionEnd
    );
}

- (void)unmarkText {
    if (moxi_marked_text == nil) {
        return;
    }
    moxi_clear_marked_text();
    moxi_queue_text_event(MOXI_EVENT_COMPOSITION_END, @"", 0, 0);
}

- (BOOL)hasMarkedText {
    return moxi_marked_text != nil && [moxi_marked_text length] > 0;
}

- (NSRange)markedRange {
    if (![self hasMarkedText]) {
        return NSMakeRange(NSNotFound, 0);
    }
    NSRange selected = [self selectedRange];
    NSString *text = moxi_active_text_input_text();
    NSUInteger start = selected.location;
    if (start == NSNotFound) {
        start = [text length];
    }
    return NSMakeRange(start, [moxi_marked_text length]);
}

- (NSRange)selectedRange {
    return moxi_active_selected_range();
}

- (NSAttributedString *)attributedSubstringForProposedRange:(NSRange)range
                                                actualRange:(NSRangePointer)actualRange {
    NSString *text = moxi_active_text_input_text();
    if (range.location == NSNotFound) {
        range = NSMakeRange(0, 0);
    }
    NSUInteger start = MIN(range.location, [text length]);
    NSUInteger end = MIN([text length], NSMaxRange(range));
    if (end < start) {
        end = start;
    }
    NSRange actual = NSMakeRange(start, end - start);
    if (actualRange != NULL) {
        *actualRange = actual;
    }
    return [[NSAttributedString alloc] initWithString:[text substringWithRange:actual]];
}

- (NSArray<NSAttributedStringKey> *)validAttributesForMarkedText {
    return @[];
}

- (NSRect)firstRectForCharacterRange:(NSRange)range
                          actualRange:(NSRangePointer)actualRange {
    NSString *text = moxi_active_text_input_text();
    NSUInteger start = range.location == NSNotFound
        ? [text length]
        : MIN(range.location, [text length]);
    NSUInteger end = range.location == NSNotFound
        ? start
        : MIN(NSMaxRange(range), [text length]);
    if (actualRange != NULL) {
        *actualRange = NSMakeRange(start, end >= start ? end - start : 0);
    }
    return moxi_active_caret_rect_at_utf16(start);
}

- (NSUInteger)characterIndexForPoint:(NSPoint)point {
    if (moxi_active_text_input_index < 0 ||
        moxi_active_text_input_index >= moxi_text_input_count) {
        return 0;
    }
    NSPoint localPoint = [self convertPoint:point fromView:nil];
    NSRect frame = moxi_text_input_frames[moxi_active_text_input_index];
    NSString *text = moxi_active_text_input_text();
    NSDictionary *attributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:
            moxi_text_input_font_sizes[moxi_active_text_input_index]],
    };
    CGFloat target = localPoint.x - frame.origin.x - 10.0;
    if (target <= 0.0) {
        return 0;
    }
    int bestCodepoint = 0;
    CGFloat bestDistance = CGFLOAT_MAX;
    NSUInteger utf16 = 0;
    int codepoint = 0;
    while (utf16 <= [text length]) {
        CGFloat width = [[text substringToIndex:utf16] sizeWithAttributes:attributes].width;
        CGFloat distance = width - target;
        if (distance < 0.0) {
            distance = -distance;
        }
        if (distance < bestDistance) {
            bestDistance = distance;
            bestCodepoint = codepoint;
        }
        if (utf16 == [text length]) {
            break;
        }
        utf16 = moxi_advance_codepoint(text, utf16);
        codepoint += 1;
    }
    return moxi_utf16_index_for_codepoint(text, bestCodepoint);
}

- (void)doCommandBySelector:(SEL)selector {
    if (selector == @selector(moveLeft:) ||
        selector == @selector(moveLeftAndModifySelection:)) {
        moxi_queue_key_event(MOXI_KEY_LEFT);
    } else if (selector == @selector(moveRight:) ||
               selector == @selector(moveRightAndModifySelection:)) {
        moxi_queue_key_event(MOXI_KEY_RIGHT);
    } else if (selector == @selector(moveUp:) ||
               selector == @selector(moveUpAndModifySelection:)) {
        moxi_queue_key_event(MOXI_KEY_UP);
    } else if (selector == @selector(moveDown:) ||
               selector == @selector(moveDownAndModifySelection:)) {
        moxi_queue_key_event(MOXI_KEY_DOWN);
    } else if (selector == @selector(moveToBeginningOfLine:) ||
               selector == @selector(moveToBeginningOfParagraph:) ||
               selector == @selector(moveToLeftEndOfLine:) ||
               selector == @selector(moveToLeftEndOfParagraph:)) {
        moxi_queue_key_event(MOXI_KEY_HOME);
    } else if (selector == @selector(moveToEndOfLine:) ||
               selector == @selector(moveToEndOfParagraph:) ||
               selector == @selector(moveToRightEndOfLine:) ||
               selector == @selector(moveToRightEndOfParagraph:)) {
        moxi_queue_key_event(MOXI_KEY_END);
    } else if (selector == @selector(deleteBackward:)) {
        moxi_queue_key_event(MOXI_KEY_BACKSPACE);
    } else if (selector == @selector(deleteForward:)) {
        moxi_queue_key_event(MOXI_KEY_DELETE);
    } else if (selector == @selector(insertNewline:) ||
               selector == @selector(insertLineBreak:)) {
        moxi_queue_key_event(MOXI_KEY_ENTER);
    } else if (selector == @selector(insertTab:)) {
        moxi_queue_key_event(MOXI_KEY_TAB);
    } else if (selector == @selector(insertBacktab:)) {
        moxi_interpreting_modifiers |= MOXI_MOD_SHIFT;
        moxi_queue_key_event(MOXI_KEY_TAB);
    } else if (selector == @selector(cancelOperation:)) {
        moxi_queue_key_event(MOXI_KEY_ESCAPE);
    } else if (selector == @selector(selectAll:)) {
        moxi_queue_key_event('a');
    } else if (selector == @selector(copy:)) {
        moxi_queue_key_event(MOXI_KEY_C);
    } else if (selector == @selector(cut:)) {
        moxi_queue_key_event(MOXI_KEY_X);
    } else if (selector == @selector(paste:)) {
        moxi_queue_key_event(MOXI_KEY_V);
    }
}

- (void)keyDown:(NSEvent *)event {
    moxi_interpreting_modifiers = moxi_event_modifiers_for_flags([event modifierFlags]);
    [self interpretKeyEvents:@[event]];
    moxi_interpreting_modifiers = 0;
}
@end

void moxi_window_open(
    const char *title,
    float width,
    float height,
    float min_width,
    float min_height,
    float max_width,
    float max_height,
    int resizable,
    int fullscreen
) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
        [NSApp finishLaunching];

        NSRect frame = NSMakeRect(0, 0, width, height);
        NSWindowStyleMask style = NSWindowStyleMaskTitled |
                                  NSWindowStyleMaskClosable |
                                  NSWindowStyleMaskMiniaturizable;
        if (resizable != 0) {
            style |= NSWindowStyleMaskResizable;
        }
        moxi_window = [[NSWindow alloc] initWithContentRect:frame
                                                   styleMask:style
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
        moxi_delegate = [[MoxiWindowDelegate alloc] init];
        [moxi_window setDelegate:moxi_delegate];

        NSString *windowTitle = title == NULL
            ? @"Moxi"
            : [NSString stringWithUTF8String:title];
        [moxi_window setTitle:windowTitle];
        [moxi_window setAcceptsMouseMovedEvents:YES];
        if (min_width > 0.0f || min_height > 0.0f) {
            float effectiveMinWidth = min_width > 0.0f ? min_width : 0.0f;
            float effectiveMinHeight = min_height > 0.0f ? min_height : 0.0f;
            [moxi_window setContentMinSize:NSMakeSize(
                effectiveMinWidth,
                effectiveMinHeight
            )];
        }
        if (max_width > 0.0f || max_height > 0.0f) {
            float effectiveMaxWidth = max_width > 0.0f ? max_width : CGFLOAT_MAX;
            float effectiveMaxHeight = max_height > 0.0f ? max_height : CGFLOAT_MAX;
            [moxi_window setContentMaxSize:NSMakeSize(
                effectiveMaxWidth,
                effectiveMaxHeight
            )];
        }

        moxi_canvas = [[MoxiCanvasView alloc] initWithFrame:NSMakeRect(0, 0, width, height)];
        [moxi_canvas setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
        moxi_reset_commands();
        moxi_accessibility_reset_storage();
        moxi_reset_event_queue();
        moxi_click_pending = NO;
        moxi_last_canvas_width = width;
        moxi_last_canvas_height = height;
        [moxi_window setContentView:moxi_canvas];
        [moxi_window center];
        [moxi_window makeKeyAndOrderFront:nil];
        [moxi_window makeFirstResponder:moxi_canvas];
        [NSApp activateIgnoringOtherApps:YES];
        if (fullscreen != 0) {
            [moxi_window toggleFullScreen:nil];
        }
        for (int i = 0; i < MOXI_MAX_DRAW_COMMANDS; i++) {
            moxi_registered_image_ids[i] = -1;
            moxi_registered_images[i] = nil;
        }
        moxi_window_opened = YES;
    }
}

void moxi_window_begin_frame(void) {
    moxi_reset_commands();
    if (moxi_canvas != nil) {
        [moxi_canvas setNeedsDisplay:YES];
    }
}

void moxi_window_begin_accessibility(void) {
    moxi_accessibility_capture_previous();
    moxi_accessibility_reset_storage();
}

void moxi_window_set_accessibility_at(
    int index,
    int id,
    int parent_id,
    int role,
    const char *label,
    const char *value,
    const char *hint,
    float x,
    float y,
    float width,
    float height,
    int enabled,
    int focused,
    int selected,
    int actions
) {
    @autoreleasepool {
        if (index < 0 || index >= MOXI_MAX_DRAW_COMMANDS) {
            if (index >= MOXI_MAX_DRAW_COMMANDS) {
                moxi_command_overflow_count += 1;
            }
            return;
        }
        moxi_accessibility_ids[index] = id;
        moxi_accessibility_parent_ids[index] = parent_id;
        moxi_accessibility_roles[index] = role;
        moxi_accessibility_labels[index] = label == NULL
            ? @""
            : [NSString stringWithUTF8String:label];
        if (moxi_accessibility_labels[index] == nil) {
            moxi_accessibility_labels[index] = @"";
        }
        moxi_accessibility_values[index] = value == NULL
            ? @""
            : [NSString stringWithUTF8String:value];
        if (moxi_accessibility_values[index] == nil) {
            moxi_accessibility_values[index] = @"";
        }
        moxi_accessibility_hints[index] = hint == NULL
            ? @""
            : [NSString stringWithUTF8String:hint];
        if (moxi_accessibility_hints[index] == nil) {
            moxi_accessibility_hints[index] = @"";
        }
        moxi_accessibility_frames[index] = NSMakeRect(x, y, width, height);
        moxi_accessibility_enabled[index] = enabled != 0;
        moxi_accessibility_focused[index] = focused != 0;
        moxi_accessibility_selected[index] = selected != 0;
        moxi_accessibility_actions[index] = actions;
        if (focused != 0 && role == MOXI_ROLE_TEXT_INPUT) {
            moxi_accessibility_focused_text_input = YES;
        }
        if (index + 1 > moxi_accessibility_count) {
            moxi_accessibility_count = index + 1;
        }
    }
}

void moxi_window_end_accessibility(void) {
    if (!moxi_accessibility_focused_text_input) {
        moxi_clear_marked_text();
    }
    moxi_accessibility_build_elements();
}

void moxi_window_set_clip(
    int enabled,
    float x,
    float y,
    float width,
    float height
) {
    moxi_current_clip_enabled = enabled != 0;
    moxi_current_clip_frame = NSMakeRect(x, y, width, height);
}

void moxi_window_set_surface(
    float red,
    float green,
    float blue,
    float alpha
) {
    moxi_copy_color(moxi_surface_fill, red, green, blue, alpha);
    if (moxi_canvas != nil) {
        [moxi_canvas setNeedsDisplay:YES];
    }
}

static void moxi_window_set_panel_impl(
    int slot,
    float x,
    float y,
    float width,
    float height,
    float red,
    float green,
    float blue,
    float alpha,
    float radius,
    int clip_enabled,
    float clip_x,
    float clip_y,
    float clip_width,
    float clip_height
) {
    if (slot < 0 || slot >= MOXI_MAX_DRAW_COMMANDS) {
        if (slot >= MOXI_MAX_DRAW_COMMANDS) {
            moxi_command_overflow_count += 1;
        }
        return;
    }
    moxi_panel_frames[slot] = NSMakeRect(x, y, width, height);
    moxi_copy_color(moxi_panel_fills[slot], red, green, blue, alpha);
    moxi_panel_radii[slot] = radius;
    moxi_panel_clip_enabled[slot] = clip_enabled != 0;
    moxi_panel_clip_frames[slot] = NSMakeRect(
        clip_x,
        clip_y,
        clip_width,
        clip_height
    );
    if (slot + 1 > moxi_panel_count) {
        moxi_panel_count = slot + 1;
    }
    if (moxi_canvas != nil) {
        [moxi_canvas setNeedsDisplay:YES];
    }
}

void moxi_window_set_panel_at(
    int slot,
    float x,
    float y,
    float width,
    float height,
    float red,
    float green,
    float blue,
    float alpha,
    float radius,
    int clip_enabled,
    float clip_x,
    float clip_y,
    float clip_width,
    float clip_height
) {
    moxi_window_set_panel_impl(
        slot,
        x,
        y,
        width,
        height,
        red,
        green,
        blue,
        alpha,
        radius,
        clip_enabled,
        clip_x,
        clip_y,
        clip_width,
        clip_height
    );
}

void moxi_window_set_panel(
    float x,
    float y,
    float width,
    float height,
    float red,
    float green,
    float blue,
    float alpha,
    float radius
) {
    moxi_window_set_panel_impl(
        0,
        x,
        y,
        width,
        height,
        red,
        green,
        blue,
        alpha,
        radius,
        moxi_current_clip_enabled ? 1 : 0,
        moxi_current_clip_frame.origin.x,
        moxi_current_clip_frame.origin.y,
        moxi_current_clip_frame.size.width,
        moxi_current_clip_frame.size.height
    );
}

void moxi_window_set_native_widget_at(
    int index,
    int kind,
    const char *text,
    float x,
    float y,
    float width,
    float height,
    float fill_red,
    float fill_green,
    float fill_blue,
    float fill_alpha,
    float text_red,
    float text_green,
    float text_blue,
    float text_alpha,
    float radius,
    float font_size,
    int focused,
    int enabled,
    int selected,
    int expanded
) {
    @autoreleasepool {
        if (moxi_canvas == nil || index < 0 || index >= MOXI_MAX_DRAW_COMMANDS) {
            if (index >= MOXI_MAX_DRAW_COMMANDS) {
                moxi_command_overflow_count += 1;
            }
            return;
        }
        MoxiNativeWidgetSlot *slot = &moxi_native_widget_slots[index];
        slot->text = text == NULL ? @"" : [NSString stringWithUTF8String:text];
        if (slot->text == nil) {
            slot->text = @"";
        }
        slot->frame = NSMakeRect(x, y, width, height);
        moxi_copy_color(slot->fill, fill_red, fill_green, fill_blue, fill_alpha);
        moxi_copy_color(slot->textColor, text_red, text_green, text_blue, text_alpha);
        slot->radius = radius;
        slot->fontSize = font_size;
        slot->kind = kind;
        slot->focused = focused != 0;
        slot->enabled = enabled != 0;
        slot->selected = selected != 0;
        slot->expanded = expanded != 0;
        slot->clipEnabled = moxi_current_clip_enabled;
        slot->clipFrame = moxi_current_clip_frame;
        if (index + 1 > moxi_native_widget_count) {
            moxi_native_widget_count = index + 1;
        }
        [moxi_canvas setNeedsDisplay:YES];
    }
}

void moxi_window_register_image(int resource_id, const char *source) {
    @autoreleasepool {
        if (resource_id < 0 || source == NULL) {
            return;
        }
        int slot = -1;
        for (int i = 0; i < MOXI_MAX_DRAW_COMMANDS; i++) {
            if (moxi_registered_image_ids[i] == resource_id) {
                slot = i;
                break;
            }
            if (slot < 0 && moxi_registered_image_ids[i] < 0) {
                slot = i;
            }
        }
        if (slot < 0) {
            return;
        }
        NSString *path = [NSString stringWithUTF8String:source];
        if (path == nil) {
            path = @"";
        }
        NSImage *image = [[NSImage alloc] initWithContentsOfFile:path];
        if (image == nil && [path length] > 0) {
            image = [NSImage imageNamed:path];
        }
        moxi_registered_image_ids[slot] = resource_id;
        moxi_registered_images[slot] = image;
    }
}

void moxi_window_set_image_at(
    int index,
    int resource_id,
    const char *alt_text,
    float x,
    float y,
    float width,
    float height,
    float fill_red,
    float fill_green,
    float fill_blue,
    float fill_alpha,
    float text_red,
    float text_green,
    float text_blue,
    float text_alpha,
    float radius
) {
    @autoreleasepool {
        if (moxi_canvas == nil || index < 0 || index >= MOXI_MAX_DRAW_COMMANDS) {
            if (index >= MOXI_MAX_DRAW_COMMANDS) {
                moxi_command_overflow_count += 1;
            }
            return;
        }
        moxi_image_resource_ids[index] = resource_id;
        moxi_image_resources[index] = nil;
        for (int i = 0; i < MOXI_MAX_DRAW_COMMANDS; i++) {
            if (moxi_registered_image_ids[i] == resource_id) {
                moxi_image_resources[index] = moxi_registered_images[i];
                break;
            }
        }
        moxi_image_alt_texts[index] = alt_text == NULL
            ? @""
            : [NSString stringWithUTF8String:alt_text];
        if (moxi_image_alt_texts[index] == nil) {
            moxi_image_alt_texts[index] = @"";
        }
        moxi_image_frames[index] = NSMakeRect(x, y, width, height);
        moxi_copy_color(moxi_image_fill_colors[index], fill_red, fill_green, fill_blue, fill_alpha);
        moxi_copy_color(moxi_image_text_colors[index], text_red, text_green, text_blue, text_alpha);
        moxi_image_radii[index] = radius;
        moxi_image_clip_enabled[index] = moxi_current_clip_enabled;
        moxi_image_clip_frames[index] = moxi_current_clip_frame;
        if (index + 1 > moxi_image_count) {
            moxi_image_count = index + 1;
        }
        [moxi_canvas setNeedsDisplay:YES];
    }
}

void moxi_window_set_label_at(
    int index,
    const char *text,
    float x,
    float y,
    float width,
    float height,
    float text_red,
    float text_green,
    float text_blue,
    float text_alpha,
    float font_size,
    int wrap_text
) {
    @autoreleasepool {
        if (moxi_canvas == nil || index < 0 || index >= MOXI_MAX_DRAW_COMMANDS) {
            if (index >= MOXI_MAX_DRAW_COMMANDS) {
                moxi_command_overflow_count += 1;
            }
            return;
        }

        NSString *label = text == NULL
            ? @""
            : [NSString stringWithUTF8String:text];
        moxi_label_texts[index] = label;
        moxi_label_frames[index] = NSMakeRect(x, y, width, height);
        moxi_copy_color(moxi_label_text_colors[index], text_red, text_green, text_blue, text_alpha);
        moxi_label_font_sizes[index] = font_size;
        moxi_label_wraps[index] = wrap_text != 0;
        moxi_label_clip_enabled[index] = moxi_current_clip_enabled;
        moxi_label_clip_frames[index] = moxi_current_clip_frame;
        if (index + 1 > moxi_label_count) {
            moxi_label_count = index + 1;
        }
        [moxi_canvas setNeedsDisplay:YES];
    }
}

void moxi_window_set_label(
    const char *text,
    float x,
    float y,
    float width,
    float height
) {
    moxi_window_set_label_at(0, text, x, y, width, height, 1.0, 1.0, 1.0, 1.0, 24.0, 0);
}

void moxi_window_set_button_at(
    int index,
    const char *text,
    float x,
    float y,
    float width,
    float height,
    float fill_red,
    float fill_green,
    float fill_blue,
    float fill_alpha,
    float text_red,
    float text_green,
    float text_blue,
    float text_alpha,
    float radius,
    float font_size,
    int wrap_text,
    int focused,
    int hovered,
    int pressed,
    int enabled
) {
    @autoreleasepool {
        if (moxi_canvas == nil || index < 0 || index >= MOXI_MAX_DRAW_COMMANDS) {
            if (index >= MOXI_MAX_DRAW_COMMANDS) {
                moxi_command_overflow_count += 1;
            }
            return;
        }

        NSString *button = text == NULL
            ? @""
            : [NSString stringWithUTF8String:text];
        moxi_button_texts[index] = button;
        moxi_button_frames[index] = NSMakeRect(x, y, width, height);
        moxi_copy_color(moxi_button_fill_colors[index], fill_red, fill_green, fill_blue, fill_alpha);
        moxi_copy_color(moxi_button_text_colors[index], text_red, text_green, text_blue, text_alpha);
        moxi_button_radii[index] = radius;
        moxi_button_font_sizes[index] = font_size;
        moxi_button_wraps[index] = wrap_text != 0;
        moxi_button_clip_enabled[index] = moxi_current_clip_enabled;
        moxi_button_clip_frames[index] = moxi_current_clip_frame;
        moxi_button_focused[index] = focused != 0;
        moxi_button_hovered[index] = hovered != 0;
        moxi_button_pressed[index] = pressed != 0;
        moxi_button_enabled[index] = enabled != 0;
        if (index + 1 > moxi_button_count) {
            moxi_button_count = index + 1;
        }
        [moxi_canvas setNeedsDisplay:YES];
    }
}

void moxi_window_set_button(
    const char *text,
    float x,
    float y,
    float width,
    float height
) {
    moxi_window_set_button_at(
        0, text, x, y, width, height,
        0.18, 0.48, 0.92, 1.0,
        1.0, 1.0, 1.0, 1.0,
        10.0, 16.0, 0, 0, 0, 0, 1
    );
}

void moxi_window_set_checkbox_at(
    int index,
    const char *text,
    float x,
    float y,
    float width,
    float height,
    float fill_red,
    float fill_green,
    float fill_blue,
    float fill_alpha,
    float text_red,
    float text_green,
    float text_blue,
    float text_alpha,
    float radius,
    float font_size,
    int focused,
    int hovered,
    int pressed,
    int enabled,
    int checked
) {
    @autoreleasepool {
        if (moxi_canvas == nil || index < 0 || index >= MOXI_MAX_DRAW_COMMANDS) {
            if (index >= MOXI_MAX_DRAW_COMMANDS) {
                moxi_command_overflow_count += 1;
            }
            return;
        }
        moxi_checkbox_texts[index] = text == NULL
            ? @""
            : [NSString stringWithUTF8String:text];
        moxi_checkbox_frames[index] = NSMakeRect(x, y, width, height);
        moxi_copy_color(moxi_checkbox_fill_colors[index], fill_red, fill_green, fill_blue, fill_alpha);
        moxi_copy_color(moxi_checkbox_text_colors[index], text_red, text_green, text_blue, text_alpha);
        moxi_checkbox_radii[index] = radius;
        moxi_checkbox_font_sizes[index] = font_size;
        moxi_checkbox_clip_enabled[index] = moxi_current_clip_enabled;
        moxi_checkbox_clip_frames[index] = moxi_current_clip_frame;
        moxi_checkbox_focused[index] = focused != 0;
        moxi_checkbox_hovered[index] = hovered != 0;
        moxi_checkbox_pressed[index] = pressed != 0;
        moxi_checkbox_enabled[index] = enabled != 0;
        moxi_checkbox_checked[index] = checked != 0;
        if (index + 1 > moxi_checkbox_count) {
            moxi_checkbox_count = index + 1;
        }
        [moxi_canvas setNeedsDisplay:YES];
    }
}

void moxi_window_set_progress_at(
    int index,
    const char *text,
    float x,
    float y,
    float width,
    float height,
    float fill_red,
    float fill_green,
    float fill_blue,
    float fill_alpha,
    float text_red,
    float text_green,
    float text_blue,
    float text_alpha,
    float radius,
    float font_size,
    float progress
) {
    @autoreleasepool {
        if (moxi_canvas == nil || index < 0 || index >= MOXI_MAX_DRAW_COMMANDS) {
            if (index >= MOXI_MAX_DRAW_COMMANDS) {
                moxi_command_overflow_count += 1;
            }
            return;
        }
        moxi_progress_texts[index] = text == NULL
            ? @""
            : [NSString stringWithUTF8String:text];
        moxi_progress_frames[index] = NSMakeRect(x, y, width, height);
        moxi_copy_color(moxi_progress_fill_colors[index], fill_red, fill_green, fill_blue, fill_alpha);
        moxi_copy_color(moxi_progress_text_colors[index], text_red, text_green, text_blue, text_alpha);
        moxi_progress_radii[index] = radius;
        moxi_progress_font_sizes[index] = font_size;
        moxi_progress_values[index] = MIN(1.0, MAX(0.0, progress));
        moxi_progress_clip_enabled[index] = moxi_current_clip_enabled;
        moxi_progress_clip_frames[index] = moxi_current_clip_frame;
        if (index + 1 > moxi_progress_count) {
            moxi_progress_count = index + 1;
        }
        [moxi_canvas setNeedsDisplay:YES];
    }
}

void moxi_window_set_slider_at(
    int index,
    const char *text,
    float x,
    float y,
    float width,
    float height,
    float fill_red,
    float fill_green,
    float fill_blue,
    float fill_alpha,
    float text_red,
    float text_green,
    float text_blue,
    float text_alpha,
    float radius,
    float font_size,
    float value,
    int focused,
    int hovered,
    int pressed,
    int enabled
) {
    @autoreleasepool {
        if (moxi_canvas == nil || index < 0 || index >= MOXI_MAX_DRAW_COMMANDS) {
            if (index >= MOXI_MAX_DRAW_COMMANDS) {
                moxi_command_overflow_count += 1;
            }
            return;
        }
        MoxiSliderSlot *slot = &moxi_slider_slots[index];
        slot->text = text == NULL ? @"" : [NSString stringWithUTF8String:text];
        if (slot->text == nil) {
            slot->text = @"";
        }
        slot->frame = NSMakeRect(x, y, width, height);
        moxi_copy_color(slot->fill, fill_red, fill_green, fill_blue, fill_alpha);
        moxi_copy_color(slot->textColor, text_red, text_green, text_blue, text_alpha);
        slot->radius = radius;
        slot->fontSize = font_size;
        slot->value = MIN(1.0, MAX(0.0, value));
        slot->focused = focused != 0;
        slot->hovered = hovered != 0;
        slot->pressed = pressed != 0;
        slot->enabled = enabled != 0;
        slot->clipEnabled = moxi_current_clip_enabled;
        slot->clipFrame = moxi_current_clip_frame;
        if (index + 1 > moxi_slider_count) {
            moxi_slider_count = index + 1;
        }
        [moxi_canvas setNeedsDisplay:YES];
    }
}

static void moxi_window_set_toggle_at_impl(
    int index,
    const char *text,
    float x,
    float y,
    float width,
    float height,
    float fill_red,
    float fill_green,
    float fill_blue,
    float fill_alpha,
    float text_red,
    float text_green,
    float text_blue,
    float text_alpha,
    float radius,
    float font_size,
    int focused,
    int hovered,
    int pressed,
    int enabled,
    int checked,
    int radio
) {
    @autoreleasepool {
        if (moxi_canvas == nil || index < 0 || index >= MOXI_MAX_DRAW_COMMANDS) {
            if (index >= MOXI_MAX_DRAW_COMMANDS) {
                moxi_command_overflow_count += 1;
            }
            return;
        }
        MoxiToggleSlot *slot = &moxi_toggle_slots[index];
        slot->text = text == NULL ? @"" : [NSString stringWithUTF8String:text];
        if (slot->text == nil) {
            slot->text = @"";
        }
        slot->frame = NSMakeRect(x, y, width, height);
        moxi_copy_color(slot->fill, fill_red, fill_green, fill_blue, fill_alpha);
        moxi_copy_color(slot->textColor, text_red, text_green, text_blue, text_alpha);
        slot->radius = radius;
        slot->fontSize = font_size;
        slot->focused = focused != 0;
        slot->hovered = hovered != 0;
        slot->pressed = pressed != 0;
        slot->enabled = enabled != 0;
        slot->checked = checked != 0;
        slot->radio = radio != 0;
        slot->clipEnabled = moxi_current_clip_enabled;
        slot->clipFrame = moxi_current_clip_frame;
        if (index + 1 > moxi_toggle_count) {
            moxi_toggle_count = index + 1;
        }
        [moxi_canvas setNeedsDisplay:YES];
    }
}

void moxi_window_set_toggle_at(
    int index,
    const char *text,
    float x,
    float y,
    float width,
    float height,
    float fill_red,
    float fill_green,
    float fill_blue,
    float fill_alpha,
    float text_red,
    float text_green,
    float text_blue,
    float text_alpha,
    float radius,
    float font_size,
    int focused,
    int hovered,
    int pressed,
    int enabled,
    int checked,
    int radio
) {
    moxi_window_set_toggle_at_impl(
        index,
        text,
        x,
        y,
        width,
        height,
        fill_red,
        fill_green,
        fill_blue,
        fill_alpha,
        text_red,
        text_green,
        text_blue,
        text_alpha,
        radius,
        font_size,
        focused,
        hovered,
        pressed,
        enabled,
        checked,
        radio
    );
}

void moxi_window_set_text_input_at(
    int index,
    const char *text,
    float x,
    float y,
    float width,
    float height,
    float fill_red,
    float fill_green,
    float fill_blue,
    float fill_alpha,
    float text_red,
    float text_green,
    float text_blue,
    float text_alpha,
    float radius,
    float font_size,
    int wrap_text,
    int focused,
    int cursor,
    int selection_start,
    int selection_end,
    const char *composition,
    int composition_selection_start,
    int composition_selection_end
) {
    @autoreleasepool {
        if (moxi_canvas == nil || index < 0 || index >= MOXI_MAX_DRAW_COMMANDS) {
            if (index >= MOXI_MAX_DRAW_COMMANDS) {
                moxi_command_overflow_count += 1;
            }
            return;
        }

        NSString *input = text == NULL
            ? @""
            : [NSString stringWithUTF8String:text];
        moxi_text_input_texts[index] = input;
        moxi_text_input_frames[index] = NSMakeRect(x, y, width, height);
        moxi_copy_color(moxi_text_input_fill_colors[index], fill_red, fill_green, fill_blue, fill_alpha);
        moxi_copy_color(moxi_text_input_text_colors[index], text_red, text_green, text_blue, text_alpha);
        moxi_text_input_radii[index] = radius;
        moxi_text_input_font_sizes[index] = font_size;
        moxi_text_input_wraps[index] = wrap_text != 0;
        moxi_text_input_clip_enabled[index] = moxi_current_clip_enabled;
        moxi_text_input_clip_frames[index] = moxi_current_clip_frame;
        moxi_text_input_focused[index] = focused != 0;
        moxi_text_input_cursors[index] = cursor;
        moxi_text_input_selection_starts[index] = selection_start;
        moxi_text_input_selection_ends[index] = selection_end;
        moxi_text_input_compositions[index] = composition == NULL
            ? @""
            : [NSString stringWithUTF8String:composition];
        if (moxi_text_input_compositions[index] == nil) {
            moxi_text_input_compositions[index] = @"";
        }
        moxi_text_input_composition_selection_starts[index] = composition_selection_start;
        moxi_text_input_composition_selection_ends[index] = composition_selection_end;
        if (focused != 0) {
            moxi_active_text_input_index = index;
        }
        if (index + 1 > moxi_text_input_count) {
            moxi_text_input_count = index + 1;
        }
        [moxi_canvas setNeedsDisplay:YES];
    }
}

void moxi_window_pump(void) {
    @autoreleasepool {
        NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:0.016];
        NSEvent *event = [NSApp nextEventMatchingMask:NSEventMaskAny
                                            untilDate:deadline
                                               inMode:NSDefaultRunLoopMode
                                              dequeue:YES];
        if (event != nil) {
            [NSApp sendEvent:event];
        }
        [NSApp updateWindows];

        if (moxi_canvas != nil) {
            CGFloat width = NSWidth(moxi_canvas.bounds);
            CGFloat height = NSHeight(moxi_canvas.bounds);
            if (width != moxi_last_canvas_width || height != moxi_last_canvas_height) {
                moxi_last_canvas_width = width;
                moxi_last_canvas_height = height;
                moxi_queue_event(MOXI_EVENT_WINDOW_RESIZED);
            }
        }
    }
}

int moxi_window_is_open(void) {
    return moxi_window_opened ? 1 : 0;
}

int moxi_window_poll_click(void) {
    BOOL hasClick = moxi_click_pending;
    moxi_click_pending = NO;
    return hasClick ? 1 : 0;
}

float moxi_window_click_x(void) {
    return moxi_last_click_x;
}

float moxi_window_click_y(void) {
    return moxi_last_click_y;
}

int moxi_window_poll_event(void) {
    if (!moxi_has_pending_events()) {
        return MOXI_EVENT_NONE;
    }
    MoxiQueuedEvent *queued = &moxi_event_queue[moxi_event_queue_head];
    moxi_event_kind = queued->kind;
    moxi_event_key = queued->key;
    moxi_event_modifiers = queued->modifiers;
    moxi_event_codepoint = queued->codepoint;
    moxi_event_selection_start = queued->selectionStart;
    moxi_event_selection_end = queued->selectionEnd;
    moxi_event_x = queued->x;
    moxi_event_y = queued->y;
    moxi_event_scroll_x = queued->scrollX;
    moxi_event_scroll_y = queued->scrollY;
    moxi_event_target = queued->target;
    moxi_event_action = queued->action;
    moxi_event_text_value = queued->text == nil ? nil : [queued->text copy];
    queued->text = nil;
    int kind = moxi_event_kind;
    queued->kind = MOXI_EVENT_NONE;
    moxi_event_queue_head =
        (moxi_event_queue_head + 1) % MOXI_EVENT_QUEUE_CAPACITY;
    moxi_event_queue_count -= 1;
    if (kind == MOXI_EVENT_POINTER_DOWN) {
        moxi_click_pending = NO;
    }
    return kind;
}

int moxi_window_event_queue_depth(void) {
    return moxi_event_queue_count;
}

int moxi_window_event_dropped_count(void) {
    return moxi_event_dropped_count;
}

int moxi_window_command_overflow_count(void) {
    return moxi_command_overflow_count;
}

int moxi_window_event_key(void) {
    return moxi_event_key;
}

int moxi_window_event_modifiers(void) {
    return moxi_event_modifiers;
}

int moxi_window_event_codepoint(void) {
    return moxi_event_codepoint;
}

int moxi_window_event_codepoint_at(int target) {
    @autoreleasepool {
        if (target < 0 || moxi_event_text_value == nil) {
            return -1;
        }
        NSUInteger index = 0;
        int current = 0;
        while (index < [moxi_event_text_value length] && current < target) {
            index = moxi_advance_codepoint(moxi_event_text_value, index);
            current += 1;
        }
        if (current != target || index >= [moxi_event_text_value length]) {
            return -1;
        }
        unichar high = [moxi_event_text_value characterAtIndex:index];
        if (high >= 0xD800 && high <= 0xDBFF && index + 1 < [moxi_event_text_value length]) {
            unichar low = [moxi_event_text_value characterAtIndex:index + 1];
            if (low >= 0xDC00 && low <= 0xDFFF) {
                return 0x10000 + ((high - 0xD800) << 10) + (low - 0xDC00);
            }
        }
        return (int)high;
    }
}

int moxi_window_event_selection_start(void) {
    return moxi_event_selection_start;
}

int moxi_window_event_selection_end(void) {
    return moxi_event_selection_end;
}

float moxi_window_event_x(void) {
    return moxi_event_x;
}

float moxi_window_event_y(void) {
    return moxi_event_y;
}

float moxi_window_event_scroll_x(void) {
    return moxi_event_scroll_x;
}

float moxi_window_event_scroll_y(void) {
    return moxi_event_scroll_y;
}

int moxi_window_event_target(void) {
    return moxi_event_target;
}

int moxi_window_event_action(void) {
    return moxi_event_action;
}

float moxi_window_width(void) {
    if (moxi_canvas == nil) {
        return 0.0;
    }
    return NSWidth(moxi_canvas.bounds);
}

float moxi_window_height(void) {
    if (moxi_canvas == nil) {
        return 0.0;
    }
    return NSHeight(moxi_canvas.bounds);
}

static BOOL moxi_demo_task_name_is_safe(NSString *task) {
    NSUInteger length = [task length];
    if (length == 0 || length > 64) {
        return NO;
    }
    for (NSUInteger index = 0; index < length; index++) {
        unichar value = [task characterAtIndex:index];
        BOOL lowercase = value >= 'a' && value <= 'z';
        BOOL digit = value >= '0' && value <= '9';
        if (!lowercase && !digit && value != '-' && value != '_') {
            return NO;
        }
    }
    return YES;
}

int moxi_demo_launch(const char *task) {
    @autoreleasepool {
        if (task == NULL) {
            return 0;
        }
        NSString *taskName = [NSString stringWithUTF8String:task];
        if (taskName == nil || !moxi_demo_task_name_is_safe(taskName)) {
            return 0;
        }
        if (moxi_demo_task != nil && [moxi_demo_task isRunning]) {
            return 0;
        }

        NSTask *process = [[NSTask alloc] init];
        process.executableURL = [NSURL fileURLWithPath:@"/bin/zsh"];
        process.arguments = @[
            @"-lc",
            [NSString stringWithFormat:@"exec pixi run %@", taskName],
        ];
        process.currentDirectoryURL = [NSURL fileURLWithPath:
            [[NSFileManager defaultManager] currentDirectoryPath]
            isDirectory:YES];
        process.standardOutput = [NSFileHandle fileHandleWithStandardOutput];
        process.standardError = [NSFileHandle fileHandleWithStandardError];

        NSError *error = nil;
        if (![process launchAndReturnError:&error]) {
            return 0;
        }
        moxi_demo_task = process;
        return 1;
    }
}

int moxi_demo_is_running(void) {
    @autoreleasepool {
        return moxi_demo_task != nil && [moxi_demo_task isRunning] ? 1 : 0;
    }
}

int moxi_demo_exit_status(void) {
    @autoreleasepool {
        if (moxi_demo_task == nil || [moxi_demo_task isRunning]) {
            return -1;
        }
        return (int)[moxi_demo_task terminationStatus];
    }
}
