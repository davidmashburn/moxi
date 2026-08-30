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

#ifdef __cplusplus
}
#endif

#endif
