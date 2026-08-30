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
