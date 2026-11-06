// Genuine Moxi/AppKit host. Private in-memory image registration is confined to
// this experiment and selected through F02's explicit instance handle.
#import "../../native/macos_window.m"
#import "spatial.h"
#include <assert.h>
#include <sys/resource.h>

typedef NS_ENUM(int, SPAction) { SPActionCamera, SPActionRenderer, SPActionOverlay, SPActionScroll, SPActionReset, SPActionDispose, SPActionCount };
typedef NS_ENUM(int, SPFocus) { SPFocusCamera, SPFocusRenderer, SPFocusOverlay, SPFocusScroll, SPFocusReset, SPFocusDispose, SPFocusViewport, SPFocusCount };
static const int SPImageResource=7301;
static SPView defaultView(void) { return (SPView){SPCameraPerspective,.38f,.24f,5,0,0}; }
static NSString *backendName(SPBackend backend) { return backend==SPBackendBridge?@"Metal bridge extension":@"SceneKit adapter"; }
static NSArray *pixel(NSBitmapImageRep *bitmap, int x, int y) {
    // Read encoded premultiplied sRGB bytes directly. colorAtX returns a
    // device-color NSColor on this host even when the bitmap is tagged sRGB.
    const unsigned char *p=bitmap.bitmapData+y*bitmap.bytesPerRow+x*4;
    double a=p[3]/255.;
    return @[@(a?p[0]/255./a:0),@(a?p[1]/255./a:0),@(a?p[2]/255./a:0),@(a)];
}
static double cpuTime(void) { struct rusage r; getrusage(RUSAGE_SELF,&r); return r.ru_utime.tv_sec+r.ru_utime.tv_usec/1e6+r.ru_stime.tv_sec+r.ru_stime.tv_usec/1e6; }

