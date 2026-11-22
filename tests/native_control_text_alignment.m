#import "../native/macos_window.m"
#include <stdio.h>
#include <string.h>

typedef NS_ENUM(NSInteger, MoxiAlignmentSample) {
    MoxiAlignmentButton,
    MoxiAlignmentCheckbox,
    MoxiAlignmentSlider,
    MoxiAlignmentRadio,
    MoxiAlignmentSwitch,
    MoxiAlignmentBadge,
    MoxiAlignmentPlainLabel,
    MoxiAlignmentMultilineLabel,
};

typedef struct {
    NSInteger minX, minY, maxX, maxY, count;
} MoxiTextInk;

static NSBitmapImageRep *render_control(
    MoxiAlignmentSample sample,
    const char *text,
    NSRect frame,
    BOOL wrap,
    NSInteger scale
) {
    moxi_window_begin_frame();
    moxi_copy_color(moxi_surface_fill, 0, 0, 0, 1);
    switch (sample) {
        case MoxiAlignmentButton:
            moxi_window_set_button_at(0, text,
                frame.origin.x, frame.origin.y, frame.size.width, frame.size.height,
                0.10, 0.25, 0.50, 1, 1, 1, 1, 1, 6, 18, wrap, 0, 0, 0, 1);
            break;
        case MoxiAlignmentCheckbox:
            moxi_window_set_checkbox_at(0, text,
                frame.origin.x, frame.origin.y, frame.size.width, frame.size.height,
                0, 0, 0, 1, 1, 1, 1, 1, 3, 18, 0, 0, 0, 1, 0);
            break;
        case MoxiAlignmentSlider:
            moxi_window_set_slider_at(0, text,
                frame.origin.x, frame.origin.y, frame.size.width, frame.size.height,
                0, 0, 0, 1, 1, 1, 1, 1, 3, 18, 0.5, 0, 0, 0, 1);
            break;
        case MoxiAlignmentRadio:
        case MoxiAlignmentSwitch:
            moxi_window_set_toggle_at(0, text,
                frame.origin.x, frame.origin.y, frame.size.width, frame.size.height,
                0, 0, 0, 1, 1, 1, 1, 1, 3, 18, 0, 0, 0, 1, 0,
                sample == MoxiAlignmentRadio);
            break;
        case MoxiAlignmentBadge:
        case MoxiAlignmentPlainLabel:
        case MoxiAlignmentMultilineLabel:
            moxi_window_set_label_at(0, text,
                frame.origin.x, frame.origin.y, frame.size.width, frame.size.height,
                1, 1, 1, 1, sample == MoxiAlignmentBadge ? 11 : 18, wrap);
            moxi_window_set_label_background(0, 0.10, 0.25, 0.50, 1, 999);
            if (sample == MoxiAlignmentBadge) moxi_window_set_label_badge(0, 1, 12);
            break;
    }

    NSInteger width = 320 * scale, height = 160 * scale;
    NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc]
        initWithBitmapDataPlanes:NULL pixelsWide:width pixelsHigh:height
        bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO
        colorSpaceName:NSDeviceRGBColorSpace bitmapFormat:0 bytesPerRow:0 bitsPerPixel:0];
    memset(bitmap.bitmapData, 0, bitmap.bytesPerRow * bitmap.pixelsHigh);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef cg = CGBitmapContextCreate(bitmap.bitmapData, width, height, 8,
        bitmap.bytesPerRow, colorSpace, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    NSGraphicsContext *context = [NSGraphicsContext graphicsContextWithCGContext:cg flipped:YES];
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:context];
    CGContextTranslateCTM(cg, 0, height);
    CGContextScaleCTM(cg, scale, -scale);
    [moxi_canvas drawRect:moxi_canvas.bounds];
    [context flushGraphics];
    [NSGraphicsContext restoreGraphicsState];
    CGContextRelease(cg);
    CGColorSpaceRelease(colorSpace);
    return bitmap;
}

static MoxiTextInk text_ink(NSBitmapImageRep *bitmap, NSRect region, NSInteger scale) {
    MoxiTextInk ink = {bitmap.pixelsWide, bitmap.pixelsHigh, -1, -1, 0};
    for (NSInteger y = 0; y < bitmap.pixelsHigh; y++) {
        for (NSInteger x = 0; x < bitmap.pixelsWide; x++) {
            NSPoint point = NSMakePoint((x + 0.5) / scale, (y + 0.5) / scale);
            if (!NSPointInRect(point, region)) continue;
            unsigned char *pixel = bitmap.bitmapData + y * bitmap.bytesPerRow + x * 4;
            if (pixel[0] < 160 || pixel[1] < 160 || pixel[2] < 160) continue;
            ink.minX = MIN(ink.minX, x); ink.maxX = MAX(ink.maxX, x);
            ink.minY = MIN(ink.minY, y); ink.maxY = MAX(ink.maxY, y);
            ink.count++;
        }
    }
    return ink;
}

static void save_artifact(NSBitmapImageRep *bitmap, NSString *name) {
    const char *directory = getenv("MOXI_CONTROL_TEXT_ARTIFACT_DIR");
    if (!directory) return;
    NSString *path = [NSString stringWithUTF8String:directory];
    [[NSFileManager defaultManager] createDirectoryAtPath:path
        withIntermediateDirectories:YES attributes:nil error:NULL];
    [[bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}]
        writeToFile:[path stringByAppendingPathComponent:name] atomically:YES];
}

