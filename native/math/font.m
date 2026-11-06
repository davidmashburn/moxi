/* D02's narrow math-only adapter. No changes to Moxi native host ownership.
 * UI-thread confined; snapshots own numeric glyph IDs; a session retains one
 * immutable font until all math views have been removed. */
#import <Cocoa/Cocoa.h>
#import <CoreText/CoreText.h>
#include <hb.h>
#include <hb-ot.h>
#include <stdint.h>
#include <math.h>

static CTFontRef math_font;
static hb_font_t *hb_font;
static unsigned upem;
static NSMutableArray<NSDictionary *> *commands;
static NSMutableArray<NSDictionary *> *semantics;
static NSRect clip;
static float origin_x, origin_y, view_scale=1;
static NSString *composition=@"";
static NSRect composition_rect;
// Math-local input scope. The existing Moxi host continues to own the window.
static NSMutableArray<NSDictionary *> *input_events;
static NSString *clipboard_text;
static NSUInteger paste_utf16, input_utf16;
static int32_t paste_index=-1, input_index=-1;
static NSDictionary *current_event;
static NSString *leaf_text=@"", *marked_text=@"";
static NSRange leaf_selection, marked_selection;
static NSRect caret_rect;
static BOOL math_focused;
static int input_modifiers;
static NSMutableSet<NSString *> *bound_keys;
static int modifiers(NSEventModifierFlags flags) {
    return ((flags & NSEventModifierFlagShift)?1:0) |
           ((flags & NSEventModifierFlagCommand)?2:0) |
           ((flags & NSEventModifierFlagControl)?4:0) |
           ((flags & NSEventModifierFlagOption)?8:0);
}
static NSUInteger utf16_at(NSString *s, NSUInteger codepoints) {
    NSUInteger i=0;
    while(i<s.length && codepoints--) {
        unichar c=[s characterAtIndex:i++];
        if(CFStringIsSurrogateHighCharacter(c) && i<s.length && CFStringIsSurrogateLowCharacter([s characterAtIndex:i])) i++;
    }
    return i;
}
static int codepoints_to(NSString *s, NSUInteger end) {
    int count=0;
    for(NSUInteger i=0;i<MIN(end,s.length);count++) {
        unichar c=[s characterAtIndex:i++];
        if(CFStringIsSurrogateHighCharacter(c) && i<s.length && CFStringIsSurrogateLowCharacter([s characterAtIndex:i])) i++;
    }
    return count;
}
static void input_push(int kind,int key,NSString *text,NSRange replacement) {
    if (!input_events) input_events=[NSMutableArray array];
    [input_events addObject:@{@"kind":@(kind),@"key":@(key),@"modifiers":@(input_modifiers),@"text":text?:@"",@"start":@(replacement.location==NSNotFound?-1:codepoints_to(leaf_text,replacement.location)),@"end":@(replacement.location==NSNotFound?-1:codepoints_to(leaf_text,NSMaxRange(replacement)))}];
}
@interface MoxiMathLayer : NSView <NSTextInputClient>
@end
static MoxiMathLayer *layer;
@implementation MoxiMathLayer
- (BOOL)acceptsFirstResponder { return YES; }
- (void)keyDown:(NSEvent *)event {
    input_modifiers=modifiers(event.modifierFlags);
    NSString *chars=event.charactersIgnoringModifiers;
    int key=chars.length?[chars characterAtIndex:0]:0;
    NSString *chord=[NSString stringWithFormat:@"%d:%d",key,input_modifiers];
    NSString *unshifted=[NSString stringWithFormat:@"%d:%d",key,input_modifiers&~1];
    BOOL editing=(input_modifiers&2) && (key=='a'||key=='c'||key=='v'||key=='x');
    if (!marked_text.length && (editing || [bound_keys containsObject:chord] || [bound_keys containsObject:unshifted])) {
        input_push(2,key,nil,NSMakeRange(NSNotFound,0));
    } else {
        [self interpretKeyEvents:@[event]];
    }
    input_modifiers=0;
}
- (BOOL)performKeyEquivalent:(NSEvent *)event {
    if (!math_focused || self.window.firstResponder!=self) return NO;
    NSString *chars=event.charactersIgnoringModifiers;
    if (!chars.length) return NO;
    int key=[chars characterAtIndex:0], mods=modifiers(event.modifierFlags);
    NSString *chord=[NSString stringWithFormat:@"%d:%d",key,mods];
    NSString *alias=[NSString stringWithFormat:@"%d:%d",key,mods&~1];
    if ([bound_keys containsObject:chord] || [bound_keys containsObject:alias] || ((mods&2)&&(key=='a'||key=='c'||key=='v'||key=='x'))) {
        [self keyDown:event]; return YES;
    }
    return NO;
}
- (void)insertText:(id)string replacementRange:(NSRange)range {
    NSString *text=[string isKindOfClass:NSAttributedString.class]?[string string]:string;
    // A preedit range refers to marked text, not persisted leaf contents.
    if(marked_text.length) range=NSMakeRange(NSNotFound,0);
    marked_text=@"";
    input_push(9,0,nil,NSMakeRange(NSNotFound,0));
    input_push(3,0,text,range);
}
- (void)setMarkedText:(id)string selectedRange:(NSRange)selection replacementRange:(NSRange)range {
    (void)range;
    marked_text=[string isKindOfClass:NSAttributedString.class]?[string string]:string;
    marked_selection=selection;
    input_push(8,0,marked_text,NSMakeRange(NSNotFound,0));
}
- (void)unmarkText { marked_text=@""; input_push(9,0,nil,NSMakeRange(NSNotFound,0)); }
- (BOOL)hasMarkedText { return marked_text.length>0; }
- (NSRange)markedRange { return marked_text.length?NSMakeRange(leaf_selection.location,marked_text.length):NSMakeRange(NSNotFound,0); }
- (NSRange)selectedRange { return marked_text.length?NSMakeRange(leaf_selection.location+marked_selection.location,marked_selection.length):leaf_selection; }
- (NSArray<NSAttributedStringKey> *)validAttributesForMarkedText { return @[]; }
- (NSAttributedString *)attributedSubstringForProposedRange:(NSRange)range actualRange:(NSRangePointer)actual {
    NSString *text=leaf_text;
    if (range.location==NSNotFound) return nil;
    range.location=MIN(range.location,text.length);
    range.length=MIN(range.length,text.length-range.location);
    if(actual) *actual=range;
    return [[NSAttributedString alloc] initWithString:[text substringWithRange:range]];
}
- (NSRect)firstRectForCharacterRange:(NSRange)range actualRange:(NSRangePointer)actual {
    (void)range;
    if(actual) *actual=leaf_selection;
    NSRect r=caret_rect;
    r.origin.x=origin_x+r.origin.x*view_scale;
    r.origin.y=origin_y+r.origin.y*view_scale;
    r.size.width*=view_scale; r.size.height*=view_scale;
    return [self.window convertRectToScreen:[self convertRect:r toView:nil]];
}
- (NSUInteger)characterIndexForPoint:(NSPoint)point { (void)point; return leaf_selection.location; }
- (void)doCommandBySelector:(SEL)selector {
    int key=0;
    if(selector==@selector(moveLeft:)||selector==@selector(moveLeftAndModifySelection:)) key=1000;
    else if(selector==@selector(moveRight:)||selector==@selector(moveRightAndModifySelection:)) key=1001;
    else if(selector==@selector(moveUp:)||selector==@selector(moveUpAndModifySelection:)) key=1002;
    else if(selector==@selector(moveDown:)||selector==@selector(moveDownAndModifySelection:)) key=1003;
    else if(selector==@selector(moveToBeginningOfLine:)||selector==@selector(moveToBeginningOfDocument:)) key=1004;
    else if(selector==@selector(moveToEndOfLine:)||selector==@selector(moveToEndOfDocument:)) key=1005;
    else if(selector==@selector(deleteBackward:)) key=8;
    else if(selector==@selector(deleteForward:)) key=127;
    else if(selector==@selector(insertTab:)) key=9;
    else if(selector==@selector(insertBacktab:)) { key=9; input_modifiers|=1; }
    else if(selector==@selector(insertNewline:)) key=13;
    else if(selector==@selector(cancelOperation:)) { if(marked_text.length) { [self unmarkText]; return; } key=27; }
    if(key) input_push(2,key,nil,NSMakeRange(NSNotFound,0));
}
- (BOOL)isFlipped { return YES; }
- (NSView *)hitTest:(NSPoint)p { (void)p; return nil; }
- (BOOL)isAccessibilityElement { return NO; }
- (NSArray *)accessibilityChildren {
    NSMutableArray *children = [NSMutableArray array];
    for (NSDictionary *s in semantics) {
        NSAccessibilityElement *e = [NSAccessibilityElement accessibilityElementWithRole:NSAccessibilityStaticTextRole frame:NSZeroRect label:s[@"label"] parent:self];
        NSRect r = [s[@"rect"] rectValue];
        r.origin.x = origin_x + r.origin.x * view_scale;
        r.origin.y = origin_y + r.origin.y * view_scale;
        r.size.width *= view_scale; r.size.height *= view_scale;
        NSRect screen = [self.window convertRectToScreen:[self convertRect:r toView:nil]];
        e.accessibilityFrame = screen;
        e.accessibilityValue = s[@"value"];
        [children addObject:e];
    }
    return children;
}
- (void)drawRect:(NSRect)dirty {
    (void)dirty;
    CGContextRef ctx = NSGraphicsContext.currentContext.CGContext;
    CGContextSaveGState(ctx);
    CGContextClipToRect(ctx, clip);
    CGContextSetFillColorWithColor(ctx,NSColor.whiteColor.CGColor);
    CGContextFillRect(ctx,clip);
    CGContextTranslateCTM(ctx, origin_x, origin_y);
    CGContextScaleCTM(ctx, view_scale, view_scale);
    for (NSDictionary *d in commands) {
        int kind = [d[@"kind"] intValue];
        float x=[d[@"x"] floatValue], y=[d[@"y"] floatValue];
        float w=[d[@"w"] floatValue], h=[d[@"h"] floatValue];
        int tone=[d[@"tone"] intValue];
        NSColor *color = tone==1 ? [NSColor colorWithSRGBRed:.20 green:.55 blue:.96 alpha:.23] : tone==2 ? [NSColor colorWithSRGBRed:.85 green:.18 blue:.18 alpha:1] : tone==3 ? [NSColor colorWithSRGBRed:.12 green:.45 blue:.85 alpha:1] : [NSColor colorWithSRGBRed:.12 green:.17 blue:.24 alpha:1];
        CGContextSetFillColorWithColor(ctx, color.CGColor);
        CGContextSetStrokeColorWithColor(ctx, color.CGColor);
        if (kind==0) {
            CTFontRef font = CTFontCreateCopyWithAttributes(math_font, h, NULL, NULL);
            CGGlyph glyph=(CGGlyph)[d[@"glyph"] unsignedIntValue];
            CGPoint zero=CGPointZero;
            CGContextSaveGState(ctx);
            CGContextTranslateCTM(ctx,x,y);
            CGContextScaleCTM(ctx,1,-1);
            CGContextSetTextMatrix(ctx,CGAffineTransformIdentity);
            CTFontDrawGlyphs(font,&glyph,&zero,1,ctx);
            CGContextRestoreGState(ctx);
            CFRelease(font);
        } else if (kind==1) {
            CGContextFillRect(ctx, CGRectMake(x,y,w,h));
        } else {
            CGContextSetLineWidth(ctx,1);
            CGContextStrokeRect(ctx,CGRectMake(x,y,w,h));
        }
    }
    if (composition.length) {
        [composition drawInRect:composition_rect withAttributes:@{NSFontAttributeName:[NSFont systemFontOfSize:20], NSUnderlineStyleAttributeName:@1, NSForegroundColorAttributeName:NSColor.systemBlueColor}];
    }
    CGContextRestoreGState(ctx);
}
@end
int32_t moxi_math_font_open(const char *path) {
    if (math_font || hb_font) return 0; /* one owned session, no silent replacement */
    NSURL *url=[NSURL fileURLWithPath:[NSString stringWithUTF8String:path]];
    CGDataProviderRef provider=CGDataProviderCreateWithURL((__bridge CFURLRef)url);
    if (!provider) return 0;
    CGFontRef cg=CGFontCreateWithDataProvider(provider);
    CGDataProviderRelease(provider);
    if (!cg) return 0;
    math_font=CTFontCreateWithGraphicsFont(cg,1000,NULL,NULL);
    CGFontRelease(cg);
    hb_blob_t *blob=hb_blob_create_from_file_or_fail(path);
    if (!blob) { CFRelease(math_font); math_font=NULL; return 0; }
    hb_face_t *face=hb_face_create(blob,0);
    hb_blob_destroy(blob);
    if (!hb_ot_math_has_data(face)) { hb_face_destroy(face); CFRelease(math_font); math_font=NULL; return 0; }
    upem=hb_face_get_upem(face);
    hb_font=hb_font_create(face);
    hb_face_destroy(face);
    hb_ot_font_set_funcs(hb_font);
    hb_font_set_scale(hb_font,upem,upem);
    commands=[NSMutableArray array]; semantics=[NSMutableArray array];
    return 1;
}
static hb_buffer_t *shape_buffer;
void moxi_math_font_close(void) {
    if (shape_buffer) { hb_buffer_destroy(shape_buffer); shape_buffer=NULL; }
    [layer removeFromSuperview]; layer=nil;
    commands=nil; semantics=nil; input_events=nil; current_event=nil; bound_keys=nil; clipboard_text=nil;
    leaf_text=@""; marked_text=@""; math_focused=NO;
    if (hb_font) hb_font_destroy(hb_font);
    if (math_font) CFRelease(math_font);
    hb_font=NULL; math_font=NULL;
}
float moxi_math_constant(int32_t index, float size) {
    if (!hb_font || index<0 || index>55) return 0;
    int value=hb_ot_math_get_constant(hb_font,(hb_ot_math_constant_t)index);
    if (index==0 || index==1 || index==55) return value/100.f;
    return value*size/upem;
}
int32_t moxi_math_glyph(int32_t codepoint) {
    hb_codepoint_t glyph=0;
    if (hb_font) hb_font_get_nominal_glyph(hb_font,codepoint,&glyph);
    return glyph;
}
float moxi_math_metric(int32_t glyph, float size, int32_t metric) {
    if (!hb_font) return 0;
    hb_glyph_extents_t e={0}; hb_font_get_glyph_extents(hb_font,glyph,&e);
    float value=0;
    switch(metric) {
        case 0: value=hb_font_get_glyph_h_advance(hb_font,glyph); break;
        case 1: value=e.y_bearing; break;
        case 2: value=-e.y_bearing-e.height; break;
        case 3: value=e.x_bearing; break;
        case 4: value=e.width; break;
        case 5: value=hb_ot_math_get_glyph_italics_correction(hb_font,glyph); break;
    }
    return value*size/upem;
}

