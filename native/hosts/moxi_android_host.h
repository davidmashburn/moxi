#ifndef MOXI_ANDROID_HOST_H
#define MOXI_ANDROID_HOST_H

#include "moxi_host.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct MoxiAndroidHost MoxiAndroidHost;

MoxiAndroidHost *moxi_android_host_create(
    float width,
    float height,
    float scale,
    MoxiHostCallbacks callbacks,
    void *context
);

void moxi_android_host_destroy(MoxiAndroidHost *host);
void moxi_android_host_set_surface(MoxiAndroidHost *host, void *surface);
void moxi_android_host_set_size(MoxiAndroidHost *host, float width, float height, float scale);
void moxi_android_host_touch(
    MoxiAndroidHost *host,
    int kind,
    int pointer_id,
    float x,
    float y,
    int buttons,
    int modifiers
);
void moxi_android_host_key(MoxiAndroidHost *host, int key, int modifiers);
void moxi_android_host_text(MoxiAndroidHost *host, const char *text, int start, int end);
void moxi_android_host_composition(MoxiAndroidHost *host, const char *text, int start, int end);
void moxi_android_host_action(MoxiAndroidHost *host, int target, int action);
void moxi_android_host_frame(MoxiAndroidHost *host);

#ifdef __cplusplus
}
#endif

#endif
