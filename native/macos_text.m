#import <Cocoa/Cocoa.h>
#import <CoreText/CoreText.h>

#define MOXI_MAX_SHAPED_GLYPHS 8192

static int moxi_shaped_count;
static int moxi_shaped_codepoints[MOXI_MAX_SHAPED_GLYPHS];
static int moxi_shaped_clusters[MOXI_MAX_SHAPED_GLYPHS];
static unsigned short moxi_shaped_glyphs[MOXI_MAX_SHAPED_GLYPHS];
static float moxi_shaped_positions[MOXI_MAX_SHAPED_GLYPHS];
static float moxi_shaped_advances[MOXI_MAX_SHAPED_GLYPHS];
static float moxi_shaped_width;
static float moxi_shaped_ascent;
static float moxi_shaped_descent;

static NSUInteger moxi_advance_codepoint(NSString *text, NSUInteger index) {
    if (index + 1 < [text length]) {
        unichar high = [text characterAtIndex:index];
        unichar low = [text characterAtIndex:index + 1];
        if (high >= 0xD800 && high <= 0xDBFF && low >= 0xDC00 && low <= 0xDFFF) {
            return index + 2;
        }
    }
    return index + 1;
}

static int moxi_codepoint_offset(NSString *text, NSUInteger utf16Index) {
    int result = 0;
    NSUInteger index = 0;
    while (index < utf16Index && index < [text length]) {
        index = moxi_advance_codepoint(text, index);
        result += 1;
    }
    return result;
}

static int moxi_codepoint_at(NSString *text, NSUInteger index) {
    NSUInteger utf16 = 0;
    for (NSUInteger current = 0; current < index && utf16 < [text length]; current++) {
        utf16 = moxi_advance_codepoint(text, utf16);
    }
    if (utf16 >= [text length]) return -1;
    unichar high = [text characterAtIndex:utf16];
    if (high >= 0xD800 && high <= 0xDBFF && utf16 + 1 < [text length]) {
        unichar low = [text characterAtIndex:utf16 + 1];
        if (low >= 0xDC00 && low <= 0xDFFF) {
            return 0x10000 + ((high - 0xD800) << 10) + (low - 0xDC00);
        }
    }
    return (int)high;
}

int moxi_coretext_available(void) {
    return 1;
}

int moxi_coretext_shape(const char *utf8, float font_size, int right_to_left) {
    @autoreleasepool {
        NSString *text = utf8 == NULL ? @"" : [NSString stringWithUTF8String:utf8];
        if (text == nil) text = @"";
        CGFloat size = font_size > 0.0f ? font_size : 16.0f;
        NSFont *font = [NSFont systemFontOfSize:size];
        CTWritingDirection writingDirection = right_to_left
            ? kCTWritingDirectionRightToLeft
            : kCTWritingDirectionLeftToRight;
        CTParagraphStyleSetting setting = {
            kCTParagraphStyleSpecifierBaseWritingDirection,
            sizeof(CTWritingDirection),
            &writingDirection,
        };
        CTParagraphStyleRef paragraph = CTParagraphStyleCreate(&setting, 1);
        NSDictionary *attributes = @{
            NSFontAttributeName: font,
            NSParagraphStyleAttributeName: (__bridge id)paragraph,
        };
        NSAttributedString *attributed = [[NSAttributedString alloc]
            initWithString:text attributes:attributes];
        CTLineRef line = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)attributed);
        moxi_shaped_count = 0;
        moxi_shaped_width = 0.0f;
        moxi_shaped_ascent = 0.0f;
        moxi_shaped_descent = 0.0f;
        if (line != nil) {
            CGFloat ascent = 0.0;
            CGFloat descent = 0.0;
            CGFloat trailing = 0.0;
            moxi_shaped_width = (float)CTLineGetTypographicBounds(
                line, &ascent, &descent, &trailing
            );
            moxi_shaped_ascent = (float)ascent;
            moxi_shaped_descent = (float)descent;
            CFArrayRef runs = CTLineGetGlyphRuns(line);
            CFIndex runCount = CFArrayGetCount(runs);
            for (CFIndex runIndex = 0; runIndex < runCount; runIndex++) {
                CTRunRef run = (CTRunRef)CFArrayGetValueAtIndex(runs, runIndex);
                CFIndex count = CTRunGetGlyphCount(run);
                if (count <= 0) continue;
                CGGlyph glyphs[count];
                CGPoint positions[count];
                CFIndex indices[count];
                CGSize advances[count];
                CTRunGetGlyphs(run, CFRangeMake(0, 0), glyphs);
                CTRunGetPositions(run, CFRangeMake(0, 0), positions);
                CTRunGetStringIndices(run, CFRangeMake(0, 0), indices);
                CTRunGetAdvances(run, CFRangeMake(0, 0), advances);
                for (CFIndex glyphIndex = 0;
                     glyphIndex < count && moxi_shaped_count < MOXI_MAX_SHAPED_GLYPHS;
                     glyphIndex++) {
                    int destination = moxi_shaped_count++;
                    int cluster = moxi_codepoint_offset(text, (NSUInteger)indices[glyphIndex]);
                    moxi_shaped_glyphs[destination] = glyphs[glyphIndex];
                    moxi_shaped_clusters[destination] = cluster;
                    moxi_shaped_codepoints[destination] = moxi_codepoint_at(text, (NSUInteger)cluster);
                    moxi_shaped_positions[destination] = (float)positions[glyphIndex].x;
                    moxi_shaped_advances[destination] = (float)advances[glyphIndex].width;
                }
            }
            CFRelease(line);
        }
        CFRelease(paragraph);
        return moxi_shaped_count;
    }
}

