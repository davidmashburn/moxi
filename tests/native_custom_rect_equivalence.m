#import "../native/macos_window.m"
#include <stdio.h>
#include <string.h>

static NSBitmapImageRep *render(BOOL legacy, CGFloat scale) {
    NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc]
        initWithBitmapDataPlanes:NULL pixelsWide:128 pixelsHigh:128
        bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO
        colorSpaceName:NSDeviceRGBColorSpace bitmapFormat:0 bytesPerRow:0 bitsPerPixel:0];
    memset(bitmap.bitmapData, 0, bitmap.bytesPerRow * bitmap.pixelsHigh);
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap]];
    CGContextRef context = NSGraphicsContext.currentContext.CGContext;
    CGContextScaleCTM(context, scale, scale);
    CGContextClipToRect(context, CGRectMake(4.5, 5.25, 112.25, 115.5));
    if (legacy) {
        for (int i = 0; i < moxi_custom_rect_count; i++) {
            [moxi_color(moxi_custom_rect_fills[i]) setFill];
            NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:moxi_custom_rect_frames[i]
                xRadius:moxi_custom_rect_radii[i] yRadius:moxi_custom_rect_radii[i]];
            [path fill];
            if (moxi_custom_rect_stroke_widths[i] > 0 && moxi_custom_rect_strokes[i][3] > 0) {
                [moxi_color(moxi_custom_rect_strokes[i]) setStroke];
                path.lineWidth = moxi_custom_rect_stroke_widths[i];
                [path stroke];
            }
        }
    } else {
        moxi_draw_custom_rectangles();
    }
    [NSGraphicsContext restoreGraphicsState];
    return bitmap;
}

int main(void) {
    @autoreleasepool {
        moxi_custom_rect_count = 120;
        for (int i = 0; i < moxi_custom_rect_count; i++) {
            moxi_custom_rect_frames[i] = NSMakeRect(8.25 + (i % 10) * 9.125, 8.5 + (i / 10) * 8.25, 14.5, 12.75);
            moxi_custom_rect_radii[i] = (i % 5) * 3.0;
            moxi_copy_color(moxi_custom_rect_fills[i], 0.2, 0.4, 0.7, (i % 3 + 1) / 3.0);
            moxi_copy_color(moxi_custom_rect_strokes[i], 0.8, 0.3, 0.2, 0.5);
            moxi_custom_rect_stroke_widths[i] = i % 2 ? 1.5 : 0.0;
        }
        // Degenerate rectangles retain the legacy path. Exercise both zero
        // extents and negative extents through the same draw-array contract.
        moxi_custom_rect_frames[0] = NSMakeRect(24.5, 24.5, 0.0, 12.0);
        moxi_custom_rect_frames[1] = NSMakeRect(36.5, 24.5, 12.0, 0.0);
        moxi_custom_rect_frames[2] = NSMakeRect(48.5, 24.5, -12.0, 12.0);
        moxi_custom_rect_frames[3] = NSMakeRect(60.5, 24.5, 12.0, -12.0);
        // A negative public radius is normalized on submission, never stored.
        int negative_radius_index = moxi_custom_rect_count;
        moxi_window_add_custom_rounded_rect(20.25, 20.75, 15.5, 15.5,
            0.2, 0.4, 0.7, 0.5, 0.8, 0.3, 0.2, 0.5, 1.5, -3.0);
        if (moxi_custom_rect_radii[negative_radius_index] != 0.0) {
            fprintf(stderr, "negative radius was not normalized\n");
            return 1;
        }
        moxi_window_add_custom_rounded_rect(32.25, 20.75, 15.5, 15.5,
            0.2, 0.4, 0.7, 0.5, 0.8, 0.3, 0.2, 0.5, 1.5, 0.0);
        size_t total_changed = 0;
        for (int scale = 1; scale <= 2; scale++) {
            NSBitmapImageRep *before = render(YES, scale);
            NSBitmapImageRep *after = render(NO, scale);
            size_t count = before.bytesPerRow * before.pixelsHigh;
            size_t changed = 0;
            int max_delta = 0;
            for (size_t i = 0; i < count; i++) {
                int delta = abs(before.bitmapData[i] - after.bitmapData[i]);
                if (delta) changed++;
                if (delta > max_delta) max_delta = delta;
            }
            printf("custom rectangle equivalence: scale=%d changed_bytes=%zu max_delta=%d\n", scale, changed, max_delta);
            total_changed += changed;
        }
        return total_changed ? 1 : 0;
    }
}
