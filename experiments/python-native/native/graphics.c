/* Host-specific CoreGraphics/CoreText sink for the bounded Mojo plot scene.
 * No Python or Mojo object is retained. The C boundary owns this context. */
#include "graphics.h"
#include <CoreGraphics/CoreGraphics.h>
#include <CoreText/CoreText.h>
#include <stdlib.h>
#include <string.h>

struct MoxiGraphics {
    CGContextRef context;
    CFMutableDataRef pdf;
    int width, height, clip_depth;
};

MoxiGraphics *moxi_e04_graphics_create(Output kind, int width, int height, void *pixels) {
    MoxiGraphics *graphics = calloc(1, sizeof(*graphics));
    if (!graphics) return NULL;
    graphics->width = width;
    graphics->height = height;
    if (kind == OUTPUT_RGBA) {
        CGColorSpaceRef color = CGColorSpaceCreateDeviceRGB();
        if (color) {
            graphics->context = CGBitmapContextCreate(pixels, (size_t)width, (size_t)height,
                8, (size_t)width * 4, color, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
            CGColorSpaceRelease(color);
        }
    } else if (kind == OUTPUT_PDF) {
        graphics->pdf = CFDataCreateMutable(NULL, 0);
        CGDataConsumerRef consumer = graphics->pdf ? CGDataConsumerCreateWithCFData(graphics->pdf) : NULL;
        CGRect bounds = CGRectMake(0, 0, width, height);
        if (consumer) {
            graphics->context = CGPDFContextCreate(consumer, &bounds, NULL);
            CGDataConsumerRelease(consumer);
        }
        if (graphics->context) CGPDFContextBeginPage(graphics->context, NULL);
    }
    if (!graphics->context) {
        moxi_e04_graphics_destroy(graphics);
        return NULL;
    }
    CGContextSetRGBFillColor(graphics->context, 1, 1, 1, 1);
    CGContextFillRect(graphics->context, CGRectMake(0, 0, width, height));
    CGContextTranslateCTM(graphics->context, 0, height);
    CGContextScaleCTM(graphics->context, 1, -1);
    CGContextSetShouldAntialias(graphics->context, true);
    return graphics;
}

Status moxi_e04_graphics_finish(MoxiGraphics *graphics, void *output, int64_t capacity,
                                 int64_t *written) {
    if (graphics->clip_depth) return STATUS_RENDER_FAILED;
    if (graphics->pdf) {
        CGPDFContextEndPage(graphics->context);
        CGPDFContextClose(graphics->context);
        CFIndex size = CFDataGetLength(graphics->pdf);
        if (size > capacity) return STATUS_OUTPUT_LIMIT;
        memcpy(output, CFDataGetBytePtr(graphics->pdf), (size_t)size);
        *written = (int64_t)size;
    } else {
        CGContextFlush(graphics->context);
        *written = (int64_t)graphics->width * graphics->height * 4;
    }
    return STATUS_OK;
}

void moxi_e04_graphics_destroy(MoxiGraphics *graphics) {
    if (!graphics) return;
    if (graphics->context) {
        while (graphics->clip_depth > 0) {
            CGContextRestoreGState(graphics->context);
            graphics->clip_depth--;
        }
        CGContextRelease(graphics->context);
    }
    if (graphics->pdf) CFRelease(graphics->pdf);
    free(graphics);
}

void moxi_e04_rect(int64_t address, double x, double y, double width, double height,
                   double radius, double red, double green, double blue, double alpha) {
    MoxiGraphics *graphics = (MoxiGraphics *)(intptr_t)address;
    CGContextSetRGBFillColor(graphics->context, red, green, blue, alpha);
    CGRect bounds = CGRectMake(x, y, width, height);
    if (radius > 0) {
        CGPathRef path = CGPathCreateWithRoundedRect(bounds, radius, radius, NULL);
        CGContextAddPath(graphics->context, path);
        CGContextFillPath(graphics->context);
        CGPathRelease(path);
    } else CGContextFillRect(graphics->context, bounds);
}

void moxi_e04_line(int64_t address, double x1, double y1, double x2, double y2,
                   double width, double red, double green, double blue, double alpha) {
    MoxiGraphics *graphics = (MoxiGraphics *)(intptr_t)address;
    CGContextSetRGBStrokeColor(graphics->context, red, green, blue, alpha);
    CGContextSetLineWidth(graphics->context, width);
    CGContextBeginPath(graphics->context);
    CGContextMoveToPoint(graphics->context, x1, y1);
    CGContextAddLineToPoint(graphics->context, x2, y2);
    CGContextStrokePath(graphics->context);
}

int32_t moxi_e04_text(int64_t address, const char *text, double x, double baseline,
                      double size, double red, double green, double blue, double alpha) {
    MoxiGraphics *graphics = (MoxiGraphics *)(intptr_t)address;
    CFStringRef string = CFStringCreateWithCString(NULL, text, kCFStringEncodingUTF8);
    CTFontRef font = CTFontCreateWithName(CFSTR("Helvetica"), size, NULL);
    const void *keys[] = {kCTFontAttributeName, kCTForegroundColorFromContextAttributeName};
    const void *values[] = {font, kCFBooleanTrue};
    CFDictionaryRef attributes = font ? CFDictionaryCreate(NULL, keys, values, 2,
        &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks) : NULL;
    CFAttributedStringRef attributed = string && attributes ?
        CFAttributedStringCreate(NULL, string, attributes) : NULL;
    CTLineRef line = attributed ? CTLineCreateWithAttributedString(attributed) : NULL;
    if (line) {
        CGContextSaveGState(graphics->context);
        CGContextSetRGBFillColor(graphics->context, red, green, blue, alpha);
        CGContextTranslateCTM(graphics->context, x, baseline);
        CGContextScaleCTM(graphics->context, 1, -1);
        CGContextSetTextMatrix(graphics->context, CGAffineTransformIdentity);
        CGContextSetTextPosition(graphics->context, 0, 0);
        CTLineDraw(line, graphics->context);
        CGContextRestoreGState(graphics->context);
    }
    int32_t ok = line != NULL;
    if (line) CFRelease(line);
    if (attributed) CFRelease(attributed);
    if (attributes) CFRelease(attributes);
    if (font) CFRelease(font);
    if (string) CFRelease(string);
    return ok;
}

void moxi_e04_clip(int64_t address, double x, double y, double width, double height) {
    MoxiGraphics *graphics = (MoxiGraphics *)(intptr_t)address;
    CGContextSaveGState(graphics->context);
    CGContextClipToRect(graphics->context, CGRectMake(x, y, width, height));
    graphics->clip_depth++;
}

int32_t moxi_e04_pop_clip(int64_t address) {
    MoxiGraphics *graphics = (MoxiGraphics *)(intptr_t)address;
    if (!graphics->clip_depth) return 0;
    CGContextRestoreGState(graphics->context);
    graphics->clip_depth--;
    return 1;
}