int moxi_coretext_glyph_codepoint_at(int index) {
    if (index < 0 || index >= moxi_shaped_count) return -1;
    return moxi_shaped_codepoints[index];
}

int moxi_coretext_glyph_cluster_at(int index) {
    if (index < 0 || index >= moxi_shaped_count) return -1;
    return moxi_shaped_clusters[index];
}

unsigned short moxi_coretext_glyph_id_at(int index) {
    if (index < 0 || index >= moxi_shaped_count) return 0;
    return moxi_shaped_glyphs[index];
}

float moxi_coretext_glyph_position_at(int index) {
    if (index < 0 || index >= moxi_shaped_count) return 0.0f;
    return moxi_shaped_positions[index];
}

float moxi_coretext_glyph_advance_at(int index) {
    if (index < 0 || index >= moxi_shaped_count) return 0.0f;
    return moxi_shaped_advances[index];
}

float moxi_coretext_width(void) { return moxi_shaped_width; }
float moxi_coretext_height(void) { return moxi_shaped_ascent + moxi_shaped_descent; }

#import "macos_paragraph.h"
#include <math.h>
#include <stdint.h>

// One immutable set of CoreText lines supplies measurement AND drawing. The
// bridge owns one reference; snapshots and the AppKit draw slot retain it.
@interface MoxiParagraph : NSObject <MoxiParagraphDrawing>
@property(nonatomic, strong) NSArray *lines;
@property(nonatomic, strong) NSArray<NSNumber *> *baselines;
@property(nonatomic) CGFloat width;
@property(nonatomic) CGFloat height;
@property(nonatomic) CGFloat firstBaseline;
@property(nonatomic) CGFloat lastBaseline;
@end

@implementation MoxiParagraph
- (void)drawAt:(NSPoint)origin color:(NSColor *)color {
    CGContextRef context = NSGraphicsContext.currentContext.CGContext;
    if (context == NULL) return;
    CGContextSaveGState(context);
    CGContextSetTextMatrix(context, CGAffineTransformIdentity);
    CGContextSetFillColorWithColor(context, color.CGColor);
    // Moxi's canvas is top-down. Keep the retained line origins top-down too,
    // and invert only the glyph coordinate system, not the paragraph order.
    CGContextTranslateCTM(context, origin.x, origin.y);
    CGContextScaleCTM(context, 1.0, -1.0);
    for (NSUInteger i = 0; i < self.lines.count; i++) {
        CGContextSetTextPosition(context, 0.0, -self.baselines[i].doubleValue);
        CTLineDraw((__bridge CTLineRef)self.lines[i], context);
    }
    CGContextRestoreGState(context);
}
@end

