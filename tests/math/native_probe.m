#import <Cocoa/Cocoa.h>
static NSView<NSTextInputClient> *math_view(void) {
    for(NSWindow *window in NSApp.windows)
        for(NSView *view in window.contentView.subviews)
            if([view isKindOfClass:NSClassFromString(@"MoxiMathLayer")]) return (id)view;
    return nil;
}
int32_t moxi_math_probe_key(const char *text,int32_t modifiers) {
    NSView *view=math_view(); if(!view) return 0;
    NSEventModifierFlags flags=((modifiers&1)?NSEventModifierFlagShift:0)|((modifiers&2)?NSEventModifierFlagCommand:0)|((modifiers&4)?NSEventModifierFlagControl:0)|((modifiers&8)?NSEventModifierFlagOption:0);
    NSString *s=[NSString stringWithUTF8String:text];
    NSEvent *event=[NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:flags timestamp:NSProcessInfo.processInfo.systemUptime windowNumber:view.window.windowNumber context:nil characters:s charactersIgnoringModifiers:s isARepeat:NO keyCode:0];
    [view keyDown:event]; return 1;
}
int32_t moxi_math_probe_marked(const char *text,int32_t commit) {
    NSView<NSTextInputClient> *view=math_view(); if(!view) return 0;
    NSString *s=[NSString stringWithUTF8String:text];
    if(commit) [view insertText:s replacementRange:NSMakeRange(NSNotFound,0)];
    else [view setMarkedText:s selectedRange:NSMakeRange(s.length,0) replacementRange:NSMakeRange(NSNotFound,0)];
    return 1;
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
