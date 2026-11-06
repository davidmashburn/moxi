/* Real AppKit windows, callbacks and resources; no alternative host. */
#import "../native/macos_window.m"
#include <assert.h>

static void open_instance(uint64_t handle, const char *title) {
    assert(moxi_window_select_instance(handle));
    moxi_window_open(title, 400, 300, 0, 0, 0, 0, 1, 0);
    assert(moxi_window.isVisible && moxi_canvas.window==moxi_window);
    moxi_reset_event_queue();
}
static MoxiAccessibilityElement *publish_editor(NSString *value) {
    moxi_window_begin_accessibility();
    moxi_accessibility_count = 2;
    moxi_accessibility_ids[0] = 1;
    moxi_accessibility_roles[0] = MOXI_ROLE_TABLE;
    moxi_accessibility_labels[0] = @"Rows";
    moxi_accessibility_ids[1] = 50001;
    moxi_accessibility_parent_ids[1] = 1;
    moxi_accessibility_roles[1] = MOXI_ROLE_TEXT_INPUT;
    moxi_accessibility_values[1] = value;
    moxi_accessibility_labels[1] = @"Row editor";
    moxi_accessibility_enabled[1] = YES;
    moxi_accessibility_focused[1] = YES;
    moxi_window_end_accessibility();
    return (MoxiAccessibilityElement *)moxi_accessibility_elements[1];
}
static NSColor *pixel(MoxiCanvasView *view) {
    NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc]
        initWithBitmapDataPlanes:NULL pixelsWide:400 pixelsHigh:300
        bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO
        colorSpaceName:NSDeviceRGBColorSpace bitmapFormat:0 bytesPerRow:0 bitsPerPixel:0];
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap]];
    [view drawRect:view.bounds];
    [NSGraphicsContext restoreGraphicsState];
    return [[bitmap colorAtX:20 y:20] colorUsingColorSpace:NSColorSpace.deviceRGBColorSpace];
}
int main(void) {
    @autoreleasepool {
        uint64_t a=moxi_window_create_instance(), b=moxi_window_create_instance();
        assert(a && b && a!=b);
        open_instance(a,"F02 ownership A");
        BOOL rejectedDuplicate=NO;
        @try { moxi_window_open("Must not steal A",400,300,0,0,0,0,1,0); }
        @catch(NSException *exception) { rejectedDuplicate=YES; }
        assert(rejectedDuplicate);
        MoxiCanvasView *av=moxi_canvas;
        MoxiWindowDelegate *ad=moxi_delegate;
        MoxiAccessibilityElement *ae=publish_editor(@"Alpha");
        moxi_window_begin_custom_paint();
        moxi_window_add_custom_rect(0,0,400,300,1,0,0,1,0,0,0,0,0);
        moxi_registered_image_ids[0]=7;
        moxi_registered_images[0]=[[NSImage alloc] initWithSize:NSMakeSize(2,2)];
        __weak NSImage *imageA=moxi_registered_images[0];
        moxi_queue_text_event(MOXI_EVENT_TEXT_INPUT,@"queued A",0,0);
        open_instance(b,"F02 ownership B");
        MoxiCanvasView *bv=moxi_canvas;
        MoxiAccessibilityElement *be=publish_editor(@"Beta");
        moxi_window_begin_custom_paint();
        moxi_window_add_custom_rect(0,0,400,300,0,0,1,1,0,0,0,0,0);
        assert(moxi_registered_images[0]==nil);
        assert(ae!=be && av!=bv);
        assert(pixel(av).redComponent>0.9); // Draw A while B is selected.
        assert(moxi_canvas==bv);             // Nested callback restores cursor.
        assert(pixel(bv).blueComponent>0.9);
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        assert([[ae accessibilityAttributeValue:NSAccessibilityValueAttribute] isEqual:@"Alpha"]);
        assert([[be accessibilityAttributeValue:NSAccessibilityValueAttribute] isEqual:@"Beta"]);
        [ae accessibilitySetValue:@"Edited A" forAttribute:NSAccessibilityValueAttribute];
        [be accessibilitySetValue:@"Edited B" forAttribute:NSAccessibilityValueAttribute];
#pragma clang diagnostic pop
        [ae setAccessibilityFocused:YES];
        assert(moxi_window_poll_event()==MOXI_EVENT_TEXT_INPUT);
        assert([moxi_event_text_value isEqual:@"Edited B"] && moxi_event_target==50001);
        assert(moxi_window_poll_event()==MOXI_EVENT_NONE);
        assert(moxi_window_select_instance(a));
        assert(moxi_window_poll_event()==MOXI_EVENT_TEXT_INPUT && [moxi_event_text_value isEqual:@"queued A"]);
        assert(moxi_window_poll_event()==MOXI_EVENT_TEXT_INPUT && [moxi_event_text_value isEqual:@"Edited A"]);
        assert(moxi_window_poll_event()==MOXI_EVENT_FOCUS && moxi_event_target==50001);
        moxi_reset_event_queue();
        // A's drag stream must not inherit B's pointer state or clear B's queue.
        assert(moxi_window_select_instance(b));
        moxi_mouse_is_down=YES;
        [ad windowDidResignKey:[NSNotification notificationWithName:NSWindowDidResignKeyNotification object:av.window]];
        assert(moxi_mouse_is_down && moxi_event_queue_count==0);
        assert(moxi_window_select_instance(a));
        assert(!moxi_mouse_is_down && moxi_window_poll_event()==MOXI_EVENT_POINTER_CANCEL);
        // Overflow is local, and destruction releases registered resources.
        for (int i=0;i<MOXI_EVENT_QUEUE_CAPACITY+10;i++) moxi_queue_key_event(MOXI_KEY_ENTER);
        assert(moxi_event_dropped_count>0);
        assert(moxi_window_select_instance(b));
        assert(moxi_event_dropped_count==0 && moxi_window_is_open());
        // Reset A must preserve B's not-yet-dispatched AppKit input and order.
        [NSApp discardEventsMatchingMask:NSEventMaskAny beforeEvent:nil];
        NSEvent *aDown=[NSEvent mouseEventWithType:NSEventTypeLeftMouseDown
            location:NSMakePoint(20,20) modifierFlags:0 timestamp:0
            windowNumber:av.window.windowNumber context:nil eventNumber:101 clickCount:1 pressure:1];
        NSEvent *bDown=[NSEvent mouseEventWithType:NSEventTypeLeftMouseDown
            location:NSMakePoint(20,20) modifierFlags:0 timestamp:0
            windowNumber:bv.window.windowNumber context:nil eventNumber:102 clickCount:1 pressure:1];
        NSEvent *bUp=[NSEvent mouseEventWithType:NSEventTypeLeftMouseUp
            location:NSMakePoint(20,20) modifierFlags:0 timestamp:0
            windowNumber:bv.window.windowNumber context:nil eventNumber:103 clickCount:1 pressure:0];
        NSEvent *marker=[NSEvent otherEventWithType:NSEventTypeApplicationDefined
            location:NSZeroPoint modifierFlags:0 timestamp:0 windowNumber:0
            context:nil subtype:0 data1:2468 data2:0];
        [NSApp postEvent:aDown atStart:NO];
        [NSApp postEvent:bDown atStart:NO];
        [NSApp postEvent:marker atStart:NO];
        [NSApp postEvent:bUp atStart:NO];
        // postEvent delivery itself can wait for a run-loop turn. Peek without
        // consuming to establish that the reset sees an already-pending queue.
        assert([NSApp nextEventMatchingMask:NSEventMaskAny
            untilDate:[NSDate dateWithTimeIntervalSinceNow:1]
            inMode:NSDefaultRunLoopMode dequeue:NO]!=nil);
        assert(moxi_window_select_instance(a));
        moxi_window_reset_input();
        int order=0;
        NSEvent *pending;
        while ((pending=[NSApp nextEventMatchingMask:NSEventMaskAny
            untilDate:[NSDate distantPast] inMode:NSDefaultRunLoopMode dequeue:YES])!=nil) {
            if (pending.type==NSEventTypeLeftMouseDown) {
                assert(pending.windowNumber!=av.window.windowNumber);
                if (pending.windowNumber==bv.window.windowNumber && pending.eventNumber==102) {
                    assert(order==0); order=1;
                }
            }
            if (pending.type==NSEventTypeApplicationDefined && pending.data1==2468) {
                assert(order==1); order=2;
            }
            if (pending.type==NSEventTypeLeftMouseUp && pending.windowNumber==bv.window.windowNumber && pending.eventNumber==103) {
                assert(order==2); order=3;
            }
        }
        assert(order==3);
        assert(moxi_window_select_instance(b));
        assert(moxi_window_destroy_instance(a));
        assert(imageA==nil && !moxi_window_select_instance(a));
        assert(moxi_canvas==bv && moxi_window_is_open());
        [av insertText:@"late" replacementRange:NSMakeRange(0,0)];
        [ae setAccessibilityFocused:YES];
        assert(moxi_event_queue_count==0);
        assert([av accessibilityChildren].count==0);
        uint64_t reopened=moxi_window_create_instance();
        assert(reopened && reopened!=a);
        open_instance(reopened,"F02 ownership A reopened");
        assert(moxi_event_queue_count==0 && moxi_registered_images[0]==nil);
        [ae setAccessibilityFocused:YES];
        assert(moxi_event_queue_count==0);
        assert(moxi_window_select_instance(b));
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        assert([[be accessibilityAttributeValue:NSAccessibilityValueAttribute] isEqual:@"Beta"]);
#pragma clang diagnostic pop
        assert(moxi_window_destroy_instance(reopened));
        assert(moxi_window_destroy_instance(b));
        uint64_t handles[MoxiWindowCapacity];
        for(int i=0;i<MoxiWindowCapacity;i++) assert((handles[i]=moxi_window_create_instance())!=0);
        assert(moxi_window_create_instance()==0);
        for(int i=0;i<MoxiWindowCapacity;i++) assert(moxi_window_destroy_instance(handles[i]));
        assert(!moxi_window_destroy_instance(a));
        puts("F02 native ownership: draw/image/event/AX isolation, stale callbacks, close/reopen, capacity PASS");
    }
    return 0;
}