uintptr_t moxi_paragraph_create(const char *utf8, float fontSize, float width, int direction) {
    if (utf8 == NULL || !isfinite(fontSize) || fontSize <= 0 ||
        !isfinite(width) || width < 0 || direction < 0 || direction > 2) return 0;
    @autoreleasepool {
        NSString *text = [NSString stringWithUTF8String:utf8];
        if (text == nil) return 0;
        NSFont *font = [NSFont systemFontOfSize:fontSize];
        CTWritingDirection writing = direction == 2 ? kCTWritingDirectionRightToLeft
            : direction == 1 ? kCTWritingDirectionLeftToRight : kCTWritingDirectionNatural;
        CTParagraphStyleSetting setting = { kCTParagraphStyleSpecifierBaseWritingDirection,
            sizeof(writing), &writing };
        CTParagraphStyleRef style = CTParagraphStyleCreate(&setting, 1);
        NSAttributedString *attributed = [[NSAttributedString alloc] initWithString:text attributes:@{
            NSFontAttributeName: font,
            (__bridge NSString *)kCTParagraphStyleAttributeName: (__bridge id)style,
            (__bridge NSString *)kCTForegroundColorFromContextAttributeName: @YES,
        }];
        CFRelease(style);
        CTTypesetterRef typesetter = CTTypesetterCreateWithAttributedString(
            (__bridge CFAttributedStringRef)attributed);
        NSMutableArray *lines = [NSMutableArray array];
        NSMutableArray<NSNumber *> *baselines = [NSMutableArray array];
        CGFloat top = 0;
        NSUInteger start = 0;
        // Include an empty final line after a hard break and one line for empty
        // content. Zero width is a real offer; overflowing clusters are clipped
        // by the committed box, never interpreted as an unbounded paragraph.
        do {
            NSUInteger paragraphEnd = start;
            while (paragraphEnd < text.length &&
                   [text characterAtIndex:paragraphEnd] != '\n' &&
                   [text characterAtIndex:paragraphEnd] != '\r') paragraphEnd++;
            NSUInteger count = 0;
            if (paragraphEnd > start) {
                CFIndex suggested = CTTypesetterSuggestLineBreak(typesetter, (CFIndex)start, width);
                count = MIN((NSUInteger)MAX(suggested, 0), paragraphEnd - start);
                if (count == 0) {
                    count = MIN([text rangeOfComposedCharacterSequenceAtIndex:start].length,
                                paragraphEnd - start);
                }
            }
            // CTTypesetter's zero-length range means "the rest", so create
            // blank lines separately instead of accidentally drawing that rest.
            CTLineRef line;
            if (count == 0) {
                NSAttributedString *empty = [[NSAttributedString alloc] initWithString:@""
                    attributes:@{NSFontAttributeName: font}];
                line = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)empty);
            } else {
                line = CTTypesetterCreateLine(typesetter, CFRangeMake(start, count));
            }
            CGFloat ascent = 0, descent = 0, leading = 0;
            CTLineGetTypographicBounds(line, &ascent, &descent, &leading);
            ascent = MAX(ascent, font.ascender);
            descent = MAX(descent, -font.descender);
            leading = MAX(leading, MAX(0, font.leading));
            [baselines addObject:@(top + ascent)];
            [lines addObject:(__bridge id)line];
            CFRelease(line);
            top += ascent + descent + leading;
            start += count;
            if (start == text.length) break;
            if (start == paragraphEnd) {
                unichar separator = [text characterAtIndex:start++];
                if (separator == '\r' && start < text.length && [text characterAtIndex:start] == '\n') start++;
            }
        } while (start <= text.length);
        CFRelease(typesetter);
        MoxiParagraph *result = [MoxiParagraph new];
        result.lines = [lines copy];
        result.baselines = [baselines copy];
        result.width = width;
        result.height = top;
        result.firstBaseline = baselines.firstObject.doubleValue;
        result.lastBaseline = baselines.lastObject.doubleValue;
        return (uintptr_t)CFBridgingRetain(result);
    }
}