int main(void) {
    @autoreleasepool {
        moxi_canvas = [[MoxiCanvasView alloc] initWithFrame:NSMakeRect(0, 0, 320, 160)];
        int failures = 0;
        const NSRect frame = NSMakeRect(40, 40, 240, 80);
        NSArray<NSString *> *names = @[@"button", @"checkbox", @"slider", @"radio", @"switch"];
        for (NSInteger scale = 1; scale <= 2; scale++) {
            for (MoxiAlignmentSample sample = MoxiAlignmentButton;
                 sample <= MoxiAlignmentSwitch; sample++) {
                NSBitmapImageRep *bitmap = render_control(sample, "HH", frame, NO, scale);
                NSRect label = frame;
                if (sample == MoxiAlignmentCheckbox || sample == MoxiAlignmentRadio) {
                    label.origin.x += 28; label.size.width -= 28;
                } else if (sample == MoxiAlignmentSwitch) {
                    label.origin.x += 52; label.size.width -= 52;
                } else if (sample == MoxiAlignmentSlider) {
                    label.size.width = 60;
                }
                MoxiTextInk ink = text_ink(bitmap, label, scale);
                CGFloat midY = (ink.minY + ink.maxY + 1) / (2.0 * scale);
                BOOL centered = ink.count > 0 && fabs(midY - 80) <= 4;
                if (sample == MoxiAlignmentButton) {
                    CGFloat midX = (ink.minX + ink.maxX + 1) / (2.0 * scale);
                    centered = centered && fabs(midX - NSMidX(frame)) <= 2;
                } else {
                    centered = centered && fabs((CGFloat)ink.minX / scale - NSMinX(label)) <= 3;
                }
                printf("%s %ldx: ink=%ld center_y=%.2f %s\n",
                    names[sample].UTF8String, (long)scale, (long)ink.count, midY,
                    centered ? "PASS" : "FAIL");
                failures += !centered;
                save_artifact(bitmap, [NSString stringWithFormat:@"%@-%ldx.png", names[sample], (long)scale]);
            }
            NSBitmapImageRep *wrapped = render_control(MoxiAlignmentButton, "HH\nHH", frame, YES, scale);
            MoxiTextInk ink = text_ink(wrapped, frame, scale);
            BOOL centered = ink.count > 0 &&
                fabs((ink.minX + ink.maxX + 1) / (2.0 * scale) - NSMidX(frame)) <= 2 &&
                fabs((ink.minY + ink.maxY + 1) / (2.0 * scale) - 80) <= 4;
            printf("wrapped button %ldx: %s\n", (long)scale, centered ? "PASS" : "FAIL");
            failures += !centered;
            save_artifact(wrapped, [NSString stringWithFormat:@"button-wrapped-%ldx.png", (long)scale]);

            NSRect small = NSMakeRect(125, 74, 70, 12);
            NSBitmapImageRep *clipped = render_control(MoxiAlignmentButton,
                "An overlong button title", small, NO, scale);
            MoxiTextInk all = text_ink(clipped, moxi_canvas.bounds, scale);
            MoxiTextInk inside = text_ink(clipped, small, scale);
            BOOL contained = inside.count > 0 && all.count == inside.count;
            printf("clipped button %ldx: %s\n", (long)scale, contained ? "PASS" : "FAIL");
            failures += !contained;
            save_artifact(clipped, [NSString stringWithFormat:@"button-clipped-%ldx.png", (long)scale]);

            NSRect badge = NSMakeRect(100, 68, 120, 24);
            NSBitmapImageRep *badgeBitmap = render_control(MoxiAlignmentBadge,
                "Theme: Light", badge, NO, scale);
            MoxiTextInk badgeInk = text_ink(badgeBitmap, badge, scale);
            BOOL badgeCentered = badgeInk.count > 0 &&
                fabs((badgeInk.minX + badgeInk.maxX + 1) / (2.0 * scale) - 160) <= 2 &&
                fabs((badgeInk.minY + badgeInk.maxY + 1) / (2.0 * scale) - 80) <= 4 &&
                (CGFloat)badgeInk.minX / scale >= NSMinX(badge) + 12 &&
                (CGFloat)(badgeInk.maxX + 1) / scale <= NSMaxX(badge) - 12;
            unsigned char *shoulder = badgeBitmap.bitmapData + 69 * scale * badgeBitmap.bytesPerRow + 114 * scale * 4;
            // A capsule has a flat top between its circular end caps. An oval
            // with radii independently stretched to half the width/height fails.
            BOOL capsule = shoulder[2] > 64;
            printf("badge %ldx: %s\n", (long)scale, badgeCentered && capsule ? "PASS" : "FAIL");
            failures += !(badgeCentered && capsule);
            save_artifact(badgeBitmap, [NSString stringWithFormat:@"badge-%ldx.png", (long)scale]);

            for (MoxiAlignmentSample label = MoxiAlignmentPlainLabel;
                 label <= MoxiAlignmentMultilineLabel; label++) {
                NSBitmapImageRep *plain = render_control(label,
                    label == MoxiAlignmentMultilineLabel ? "HH\nHH" : "HH", frame,
                    label == MoxiAlignmentMultilineLabel, scale);
                MoxiTextInk plainInk = text_ink(plain, frame, scale);
                BOOL leading = plainInk.count > 0 &&
                    (CGFloat)plainInk.minX / scale < NSMinX(frame) + 4 &&
                    (CGFloat)plainInk.minY / scale < NSMinY(frame) + 8;
                NSString *name = label == MoxiAlignmentMultilineLabel ? @"multiline-label" : @"plain-label";
                printf("%s %ldx: %s\n", name.UTF8String, (long)scale, leading ? "PASS" : "FAIL");
                failures += !leading;
                save_artifact(plain, [NSString stringWithFormat:@"%@-%ldx.png", name, (long)scale]);
            }
        }
        return failures ? 1 : 0;
    }
}
