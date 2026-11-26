/* Test bridge to the real adapter, raster and NSEvent translation. */
#define moxi_window_begin_frame moxi_capacity_original_begin_frame
#define moxi_window_begin_accessibility moxi_capacity_original_begin_accessibility
#define moxi_window_end_accessibility moxi_capacity_original_end_accessibility
#import "../../native/macos_window.m"
#undef moxi_window_begin_frame
#undef moxi_window_begin_accessibility
#undef moxi_window_end_accessibility
#import "capture.m"
#include <objc/runtime.h>

static double capacityResetMS, capacityAXBeginMS, capacityAXEndMS;

void moxi_window_begin_frame(void) {
    uint64_t start = moxi_native_timing_now_ns();
    moxi_capacity_original_begin_frame();
    capacityResetMS = moxi_native_timing_ms(start, moxi_native_timing_now_ns());
}
void moxi_window_begin_accessibility(void) {
    uint64_t start = moxi_native_timing_now_ns();
    moxi_capacity_original_begin_accessibility();
    capacityAXBeginMS = moxi_native_timing_ms(start, moxi_native_timing_now_ns());
}
void moxi_window_end_accessibility(void) {
    uint64_t start = moxi_native_timing_now_ns();
    moxi_capacity_original_end_accessibility();
    capacityAXEndMS = moxi_native_timing_ms(start, moxi_native_timing_now_ns());
}
double moxi_capacity_reset_ms(void) { return capacityResetMS; }
double moxi_capacity_ax_begin_ms(void) { return capacityAXBeginMS; }
double moxi_capacity_ax_end_ms(void) { return capacityAXEndMS; }
int64_t moxi_capacity_state_bytes(void) { return class_getInstanceSize(MoxiWindowState.class); }

static NSBitmapImageRep *capacityBitmap;

double moxi_capacity_raster(const char *path) {
    @autoreleasepool {
        NSView *view = moxi_canvas;
        capacityBitmap = [[NSBitmapImageRep alloc]
            initWithBitmapDataPlanes:NULL pixelsWide:(NSInteger)view.bounds.size.width
            pixelsHigh:(NSInteger)view.bounds.size.height bitsPerSample:8
            samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace
            bitmapFormat:0 bytesPerRow:0 bitsPerPixel:0];
        uint64_t start = moxi_native_timing_now_ns();
        [NSGraphicsContext saveGraphicsState];
        [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithBitmapImageRep:capacityBitmap]];
        NSAffineTransform *flip = NSAffineTransform.transform;
        [flip translateXBy:0 yBy:view.bounds.size.height];
        [flip scaleXBy:1 yBy:-1];
        [flip concat];
        [view drawRect:view.bounds];
        [NSGraphicsContext restoreGraphicsState];
        double elapsed = moxi_native_timing_ms(start, moxi_native_timing_now_ns());
        if (path && path[0]) {
            NSData *png = [capacityBitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
            if (![png writeToFile:[NSString stringWithUTF8String:path] atomically:YES]) return -1;
        }
        return elapsed;
    }
}

/* Every node's ordinary blue button must be present in actual native output.
 * The toolbar/background buttons lie outside the requested node-size range. */
int moxi_capacity_visible_buttons(void) {
    int found = 0;
    for (int slot = 0; slot < moxi_button_count; slot++) {
        NSRect frame = moxi_button_frames[slot];
        if (frame.size.width > 40 || frame.size.height > 10) continue;
        NSRect visible = moxi_button_clip_enabled[slot]
            ? NSIntersectionRect(frame, moxi_button_clip_frames[slot]) : frame;
        BOOL blue = NO;
        for (int y = (int)ceil(NSMinY(visible)); y < (int)floor(NSMaxY(visible)); y++) {
            for (int x = (int)ceil(NSMinX(visible)); x < (int)floor(NSMaxX(visible)); x++) {
                if (x < 0 || y < 0 || x >= capacityBitmap.pixelsWide || y >= capacityBitmap.pixelsHigh) continue;
                NSColor *pixel = [[capacityBitmap colorAtX:x y:y] colorUsingColorSpace:NSColorSpace.deviceRGBColorSpace];
                if (pixel.blueComponent > .5 && pixel.blueComponent > pixel.redComponent * 1.5) blue = YES;
            }
        }
        found += blue ? 1 : 0;
    }
    return found;
}

void moxi_capacity_pointer(int kind, float x, float y) {
    NSEventType type = kind == MOXI_EVENT_POINTER_DOWN ? NSEventTypeLeftMouseDown : NSEventTypeLeftMouseUp;
    NSPoint point = [moxi_canvas convertPoint:NSMakePoint(x, y) toView:nil];
    NSEvent *event = [NSEvent mouseEventWithType:type location:point modifierFlags:0
        timestamp:NSProcessInfo.processInfo.systemUptime windowNumber:moxi_window.windowNumber
        context:nil eventNumber:1 clickCount:1 pressure:1];
    if (kind == MOXI_EVENT_POINTER_DOWN) [moxi_canvas mouseDown:event];
    else [moxi_canvas mouseUp:event];
}

int moxi_capacity_ordered_count(void) { return moxi_ordered_paint_count; }

int moxi_capacity_button_geometry(float x, float y, float width, float height) {
    for (int slot = 0; slot < moxi_button_count; slot++) {
        NSRect frame = moxi_button_frames[slot];
        if (fabs(frame.origin.x - x) < .01 && fabs(frame.origin.y - y) < .01 &&
            fabs(frame.size.width - width) < .01 && fabs(frame.size.height - height) < .01) return 1;
    }
    return 0;
}
