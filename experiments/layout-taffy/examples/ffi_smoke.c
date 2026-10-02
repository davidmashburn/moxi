#include <stdio.h>
#include <stdlib.h>

#include "layout_taffy.h"

int main(void) {
    void *tree = layout_taffy_create(200.0f, 100.0f);
    if (tree == NULL) {
        return 1;
    }
    int32_t first = layout_taffy_add_text(tree, "hello", 16.0f, 1.0f);
    int32_t second = layout_taffy_add_text(tree, "world", 16.0f, 1.0f);
    if (first < 0 || second < 0 || layout_taffy_compute(tree, 200.0f, 100.0f) != 0) {
        layout_taffy_destroy(tree);
        return 2;
    }
    layout_taffy_rect rect = {0};
    if (layout_taffy_get_rect(tree, (uint32_t)first, &rect) != 0) {
        layout_taffy_destroy(tree);
        return 3;
    }
    printf("ffi first: %.2f %.2f %.2f %.2f\n", rect.x, rect.y, rect.width, rect.height);
    layout_taffy_destroy(tree);
    return rect.width > 0.0f ? 0 : 4;
}
