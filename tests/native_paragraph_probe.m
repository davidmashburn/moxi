// Test-only host, CoreText oracle, and offscreen pixel/lifetime probes.
#import "../native/macos_window.m"
#define moxi_advance_codepoint moxi_paragraph_test_advance_codepoint
#import "../native/macos_text.m"
#undef moxi_advance_codepoint
#include <string.h>

void moxi_test_paragraph_host(void) {
    moxi_canvas = [[MoxiCanvasView alloc] initWithFrame:NSMakeRect(0, 0, 800, 700)];
}

int moxi_test_paragraph_geometry(int slot, int key, float x, float y, float w, float h, uintptr_t payload) {
    int ax = moxi_accessibility_index_for_id(key);
    NSRect expected = NSMakeRect(x, y, w, h);
    return slot >= 0 && slot < moxi_label_count && ax >= 0 &&
        NSEqualRects(moxi_label_frames[slot], expected) &&
        NSEqualRects(moxi_accessibility_frames[ax], expected) &&
        (__bridge void *)moxi_label_paragraphs[slot] == (void *)payload;
}

int moxi_test_paragraph_reference(uintptr_t handle, const char *utf8, float fontSize, float width) {
    MoxiParagraph *paragraph = (__bridge MoxiParagraph *)(void *)handle;
    NSAttributedString *text = [[NSAttributedString alloc]
        initWithString:[NSString stringWithUTF8String:utf8]
        attributes:@{NSFontAttributeName:[NSFont systemFontOfSize:fontSize]}];
    CTFramesetterRef setter = CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef)text);
    CGPathRef path = CGPathCreateWithRect(CGRectMake(0, 0, width, 10000), NULL);
    CTFrameRef frame = CTFramesetterCreateFrame(setter, CFRangeMake(0, 0), path, NULL);
    CFArrayRef reference = CTFrameGetLines(frame);
    BOOL matches = CFArrayGetCount(reference) == (CFIndex)paragraph.lines.count;
    for (CFIndex i = 0; matches && i < CFArrayGetCount(reference); i++) {
        CFRange a = CTLineGetStringRange((CTLineRef)CFArrayGetValueAtIndex(reference, i));
        CFRange b = CTLineGetStringRange((__bridge CTLineRef)paragraph.lines[(NSUInteger)i]);
        matches = a.location == b.location && a.length == b.length;
    }
    CFRelease(frame);
    CGPathRelease(path);
    CFRelease(setter);
    return matches;
}

// Render through the actual canvas, then compare with drawing the exact retained
// lines at the committed baseline origins into an independent bitmap.
int moxi_test_paragraph_pixels(int slot) {
    if (slot < 0 || slot >= moxi_label_count || moxi_label_paragraphs[slot] == nil) return 0;
    const size_t width = 800, height = 700, stride = width * 4;
    unsigned char *actual = calloc(height, stride);
    unsigned char *expected = calloc(height, stride);
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    for (int pass = 0; pass < 2; pass++) {
        CGContextRef cg = CGBitmapContextCreate(pass == 0 ? actual : expected,
            width, height, 8, stride, space, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
        NSGraphicsContext *ns = [NSGraphicsContext graphicsContextWithCGContext:cg flipped:YES];
        [NSGraphicsContext saveGraphicsState];
        [NSGraphicsContext setCurrentContext:ns];
        CGContextTranslateCTM(cg, 0, height);
        CGContextScaleCTM(cg, 1, -1);
        if (pass == 0) {
            [moxi_canvas drawRect:moxi_canvas.bounds];
        } else {
            [moxi_color(moxi_surface_fill) setFill];
            NSRectFill(moxi_canvas.bounds);
            NSRectClip(moxi_label_frames[slot]);
            MoxiParagraph *p = (MoxiParagraph *)moxi_label_paragraphs[slot];
            CGContextSetTextMatrix(cg, CGAffineTransformIdentity);
            CGContextSetFillColorWithColor(cg, moxi_color(moxi_label_text_colors[slot]).CGColor);
            CGContextTranslateCTM(cg, moxi_label_frames[slot].origin.x, moxi_label_frames[slot].origin.y);
            CGContextScaleCTM(cg, 1, -1);
            for (NSUInteger i = 0; i < p.lines.count; i++) {
                CGContextSetTextPosition(cg, 0, -p.baselines[i].doubleValue);
                CTLineDraw((__bridge CTLineRef)p.lines[i], cg);
            }
        }
        [NSGraphicsContext restoreGraphicsState];
        CGContextRelease(cg);
    }
    int equal = memcmp(actual, expected, stride * height) == 0;
    // A matching pair of blank canvases is not a drawing pass.
    size_t ink = 0;
    for (size_t i = 0; i < width * height; i++) {
        if (actual[4*i] > 100 && actual[4*i+1] > 100 && actual[4*i+2] > 100) ink++;
    }
    free(actual);
    free(expected);
    CGColorSpaceRelease(space);
    return equal && ink > 20;
}

int moxi_test_paragraph_slot_lifetime(void) {
    __weak id weak;
    @autoreleasepool {
        uintptr_t handle = moxi_paragraph_create("retained", 16, 100, 0);
        weak = (__bridge id)(void *)handle;
        moxi_window_set_label_at(0, "retained", 0, 0, 100, 30, 1, 1, 1, 1, 16, 0);
        moxi_window_set_paragraph_at(0, handle);
        moxi_paragraph_release(handle);
    }
    if (weak == nil) return 0;
    moxi_window_begin_frame();
    return weak == nil;
}
