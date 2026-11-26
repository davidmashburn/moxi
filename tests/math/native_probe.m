#import <Cocoa/Cocoa.h>
static NSView<NSTextInputClient> *math_view(void) {
    for(NSWindow *window in NSApp.windows)
        for(NSView *view in window.contentView.subviews)
            if([view isKindOfClass:NSClassFromString(@"MoxiMathLayer")]) return (id)view;
    return nil;
}
int32_t moxi_math_probe_key_repeat(const char *text,int32_t modifiers,int32_t source,int32_t repeat) {
    NSView *view=math_view();
    NSResponder *expected=source?[view.window fieldEditor:NO forObject:nil]:view;
    if(!expected || view.window.firstResponder!=expected) return 0;
    NSEventModifierFlags flags=((modifiers&1)?NSEventModifierFlagShift:0)|((modifiers&2)?NSEventModifierFlagCommand:0)|((modifiers&4)?NSEventModifierFlagControl:0)|((modifiers&8)?NSEventModifierFlagOption:0);
    NSString *s=[NSString stringWithUTF8String:text];
    unichar character=s.length?[s characterAtIndex:0]:0;
    unsigned short code=character==NSDeleteCharacter?51:character==NSDeleteFunctionKey?117:
        character==NSLeftArrowFunctionKey?123:character==NSRightArrowFunctionKey?124:
        character==NSDownArrowFunctionKey?125:character==NSUpArrowFunctionKey?126:0;
    NSEvent *event=[NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:flags timestamp:NSProcessInfo.processInfo.systemUptime windowNumber:view.window.windowNumber context:nil characters:s charactersIgnoringModifiers:s isARepeat:repeat!=0 keyCode:code];
    [view.window sendEvent:event]; return 1;
}
int32_t moxi_math_probe_key(const char *text,int32_t modifiers,int32_t source) {
    return moxi_math_probe_key_repeat(text,modifiers,source,0);
}
extern int32_t moxi_math_capture(const char *path);
int32_t moxi_math_probe_capture(const char *name) {
    const char *directory=getenv("MOXI_MATH_NATIVE_EVIDENCE_DIR");
    if (!directory || !*directory) return 1;
    NSString *root=[NSString stringWithUTF8String:directory];
    if (![NSFileManager.defaultManager createDirectoryAtPath:root withIntermediateDirectories:YES attributes:nil error:NULL]) return 0;
    NSString *path=[root stringByAppendingPathComponent:[NSString stringWithFormat:@"%s.png",name]];
    return moxi_math_capture(path.UTF8String);
}
// Exercise the native canvas callbacks even when the test window is in the background.
static NSView *drag_view;
int32_t moxi_math_probe_mouse(float x,float y,int32_t phase) {
    NSWindow *window=math_view().window;
    if (!window) return 0;
    NSPoint location=[window.contentView convertPoint:NSMakePoint(x,y) toView:nil];
    NSEventType type=phase==0?NSEventTypeLeftMouseDown:phase==1?NSEventTypeLeftMouseDragged:NSEventTypeLeftMouseUp;
    NSEvent *event=[NSEvent mouseEventWithType:type location:location modifierFlags:0
        timestamp:NSProcessInfo.processInfo.systemUptime windowNumber:window.windowNumber
        context:nil eventNumber:1 clickCount:1 pressure:phase==2?0:1];
    if (phase==0) {
        drag_view=[window.contentView hitTest:[window.contentView convertPoint:location fromView:nil]];
        if (!drag_view) return 0;
        [drag_view mouseDown:event];
    } else if (phase==1) {
        [drag_view mouseDragged:event];
    } else {
        [drag_view mouseUp:event];
        drag_view=nil;
    }
    return 1;
}
int32_t moxi_math_probe_select_source_and_blur(int32_t start,int32_t length) {
    NSWindow *window=math_view().window;
    NSTextView *editor=(NSTextView *)[window fieldEditor:NO forObject:nil];
    if (!editor || window.firstResponder!=editor) return 0;
    [editor setSelectedRange:NSMakeRange(start,length)];
    return [window makeFirstResponder:window.contentView];
}
int32_t moxi_math_probe_selected_range(int32_t start,int32_t length) {
    NSRange selected=[math_view() selectedRange];
    return NSEqualRanges(selected,NSMakeRange(start,length));
}
int32_t moxi_math_probe_clear_first_character(void) {
    NSView<NSTextInputClient> *view=math_view();
    if (!view) return 0;
    [view insertText:@"" replacementRange:NSMakeRange(0,1)];
    return 1;
}
int32_t moxi_math_probe_marked(const char *text,int32_t commit) {
    NSView<NSTextInputClient> *view=math_view(); if(!view) return 0;
    NSMutableString *s=[[NSString stringWithUTF8String:text] mutableCopy];
    if(commit) [view insertText:s replacementRange:NSMakeRange(NSNotFound,0)];
    else [view setMarkedText:s selectedRange:NSMakeRange(s.length,0) replacementRange:NSMakeRange(NSNotFound,0)];
    // Mimic the input service recycling its buffer before the editor polls.
    [s setString:@""];
    return commit || view.hasMarkedText;
}
int32_t moxi_math_probe_semantics(void) {
    NSView<NSTextInputClient> *view=math_view();
    if(!view || view.window.firstResponder!=view) return -1;
    NSArray *children=view.accessibilityChildren;
    for(NSAccessibilityElement *child in children)
        if(!child.accessibilityLabel.length || NSIsEmptyRect(child.accessibilityFrame)) return -2;
    NSRect caret=[view firstRectForCharacterRange:NSMakeRange(0,0) actualRange:NULL];
    if(NSIsEmptyRect(caret) || !NSIntersectsRect(caret,view.window.frame)) return -3;
    return (int32_t)children.count;
}
// Preserve every pasteboard item/type around the isolated clipboard probe.
static NSArray<NSPasteboardItem *> *saved_pasteboard;
extern int32_t moxi_math_paste_begin(void);
extern int32_t moxi_math_paste_codepoint(int32_t index);
int32_t moxi_math_probe_clipboard_limits(void) {
    NSPasteboard *p=NSPasteboard.generalPasteboard;
    [p clearContents];
    [p setString:[@"x" stringByPaddingToLength:1048577 withString:@"x" startingAtIndex:0] forType:NSPasteboardTypeString];
    if(moxi_math_paste_begin()!=-1) return 0;
    [p clearContents]; [p setString:@"a😀β" forType:NSPasteboardTypeString];
    return moxi_math_paste_begin()==3 && moxi_math_paste_codepoint(0)=='a' &&
        moxi_math_paste_codepoint(1)==0x1f600 && moxi_math_paste_codepoint(2)==0x3b2 &&
        moxi_math_paste_codepoint(0)=='a' && moxi_math_paste_codepoint(2)==0x3b2;
}
int32_t moxi_math_probe_clipboard(int32_t mode) {
    NSPasteboard *p=NSPasteboard.generalPasteboard;
    if(mode==0) {
        NSMutableArray *copies=[NSMutableArray array];
        for(NSPasteboardItem *item in p.pasteboardItems) {
            NSPasteboardItem *copy=[[NSPasteboardItem alloc] init];
            for(NSPasteboardType type in item.types) {
                NSData *data=[item dataForType:type];
                if(data) [copy setData:data forType:type];
            }
            [copies addObject:copy];
        }
        saved_pasteboard=copies;
        return 1;
    }
    if(mode==1) return [p stringForType:NSPasteboardTypeString].length>0 && [[p stringForType:@"org.moxi.math.fragment.v1"] hasPrefix:@"moxi-math/1\n"];
    [p clearContents];
    if(saved_pasteboard.count) [p writeObjects:saved_pasteboard];
    saved_pasteboard=nil;
    return 1;
}
