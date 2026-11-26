// Reuse I20's actual AppKit callback injection and content-view screenshots.
#import "../application-operations/host.m"

int investigation_save(const char *path, const char *text) {
    NSError *error = nil;
    return [@(text) writeToFile:@(path) atomically:YES encoding:NSUTF8StringEncoding error:&error] ? 1 : 0;
}

// Test adapters enter through the canvas' normal NSTextInputClient/key callbacks.
void investigation_text(const char *text) {
    if (strlen(text)) {
        [moxi_canvas insertText:@(text) replacementRange:NSMakeRange(NSNotFound, 0)];
    } else {
        // AppKit sends deletion rather than insertText: for an empty replacement.
        [moxi_canvas doCommandBySelector:@selector(deleteBackward:)];
    }
}

void investigation_select_all(void) {
    [moxi_canvas selectAll:nil];
}

// Measure with the same AppKit font as the normal text-input painter/editor.
float investigation_text_width(const char *text, float font_size) {
    return (float)[@(text) sizeWithAttributes:@{
        NSFontAttributeName: [NSFont systemFontOfSize:font_size]
    }].width;
}

// Match drawInRect:withAttributes: in the native label painter. In particular,
// do not request font leading: emoji/CJK fallback leading can shorten the
// measured rows, while drawInRect: uses the taller default line fragments.
float investigation_wrapped_height(const char *text, float font_size, float width) {
    NSMutableParagraphStyle *paragraph = [[NSMutableParagraphStyle alloc] init];
    paragraph.lineBreakMode = NSLineBreakByCharWrapping;
    NSRect measured = [@(text) boundingRectWithSize:NSMakeSize(width, CGFLOAT_MAX)
        options:NSStringDrawingUsesLineFragmentOrigin
        attributes:@{NSFontAttributeName: [NSFont systemFontOfSize:font_size],
                     NSParagraphStyleAttributeName: paragraph}];
    return (float)ceil(measured.size.height) + 2;
}

// The shared single-line editor clips instead of scrolling long values. Use
// AppKit's scrolling field editor for coefficients, including whitespace-padded
// numbers. Reconfigure only when entering/leaving these fields, preserving the
// selection and restoring the other example inputs' normal editor behavior.
void investigation_coefficient_editor(int enabled) {
    NSTextField *field = moxi_canvas.nativeTextEditor;
    if (field == nil || field.hidden) return;
    NSTextFieldCell *cell = (NSTextFieldCell *)field.cell;
    NSText *editor = field.currentEditor;
    if (cell.scrollable != (enabled != 0)) {
        NSRange selection = editor.selectedRange;
        cell.scrollable = enabled != 0;
        if (editor != nil && editor == moxi_window.firstResponder) {
            // The cell configures horizontal layout when editing begins.
            [field abortEditing];
            [moxi_window makeFirstResponder:field];
            editor = field.currentEditor;
            [editor setSelectedRange:selection];
        }
    }
    if (enabled && editor == moxi_window.firstResponder && [editor isKindOfClass:NSTextView.class]) {
        [(NSTextView *)editor scrollRangeToVisible:editor.selectedRange];
    }
}

// Regression oracle: invoke the real native label painter, rather than another
// metric API that can share the sizing bug. Only the submitted frame is varied.
@interface InvestigationLabelProbe : NSView
@property(nonatomic) int slot;
@property(nonatomic) CGFloat labelHeight;
@end

@implementation InvestigationLabelProbe
- (BOOL)isFlipped { return YES; }
- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    [[NSColor blackColor] setFill];
    NSRectFill(self.bounds);
    NSRect frame = moxi_label_frames[self.slot];
    BOOL clipped = moxi_label_clip_enabled[self.slot];
    moxi_label_frames[self.slot] = NSMakeRect(0, 0, frame.size.width, self.labelHeight);
    moxi_label_clip_enabled[self.slot] = NO;
    [moxi_canvas drawOrderedSlot:self.slot kind:1];
    moxi_label_frames[self.slot] = frame;
    moxi_label_clip_enabled[self.slot] = clipped;
}
@end

static NSBitmapImageRep *investigation_paint_label(int slot, CGFloat height, CGFloat referenceHeight) {
    InvestigationLabelProbe *probe = [[InvestigationLabelProbe alloc]
        initWithFrame:NSMakeRect(0, 0, ceil(moxi_label_frames[slot].size.width), referenceHeight)];
    probe.slot = slot;
    probe.labelHeight = height;
    NSBitmapImageRep *bitmap = [probe bitmapImageRepForCachingDisplayInRect:probe.bounds];
    [probe cacheDisplayInRect:probe.bounds toBitmapImageRep:bitmap];
    return bitmap;
}

