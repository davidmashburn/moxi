#import "../native/macos_window.m"
#include <stdio.h>
#include <string.h>

@interface MoxiTestScaleWindow : NSWindow
@end

@implementation MoxiTestScaleWindow
- (CGFloat)backingScaleFactor {
    return 2.0;
}
@end

static NSBitmapImageRep *new_bitmap(NSInteger width, NSInteger height) {
    NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc]
        initWithBitmapDataPlanes:NULL
                      pixelsWide:width
                      pixelsHigh:height
                   bitsPerSample:8
                 samplesPerPixel:4
                        hasAlpha:YES
                        isPlanar:NO
                  colorSpaceName:NSDeviceRGBColorSpace
                     bitmapFormat:0
                      bytesPerRow:0
                     bitsPerPixel:0];
    memset(bitmap.bitmapData, 0, bitmap.bytesPerRow * bitmap.pixelsHigh);
    return bitmap;
}

static NSBitmapImageRep *render_current_canvas(
    NSInteger width,
    NSInteger height,
    CGFloat scale
) {
    NSBitmapImageRep *bitmap = new_bitmap(width, height);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef cgContext = CGBitmapContextCreate(
        bitmap.bitmapData,
        width,
        height,
        8,
        bitmap.bytesPerRow,
        colorSpace,
        (CGBitmapInfo)kCGImageAlphaPremultipliedLast
    );
    NSGraphicsContext *context = [NSGraphicsContext
        graphicsContextWithCGContext:cgContext
                             flipped:YES];
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:context];
    CGContextTranslateCTM(cgContext, 0.0, height);
    CGContextScaleCTM(cgContext, scale, -scale);
    moxi_draw_custom_commands();
    [context flushGraphics];
    [NSGraphicsContext restoreGraphicsState];
    CGContextRelease(cgContext);
    CGColorSpaceRelease(colorSpace);
    return bitmap;
}

static NSBitmapImageRep *render_uncached_flipped(
    NSInteger width,
    NSInteger height,
    CGFloat scale
) {
    NSBitmapImageRep *bitmap = new_bitmap(width, height);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef cgContext = CGBitmapContextCreate(
        bitmap.bitmapData,
        width,
        height,
        8,
        bitmap.bytesPerRow,
        colorSpace,
        (CGBitmapInfo)kCGImageAlphaPremultipliedLast
    );
    NSGraphicsContext *context = [NSGraphicsContext
        graphicsContextWithCGContext:cgContext
                             flipped:YES];
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:context];
    CGContextTranslateCTM(cgContext, 0.0, height);
    CGContextScaleCTM(cgContext, scale, -scale);
    moxi_draw_custom_commands_uncached();
    [context flushGraphics];
    [NSGraphicsContext restoreGraphicsState];
    CGContextRelease(cgContext);
    CGColorSpaceRelease(colorSpace);
    return bitmap;
}

static BOOL bitmaps_equal(NSBitmapImageRep *left, NSBitmapImageRep *right) {
    size_t left_bytes = left.bytesPerRow * left.pixelsHigh;
    size_t right_bytes = right.bytesPerRow * right.pixelsHigh;
    return left_bytes == right_bytes &&
        memcmp(left.bitmapData, right.bitmapData, left_bytes) == 0;
}

static size_t changed_bytes(NSBitmapImageRep *left, NSBitmapImageRep *right) {
    size_t left_bytes = left.bytesPerRow * left.pixelsHigh;
    size_t right_bytes = right.bytesPerRow * right.pixelsHigh;
    size_t count = left_bytes < right_bytes ? left_bytes : right_bytes;
    size_t changed = left_bytes == right_bytes ? 0 : 1;
    for (size_t index = 0; index < count; index++) {
        if (left.bitmapData[index] != right.bitmapData[index]) {
            changed += 1;
        }
    }
    return changed;
}

