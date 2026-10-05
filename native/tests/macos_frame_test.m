#import "../macos_window.m"
#import <objc/runtime.h>
#include <assert.h>
#include <stdio.h>

static NSUInteger drawCount;
static IMP originalDraw;

static void countDraw(id canvas, SEL selector, NSRect dirtyRect) {
    drawCount += 1;
    ((void (*)(id, SEL, NSRect))originalDraw)(canvas, selector, dirtyRect);
}

int main(void) {
    @autoreleasepool {
        Method draw = class_getInstanceMethod(MoxiCanvasView.class,
            @selector(drawRect:));
        originalDraw = method_setImplementation(draw, (IMP)countDraw);
        moxi_window_open("Moxi idle frame regression", 160, 100,
            0, 0, 0, 0, 0, 0);

        // No event pump or user input occurs between publication and the idle
        // boundary. Both the first frame and a later invalidation must paint.
        for (int frame = 0; frame < 2; frame++) {
            moxi_window_begin_frame();
            moxi_window_add_custom_rect(0, 0, 160, 100,
                0.2, frame == 0 ? 0.7 : 0.3, 0.3, 1, 0, 0, 0, 0, 0);
            NSUInteger before = drawCount;
            moxi_window_end_frame();
            assert(drawCount > before);
            assert(!moxi_canvas.needsDisplay);
        }

        moxi_window_close();
        method_setImplementation(draw, originalDraw);
        puts("AppKit published frames paint before indefinite idle: pass");
    }
    return 0;
}
