#include "../linux_text.h"

#include <assert.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

static void check_validation(void) {
    assert(moxi_paragraph_create(NULL, 16, 100, 0) == 0);
    assert(moxi_paragraph_create("bad\xc0\xaf", 16, 100, 0) == 0);
    assert(moxi_paragraph_create("text", 0, 100, 0) == 0);
    assert(moxi_paragraph_create("text", NAN, 100, 0) == 0);
    assert(moxi_paragraph_create("text", INFINITY, 100, 0) == 0);
    assert(moxi_paragraph_create("text", 16, -1, 0) == 0);
    assert(moxi_paragraph_create("text", 16, NAN, 0) == 0);
    assert(moxi_paragraph_create("text", 16, INFINITY, 0) == 0);
    assert(moxi_paragraph_create("text", 16, 100, -1) == 0);
    assert(moxi_paragraph_create("text", 16, 100, 3) == 0);
    assert(moxi_paragraph_query("text", 16, 100, 0, -1) == 0);
    assert(moxi_paragraph_query("text", 16, 100, 0, 3) == 0);
    assert(moxi_paragraph_metric(0, 0) == 0);
    moxi_paragraph_retain(0);
    moxi_paragraph_release(0);
}

static void check_lines(const char *text, float width, int line_count) {
    uintptr_t handle = moxi_paragraph_create(text, 16, width, 0);
    assert(handle != 0);
    assert(moxi_paragraph_metric(handle, 0) == width);
    assert(moxi_paragraph_metric(handle, 4) == line_count);
    float height = moxi_paragraph_metric(handle, 1);
    float first = moxi_paragraph_metric(handle, 2);
    float last = moxi_paragraph_metric(handle, 3);
    assert(isfinite(height) && height > 0);
    assert(first > 0 && first <= last && last < height);
    assert((line_count == 1) == (first == last));
    assert(moxi_paragraph_metric(handle, 99) == 0);
    moxi_paragraph_release(handle);
}

static void check_intrinsic(void) {
    for (int query = 0; query <= 2; query++) {
        uintptr_t empty = moxi_paragraph_query("", 16, 0, 0, query);
        assert(empty != 0 && moxi_paragraph_metric(empty, 0) == 0);
        assert(moxi_paragraph_metric(empty, 4) == 1);
        moxi_paragraph_release(empty);
    }
    uintptr_t max = moxi_paragraph_query("abcdef\nxy", 16, NAN, 0, 2);
    uintptr_t min = moxi_paragraph_query("abcdef\nxy", 16, NAN, 0, 1);
    assert(max != 0 && min != 0);
    assert(moxi_paragraph_metric(max, 4) == 2);
    assert(moxi_paragraph_metric(min, 0) > 0);
    assert(moxi_paragraph_metric(min, 0) < moxi_paragraph_metric(max, 0));
    uintptr_t finite = moxi_paragraph_create("abcdef\nxy", 16,
                                            moxi_paragraph_metric(max, 0), 0);
    assert(finite != 0 && moxi_paragraph_metric(finite, 4) == 2);
    uintptr_t narrow = moxi_paragraph_create("abcdef", 16, 10, 0);
    assert(narrow != 0 && moxi_paragraph_metric(narrow, 4) > 1);
    // A composed cluster cannot be split merely because its offer is zero.
    uintptr_t cluster = moxi_paragraph_query("a\xcc\x81", 16, 0, 0, 1);
    assert(cluster != 0 && moxi_paragraph_metric(cluster, 4) == 1);
    moxi_paragraph_release(cluster);
    moxi_paragraph_release(narrow);
    moxi_paragraph_release(finite);
    moxi_paragraph_release(min);
    moxi_paragraph_release(max);
}

