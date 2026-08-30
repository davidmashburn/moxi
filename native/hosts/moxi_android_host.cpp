#include "moxi_android_host.h"

#include <stdint.h>
#include <stdlib.h>

#if defined(__ANDROID__)
#include <android/input.h>
#include <android/native_window.h>
#endif

struct MoxiAndroidHost {
    MoxiHostCallbacks callbacks;
    void *context;
    float width;
    float height;
    float scale;
#if defined(__ANDROID__)
    ANativeWindow *surface;
#else
    void *surface;
#endif
};

static void moxi_android_resize(MoxiAndroidHost *host) {
    if (host == NULL || host->callbacks.resize == NULL) return;
    host->callbacks.resize(host->context, host->width, host->height, host->scale);
}

extern "C" MoxiAndroidHost *moxi_android_host_create(
    float width,
    float height,
    float scale,
    MoxiHostCallbacks callbacks,
    void *context
) {
    MoxiAndroidHost *host = (MoxiAndroidHost *)calloc(1, sizeof(MoxiAndroidHost));
    if (host == NULL) return NULL;
    host->callbacks = callbacks;
    host->context = context;
    host->width = width > 0.0f ? width : 1.0f;
    host->height = height > 0.0f ? height : 1.0f;
    host->scale = scale > 0.0f ? scale : 1.0f;
#if defined(__ANDROID__)
    host->surface = NULL;
#else
    host->surface = NULL;
#endif
    moxi_android_resize(host);
    return host;
}

extern "C" void moxi_android_host_destroy(MoxiAndroidHost *host) {
    if (host == NULL) return;
#if defined(__ANDROID__)
    if (host->surface != NULL) ANativeWindow_release(host->surface);
#endif
    free(host);
}

extern "C" void moxi_android_host_set_surface(MoxiAndroidHost *host, void *surface) {
    if (host == NULL) return;
#if defined(__ANDROID__)
    ANativeWindow *next = (ANativeWindow *)surface;
    if (next == host->surface) return;
    if (next != NULL) ANativeWindow_acquire(next);
    if (host->surface != NULL) ANativeWindow_release(host->surface);
    host->surface = next;
#else
    host->surface = surface;
#endif
}

extern "C" void moxi_android_host_set_size(
    MoxiAndroidHost *host,
    float width,
    float height,
    float scale
) {
    if (host == NULL) return;
    host->width = width > 0.0f ? width : 1.0f;
    host->height = height > 0.0f ? height : 1.0f;
    host->scale = scale > 0.0f ? scale : 1.0f;
    moxi_android_resize(host);
}

extern "C" void moxi_android_host_touch(
    MoxiAndroidHost *host,
    int kind,
    int pointer_id,
    float x,
    float y,
    int buttons,
    int modifiers
) {
    if (host != NULL && host->callbacks.event != NULL) {
        host->callbacks.event(host->context, kind, pointer_id, x, y, buttons, modifiers);
    }
}

extern "C" void moxi_android_host_key(MoxiAndroidHost *host, int key, int modifiers) {
    if (host != NULL && host->callbacks.key != NULL) {
        host->callbacks.key(host->context, key, modifiers);
    }
}

extern "C" void moxi_android_host_text(
    MoxiAndroidHost *host,
    const char *text,
    int start,
    int end
) {
    if (host != NULL && host->callbacks.text != NULL) {
        host->callbacks.text(host->context, text, start, end);
    }
}

extern "C" void moxi_android_host_composition(
    MoxiAndroidHost *host,
    const char *text,
    int start,
    int end
) {
    if (host != NULL && host->callbacks.composition != NULL) {
        host->callbacks.composition(host->context, text, start, end);
    }
}

extern "C" void moxi_android_host_frame(MoxiAndroidHost *host) {
    if (host != NULL && host->callbacks.frame != NULL) {
        host->callbacks.frame(host->context);
    }
}

#if defined(__ANDROID__)
extern "C" int moxi_android_host_dispatch_input(
    MoxiAndroidHost *host,
    AInputEvent *event,
    int modifiers
) {
    if (host == NULL || event == NULL) return 0;
    if (AInputEvent_getType(event) == AINPUT_EVENT_TYPE_MOTION) {
        int32_t action = AMotionEvent_getAction(event);
        int32_t masked = action & AMOTION_EVENT_ACTION_MASK;
        size_t pointerIndex = (size_t)((action & AMOTION_EVENT_ACTION_POINTER_INDEX_MASK) >>
                                       AMOTION_EVENT_ACTION_POINTER_INDEX_SHIFT);
        size_t pointerCount = AMotionEvent_getPointerCount(event);
        if (pointerIndex >= pointerCount) return 0;
        int kind = 0;
        if (masked == AMOTION_EVENT_ACTION_DOWN || masked == AMOTION_EVENT_ACTION_POINTER_DOWN) {
            kind = MOXI_HOST_TOUCH_BEGIN;
        } else if (masked == AMOTION_EVENT_ACTION_MOVE) {
            kind = MOXI_HOST_TOUCH_UPDATE;
        } else if (masked == AMOTION_EVENT_ACTION_UP || masked == AMOTION_EVENT_ACTION_POINTER_UP) {
            kind = MOXI_HOST_TOUCH_END;
        } else if (masked == AMOTION_EVENT_ACTION_CANCEL) {
            kind = MOXI_HOST_POINTER_CANCEL;
        }
        if (kind == 0) return 0;
        int pointerID = AMotionEvent_getPointerId(event, pointerIndex);
        moxi_android_host_touch(
            host,
            kind,
            pointerID,
            AMotionEvent_getX(event, pointerIndex),
            AMotionEvent_getY(event, pointerIndex),
            (int)AMotionEvent_getButtonState(event),
            modifiers
        );
        return 1;
    }
    if (AInputEvent_getType(event) == AINPUT_EVENT_TYPE_KEY &&
        AKeyEvent_getAction(event) == AKEY_EVENT_ACTION_DOWN) {
        moxi_android_host_key(host, AKeyEvent_getKeyCode(event), modifiers);
        return 1;
    }
    return 0;
}
#endif