@interface SPApp : NSObject
@property uint64_t owner;
@property SPRenderer *renderer;
@property SPFrame *frame;
@property SPView view;
@property SPRevision revision;
@property SPBackend backend;
@property NSRect viewport;
@property CGFloat scroll;
@property SPFocus focus;
@property SPAction armed;
@property BOOL overlayArmed;
@property BOOL overlay, dragging, dirty, disposed;
@property NSPoint pointer;
@property NSString *message;
@property double publishMS;
- (void)open;
- (void)draw;
- (void)action:(SPAction)action;
- (void)events;
- (BOOL)accept:(SPFrame *)frame;
- (void)close;
@end
@implementation SPApp
- (instancetype)init {
    if((self=[super init])) { _view=defaultView(); _revision=(SPRevision){1,1,1,1,1}; _focus=SPFocusViewport; _dirty=YES; _armed=SPActionCount; _message=@"Drag to orbit; Shift-drag to pan; wheel to dolly."; }
    return self;
}
- (void)open {
    _owner=moxi_window_create_instance(); assert(_owner && moxi_window_select_instance(_owner));
    moxi_window_open("Moxi spatial-probe / D05 S0",900,620,620,440,1200,900,1,0);
    moxi_window_set_surface(.045,.065,.095,1);
    _renderer=[[SPRenderer alloc] initWithBackend:_backend]; assert(_renderer);
    assert([_renderer geometryWithObjects:2 repeats:1 reverse:NO]);
    moxi_reset_event_queue();
}
- (BOOL)accept:(SPFrame *)frame {
    if(_disposed || !frame || !SPRevisionEqual(frame.revision,_revision)) return NO;
    _frame=frame; return YES;
}
- (void)draw {
    if(!_dirty) return;
    assert(moxi_window_select_instance(_owner));
    double begin=CACurrentMediaTime();
    CGFloat width=moxi_canvas.bounds.size.width, height=moxi_canvas.bounds.size.height;
    NSRect next=NSMakeRect(242,96,width-266,height-182);
    if(!NSEqualSizes(next.size,_viewport.size)) _revision.viewport++;
    _viewport=next;
    if(!_disposed && (!_frame || !SPRevisionEqual(_frame.revision,_revision))) {
        CGFloat scale=moxi_window_scale_factor();
        SPFrame *frame=[_renderer renderWidth:lrint(next.size.width*scale) height:lrint(next.size.height*scale) view:_view revision:_revision];
        if(![self accept:frame]) { _frame=nil; _message=@"Frame unavailable (capacity or stale revision)."; }
    }
    // Only current owner's resource table is touched. No disk PNG in render path.
    NSImage *image=nil;
    if(_frame) { image=[[NSImage alloc] initWithSize:_viewport.size]; [image addRepresentation:_frame.bitmap]; }
    moxi_registered_image_ids[0]=SPImageResource; moxi_registered_images[0]=image;
    moxi_window_begin_frame();
    moxi_window_set_label_at(0,"SPATIAL PROBE   /   D05 S0",24,20,width-48,32,.94,.96,1,1,23,0);
    NSString *subtitle=[NSString stringWithFormat:@"%@  |  %@  |  %lu triangles",backendName(_backend),_view.kind==SPCameraPerspective?@"Perspective 45°":@"Orthographic",(unsigned long)_renderer.vertexCount/3];
    moxi_window_set_label_at(1,subtitle.UTF8String,24,57,width-48,24,.56,.76,.94,1,15,0);
    NSArray *titles=@[_view.kind==SPCameraPerspective?@"Use orthographic":@"Use perspective",@"Switch renderer",_overlay?@"Hide overlay":@"Show overlay",_scroll?@"Restore scroll":@"Scroll / clip 72px",@"Reset camera",_disposed?@"Recreate resources":@"Dispose resources"];
    for(int i=0;i<SPActionCount;i++) moxi_window_set_button_at(i,[titles[i] UTF8String],24,100+i*49,194,38,.12,.19,.28,1,.94,.97,1,1,6,14,0,_focus==i,0,0,1);
    moxi_window_set_label_at(2,height<550?"Tab / Enter: controls\nArrows: orbit • +/-: zoom\nShift-drag: pan":"Tab: change focus\nEnter: activate\nArrows: orbit\n+ / -: dolly\nEsc: end drag\n\nCamera frames retain mesh.",24,404,200,height-414,.66,.75,.85,1,13,1);
    moxi_window_set_clip(1,next.origin.x,next.origin.y,next.size.width,next.size.height);
    moxi_window_set_image_at(0,SPImageResource,(_disposed?"Resources disposed — recreate":"No current frame"),next.origin.x,next.origin.y-_scroll,next.size.width,next.size.height,.12,.16,.22,1,.9,.9,.95,1,0);
    if(_overlay) {
        // Ordinary host button overlays the scene and wins input routing.
        moxi_window_set_button_at(SPActionCount,"Overlay • reset camera",next.origin.x+16,next.origin.y+16,220,38,.2,.17,.35,1,1,1,1,1,5,14,0,0,0,0,1);
    }
    if(_disposed) moxi_window_set_label_at(4,"Viewport resources released",next.origin.x+20,next.origin.y+90,next.size.width-40,30,.85,.9,1,1,15,0);
    moxi_window_set_clip(0,0,0,0,0);
    if(_focus==SPFocusViewport) {
        moxi_window_begin_custom_paint();
        moxi_window_add_custom_rect(next.origin.x-2,next.origin.y-2,next.size.width+4,next.size.height+4,0,0,0,0,.4,.75,1,1,2);
    }
    NSString *status=[NSString stringWithFormat:@"%@\nframe s%llu c%llu g%llu v%llu / generation %llu · %@",_message,_revision.scene,_revision.camera,_revision.geometry,_revision.viewport,_revision.generation,_disposed?@"DISPOSED":(_frame?@"ready":@"unavailable")];
    moxi_window_set_label_at(3,status.UTF8String,242,height-75,width-265,60,.76,.84,.92,1,12,1);
    moxi_window_end_frame();
    _publishMS=(CACurrentMediaTime()-begin)*1000; _dirty=NO;
}
- (void)action:(SPAction)action {
    switch(action) {
        case SPActionCamera: _view.kind=_view.kind==SPCameraPerspective?SPCameraOrthographic:SPCameraPerspective; _revision.camera++; break;
        case SPActionRenderer: {
#if SP_SCENEKIT
            _backend=_backend==SPBackendBridge?SPBackendSceneKit:SPBackendBridge;
            _renderer=nil; _frame=nil; _revision.generation++; _disposed=NO;
            _renderer=[[SPRenderer alloc] initWithBackend:_backend]; assert(_renderer);
            assert([_renderer geometryWithObjects:2 repeats:1 reverse:NO]);
#else
            _message=@"SceneKit excluded from this bridge-only build.";
#endif
            break;
        }
        case SPActionOverlay: _overlay=!_overlay; break;
        case SPActionScroll: _scroll=_scroll?0:72; break;
        case SPActionReset: _view=defaultView(); _revision.camera++; break;
        case SPActionDispose:
            _revision.generation++; _frame=nil; _renderer=nil; _dragging=NO; _disposed=!_disposed;
            if(!_disposed) { _renderer=[[SPRenderer alloc] initWithBackend:_backend]; assert(_renderer); assert([_renderer geometryWithObjects:2 repeats:1 reverse:NO]); }
            break;
        case SPActionCount: return;
    }
    _dirty=YES;
}
- (void)events {
    assert(moxi_window_select_instance(_owner));
    int event;
    while((event=moxi_window_poll_event())!=MOXI_EVENT_NONE) {
        NSPoint p=NSMakePoint(moxi_window_event_x(),moxi_window_event_y());
        int key=moxi_window_event_key();
        if(event==MOXI_EVENT_WINDOW_RESIZED) { _dirty=YES; _dragging=NO; }
        else if(event==MOXI_EVENT_POINTER_CANCEL) { _armed=SPActionCount; _overlayArmed=NO; _dragging=NO; _message=@"Camera capture cancelled; view retained."; _dirty=YES; }
        else if(event==MOXI_EVENT_POINTER_DOWN) {
            _dragging=NO; _pointer=p; _armed=SPActionCount; _overlayArmed=NO;
            for(int i=0;i<SPActionCount;i++) if(NSPointInRect(p,NSMakeRect(24,100+i*49,194,38))) { _focus=(SPFocus)i; _armed=(SPAction)i; _dirty=YES; }
            if(NSPointInRect(p,_viewport)) {
                _focus=SPFocusViewport; _dirty=YES;
                BOOL overOverlay=_overlay && NSPointInRect(p,NSMakeRect(_viewport.origin.x+16,_viewport.origin.y+16,220,38));
                _overlayArmed=overOverlay; _dragging=!_disposed && !overOverlay;
            }
        } else if(event==MOXI_EVENT_POINTER_UP) {
            _dragging=NO;
            if(_overlayArmed && NSPointInRect(p,NSMakeRect(_viewport.origin.x+16,_viewport.origin.y+16,220,38))) [self action:SPActionReset];
            else if(_armed<SPActionCount && NSPointInRect(p,NSMakeRect(24,100+_armed*49,194,38))) [self action:_armed];
            _armed=SPActionCount; _overlayArmed=NO;
        } else if(event==MOXI_EVENT_DROP) { _dragging=NO; _armed=SPActionCount; _overlayArmed=NO;
        } else if(event==MOXI_EVENT_DRAG_UPDATE && _dragging) {
            float dx=p.x-_pointer.x, dy=p.y-_pointer.y;
            if(moxi_window_event_modifiers() & MOXI_MOD_SHIFT) { _view.panX-=dx*.006; _view.panY+=dy*.006; }
            else { _view.yaw+=dx*.008; _view.pitch=fmaxf(-1.4,fminf(1.4,_view.pitch+dy*.008)); }
            _pointer=p; _revision.camera++; _dirty=YES;
        } else if(event==MOXI_EVENT_SCROLL && NSPointInRect(p,_viewport)) {
            if(moxi_window_event_modifiers() & MOXI_MOD_SHIFT) _scroll=fmax(0,fmin(120,_scroll+moxi_window_event_scroll_y()));
            else if(!_disposed) { _view.distance=fmaxf(2,fminf(40,_view.distance+moxi_window_event_scroll_y()*.04)); _revision.camera++; }
            _dirty=YES;
        } else if(event==MOXI_EVENT_KEY_DOWN) {
            if(key==MOXI_KEY_TAB) { _focus=(SPFocus)((_focus+((moxi_window_event_modifiers()&MOXI_MOD_SHIFT)?SPFocusCount-1:1))%SPFocusCount); _dragging=NO; _dirty=YES; }
            else if(key==MOXI_KEY_ENTER && _focus<SPFocusViewport) [self action:(SPAction)_focus];
            else if(key==MOXI_KEY_ESCAPE) { _dragging=NO; _message=@"Camera capture cancelled; view retained."; _dirty=YES; }
            else if(_focus==SPFocusViewport && !_disposed) {
                BOOL changed=YES;
                if(key==MOXI_KEY_LEFT) _view.yaw-=.12;
                else if(key==MOXI_KEY_RIGHT) _view.yaw+=.12;
                else if(key==MOXI_KEY_UP) _view.pitch=fminf(1.4,_view.pitch+.12);
                else if(key==MOXI_KEY_DOWN) _view.pitch=fmaxf(-1.4,_view.pitch-.12);
                else if(key=='+' || key=='=') _view.distance=fmaxf(2,_view.distance-.25);
                else if(key=='-') _view.distance=fminf(40,_view.distance+.25);
                else changed=NO;
                if(changed) { _revision.camera++; _dirty=YES; }
            }
        }
    }
}
- (void)close { _renderer=nil; _frame=nil; assert(moxi_window_destroy_instance(_owner)); _owner=0; }
@end

