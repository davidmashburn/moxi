#ifndef MOXI_IOS_HOST_H
#define MOXI_IOS_HOST_H

#include "moxi_host.h"

#ifdef __cplusplus
extern "C" {
#endif

void *moxi_ios_host_create(
    float width,
    float height,
    MoxiHostCallbacks callbacks,
    void *context
);

void moxi_ios_host_destroy(void *handle);
void moxi_ios_host_request_frame(void *handle);
void moxi_ios_host_resize(void *handle, float width, float height);
void moxi_ios_host_text(void *handle, const char *text, int start, int end);
void moxi_ios_host_composition(void *handle, const char *text, int start, int end);
void moxi_ios_host_begin_accessibility(void *handle);
void moxi_ios_host_set_accessibility_node(
    void *handle,
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
void moxi_ios_host_end_accessibility(void *handle);

#ifdef __cplusplus
}
#endif

#endif
