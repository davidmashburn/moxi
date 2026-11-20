/* Reuse the retained text-input identity and value path with AppKit's standard
 * multiline editing, selection, undo and scrolling while the control is focused. */
@interface MoxiMultilineTextView : NSTextView
@property(nonatomic, weak) MoxiWindowState *moxiOwner;
@end
@implementation MoxiMultilineTextView
- (BOOL)queueRun:(NSEvent *)event {
    MOXI_CALLBACK_SCOPE(return NO);
    return moxi_queue_modified_enter(event);
}
- (BOOL)performKeyEquivalent:(NSEvent *)event {
    return [self queueRun:event] || [super performKeyEquivalent:event];
}
- (void)keyDown:(NSEvent *)event {
    if (![self queueRun:event]) [super keyDown:event];
}
- (void)insertTab:(id)sender {
    (void)sender;
    [self insertText:@"    " replacementRange:self.selectedRange];
}
@end

@implementation MoxiCanvasView (MultilineEditor)
- (void)showNativeMultilineEditorForIndex:(int)index {
    MOXI_CALLBACK_SCOPE(return);
    if (index < 0 || index >= moxi_text_input_count) return;
    if (self.nativeMultilineEditor == nil) {
        self.nativeMultilineScroll = [[NSScrollView alloc] initWithFrame:NSZeroRect];
        self.nativeMultilineScroll.hasVerticalScroller = YES;
        self.nativeMultilineScroll.borderType = NSBezelBorder;
        MoxiMultilineTextView *editor = [[MoxiMultilineTextView alloc] initWithFrame:NSZeroRect];
        editor.moxiOwner = self.moxiOwner;
        editor.delegate = self;
        editor.richText = NO;
        editor.importsGraphics = NO;
        editor.allowsUndo = YES;
        editor.automaticQuoteSubstitutionEnabled = NO;
        editor.automaticDashSubstitutionEnabled = NO;
        editor.automaticTextReplacementEnabled = NO;
        editor.automaticSpellingCorrectionEnabled = NO;
        editor.verticallyResizable = YES;
        editor.horizontallyResizable = NO;
        editor.autoresizingMask = NSViewWidthSizable;
        editor.textContainerInset = NSMakeSize(8, 8);
        editor.textContainer.widthTracksTextView = YES;
        editor.accessibilityIdentifier = @"moxi-native-multiline-input";
        self.nativeMultilineEditor = editor;
        self.nativeMultilineScroll.documentView = editor;
        [self addSubview:self.nativeMultilineScroll];
    }
    NSRect logical = moxi_text_input_frames[index];
    NSRect visible = moxi_text_input_clip_enabled[index]
        ? NSIntersectionRect(logical, moxi_text_input_clip_frames[index]) : logical;
    if (NSIsEmptyRect(visible)) {
        self.nativeMultilineScroll.hidden = YES;
        return;
    }
    BOOL newIdentity = self.nativeMultilineKey != moxi_retained_text_editor_key;
    BOOL wasHidden = self.nativeMultilineScroll.hidden || newIdentity;
    self.nativeMultilineKey = moxi_retained_text_editor_key;
    self.nativeTextEditor.hidden = YES;
    self.nativeMultilineScroll.hidden = NO;
    self.nativeMultilineScroll.frame = visible;
    NSTextView *editor = self.nativeMultilineEditor;
    editor.minSize = NSMakeSize(0, visible.size.height);
    editor.maxSize = NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX);
    editor.textContainer.containerSize = NSMakeSize(self.nativeMultilineScroll.contentSize.width, CGFLOAT_MAX);
    editor.font = [NSFont monospacedSystemFontOfSize:moxi_text_input_font_sizes[index] weight:NSFontWeightRegular];
    editor.textColor = moxi_color(moxi_text_input_text_colors[index]);
    editor.backgroundColor = moxi_color(moxi_text_input_fill_colors[index]);
    NSString *value = moxi_text_input_texts[index] ?: @"";
    BOOL changed = newIdentity || ![self.nativeMultilineValue isEqualToString:value];
    if (changed) {
        self.synchronizingNativeTextEditor = YES;
        [editor.undoManager removeAllActions];
        editor.string = value;
        self.nativeMultilineValue = value;
        self.synchronizingNativeTextEditor = NO;
    }
    if (changed || wasHidden) {
        NSUInteger start = moxi_utf16_index_for_codepoint(value, moxi_text_input_selection_starts[index]);
        NSUInteger end = moxi_utf16_index_for_codepoint(value, moxi_text_input_selection_ends[index]);
        editor.selectedRange = NSMakeRange(start, end >= start ? end - start : 0);
        [editor scrollRangeToVisible:editor.selectedRange];
    }
    if (self.window.firstResponder != editor) [self.window makeFirstResponder:editor];
    moxi_native_text_editor_seen = YES;
}

- (void)textDidChange:(NSNotification *)notification {
    MOXI_CALLBACK_SCOPE(return);
    if (notification.object != self.nativeMultilineEditor || self.synchronizingNativeTextEditor) return;
    NSString *value = self.nativeMultilineEditor.string ?: @"";
    NSString *previous = self.nativeMultilineValue ?: @"";
    if ([value isEqualToString:previous]) return;
    moxi_queue_text_event_for_target(self.nativeMultilineKey, MOXI_EVENT_TEXT_INPUT, value,
        0, moxi_codepoint_index_for_utf16(previous, previous.length));
    self.nativeMultilineValue = value;
}
@end