static void capture(SPApp *app, NSString *directory, NSString *name) {
    [app draw]; assert(moxi_window_select_instance(app.owner));
    NSView *v=moxi_canvas; [v layoutSubtreeIfNeeded]; [v displayIfNeeded];
    NSBitmapImageRep *b=[v bitmapImageRepForCachingDisplayInRect:v.bounds];
    [v cacheDisplayInRect:v.bounds toBitmapImageRep:b];
    if([name isEqualToString:@"04-clip-overlay"] || [name isEqualToString:@"13-adapter-clip"]) {
        CGFloat scale=b.pixelsWide/v.bounds.size.width;
        NSColor *outside=[b colorAtX:230*scale y:85*scale];
        NSColor *clipped=[b colorAtX:(app.viewport.origin.x+80)*scale y:(NSMaxY(app.viewport)-10)*scale];
        assert(fabs(outside.redComponent-clipped.redComponent)<.001);
        assert(fabs(outside.greenComponent-clipped.greenComponent)<.001);
        assert(fabs(outside.blueComponent-clipped.blueComponent)<.001);
        NSColor *overlay=[b colorAtX:(app.viewport.origin.x+25)*scale y:(app.viewport.origin.y+30)*scale];
        NSColor *scene=[b colorAtX:(app.viewport.origin.x+250)*scale y:(app.viewport.origin.y+30)*scale];
        assert(fabs(overlay.redComponent-scene.redComponent)>.03);
    }
    assert([[b representationUsingType:NSBitmapImageFileTypePNG properties:@{}]
        writeToFile:[directory stringByAppendingPathComponent:[name stringByAppendingString:@".png"]] atomically:YES]);
}
static void mouse(SPApp *app, NSEventType type, NSPoint point, NSEventModifierFlags flags) {
    assert(moxi_window_select_instance(app.owner));
    NSEvent *e=[NSEvent mouseEventWithType:type location:[moxi_canvas convertPoint:point toView:nil] modifierFlags:flags timestamp:CACurrentMediaTime() windowNumber:moxi_window.windowNumber context:nil eventNumber:1 clickCount:1 pressure:1];
    if(type==NSEventTypeLeftMouseDown) [moxi_canvas mouseDown:e];
    if(type==NSEventTypeLeftMouseDragged) [moxi_canvas mouseDragged:e];
    if(type==NSEventTypeLeftMouseUp) [moxi_canvas mouseUp:e];
    [app events];
}
static void click(SPApp *app, SPAction action) {
    NSPoint p=NSMakePoint(70,119+action*49);
    mouse(app,NSEventTypeLeftMouseDown,p,0); mouse(app,NSEventTypeLeftMouseUp,p,0); [app draw];
}
static void key(SPApp *app, unsigned short code, NSString *characters) {
    assert(moxi_window_select_instance(app.owner));
    NSEvent *e=[NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:0 timestamp:CACurrentMediaTime() windowNumber:moxi_window.windowNumber context:nil characters:characters charactersIgnoringModifiers:characters isARepeat:NO keyCode:code];
    [moxi_canvas keyDown:e]; [app events]; [app draw];
}
static NSDictionary *stats(NSArray<NSNumber *> *values) {
    NSArray<NSNumber *> *s=[values sortedArrayUsingSelector:@selector(compare:)];
    return @{@"p50":s[(s.count-1)/2],@"p95":s[(NSUInteger)ceil(s.count*.95)-1],@"p99":s[(NSUInteger)ceil(s.count*.99)-1],@"max":s.lastObject};
}
static NSDictionary *bench(SPBackend backend, NSUInteger objects, NSUInteger repeats, NSUInteger size, BOOL updates) {
    SPRenderer *renderer=[[SPRenderer alloc] initWithBackend:backend]; assert(renderer);
    double uploadStart=CACurrentMediaTime(); assert([renderer geometryWithObjects:objects repeats:repeats reverse:NO]);
    double uploadMS=(CACurrentMediaTime()-uploadStart)*1000;
    SPView view=defaultView(); SPRevision rev={1,1,1,1,1};
    NSMutableArray *encode=[NSMutableArray new], *wait=[NSMutableArray new], *gpu=[NSMutableArray new], *read=[NSMutableArray new], *total=[NSMutableArray new], *transfer=[NSMutableArray new], *alpha=[NSMutableArray new], *updatesWall=[NSMutableArray new];
    SPFrame *cold=[renderer renderWidth:size height:size view:view revision:rev]; assert(cold);
    double cpu=cpuTime();
    for(int i=0;i<60;i++) @autoreleasepool {
        view.yaw+=.006; rev.camera++;
        if(updates) { double t=CACurrentMediaTime(); assert([renderer geometryWithObjects:objects repeats:repeats reverse:i%2]); rev.geometry++; [updatesWall addObject:@((CACurrentMediaTime()-t)*1000)]; }
        SPFrame *frame=[renderer renderWidth:size height:size view:view revision:rev]; assert(frame);
        SPTiming t=frame.timing;
        [encode addObject:@(t.encode_ms)]; [wait addObject:@(t.wait_ms)];
        if(isfinite(t.gpu_ms)) [gpu addObject:@(t.gpu_ms)];
        [transfer addObject:@(t.transfer_ms)]; [alpha addObject:@(t.alpha_ms)];
        [read addObject:@(t.readback_ms)]; [total addObject:@(t.frame_ms)];
    }
    cpu=cpuTime()-cpu;
    return @{@"backend":backendName(backend),@"objects":@(objects),@"triangles":@(renderer.vertexCount/3),@"materials":@1,@"pixels":@(size),@"geometry_each_frame":@(updates),@"geometry_update_wall_ms":updates?stats(updatesWall):NSNull.null,@"initial_upload_wall_ms":@(uploadMS),@"cold_frame_wall_ms":@(cold.timing.frame_ms),@"sample_count":@60,@"encode_wall_ms":stats(encode),@"wait_wall_ms":stats(wait),@"gpu_ms":gpu.count?stats(gpu):NSNull.null,@"gpu_samples":@(gpu.count),@"get_bytes_wall_ms":stats(transfer),@"alpha_conversion_wall_ms":stats(alpha),@"readback_and_alpha_conversion_wall_ms":stats(read),@"frame_to_cpu_image_wall_ms":stats(total),@"process_cpu_ms_per_frame":@(cpu*1000/60),@"uploads":@(renderer.uploads),@"readback_bytes_per_frame":@(size*size*4)};
}
static void rendererTests(SPBackend backend, NSMutableArray *checks) {
    SPRenderer *r=[[SPRenderer alloc] initWithBackend:backend]; assert(r);
    assert(![r geometryWithObjects:0 repeats:1 reverse:NO]);
    assert(![r geometryWithObjects:SPMaxObjects+1 repeats:1 reverse:NO]);
    assert([r geometryWithObjects:2 repeats:1 reverse:NO]);
    for(int camera=SPCameraPerspective;camera<=SPCameraOrthographic;camera++) {
        SPView v=defaultView(); v.kind=(SPCamera)camera; v.yaw=0; v.pitch=0;
        SPRevision rev={1,2,3,4,5};
        SPFrame *a=[r renderWidth:256 height:256 view:v revision:rev]; assert(a);
        assert([r geometryWithObjects:2 repeats:1 reverse:YES]);
        SPFrame *b=[r renderWidth:256 height:256 view:v revision:rev]; assert(b);
        assert(!memcmp(a.bitmap.bitmapData,b.bitmap.bitmapData,256*256*4));
        NSArray *center=pixel(a.bitmap,128,128), *background=pixel(a.bitmap,0,0);
        // Independent expected sRGB transfer values, tolerance for 8-bit alpha.
        const double expectedCenter[4]={1,.410,.206,1};
        const double expectedBackground[4]={.485,.584,.665,.5};
        for(int channel=0;channel<4;channel++) {
            assert(fabs([center[channel] doubleValue]-expectedCenter[channel])<.013);
            assert(fabs([background[channel] doubleValue]-expectedBackground[channel])<.013);
        }
        assert([center[0] doubleValue]>.9 && [center[2] doubleValue]<.4); // Front red occludes later blue.
        assert(fabs([background[3] doubleValue]-.5)<.01);
        [checks addObject:@{@"backend":backendName(backend),@"camera":@(camera),@"reversed_submission_pixels_equal":@YES,@"center_srgb_straight":center,@"background_srgb_straight":background}];
    }
    SPView bad=defaultView(); SPRevision rev={1,1,1,1,1};
    assert(![r renderWidth:SPMaxPixels+1 height:10 view:bad revision:rev]);
    bad.yaw=NAN; assert(![r renderWidth:64 height:64 view:bad revision:rev]);
    for(int camera=SPCameraPerspective;camera<=SPCameraOrthographic;camera++) {
        matrix_float4x4 p=SPProjection((SPCamera)camera,1,5);
        vector_float4 near=simd_mul(p,(vector_float4){0,0,-.1,1}), far=simd_mul(p,(vector_float4){0,0,-100,1});
        assert(fabsf(near.z/near.w)<1e-5 && fabsf(far.z/far.w-1)<1e-5);
    }
}
#if SP_SCENEKIT
static NSArray *comparisonTests(void) {
    SPRenderer *a=[[SPRenderer alloc] initWithBackend:SPBackendBridge];
    SPRenderer *b=[[SPRenderer alloc] initWithBackend:SPBackendSceneKit];
    assert([a geometryWithObjects:2 repeats:1 reverse:NO]); assert([b geometryWithObjects:2 repeats:1 reverse:NO]);
    NSMutableArray *results=[NSMutableArray new];
    for(int camera=SPCameraPerspective;camera<=SPCameraOrthographic;camera++) {
        SPView v=defaultView(); v.kind=(SPCamera)camera; SPRevision rev={1,1,1,1,1};
        SPFrame *x=[a renderWidth:384 height:256 view:v revision:rev];
        SPFrame *y=[b renderWidth:384 height:256 view:v revision:rev]; assert(x && y);
        NSUInteger different=0;
        for(int p=0;p<384*256;p++) {
            BOOL mismatch=NO;
            for(int c=0;c<4;c++) if(abs(x.bitmap.bitmapData[p*4+c]-y.bitmap.bitmapData[p*4+c])>2) mismatch=YES;
            different+=mismatch;
        }
        double fraction=(double)different/(384*256);
        assert(fraction<.01); // Independent rasterizers: allow edge differences only.
        [results addObject:@{@"camera":@(camera),@"size":@[@384,@256],@"fraction_pixels_differing_over_2_bytes":@(fraction)}];
    }
    return results;
}
#endif
static void replay(NSString *directory) {
    [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];
    NSMutableArray *checks=[NSMutableArray new], *measurements=[NSMutableArray new];
    rendererTests(SPBackendBridge,checks);
#if SP_SCENEKIT
    rendererTests(SPBackendSceneKit,checks);
    NSArray *agreement=comparisonTests();
#endif
    SPApp *app=[SPApp new]; [app open]; [app draw];
    capture(app,directory,@"01-perspective");
    NSUInteger uploads=app.renderer.uploads;
    mouse(app,NSEventTypeLeftMouseDown,NSMakePoint(430,260),0);
    mouse(app,NSEventTypeLeftMouseDragged,NSMakePoint(475,285),0);
    assert(app.dragging); capture(app,directory,@"02-orbit-active");
    mouse(app,NSEventTypeLeftMouseUp,NSMakePoint(475,285),0);
    assert(app.renderer.uploads==uploads);
    mouse(app,NSEventTypeLeftMouseDown,NSMakePoint(480,300),NSEventModifierFlagShift);
    mouse(app,NSEventTypeLeftMouseDragged,NSMakePoint(505,315),NSEventModifierFlagShift);
    mouse(app,NSEventTypeLeftMouseUp,NSMakePoint(505,315),NSEventModifierFlagShift);
    assert(app.view.panX<0 && app.view.panY>0);
    float distance=app.view.distance;
    moxi_enqueue_event(MOXI_EVENT_SCROLL,0,0,-1,nil,-1,-1,500,300,0,-5);
    [app events]; assert(app.view.distance<distance);
    capture(app,directory,@"02b-pan-dolly");
    click(app,SPActionCamera); assert(app.view.kind==SPCameraOrthographic);
    capture(app,directory,@"03-orthographic");
    click(app,SPActionOverlay); click(app,SPActionScroll);
    assert(app.overlay && app.scroll==72);
    capture(app,directory,@"04-clip-overlay");
    // Overlay click resets instead of dragging the viewport.
    mouse(app,NSEventTypeLeftMouseDown,NSMakePoint(300,130),0); assert(!app.dragging);
    mouse(app,NSEventTypeLeftMouseUp,NSMakePoint(300,130),0); assert(app.view.kind==SPCameraPerspective);
    app.focus=SPFocusViewport; key(app,48,@"\t"); assert(app.focus==SPFocusCamera);
    uint64_t cameraRev=app.revision.camera; key(app,124,@"\uF703"); assert(app.revision.camera==cameraRev);
    capture(app,directory,@"05-control-focus");
    [moxi_window setContentSize:NSMakeSize(680,480)]; [app events]; app.dirty=YES; [app draw];
    assert(app.frame.bitmap.pixelsWide==lrint(app.viewport.size.width*moxi_window_scale_factor()));
    capture(app,directory,@"06-resize");
    SPFrame *stale=app.frame;
    __weak SPRenderer *old=app.renderer;
    click(app,SPActionDispose); assert(app.disposed && !app.frame && !app.renderer && old==nil);
    assert(![app accept:stale]);
    capture(app,directory,@"07-disposed");
    click(app,SPActionDispose); assert(!app.disposed && app.frame && ![app accept:stale]);
    capture(app,directory,@"08-recreated");
    // F02 isolation: callback/draw of A while B is selected; same resource id.
    MoxiWindowDelegate *firstDelegate=moxi_delegate; NSWindow *firstWindow=moxi_window;
    SPApp *other=[SPApp new]; [other open]; [other draw];
    NSImage *otherImage=moxi_registered_images[0];
    mouse(app,NSEventTypeLeftMouseDown,NSMakePoint(500,230),0);
    assert(moxi_window_select_instance(other.owner));
    [firstDelegate windowDidResignKey:[NSNotification notificationWithName:NSWindowDidResignKeyNotification object:firstWindow]];
    [app events]; assert(!app.dragging);
    key(app,53,@"\x1b"); assert(!app.dragging);
    assert(moxi_window_select_instance(other.owner)); assert(moxi_registered_images[0]==otherImage);
    [other close]; assert(moxi_window_select_instance(app.owner));
    app.focus=SPFocusViewport; key(app,124,@"\uF703");
    capture(app,directory,@"09-focus-recovery");
    [moxi_window setContentSize:NSMakeSize(900,620)]; [app events]; app.dirty=YES; [app draw];
    click(app,SPActionReset); if(app.scroll) click(app,SPActionScroll); if(app.overlay) click(app,SPActionOverlay);
    capture(app,directory,@"10-bridge-comparison");
#if SP_SCENEKIT
    click(app,SPActionRenderer); assert(app.backend==SPBackendSceneKit);
    capture(app,directory,@"11-adapter-perspective");
    click(app,SPActionCamera); capture(app,directory,@"12-adapter-orthographic");
    click(app,SPActionOverlay); click(app,SPActionScroll); capture(app,directory,@"13-adapter-clip");
    click(app,SPActionDispose); click(app,SPActionDispose); capture(app,directory,@"14-adapter-recreated");
#endif
    NSMutableArray *idle=[NSMutableArray new];
    for(int i=0;i<
#if SP_SCENEKIT
        2
#else
        1
#endif
        ;i++) {
        NSUInteger submissions=app.renderer.submissions;
        double idleCPU=cpuTime(), idleStart=CACurrentMediaTime();
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.3]];
        double idleWall=CACurrentMediaTime()-idleStart; idleCPU=cpuTime()-idleCPU;
        assert(app.renderer.submissions==submissions);
        [idle addObject:@{@"backend":backendName(app.backend),@"seconds":@(idleWall),@"process_cpu_ms":@(idleCPU*1000),@"adapter_submissions":@0}];