int investigation_label_fits(const char *text) {
    for (int i = 0; i < moxi_label_count; i++) {
        if (![moxi_label_texts[i] isEqualToString:@(text)]) continue;
        // Test-only bound: even one line per UTF-16 unit has ample space. This
        // never calls investigation_wrapped_height or TextKit glyph coverage.
        CGFloat height = moxi_label_frames[i].size.height;
        CGFloat referenceHeight = MAX(height, (moxi_label_texts[i].length + 1)
            * ceil(moxi_label_font_sizes[i] * 2));
        NSBitmapImageRep *actual = investigation_paint_label(i, height, referenceHeight);
        NSBitmapImageRep *reference = investigation_paint_label(i, referenceHeight, referenceHeight);
        BOOL fits = actual != nil && reference != nil && actual.bytesPerRow == reference.bytesPerRow
            && actual.pixelsHigh == reference.pixelsHigh
            && !memcmp(actual.bitmapData, reference.bitmapData, actual.bytesPerRow * actual.pixelsHigh);
        printf("PAINT %lu UTF16 units, frame %.1f, full raster equal %d\n",
            (unsigned long)moxi_label_texts[i].length, height, fits);
        // A deliberately short frame must omit ink for multiline labels. This
        // negative control keeps the oracle from silently passing empty renders.
        if (fits && moxi_label_wraps[i] && height > moxi_label_font_sizes[i] * 2) {
            NSBitmapImageRep *shortened = investigation_paint_label(i, 1, referenceHeight);
            fits = memcmp(shortened.bitmapData, reference.bitmapData,
                reference.bytesPerRow * reference.pixelsHigh) != 0;
        }
        return fits;
    }
    return 0;
}

int investigation_unicode_check(void) {
    const char *mode = getenv("MOXI_I10_UNICODE_CHECK");
    if (!mode) return 0;
    if (!strcmp(mode, "frozen") || !strcmp(mode, "live")) return 1;
    abort();
}

int investigation_unicode_live(void) {
    return !strcmp(getenv("MOXI_I10_UNICODE_CHECK"), "live");
}

// Count real foreground pixels inside the coefficient editor, excluding its
// border and caret. Text metrics alone do not establish that it is visible.
int investigation_input_ink(const char *text) {
    for (int i = 0; i < moxi_text_input_count; i++) {
        if (![moxi_text_input_texts[i] isEqualToString:@(text)]) continue;
        NSRect rect = NSInsetRect(moxi_text_input_frames[i], 6, 4);
        NSView *view = moxi_window.contentView;
        [view layoutSubtreeIfNeeded];
        [view displayIfNeeded];
        NSBitmapImageRep *bitmap = [view bitmapImageRepForCachingDisplayInRect:rect];
        [view cacheDisplayInRect:rect toBitmapImageRep:bitmap];
        int ink = 0;
        for (NSInteger y = 0; y < bitmap.pixelsHigh; y++) {
            for (NSInteger x = 0; x < bitmap.pixelsWide; x++) {
                NSUInteger pixel[4] = {0};
                [bitmap getPixel:pixel atX:x y:y];
                if (pixel[0] > 190 && pixel[1] > 190 && pixel[2] > 190) ink++;
            }
        }
        printf("INPUT foreground pixels %d\n", ink);
        return ink;
    }
    return 0;
}

void investigation_edit_last_character(const char *text) {
    // Exercise the actual focused AppKit field editor, including navigation.
    NSResponder *editor = moxi_window.firstResponder;
    [editor doCommandBySelector:@selector(moveToEndOfLine:)];
    [editor doCommandBySelector:@selector(deleteBackward:)];
    [(id<NSTextInputClient>)editor insertText:@(text) replacementRange:NSMakeRange(NSNotFound, 0)];
}

int investigation_layout_check(void) {
    const char *enabled = getenv("MOXI_I10_LAYOUT_CHECK");
    if (!enabled) return 0;
    if (!strcmp(enabled, "1")) return 1;
    abort();
}

void investigation_resize(float width, float height) {
    [moxi_window setContentSize:NSMakeSize(width, height)];
}

int investigation_replay_mode(void) {
    const char *mode = getenv("MOXI_I10_REPLAY");
    if (!mode) return 0;
    if (!strcmp(mode, "create")) return 1;
    if (!strcmp(mode, "reopen")) return 2;
    if (!strcmp(mode, "invalid")) return 3;
    if (!strcmp(mode, "write-failure")) return 4;
    abort();
}