void moxi_paragraph_release(uintptr_t handle) {
    if (handle != 0) CFRelease((CFTypeRef)handle);
}

float moxi_paragraph_metric(uintptr_t handle, int metric) {
    if (handle == 0) return 0;
    MoxiParagraph *paragraph = (__bridge MoxiParagraph *)(void *)handle;
    switch (metric) {
        case 0: return (float)paragraph.width;
        case 1: return (float)paragraph.height;
        case 2: return (float)paragraph.firstBaseline;
        case 3: return (float)paragraph.lastBaseline;
        case 4: return (float)paragraph.lines.count;
        default: return 0;
    }
}

// Optional retained-tree adapter. Intrinsic sizing uses the same font/shaping
// provider. The paragraph profile permits emergency cluster wrapping, so its
// minimum inline contribution is the widest composed cluster, not a scalar.
void moxi_paragraph_retain(uintptr_t handle) {
    if (handle != 0) CFRetain((CFTypeRef)handle);
}

static float moxi_paragraph_intrinsic_width(const char *utf8, float fontSize, int query) {
    NSString *text = [NSString stringWithUTF8String:utf8];
    if (text == nil) return NAN;
    NSDictionary *attributes = @{NSFontAttributeName: [NSFont systemFontOfSize:fontSize]};
    __block double widest = 0;
    NSStringEnumerationOptions options = query == 1
        ? NSStringEnumerationByComposedCharacterSequences : NSStringEnumerationByLines;
    [text enumerateSubstringsInRange:NSMakeRange(0, text.length) options:options
        usingBlock:^(NSString *substring, NSRange range, NSRange enclosing, BOOL *stop) {
            (void)range; (void)enclosing; (void)stop;
            if ([substring isEqualToString:@"\n"] || [substring isEqualToString:@"\r"] ||
                [substring isEqualToString:@"\r\n"]) return;
            NSAttributedString *attributed = [[NSAttributedString alloc] initWithString:substring attributes:attributes];
            CTLineRef line = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)attributed);
            widest = MAX(widest, CTLineGetTypographicBounds(line, NULL, NULL, NULL));
            CFRelease(line);
        }];
    // Round up so an intrinsic max-content offer does not accidentally wrap the
    // last cluster because the C ABI has lower precision than CoreText.
    float result = (float)widest;
    if ((double)result < widest) result = nextafterf(result, INFINITY);
    return result;
}

// CoreText is a paragraph provider; all retained layout ownership is in Mojo.
uintptr_t moxi_paragraph_query(const char *text, float fontSize, float width,
                             int direction, int query) {
    if (text == NULL || query < 0 || query > 2) return 0;
    @autoreleasepool {
        if (query != 0) width = moxi_paragraph_intrinsic_width(text, fontSize, query);
        return moxi_paragraph_create(text, fontSize, width, direction);
    }
}

typedef struct {
    float width, height, firstBaseline, lastBaseline;
} MoxiLayoutMetrics;

static int moxi_layout_native_measure(const char *text, float fontSize, float width,
    int direction, int query, MoxiLayoutMetrics *metrics, uintptr_t *payload) {
    if (metrics == NULL || payload == NULL || text == NULL || query < 0 || query > 2) return 1;
    *payload = 0;
    @autoreleasepool {
        if (query != 0) width = moxi_paragraph_intrinsic_width(text, fontSize, query);
        uintptr_t handle = moxi_paragraph_create(text, fontSize, width, direction);
        if (handle == 0) return 1;
        metrics->width = width;
        metrics->height = moxi_paragraph_metric(handle, 1);
        metrics->firstBaseline = moxi_paragraph_metric(handle, 2);
        metrics->lastBaseline = moxi_paragraph_metric(handle, 3);
        *payload = handle;
        return 0;
    }
}

uintptr_t moxi_layout_native_measure_address(void) { return (uintptr_t)&moxi_layout_native_measure; }
uintptr_t moxi_layout_native_release_address(void) { return (uintptr_t)&moxi_paragraph_release; }
