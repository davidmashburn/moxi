/* Default AppKit path, comparable with pre-capacity adapters. No VoiceOver.
 * Override MOXI_WINDOW_SOURCE to build this identical driver against an archive. */
#ifndef MOXI_WINDOW_SOURCE
#define MOXI_WINDOW_SOURCE "../../native/macos_window.m"
#endif
#import MOXI_WINDOW_SOURCE
#include <assert.h>
#include <objc/runtime.h>

enum { SampleCount = 40 };

static double milliseconds(void) {
    return moxi_native_timing_now_ns() / 1e6;
}

int main(void) {
    @autoreleasepool {
        double start = milliseconds();
        uint64_t handle = moxi_window_create_instance();
        printf("create_ms %.6f state_bytes %zu\n", milliseconds() - start,
            class_getInstanceSize(MoxiWindowState.class));
        assert(handle && moxi_window_select_instance(handle));
        start = milliseconds();
        moxi_window_open("D03 small-window cost", 320, 240, 0, 0, 0, 0, 1, 0);
        printf("open_ms %.6f\n", milliseconds() - start);
        for (int sample = 0; sample < SampleCount; ++sample) {
            start = milliseconds();
            moxi_window_begin_frame();
            double frame = milliseconds() - start;
            start = milliseconds();
            moxi_window_begin_accessibility();
            moxi_window_end_accessibility();
            printf("sample empty %d frame_ms %.6f ax_ms %.6f\n",
                sample, frame, milliseconds() - start);
        }
        NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc]
            initWithBitmapDataPlanes:NULL pixelsWide:320 pixelsHigh:240
            bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO
            colorSpaceName:NSDeviceRGBColorSpace bitmapFormat:0 bytesPerRow:0 bitsPerPixel:0];
        for (int sample = 0; sample < SampleCount; ++sample) {
            start = milliseconds();
            moxi_window_begin_frame();
            moxi_window_set_label_at(0, "Small window", 10, 10, 200, 30,
                1, 1, 1, 1, 14, 0);
            moxi_window_set_button_at(0, "Click", 10, 50, 100, 30,
                0, 1, 0, 1, 1, 1, 1, 1, 0, 14, 0, 0, 0, 0, 1);
            moxi_window_begin_accessibility();
            moxi_window_set_accessibility_at(0, 1, -1, MOXI_ROLE_BUTTON,
                "Click", "", "", 10, 50, 100, 30, 1, 0, 0, 0, 0, 0, 0, 0, 0, MOXI_ACTION_PRESS);
            moxi_window_end_accessibility();
            double submit = milliseconds() - start;
            [NSGraphicsContext saveGraphicsState];
            [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap]];
            [moxi_canvas drawRect:moxi_canvas.bounds];
            [NSGraphicsContext restoreGraphicsState];
            printf("sample small %d submit_ms %.6f total_ms %.6f\n",
                sample, submit, milliseconds() - start);
        }
        assert(moxi_label_count == 1 && moxi_button_count == 1 && moxi_accessibility_count == 1);
        assert(moxi_accessibility_ids[0] == 1 && moxi_button_enabled[0]);
        assert(NSEqualRects(moxi_button_frames[0], NSMakeRect(10, 50, 100, 30)));
        NSColor *paint = [[bitmap colorAtX:15 y:185] colorUsingColorSpace:NSColorSpace.deviceRGBColorSpace];
        assert(paint.greenComponent > 0.9 && paint.redComponent < 0.1);
        puts("small_native_counts 1 label 1 button 1 semantic; geometry/pixel PASS");
        start = milliseconds();
        assert(moxi_window_destroy_instance(handle));
        printf("destroy_ms %.6f\n", milliseconds() - start);
    }
}