static int expect(BOOL condition, const char *message) {
    if (condition) {
        return 0;
    }
    fprintf(stderr, "%s\n", message);
    return 1;
}

int main(void) {
    @autoreleasepool {
        moxi_canvas = [[MoxiCanvasView alloc]
            initWithFrame:NSMakeRect(0.0, 0.0, 64.0, 64.0)];
        moxi_window_begin_custom_paint();
        moxi_window_set_custom_clip(0.0, 0.0, 40.0, 40.0);
        moxi_window_add_custom_rect(
            8.0, 8.0, 24.0, 24.0,
            0.2, 0.5, 0.8, 0.85,
            0.0, 0.0, 0.0, 0.0, 0.0
        );
        moxi_window_add_custom_line(
            3.0, 35.0, 31.0, 9.0, 1.5,
            0.95, 0.85, 0.10, 0.90
        );
        moxi_window_add_custom_text(
            "Flip", 9.0, 10.0, 27.0, 12.0,
            0.95, 0.95, 0.95, 1.0, 8.0
        );

        NSBitmapImageRep *reference = render_uncached_flipped(64, 64, 1.0);
        moxi_window_set_custom_paint_cache_enabled(1);
        uint64_t builds_before = moxi_custom_paint_cache_build_count;
        NSBitmapImageRep *cold = render_current_canvas(64, 64, 1.0);
        int failures = 0;
        failures += expect(
            bitmaps_equal(reference, cold),
            "cached custom paint differs from the flipped uncached output"
        );
        failures += expect(
            moxi_custom_paint_cache_build_count == builds_before + 1,
            "custom paint cache did not build on the cold render"
        );

        /* begin_frame clears the native frame commands but intentionally
         * retains the last custom stream for a table-only update. */
        moxi_window_begin_frame();
        uint64_t hits_before = moxi_custom_paint_cache_hit_count;
        NSBitmapImageRep *warm = render_current_canvas(64, 64, 1.0);
        failures += expect(
            bitmaps_equal(cold, warm),
            "cached custom paint changed pixels on a warm render"
        );
        failures += expect(
            moxi_custom_paint_cache_hit_count == hits_before + 1,
            "custom paint cache did not report a warm hit"
        );

        /* A new command stream invalidates the retained output. */
        moxi_window_begin_custom_paint();
        moxi_window_set_custom_clip(0.0, 0.0, 40.0, 40.0);
        moxi_window_add_custom_rect(
            28.0, 28.0, 24.0, 24.0,
            0.8, 0.2, 0.3, 0.85,
            0.0, 0.0, 0.0, 0.0, 0.0
        );
        uint64_t command_build_before = moxi_custom_paint_cache_build_count;
        NSBitmapImageRep *command_changed = render_current_canvas(64, 64, 1.0);
        failures += expect(
            moxi_custom_paint_cache_build_count == command_build_before + 1,
            "custom command submission did not invalidate the cache"
        );
        failures += expect(
            changed_bytes(warm, command_changed) > 0,
            "changed custom commands produced identical pixels"
        );

        /* Clip changes invalidate even when the command arrays remain intact. */
        moxi_window_set_custom_clip(0.0, 0.0, 8.0, 8.0);
        uint64_t clip_build_before = moxi_custom_paint_cache_build_count;
        NSBitmapImageRep *clip_changed = render_current_canvas(64, 64, 1.0);
        failures += expect(
            moxi_custom_paint_cache_build_count == clip_build_before + 1,
            "custom clip submission did not invalidate the cache"
        );
        failures += expect(
            changed_bytes(command_changed, clip_changed) > 0,
            "changed custom clip produced identical pixels"
        );

        /* View bounds changes force a new backing-sized bitmap. */
        [moxi_canvas setFrameSize:NSMakeSize(96.0, 64.0)];
        uint64_t bounds_build_before = moxi_custom_paint_cache_build_count;
        NSBitmapImageRep *bounds_changed = render_current_canvas(96, 64, 1.0);
        failures += expect(
            moxi_custom_paint_cache_build_count == bounds_build_before + 1,
            "canvas bounds change did not invalidate the cache key"
        );
        failures += expect(
            bounds_changed.pixelsWide == 96 && bounds_changed.pixelsHigh == 64,
            "bounds-sized cache render did not preserve the target dimensions"
        );

        /* The bitmap context already maps image points to backing pixels when
         * its NSBitmapImageRep has a larger pixel extent and a point-sized
         * image size.  A changed backing scale must rebuild at that extent,
         * while retaining the flipped canvas coordinate system. */
        moxi_window_begin_custom_paint();
        moxi_window_set_custom_clip(0.0, 0.0, 90.0, 60.0);
        moxi_window_add_custom_rect(
            3.0, 7.0, 24.0, 13.0,
            0.15, 0.65, 0.35, 0.80,
            0.0, 0.0, 0.0, 0.0, 0.0
        );
        moxi_window_add_custom_line(
            5.0, 45.0, 81.0, 22.0, 1.75,
            0.90, 0.25, 0.15, 0.90
        );
        moxi_window_add_custom_text(
            "2x", 48.0, 8.0, 24.0, 14.0,
            0.95, 0.95, 0.95, 1.0, 9.0
        );
        (void)render_current_canvas(96, 64, 1.0);
        MoxiTestScaleWindow *scale_window = [[MoxiTestScaleWindow alloc]
            initWithContentRect:NSMakeRect(0.0, 0.0, 96.0, 64.0)
                      styleMask:NSWindowStyleMaskBorderless
                        backing:NSBackingStoreBuffered
                          defer:YES];
        [scale_window setContentView:moxi_canvas];
        [moxi_canvas setFrameSize:NSMakeSize(96.0, 64.0)];
        moxi_window_begin_frame();
        failures += expect(
            moxi_custom_rect_count == 1 && moxi_custom_line_count == 1 &&
            moxi_custom_text_count == 1 && moxi_custom_clip_enabled,
            "begin_frame lost custom commands or clipping before a scale change"
        );
        NSBitmapImageRep *scale_reference = render_uncached_flipped(192, 128, 2.0);
        uint64_t scale_build_before = moxi_custom_paint_cache_build_count;
        NSBitmapImageRep *scale_cached = render_current_canvas(192, 128, 2.0);
        failures += expect(
            bitmaps_equal(scale_reference, scale_cached),
            "2x cached custom paint differs from the flipped uncached output"
        );
        failures += expect(
            moxi_custom_paint_cache_build_count == scale_build_before + 1,
            "backing-scale change did not invalidate the cache key"
        );
        failures += expect(
            scale_cached.pixelsWide == 192 && scale_cached.pixelsHigh == 128,
            "backing-scale cache render did not preserve pixel dimensions"
        );
        moxi_window_begin_frame();
        NSBitmapImageRep *scale_warm = render_current_canvas(192, 128, 2.0);
        failures += expect(
            bitmaps_equal(scale_cached, scale_warm) &&
            moxi_custom_paint_cache_build_count == scale_build_before + 1,
            "2x warm render changed pixels or unnecessarily rebuilt the cache"
        );
        moxi_window_set_custom_paint_cache_enabled(0);
        moxi_window_begin_frame();
        failures += expect(
            moxi_custom_rect_count == 0 && moxi_custom_line_count == 0 &&
            moxi_custom_text_count == 0 && !moxi_custom_clip_enabled,
            "default host no longer resets its custom commands"
        );
        /* Keep the synthetic window alive through bitmap cleanup. */

        printf(
            "custom paint cache: builds=%llu hits=%llu failures=%d\n",
            (unsigned long long)moxi_custom_paint_cache_build_count,
            (unsigned long long)moxi_custom_paint_cache_hit_count,
            failures
        );
        return failures;
    }
}
