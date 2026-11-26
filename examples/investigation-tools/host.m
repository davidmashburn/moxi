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

// Match the saved labels' real font and character wrapping, including wide glyphs.
float investigation_wrapped_height(const char *text, float font_size, float width) {
    NSMutableParagraphStyle *paragraph = [[NSMutableParagraphStyle alloc] init];
    paragraph.lineBreakMode = NSLineBreakByCharWrapping;
    NSRect measured = [@(text) boundingRectWithSize:NSMakeSize(width, CGFLOAT_MAX)
        options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
        attributes:@{NSFontAttributeName: [NSFont systemFontOfSize:font_size],
                     NSParagraphStyleAttributeName: paragraph}];
    return (float)ceil(measured.size.height) + 2;
}

// Independently lay out the actual submitted label with TextKit, not the sizing helper.
int investigation_label_fits(const char *text) {
    for (int i = 0; i < moxi_label_count; i++) {
        if (![moxi_label_texts[i] isEqualToString:@(text)]) continue;
        NSSize size = moxi_label_frames[i].size;
        NSFont *font = [NSFont systemFontOfSize:moxi_label_font_sizes[i]];
        if (!moxi_label_wraps[i]) {
            return [@(text) sizeWithAttributes:@{NSFontAttributeName:font}].width <= size.width
                && font.ascender - font.descender <= size.height;
        }
        NSTextStorage *storage = [[NSTextStorage alloc] initWithString:@(text)
            attributes:@{NSFontAttributeName:font}];
        NSLayoutManager *manager = [[NSLayoutManager alloc] init];
        NSTextContainer *container = [[NSTextContainer alloc] initWithContainerSize:size];
        container.lineFragmentPadding = 0;
        container.lineBreakMode = NSLineBreakByCharWrapping;
        [storage addLayoutManager:manager];
        [manager addTextContainer:container];
        [manager ensureLayoutForTextContainer:container];
        return [manager glyphRangeForTextContainer:container].length == manager.numberOfGlyphs
            && NSMaxY([manager usedRectForTextContainer:container]) <= size.height;
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
