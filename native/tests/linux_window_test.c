#include "../linux_window.h"
#include "../linux_text.h"

#include <assert.h>
#include <stdint.h>
#include <stdio.h>

static uint32_t pixel(cairo_surface_t *surface, int x, int y) {
    cairo_surface_flush(surface);
    const unsigned char *data = cairo_image_surface_get_data(surface);
    int stride = cairo_image_surface_get_stride(surface);
    return ((const uint32_t *)(data + y * stride))[x];
}

static cairo_surface_t *render(int width, int height) {
    cairo_surface_t *surface = cairo_image_surface_create(CAIRO_FORMAT_ARGB32,
                                                         width, height);
    cairo_t *cr = cairo_create(surface);
    moxi_linux_test_draw(cr, width, height);
    assert(cairo_status(cr) == CAIRO_STATUS_SUCCESS);
    cairo_destroy(cr);
    return surface;
}

static void check_ordered_clipped_paint(void) {
    moxi_window_begin_frame();
    moxi_window_begin_custom_paint();
    moxi_window_set_clip(0, 0, 0, 64, 64);
    moxi_window_set_surface(0, 0, 0, 0);
    moxi_window_set_panel_at(0, 0, 0, 64, 64, 1, 0, 0, 1, 0,
                              0, 0, 0, 64, 64);
    moxi_window_set_panel_at(1, 0, 0, 64, 64, 0, 0, 1, 1, 0,
                              1, 8, 8, 16, 16);
    moxi_window_set_custom_clip(0, 0, 32, 32);
    moxi_window_add_custom_rect(0, 0, 64, 64, 1, 1, 0, 1,
                                0, 0, 0, 0, 0);
    moxi_window_set_button_at(0, "", 12, 12, 20, 20,
                               0, 1, 0, 1, 0, 0, 0, 0,
                               0, 16, 0, 0, 0, 0, 1);
    moxi_window_ordered_paint_begin();
    moxi_window_ordered_paint(3, 0);
    moxi_window_ordered_paint(100, 0);
    moxi_window_ordered_paint(3, 1);
    moxi_window_ordered_paint(2, 0);
    cairo_surface_t *surface = render(64, 64);
    assert(pixel(surface, 40, 40) == UINT32_C(0xffff0000));
    assert(pixel(surface, 4, 10) == UINT32_C(0xffffff00));
    assert(pixel(surface, 10, 10) == UINT32_C(0xff0000ff));
    assert(pixel(surface, 20, 20) == UINT32_C(0xff00ff00));
    assert(pixel(surface, 28, 5) == UINT32_C(0xffffff00));
    assert(moxi_window_command_overflow_count() == 0);
    cairo_surface_destroy(surface);
}

static void check_paragraph_ownership(void) {
    moxi_window_begin_frame();
    moxi_window_begin_custom_paint();
    moxi_window_set_surface(0, 0, 0, 0);
    moxi_window_set_label_at(0, "", 10, 10, 100, 40,
                             1, 1, 1, 1, 18, 1);
    uintptr_t paragraph = moxi_paragraph_create("Retained", 18, 100, 0);
    assert(paragraph != 0);
    moxi_window_set_paragraph_at(0, paragraph);
    moxi_paragraph_release(paragraph);
    // The slot is now the sole owner; assigning that same handle must retain
    // before releasing its previous reference.
    moxi_window_set_paragraph_at(0, paragraph);
    assert(moxi_paragraph_metric(paragraph, 1) > 0);
    moxi_window_ordered_paint_begin();
    moxi_window_ordered_paint(1, 0);
    cairo_surface_t *surface = render(128, 64);
    int painted = 0;
    for (int y = 0; y < 64; y++) for (int x = 0; x < 128; x++) {
        if (pixel(surface, x, y) != 0) {
            assert(x >= 10 && x < 110 && y >= 10 && y < 50);
            painted++;
        }
    }
    assert(painted > 0);
    cairo_surface_destroy(surface);
    moxi_window_begin_frame(); // Releases the final native drawing reference.
    moxi_window_begin_frame();
}

static void drain_events(void) {
    while (moxi_window_poll_event() != 0) {}
    assert(moxi_window_event_queue_depth() == 0);
}

