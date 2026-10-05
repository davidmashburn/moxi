/* Display-free bitmap host using the production Linux painter verbatim. */
#include "../native/linux_window.c"

static cairo_surface_t *layout_benchmark_bitmap;
static cairo_t *layout_benchmark_context;

static void layout_benchmark_check(void) {
    cairo_status_t status = cairo_status(layout_benchmark_context);
    if (status == CAIRO_STATUS_SUCCESS)
        status = cairo_surface_status(layout_benchmark_bitmap);
    if (status != CAIRO_STATUS_SUCCESS) {
        fprintf(stderr, "Moxi benchmark bitmap: %s\n", cairo_status_to_string(status));
        abort();
    }
}

void moxi_layout_benchmark_host(int width, int height) {
    if (layout_benchmark_context) cairo_destroy(layout_benchmark_context);
    if (layout_benchmark_bitmap) cairo_surface_destroy(layout_benchmark_bitmap);
    layout_benchmark_bitmap = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, width, height);
    layout_benchmark_context = cairo_create(layout_benchmark_bitmap);
    window_width = (float)width;
    window_height = (float)height;
    window_scale = 1;
    layout_benchmark_check();
}

void moxi_layout_benchmark_size(int width, int height) {
    window_width = (float)width;
    window_height = (float)height;
}

void moxi_layout_benchmark_draw(void) {
    cairo_save(layout_benchmark_context);
    cairo_rectangle(layout_benchmark_context, 0, 0, window_width, window_height);
    cairo_clip(layout_benchmark_context);
    draw(NULL, layout_benchmark_context, (int)window_width, (int)window_height, NULL);
    cairo_restore(layout_benchmark_context);
    cairo_surface_flush(layout_benchmark_bitmap);
    layout_benchmark_check();
}
