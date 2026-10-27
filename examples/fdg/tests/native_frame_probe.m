// Compile this in place of the normal host object so the probe can inspect
// the exact command stream consumed by every AppKit draw, including mid-frame.
#import "macos_window.m"
#import <objc/runtime.h>

static IMP fdg_original_draw;
static int fdg_draws;
static int fdg_blank_draws;

static void fdg_probe_draw(id canvas, SEL selector, NSRect dirty) {
    fdg_draws++;
    if (moxi_custom_line_count == 0 || moxi_custom_rect_count == 0)
        fdg_blank_draws++;
    ((void (*)(id, SEL, NSRect))fdg_original_draw)(canvas, selector, dirty);
}

void fdg_probe_install(void) {
    Method method = class_getInstanceMethod(MoxiCanvasView.class, @selector(drawRect:));
    fdg_original_draw = method_setImplementation(method, (IMP)fdg_probe_draw);
    fdg_draws = 0;
    fdg_blank_draws = 0;
}

int fdg_probe_draw_count(void) { return fdg_draws; }
int fdg_probe_blank_count(void) { return fdg_blank_draws; }
int fdg_probe_pending(void) { return moxi_canvas.needsDisplay ? 1 : 0; }
