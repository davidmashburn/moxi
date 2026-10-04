/* Native Linux workbench host. Shared C ABI with the AppKit transport. */
#ifndef MOXI_LINUX_WINDOW_H
#define MOXI_LINUX_WINDOW_H
#include <stdint.h>
#ifdef MOXI_LINUX_TEST
#include <cairo.h>
#endif
#ifdef __cplusplus
extern "C" {
#endif
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
);

void moxi_window_begin_frame(void);

void moxi_window_ordered_paint_begin(void);

void moxi_window_ordered_paint(int kind, int slot);

void moxi_window_set_custom_paint_cache_enabled(int enabled);

void moxi_window_begin_custom_paint(void);

void moxi_window_set_custom_clip(
    float x,
    float y,
    float width,
    float height
);

void moxi_window_add_custom_rect(
    float x,
    float y,
    float width,
    float height,
    float fill_red,
    float fill_green,
    float fill_blue,
    float fill_alpha,
    float stroke_red,
    float stroke_green,
    float stroke_blue,
    float stroke_alpha,
    float stroke_width
);

void moxi_window_add_custom_rounded_rect(
    float x,
    float y,
    float width,
    float height,
    float fill_red,
    float fill_green,
    float fill_blue,
    float fill_alpha,
    float stroke_red,
    float stroke_green,
    float stroke_blue,
    float stroke_alpha,
    float stroke_width,
    float radius
);

void moxi_window_add_custom_line(
    float start_x,
    float start_y,
    float end_x,
    float end_y,
    float red,
    float green,
    float blue,
    float alpha,
    float width
);

void moxi_window_add_custom_circle(
    float center_x,
    float center_y,
    float radius,
    float fill_red,
    float fill_green,
    float fill_blue,
    float fill_alpha,
    float stroke_red,
    float stroke_green,
    float stroke_blue,
    float stroke_alpha,
    float stroke_width
);

void moxi_window_add_custom_text(
    const char *text,
    float x,
    float y,
    float width,
    float height,
    float red,
    float green,
    float blue,
    float alpha,
    float font_size
);

void moxi_window_end_frame(void);

void moxi_window_begin_accessibility(void);

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
    int checked,
    int expanded,
    int has_value_range,
    float value_min,
    float value_max,
    float value_now,
    int actions
);

void moxi_window_end_accessibility(void);

void moxi_window_set_clip(
    int enabled,
    float x,
    float y,
    float width,
    float height
);

void moxi_window_set_surface(
    float red,
    float green,
    float blue,
    float alpha
);

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
);

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
);

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
);

void moxi_window_set_scrollbar_at(
    int index,
    float track_x,
    float track_y,
    float track_width,
    float track_height,
    float thumb_x,
    float thumb_y,
    float thumb_width,
    float thumb_height,
    float track_red,
    float track_green,
    float track_blue,
    float track_alpha,
    float thumb_red,
    float thumb_green,
    float thumb_blue,
    float thumb_alpha,
    float radius,
    int visible
);

void moxi_window_register_image(int resource_id, const char *source);

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
);

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
);

void moxi_window_text_editor_key(int key);

void moxi_window_set_paragraph_at(int index, uintptr_t handle);

void moxi_window_set_label(
    const char *text,
    float x,
    float y,
    float width,
    float height
);

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
);

void moxi_window_set_button(
    const char *text,
    float x,
    float y,
    float width,
    float height
);

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
);

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
);

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
);

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
);

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
);

void moxi_window_pump(void);

int moxi_window_is_open(void);

int moxi_window_poll_click(void);

float moxi_window_click_x(void);

float moxi_window_click_y(void);

int moxi_window_poll_event(void);

int moxi_window_event_queue_depth(void);

int moxi_window_event_dropped_count(void);

int moxi_window_command_overflow_count(void);

int moxi_window_event_key(void);

int moxi_window_event_modifiers(void);

int moxi_window_event_codepoint(void);

int moxi_window_event_codepoint_at(int target);

int moxi_window_event_selection_start(void);

int moxi_window_event_selection_end(void);

float moxi_window_event_x(void);

float moxi_window_event_y(void);

float moxi_window_event_scroll_x(void);

float moxi_window_event_scroll_y(void);

int moxi_window_event_target(void);

int moxi_window_event_action(void);

float moxi_window_width(void);

float moxi_window_height(void);
#ifdef __cplusplus
}
#endif
#ifdef MOXI_LINUX_TEST
void moxi_linux_test_draw(cairo_t *cr, int width, int height);
void moxi_linux_test_push_event(int kind, int target, const char *text, float dx, float dy);
#endif
#endif