int32_t moxi_math_shape(const char *text) {
    if (shape_buffer) hb_buffer_destroy(shape_buffer);
    shape_buffer=hb_buffer_create();
    hb_buffer_add_utf8(shape_buffer,text,-1,0,-1);
    hb_buffer_set_direction(shape_buffer,HB_DIRECTION_LTR);
    hb_buffer_guess_segment_properties(shape_buffer);
    hb_shape(hb_font,shape_buffer,NULL,0);
    return hb_buffer_get_length(shape_buffer);
}
float moxi_math_shaped(int32_t index,int32_t field,float size) {
    unsigned count=0;
    hb_glyph_info_t *info=hb_buffer_get_glyph_infos(shape_buffer,&count);
    hb_glyph_position_t *pos=hb_buffer_get_glyph_positions(shape_buffer,&count);
    if (index<0 || (unsigned)index>=count) return 0;
    switch(field) {
        case 0:return info[index].codepoint;
        case 1:return pos[index].x_advance*size/upem;
        case 2:return pos[index].x_offset*size/upem;
        case 3:return -pos[index].y_offset*size/upem;
        case 4:return info[index].cluster;
    }
    return 0;
}
static hb_codepoint_t pieces[1024];
static float offsets[1024];
static unsigned piece_count;
static float stretch_height;
int32_t moxi_math_stretch(int32_t glyph,float size,float target) {
    piece_count=0; stretch_height=0;
    hb_ot_math_glyph_variant_t variants[128]; unsigned count=128;
    hb_ot_math_get_glyph_variants(hb_font,glyph,HB_DIRECTION_TTB,0,&count,variants);
    for(unsigned i=0;i<count;i++) {
        float height=variants[i].advance*size/upem;
        if(height>=target) { pieces[0]=variants[i].glyph; offsets[0]=0; piece_count=1; stretch_height=height; return 1; }
    }
    hb_ot_math_glyph_part_t parts[128]; count=128; hb_position_t italic;
    hb_ot_math_get_glyph_assembly(hb_font,glyph,HB_DIRECTION_TTB,0,&count,parts,&italic);
    if (!count) {
        pieces[0]=count?variants[count-1].glyph:glyph; offsets[0]=0; piece_count=1;
        stretch_height=moxi_math_metric(glyph,size,1)+moxi_math_metric(glyph,size,2);
        return 1;
    }
    float overlap=hb_ot_math_get_min_connector_overlap(hb_font,HB_DIRECTION_TTB)*size/upem;
    unsigned repeats=1;
    for (; repeats<128; repeats++) {
        float length=0; unsigned n=0;
        for(unsigned j=0;j<count;j++) {
            unsigned times=(parts[j].flags&HB_OT_MATH_GLYPH_PART_FLAG_EXTENDER)?repeats:1;
            length+=times*parts[j].full_advance*size/upem; n+=times;
        }
        length-=(n-1)*overlap;
        if(length>=target) { stretch_height=length; break; }
    }
    if(repeats==128) return 0;
    // OpenType assembly order is bottom to top for vertical constructions.
    float cursor=stretch_height;
    for(unsigned j=0;j<count;j++) {
        unsigned times=(parts[j].flags&HB_OT_MATH_GLYPH_PART_FLAG_EXTENDER)?repeats:1;
        for(unsigned k=0;k<times;k++) {
            if(piece_count>=1024) return 0;
            float advance=parts[j].full_advance*size/upem;
            pieces[piece_count]=parts[j].glyph;
            offsets[piece_count]=cursor-advance;
            piece_count++; cursor-=advance-overlap;
        }
    }
    return piece_count;
}
float moxi_math_piece(int32_t index,int32_t field) {
    if(index<0 || (unsigned)index>=piece_count) return 0;
    return field==0?pieces[index]:field==1?offsets[index]:stretch_height;
}
void moxi_math_scene_begin(float x,float y,float w,float h,float ox,float oy,float scale) {
    [commands removeAllObjects]; [semantics removeAllObjects];
    clip=NSMakeRect(x,y,w,h); origin_x=ox; origin_y=oy; view_scale=scale;
}
void moxi_math_scene_item(int32_t kind,int32_t glyph,float x,float y,float w,float h,int32_t tone) {
    @autoreleasepool { [commands addObject:@{@"kind":@(kind),@"glyph":@(glyph),@"x":@(x),@"y":@(y),@"w":@(w),@"h":@(h),@"tone":@(tone)}]; }
}
void moxi_math_semantic(const char *label,const char *value,float x,float y,float w,float h) {
    @autoreleasepool { [semantics addObject:@{@"label":[NSString stringWithUTF8String:label],@"value":[NSString stringWithUTF8String:value],@"rect":[NSValue valueWithRect:NSMakeRect(x,y,w,h)]}]; }
}
void moxi_math_composition(const char *text,float x,float y) {
    composition=[NSString stringWithUTF8String:text]; composition_rect=NSMakeRect(x,y,250,40);
}
void moxi_math_scene_end(void) {
    if (!layer) {
        for(NSWindow *w in NSApp.windows) {
            if(w==NSApp.keyWindow || [w.title hasPrefix:@"Moxi Math"]) {
                layer=[[MoxiMathLayer alloc] initWithFrame:w.contentView.bounds];
                layer.autoresizingMask=NSViewWidthSizable|NSViewHeightSizable;
                [w.contentView addSubview:layer]; break;
            }
        }
    }
    if (math_focused && layer.window.firstResponder!=layer) [layer.window makeFirstResponder:layer];
    else if (!math_focused && layer.window.firstResponder==layer) [layer.window makeFirstResponder:layer.superview];
    [layer setNeedsDisplay:YES];
}
int32_t moxi_math_capture(const char *path) {
    NSView *view=layer.window.contentView;
    if (!view) return 0;
    [view displayIfNeeded];
    NSBitmapImageRep *bitmap=[view bitmapImageRepForCachingDisplayInRect:view.bounds];
    if(!bitmap) return 0;
    [view cacheDisplayInRect:view.bounds toBitmapImageRep:bitmap];
    NSData *png=[bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    return [png writeToFile:[NSString stringWithUTF8String:path] atomically:YES];
}
void moxi_math_clipboard(const char *text) {
    NSString *s=[NSString stringWithUTF8String:text];
    NSPasteboard *p=NSPasteboard.generalPasteboard;
    [p clearContents];
    [p setString:s forType:NSPasteboardTypeString];
    [p setString:[@"moxi-math/1\n" stringByAppendingString:s] forType:@"org.moxi.math.fragment.v1"];
}

void moxi_math_keymap_begin(void) { bound_keys=[NSMutableSet set]; }
void moxi_math_keymap_add(int32_t key,int32_t mods) { @autoreleasepool { [bound_keys addObject:[NSString stringWithFormat:@"%d:%d",key,mods]]; } }
void moxi_math_input_state(const char *text,int32_t offset,int32_t focused,float x,float y,float w,float h) {
    leaf_text=[NSString stringWithUTF8String:text];
    leaf_selection=NSMakeRange(utf16_at(leaf_text,MAX(0,offset)),0);
    math_focused=focused!=0;
    caret_rect=NSMakeRect(x,y,w,h);
    [layer.inputContext invalidateCharacterCoordinates];
}
int32_t moxi_math_input_poll(void) {
    input_index=-1; input_utf16=0;
    if(!input_events.count) { current_event=nil; return 0; }
    current_event=input_events[0]; [input_events removeObjectAtIndex:0];
    return [current_event[@"kind"] intValue];
}
int32_t moxi_math_input_field(int32_t field) {
    return [current_event[field==0?@"key":field==1?@"modifiers":field==2?@"start":@"end"] intValue];
}
int32_t moxi_math_input_length(void) { return codepoints_to(current_event[@"text"],[current_event[@"text"] length]); }
int32_t moxi_math_input_codepoint(int32_t index) {
    NSString *s=current_event[@"text"];
    NSUInteger i=index==input_index+1?input_utf16:utf16_at(s,index);
    if(i>=s.length) return -1;
    unichar high=[s characterAtIndex:i];
    BOOL pair=CFStringIsSurrogateHighCharacter(high) && i+1<s.length;
    input_index=index; input_utf16=i+(pair?2:1);
    if(pair) return CFStringGetLongCharacterForSurrogatePair(high,[s characterAtIndex:i+1]);
    return high;
}

// One immutable clipboard snapshot; prefer the versioned fragment when present.
int32_t moxi_math_paste_begin(void) {
    NSPasteboard *p=NSPasteboard.generalPasteboard;
    NSString *fragment=[p stringForType:@"org.moxi.math.fragment.v1"];
    clipboard_text=[fragment hasPrefix:@"moxi-math/1\n"]?[fragment substringFromIndex:12]:[p stringForType:NSPasteboardTypeString];
    clipboard_text=clipboard_text?:@"";
    paste_index=-1; paste_utf16=0;
    if([clipboard_text lengthOfBytesUsingEncoding:NSUTF8StringEncoding]>1048576) { clipboard_text=nil; return -1; }
    return codepoints_to(clipboard_text,clipboard_text.length);
}
int32_t moxi_math_paste_codepoint(int32_t index) {
    NSUInteger i=index==paste_index+1?paste_utf16:utf16_at(clipboard_text,MAX(0,index));
    if(index<0 || i>=clipboard_text.length) return -1;
    unichar c=[clipboard_text characterAtIndex:i];
    BOOL pair=CFStringIsSurrogateHighCharacter(c) && i+1<clipboard_text.length;
    paste_index=index; paste_utf16=i+(pair?2:1);
    if(pair)
        return CFStringGetLongCharacterForSurrogatePair(c,[clipboard_text characterAtIndex:i+1]);
    return c;
}