static void check_draw(void) {
    enum { SIZE = 256 };
    cairo_surface_t *surface = cairo_image_surface_create(CAIRO_FORMAT_ARGB32,
                                                          SIZE, SIZE);
    cairo_t *cr = cairo_create(surface);
    uintptr_t handle = moxi_paragraph_create("\xd7\xa9\xd7\x9c\xd7\x95\xd7\x9d", 20, 150, 0);
    assert(handle != 0);
    float before[5];
    for (int i = 0; i < 5; i++) before[i] = moxi_paragraph_metric(handle, i);
    moxi_paragraph_retain(handle);
    moxi_paragraph_release(handle); // The remaining snapshot/draw reference is live.
    cairo_translate(cr, 3, 4);
    cairo_set_source_rgba(cr, 0.2, 0.3, 0.4, 0.5);
    cairo_matrix_t before_matrix, after_matrix;
    cairo_get_matrix(cr, &before_matrix);
    moxi_linux_paragraph_draw(cr, handle, 20, 20, 150, 40, 1, 0, 0, 1);
    cairo_get_matrix(cr, &after_matrix);
    assert(memcmp(&before_matrix, &after_matrix, sizeof(before_matrix)) == 0);
    double r, g, b, a;
    assert(cairo_pattern_get_rgba(cairo_get_source(cr), &r, &g, &b, &a) == CAIRO_STATUS_SUCCESS);
    assert(r == 0.2 && g == 0.3 && b == 0.4 && a == 0.5);
    assert(cairo_status(cr) == CAIRO_STATUS_SUCCESS);
    cairo_surface_flush(surface);
    unsigned char *data = cairo_image_surface_get_data(surface);
    int stride = cairo_image_surface_get_stride(surface);
    int left = SIZE, painted = 0;
    for (int y = 0; y < SIZE; y++) {
        const uint32_t *row = (const uint32_t *)(data + y * stride);
        for (int x = 0; x < SIZE; x++) if (row[x] != 0) {
            assert(x >= 23 && x < 173 && y >= 24 && y < 64);
            if (x < left) left = x;
            painted++;
        }
    }
    assert(painted > 0 && left < 45); // RTL logical.x must not displace text to the far edge.
    for (int i = 0; i < 5; i++) assert(moxi_paragraph_metric(handle, i) == before[i]);
    cairo_surface_t *zero = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, SIZE, SIZE);
    cairo_t *zero_cr = cairo_create(zero);
    moxi_linux_paragraph_draw(zero_cr, handle, 0, 0, 0, 40, 1, 0, 0, 1);
    cairo_surface_flush(zero);
    data = cairo_image_surface_get_data(zero);
    stride = cairo_image_surface_get_stride(zero);
    for (int y = 0; y < SIZE; y++) {
        const uint32_t *row = (const uint32_t *)(data + y * stride);
        for (int x = 0; x < SIZE; x++) assert(row[x] == 0);
    }
    cairo_destroy(zero_cr);
    cairo_surface_destroy(zero);
    moxi_paragraph_release(handle);
    cairo_destroy(cr);
    cairo_surface_destroy(surface);
}

typedef struct { float width, height, first_baseline, last_baseline; } Metrics;
typedef int (*Measure)(const char *, float, float, int, int, Metrics *, uintptr_t *);

static void check_adapter(void) {
    Measure measure = (Measure)moxi_layout_native_measure_address();
    void (*release)(uintptr_t) = (void (*)(uintptr_t))moxi_layout_native_release_address();
    Metrics metrics;
    uintptr_t payload = 99;
    assert(measure("adapter", 16, 80, 1, 0, &metrics, &payload) == 0);
    assert(payload != 0 && metrics.width == 80 && metrics.height > 0);
    assert(metrics.first_baseline == moxi_paragraph_metric(payload, 2));
    release(payload);
    assert(measure("adapter", NAN, 80, 1, 0, &metrics, &payload) == 1);
    assert(payload == 0);
}

int main(void) {
    check_validation();
    check_lines("", 24, 1);
    check_lines("a\n", 100, 2);
    check_lines("\n\n", 100, 3);
    check_lines("a\r\nb\r\n", 100, 3);
    check_lines("a\rb", 100, 2);
    check_lines("ab", 0, 2);
    check_lines("a\xcc\x81" "b", 0, 2);
    check_lines("\xf0\x9f\x91\xa9\xe2\x80\x8d\xf0\x9f\x92\xbb" "x", 0, 2);
    check_intrinsic();
    check_draw();
    check_adapter();
    puts("Linux retained Pango paragraphs: pass");
    return 0;
}
