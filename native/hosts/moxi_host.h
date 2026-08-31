#ifndef MOXI_HOST_H
#define MOXI_HOST_H

#ifdef __cplusplus
extern "C" {
#endif

/* These values intentionally match moxi/event.mojo. Keeping the native host
 * callbacks scalar-only makes the boundary usable from Mojo, C, Kotlin/NDK,
 * Swift/Objective-C, and JavaScript glue without sharing toolkit objects. */
#define MOXI_HOST_POINTER_DOWN 1
#define MOXI_HOST_TEXT_INPUT 3
#define MOXI_HOST_WINDOW_RESIZED 4
#define MOXI_HOST_POINTER_UP 5
#define MOXI_HOST_POINTER_MOVE 6
#define MOXI_HOST_COMPOSITION_UPDATE 8
#define MOXI_HOST_COMPOSITION_END 9
#define MOXI_HOST_TOUCH_BEGIN 16
#define MOXI_HOST_TOUCH_UPDATE 17
#define MOXI_HOST_TOUCH_END 18
#define MOXI_HOST_POINTER_CANCEL 19

#define MOXI_HOST_ACTION_PRESS 1
#define MOXI_HOST_ACTION_INCREMENT 2
#define MOXI_HOST_ACTION_DECREMENT 4
#define MOXI_HOST_ACTION_SELECT 8
#define MOXI_HOST_ACTION_EXPAND 16
#define MOXI_HOST_ACTION_COLLAPSE 32

typedef void (*MoxiHostEventFn)(
    void *context,
    int kind,
    int pointer_id,
    float x,
    float y,
    int buttons,
    int modifiers
);
typedef void (*MoxiHostTextFn)(void *context, const char *text, int start, int end);
typedef void (*MoxiHostCompositionFn)(void *context, const char *text, int start, int end);
typedef void (*MoxiHostKeyFn)(void *context, int key, int modifiers);
typedef void (*MoxiHostResizeFn)(void *context, float width, float height, float scale);
typedef void (*MoxiHostFrameFn)(void *context);
typedef void (*MoxiHostActionFn)(void *context, int target, int action);

typedef struct {
    MoxiHostEventFn event;
    MoxiHostKeyFn key;
    MoxiHostTextFn text;
    MoxiHostCompositionFn composition;
    MoxiHostResizeFn resize;
    MoxiHostFrameFn frame;
    MoxiHostActionFn action;
} MoxiHostCallbacks;

#ifdef __cplusplus
}
#endif

#endif