static void check_unicode_event_abi(void) {
    drain_events();
    moxi_linux_test_push_event(3, 13, "A\xe6\x97\xa5\xf0\x9f\x99\x82", 0, 0);
    assert(moxi_window_event_queue_depth() == 1);
    assert(moxi_window_poll_event() == 3);
    assert(moxi_window_event_target() == 13);
    assert(moxi_window_event_selection_start() == -1);
    assert(moxi_window_event_selection_end() == -1);
    assert(moxi_window_event_codepoint() == 'A');
    assert(moxi_window_event_codepoint_at(1) == 0x65e5);
    assert(moxi_window_event_codepoint_at(2) == 0x1f642);
    assert(moxi_window_event_codepoint_at(-1) == -1);
    assert(moxi_window_event_codepoint_at(3) == -1);
    assert(moxi_window_poll_event() == 0);
    assert(moxi_window_event_codepoint() == -1);
    moxi_linux_test_push_event(8, 1032, "\xe3\x81\x8b\xe3\x81\xaa", 0, 0);
    assert(moxi_window_poll_event() == 8);
    assert(moxi_window_event_target() == 1032);
    assert(moxi_window_event_codepoint_at(0) == 0x304b);
    assert(moxi_window_event_codepoint_at(1) == 0x306a);
    drain_events();
}

static void check_event_coalescing_and_capacity(void) {
    drain_events();
    int dropped = moxi_window_event_dropped_count();
    moxi_linux_test_push_event(3, 13, "Committed", 0, 0);
    for (int i = 0; i < 200; i++)
        moxi_linux_test_push_event(6, -1, NULL, 0, 0);
    assert(moxi_window_event_queue_depth() == 2);
    assert(moxi_window_event_dropped_count() == dropped);
    assert(moxi_window_poll_event() == 3);
    assert(moxi_window_event_target() == 13);
    assert(moxi_window_event_codepoint() == 'C');
    assert(moxi_window_poll_event() == 6);
    drain_events();
    moxi_linux_test_push_event(11, -1, NULL, 1.25f, 2.5f);
    moxi_linux_test_push_event(11, -1, NULL, -0.25f, 3.5f);
    assert(moxi_window_event_queue_depth() == 1);
    assert(moxi_window_poll_event() == 11);
    assert(moxi_window_event_scroll_x() == 1);
    assert(moxi_window_event_scroll_y() == 6);
    drain_events();
    for (int i = 0; i < 64; i++)
        moxi_linux_test_push_event(3, i, "x", 0, 0);
    assert(moxi_window_event_queue_depth() == 64);
    moxi_linux_test_push_event(3, 999, "Dropped", 0, 0);
    assert(moxi_window_event_queue_depth() == 64);
    assert(moxi_window_event_dropped_count() == dropped + 1);
    for (int i = 0; i < 64; i++) {
        assert(moxi_window_poll_event() == 3);
        assert(moxi_window_event_target() == i);
        assert(moxi_window_event_codepoint() == 'x');
    }
    drain_events();
}

static void check_command_capacity(void) {
    moxi_window_begin_frame();
    for (int i = 0; i < 1024; i++)
        moxi_window_set_label_at(i, "", 0, 0, 1, 1, 1, 1, 1, 1, 16, 0);
    assert(moxi_window_command_overflow_count() == 0);
    moxi_window_set_label_at(-1, "", 0, 0, 1, 1, 1, 1, 1, 1, 16, 0);
    moxi_window_set_label_at(1024, "", 0, 0, 1, 1, 1, 1, 1, 1, 16, 0);
    assert(moxi_window_command_overflow_count() == 2);
    moxi_window_begin_frame();
    moxi_window_ordered_paint_begin();
    for (int i = 0; i < 1024; i++) moxi_window_ordered_paint(1, i);
    moxi_window_ordered_paint(100, 0);
    assert(moxi_window_command_overflow_count() == 0);
    moxi_window_ordered_paint(100, 0);
    assert(moxi_window_command_overflow_count() == 1);
    moxi_window_begin_frame();
    assert(moxi_window_command_overflow_count() == 0);
}

int main(void) {
    assert(moxi_window_is_open() == 0);
    check_ordered_clipped_paint();
    check_paragraph_ownership();
    check_unicode_event_abi();
    check_event_coalescing_and_capacity();
    check_command_capacity();
    puts("Linux native Cairo paint and bounded event ABI: pass (no display)");
    return 0;
}