#if SP_SCENEKIT
        if(i==0) { [app action:SPActionRenderer]; [app draw]; }
#endif
    }
    double publish=app.publishMS;
    NSString *device=app.renderer.deviceName;
    [app close];
    for(int backend=SPBackendBridge;backend<=
#if SP_SCENEKIT
        SPBackendSceneKit
#else
        SPBackendBridge
#endif
        ;backend++) {
        [measurements addObject:bench((SPBackend)backend,2,1,256,NO)];
        [measurements addObject:bench((SPBackend)backend,2,1,768,NO)];
        [measurements addObject:bench((SPBackend)backend,64,1,256,NO)];
        [measurements addObject:bench((SPBackend)backend,2,128,256,NO)];
        [measurements addObject:bench((SPBackend)backend,2,1,256,YES)];
    }
    NSDictionary *report=@{
#if SP_SCENEKIT
        @"candidate_pixel_agreement":agreement,
#endif
@"device":device,@"checks":checks,@"benchmarks":measurements,@"idle":idle,@"last_host_publish_wall_ms_including_render":@(publish),@"physical_display_latency_ms":NSNull.null,@"compositor_verified":@NO,@"voiceover_tested":@NO};
    NSData *json=[NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted error:nil]; assert(json);
    assert([json writeToFile:[directory stringByAppendingPathComponent:@"measurements.json"] atomically:YES]);
    puts("PASS spatial: depth/order, cameras, invalid bounds, clip/overlay, focus, resize, generation rejection, release/recreate, F02 isolation, zero idle submissions");
}
int main(int argc, const char **argv) {
    @autoreleasepool {
        if(argc==3 && !strcmp(argv[1],"--replay")) { replay([NSString stringWithUTF8String:argv[2]]); return 0; }
        if(argc!=1) { fprintf(stderr,"Usage: spatial-probe [--replay capture-directory]\n"); return 2; }
        SPApp *app=[SPApp new]; [app open];
        while(moxi_window_is_open()) @autoreleasepool { [app events]; [app draw]; moxi_window_wait(-1); }
        [app close];
    }
    return 0;
}
