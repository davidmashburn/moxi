#include <jni.h>
#include <android/native_window_jni.h>

#include "moxi_android_host.h"

static void moxi_android_demo_event(
    void *context,
    int kind,
    int pointer_id,
    float x,
    float y,
    int buttons,
    int modifiers
) {
    (void)context;
    (void)kind;
    (void)pointer_id;
    (void)x;
    (void)y;
    (void)buttons;
    (void)modifiers;
}

static void moxi_android_demo_key(void *context, int key, int modifiers) {
    (void)context;
    (void)key;
    (void)modifiers;
}

static void moxi_android_demo_text(void *context, const char *text, int start, int end) {
    (void)context;
    (void)text;
    (void)start;
    (void)end;
}

static void moxi_android_demo_composition(void *context, const char *text, int start, int end) {
    (void)context;
    (void)text;
    (void)start;
    (void)end;
}

static void moxi_android_demo_resize(void *context, float width, float height, float scale) {
    (void)context;
    (void)width;
    (void)height;
    (void)scale;
}

static void moxi_android_demo_frame(void *context) {
    (void)context;
}

static MoxiHostCallbacks moxi_android_demo_callbacks() {
    MoxiHostCallbacks callbacks = {};
    callbacks.event = moxi_android_demo_event;
    callbacks.key = moxi_android_demo_key;
    callbacks.text = moxi_android_demo_text;
    callbacks.composition = moxi_android_demo_composition;
    callbacks.resize = moxi_android_demo_resize;
    callbacks.frame = moxi_android_demo_frame;
    return callbacks;
}

extern "C" JNIEXPORT jlong JNICALL
Java_org_moxi_host_MoxiActivity_nativeCreate(JNIEnv *, jobject, jint width, jint height, jfloat scale) {
    MoxiAndroidHost *host = moxi_android_host_create(
        static_cast<float>(width),
        static_cast<float>(height),
        scale,
        moxi_android_demo_callbacks(),
        nullptr
    );
    return reinterpret_cast<jlong>(host);
}

extern "C" JNIEXPORT void JNICALL
Java_org_moxi_host_MoxiActivity_nativeDestroy(JNIEnv *, jobject, jlong handle) {
    moxi_android_host_destroy(reinterpret_cast<MoxiAndroidHost *>(handle));
}

extern "C" JNIEXPORT void JNICALL
Java_org_moxi_host_MoxiActivity_nativeSurface(JNIEnv *env, jobject, jlong handle, jobject surface) {
    MoxiAndroidHost *host = reinterpret_cast<MoxiAndroidHost *>(handle);
    if (host == nullptr) return;
    ANativeWindow *window = surface == nullptr ? nullptr : ANativeWindow_fromSurface(env, surface);
    moxi_android_host_set_surface(host, window);
    if (window != nullptr) ANativeWindow_release(window);
}

extern "C" JNIEXPORT void JNICALL
Java_org_moxi_host_MoxiActivity_nativeSize(
    JNIEnv *,
    jobject,
    jlong handle,
    jint width,
    jint height,
    jfloat scale
) {
    moxi_android_host_set_size(
        reinterpret_cast<MoxiAndroidHost *>(handle),
        static_cast<float>(width),
        static_cast<float>(height),
        scale
    );
}

extern "C" JNIEXPORT void JNICALL
Java_org_moxi_host_MoxiActivity_nativeTouch(
    JNIEnv *,
    jobject,
    jlong handle,
    jint kind,
    jint pointer_id,
    jfloat x,
    jfloat y,
    jint buttons,
    jint modifiers
) {
    moxi_android_host_touch(
        reinterpret_cast<MoxiAndroidHost *>(handle),
        kind,
        pointer_id,
        x,
        y,
        buttons,
        modifiers
    );
}

extern "C" JNIEXPORT void JNICALL
Java_org_moxi_host_MoxiActivity_nativeKey(JNIEnv *, jobject, jlong handle, jint key, jint modifiers) {
    moxi_android_host_key(reinterpret_cast<MoxiAndroidHost *>(handle), key, modifiers);
}

extern "C" JNIEXPORT void JNICALL
Java_org_moxi_host_MoxiActivity_nativeFrame(JNIEnv *, jobject, jlong handle) {
    moxi_android_host_frame(reinterpret_cast<MoxiAndroidHost *>(handle));
}
