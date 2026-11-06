"""Real native public consumer; spatial module owns math, picking and gestures."""
from std.ffi import external_call
from std.sys import argv
from std.time import sleep, perf_counter_ns
from std.collections import List
from moxi.native_instance import MacOSWindowInstance
from moxi.window import WindowConfig
from moxi.event import (Event, NONE_KIND, POINTER_DOWN_KIND, POINTER_UP_KIND,
    DRAG_UPDATE_KIND, DROP_KIND, POINTER_CANCEL_KIND, WINDOW_RESIZED_KIND, KEY_DOWN_KIND,
    TEXT_INPUT_KIND, SCROLL_KIND, KEY_TAB, KEY_ENTER, KEY_ESCAPE, KEY_LEFT,
    KEY_RIGHT, KEY_UP, KEY_DOWN, MOD_SHIFT, MOD_COMMAND, FOCUS_KIND)
from moxi_spatial import (SpatialViewport, SpatialTool, SpatialCommand,
    SpatialState, SpatialProjection, SpatialMetric, SpatialPoint, SpatialComponent,
    SpatialAnchorPolicy, SpatialAnchorState, SpatialTiming)


struct Control(ImplicitlyCopyable):
    var value: Int32
    comptime ORBIT = Self(0)
    comptime PAN = Self(1)
    comptime PROJECTION = Self(2)
    comptime FIT = Self(3)
    comptime PARAMETER = Self(4)
    comptime AXIS_X = Self(5)
    comptime AXIS_Y = Self(6)
    comptime AXIS_Z = Self(7)
    comptime PLANE_XY = Self(8)
    comptime PLANE_XZ = Self(9)
    comptime PLANE_YZ = Self(10)
    comptime ROTATE = Self(11)
    comptime SCALE = Self(12)
    comptime SNAP = Self(13)
    comptime CORAL = Self(14)
    comptime BLUE = Self(15)
    comptime LIME = Self(16)
    comptime UNDO = Self(17)
    comptime REDO = Self(18)
    comptime DISPOSE = Self(19)
    comptime SLOW = Self(20)
    comptime SELECT = Self(21)
    comptime APPLY = Self(22)
    comptime NUMERIC = Self(23)
    comptime VIEWPORT = Self(-1)

    def __init__(out self, value: Int32):
        self.value = value


def label(slot: Int32, text: String, x: Float32, y: Float32, w: Float32, h: Float32, size: Float32 = 13):
    var value = text
    external_call["sx_label", NoneType](slot, value.as_c_string_span().ptr(), x, y, w, h, size, Float32(0.78), Float32(0.85), Float32(0.93))


def readout(value: Float64) -> String:
    return String(Float64(Int(value * 1000)) / 1000)


struct Explorer:
    var spatial: SpatialViewport
    var tool: SpatialTool
    var snap: Bool
    var focus: Control
    var armed: Control
    var numeric: String
    var message: String
    var dirty: Bool
    var controls_dirty: Bool
    var inspector_revision: UInt64
    var inspector_preview: UInt64
    var inspector_selection: UInt64
    var last_state: SpatialState

    def __init__(out self, owner: UInt64, scale: Float64) raises:
        self.spatial = SpatialViewport()
        self.tool = SpatialTool.SELECT
        self.snap = False
        self.focus = Control.VIEWPORT
        self.armed = Control.VIEWPORT
        self.numeric = "0.5"
        self.message = "Select a surface or outline row. O: orbit · P: pan · F: fit."
        self.dirty = True
        self.controls_dirty = True
        self.inspector_revision = 0
        self.inspector_preview = 0
        self.inspector_selection = 0
        self.last_state = SpatialState.READY
        _ = self.spatial.viewport(244,124,620,480,scale)
        _ = self.spatial.mount(owner)
        external_call["sx_init", NoneType]()

    def action(mut self, control: Control):
        _ = self.spatial.command(SpatialCommand.CANCEL)
        var i = control.value
        if i == Control.ORBIT.value:
            self.tool = SpatialTool.ORBIT
        elif i == Control.PAN.value:
            self.tool = SpatialTool.PAN
        elif i == Control.SELECT.value:
            self.tool = SpatialTool.SELECT
        elif i == Control.PROJECTION.value:
            var camera = self.spatial.camera()
            camera.projection = SpatialProjection.ORTHOGRAPHIC if camera.projection == SpatialProjection.PERSPECTIVE else SpatialProjection.PERSPECTIVE
            _ = self.spatial.set_camera(camera)
        elif i == Control.FIT.value:
            _ = self.spatial.command(SpatialCommand.FIT)
        elif i == Control.PARAMETER.value or i == Control.SLOW.value:
            var value = self.spatial.requested_parameter() + 0.12
            if value > 0.65:
                value = 0.06
            var accepted = self.spatial.parameter(value, Int32(700 if i == Control.SLOW.value else 0))
            self.message = "Computing immutable geometry; camera and selection remain available." if accepted else "Parameter request rejected: viewport is unavailable."
        elif i >= Control.AXIS_X.value and i <= Control.SCALE.value:
            self.tool = SpatialTool(i - Control.AXIS_X.value + SpatialTool.AXIS_X.value)
        elif i == Control.SNAP.value:
            self.snap = not self.snap
        elif i >= Control.CORAL.value and i <= Control.LIME.value:
            _ = self.spatial.select(UInt64((i - Control.CORAL.value + 1) * 101))
        elif i == Control.UNDO.value or i == Control.REDO.value:
            _ = self.spatial.command(SpatialCommand.UNDO if i == Control.UNDO.value else SpatialCommand.REDO)
            self.message = "Shared document history: parameter and transform operations."
        elif i == Control.DISPOSE.value:
            var state = self.spatial.state()
            _ = self.spatial.command(SpatialCommand.DISPOSE if state == SpatialState.READY or state == SpatialState.COMPUTING else SpatialCommand.RECREATE)
            self.message = "Resource generation changed; old work and capture are retired."
        elif i == Control.APPLY.value:
            var value = external_call["sx_parse", Float64](self.numeric.as_c_string_span().ptr())
            var applied = self.spatial.operation(self.tool, value, 0, self.snap)
            self.message = "Numeric operation committed through the shared validation path." if applied else "No commit: invalid value, no change, or choose a constraint first."
        self.dirty = True
        self.controls_dirty = True

    def dispatch(mut self, event: Event):
        var x = Float64(event.position.x)
        var y = Float64(event.position.y)
        if event.kind == POINTER_CANCEL_KIND or event.kind == WINDOW_RESIZED_KIND or (event.kind == FOCUS_KIND and not event.focused):
            _ = self.spatial.command(SpatialCommand.CANCEL)
            self.armed = Control.VIEWPORT
            self.message = "Capture cancelled; committed document restored."
            self.dirty = True
        elif event.kind == POINTER_DOWN_KIND:
            var hit = external_call["sx_hit", Int32](Float32(x), Float32(y))
            self.armed = Control(hit)
            _ = self.spatial.command(SpatialCommand.CANCEL)
            if hit >= 0:
                self.focus = Control(hit)
            elif x >= 884 and x <= 1074 and y >= 436 and y <= 472:
                self.focus = Control.NUMERIC
            else:
                self.focus = Control.VIEWPORT
                var chosen = SpatialTool.PAN if event.modifiers & MOD_SHIFT != 0 and self.tool == SpatialTool.ORBIT else self.tool
                _ = self.spatial.pointer_down(chosen,x,y)
            self.dirty = True
            self.controls_dirty = True
        elif event.kind == DRAG_UPDATE_KIND and self.focus.value == Control.VIEWPORT.value:
            self.dirty = self.spatial.pointer_move(x,y,self.snap) or self.dirty
        elif event.kind == POINTER_UP_KIND or event.kind == DROP_KIND:
            if self.armed.value >= 0:
                if self.armed.value == external_call["sx_hit", Int32](Float32(x),Float32(y)):
                    var armed = self.armed
                    self.action(armed)
            else:
                _ = self.spatial.pointer_up()
            self.armed = Control.VIEWPORT
            self.dirty = True
        elif event.kind == SCROLL_KIND and x >= 244 and x <= 864 and y >= 124 and y <= 604:
            _ = self.spatial.navigate(dolly=Float64(event.scroll_delta.y)*0.04)
            self.dirty = True
        elif event.kind == TEXT_INPUT_KIND and self.focus.value == Control.NUMERIC.value:
            # Native single-line field sends its complete replacement value.
            self.numeric = event.text
            self.dirty = True
        elif event.kind == KEY_DOWN_KIND:
            var key = event.key
            if key == KEY_ESCAPE:
                _ = self.spatial.command(SpatialCommand.CANCEL)
                self.focus = Control.VIEWPORT
                self.message = "Cancelled preview. No history entry."
            elif key == KEY_TAB:
                _ = self.spatial.command(SpatialCommand.CANCEL)
                self.focus = Control((self.focus.value + Int32(23 if event.modifiers & MOD_SHIFT != 0 else 1) + 24) % 24)
            elif key == KEY_ENTER and self.focus.value >= 0:
                var control = Control.APPLY if self.focus.value == Control.NUMERIC.value else self.focus
                self.action(control)
            elif key == 122 and event.modifiers & MOD_COMMAND != 0:
                self.action(Control.REDO if event.modifiers & MOD_SHIFT != 0 else Control.UNDO)
            elif self.focus.value != Control.NUMERIC.value:
                if key == 118:
                    self.focus = Control.VIEWPORT
                elif key == 110:
                    _ = self.spatial.command(SpatialCommand.NEXT)
                elif key == 111:
                    self.action(Control.ORBIT)
                elif key == 112:
                    self.action(Control.PAN)
                elif key == 115:
                    self.action(Control.SELECT)
                elif key == 102:
                    self.action(Control.FIT)
                elif self.focus.value == Control.VIEWPORT.value:
                    var direction = -1.0 if key == KEY_LEFT or key == KEY_DOWN else 1.0
                    if key == KEY_LEFT or key == KEY_RIGHT or key == KEY_UP or key == KEY_DOWN:
                        if self.tool == SpatialTool.ORBIT or self.tool == SpatialTool.SELECT:
                            _ = self.spatial.navigate(direction*0.12 if key == KEY_LEFT or key == KEY_RIGHT else 0, direction*0.12 if key == KEY_UP or key == KEY_DOWN else 0)
                        elif self.tool == SpatialTool.PAN:
                            _ = self.spatial.navigate(pan_x=direction*0.15 if key == KEY_LEFT or key == KEY_RIGHT else 0,pan_y=direction*0.15 if key == KEY_UP or key == KEY_DOWN else 0)
                        else:
                            var amount = direction*0.25
                            if self.tool == SpatialTool.ROTATE_Z:
                                amount = direction*0.2617993877991494
                            elif self.tool == SpatialTool.SCALE:
                                amount = 1.1 if direction > 0 else 1/1.1
                            var plane = self.tool == SpatialTool.PLANE_XY or self.tool == SpatialTool.PLANE_XZ or self.tool == SpatialTool.PLANE_YZ
                            var applied = self.spatial.operation(self.tool,0 if plane and (key == KEY_UP or key == KEY_DOWN) else amount,amount if plane and (key == KEY_UP or key == KEY_DOWN) else 0,self.snap)
                            self.message = "Keyboard operation committed through the same validation and history." if applied else "No keyboard commit: invalid, no selection, or unchanged after snapping."
                    elif key == 43 or key == 61 or key == 45:
                        _ = self.spatial.navigate(dolly=0.25 if key == 45 else -0.25)
            self.dirty = True
            self.controls_dirty = True

    def draw(mut self):
        self.dirty = self.spatial.poll() or self.dirty
        self.dirty = self.dirty or self.spatial.state() != self.last_state
        if not self.dirty:
            return
        var ok = self.spatial.render()
        var state = self.spatial.state()
        if self.last_state == SpatialState.COMPUTING and state == SpatialState.READY:
            self.message = "Latest geometry accepted. Requested and displayed parameters agree."
        self.controls_dirty = self.controls_dirty or state != self.last_state
        self.last_state = state
        if self.controls_dirty:
            external_call["sx_controls", NoneType](self.tool.value,Int32(self.snap),self.spatial.camera().projection.value,self.focus.value,state.value)
            external_call["sx_numeric", NoneType](self.numeric.as_c_string_span().ptr(),Int32(self.focus.value == Control.NUMERIC.value))
            self.controls_dirty = False
        var doc = self.spatial.metric(SpatialMetric.DOCUMENT)
        var preview = self.spatial.metric(SpatialMetric.PREVIEW)
        var selected = self.spatial.metric(SpatialMetric.SELECTED)
        if doc != self.inspector_revision or preview != self.inspector_preview or selected != self.inspector_selection:
            if selected == 0:
                label(10,"No selection",884,322,190,85,11)
            else:
                label(10,String("ID ",selected,"\nX ",readout(self.spatial.transform(selected,SpatialComponent.X)),"\nY ",readout(self.spatial.transform(selected,SpatialComponent.Y)),"\nZ ",readout(self.spatial.transform(selected,SpatialComponent.Z)),"\nAngle ",readout(self.spatial.transform(selected,SpatialComponent.ANGLE)),"\nScale ",readout(self.spatial.transform(selected,SpatialComponent.SCALE))),884,322,190,85,11)
            label(11,String("Δ units / radians / scale factor"),884,411,190,23,11)
            self.inspector_revision = doc
            self.inspector_preview = preview
            self.inspector_selection = selected
        if not ok:
            label(16,"Viewport unavailable / disposed\nUse Recreate to retry",330,290,440,100,22)
        else:
            label(16,"",330,290,440,100)
        external_call["sx_overlay_begin", NoneType]()
        if ok:
            var lines = self.spatial.overlays(self.tool)
            for line in lines:
                external_call["sx_line", NoneType](Float32(line.x1),Float32(line.y1),Float32(line.x2),Float32(line.y2),Float32(line.color.x),Float32(line.color.y),Float32(line.color.z),Int32(line.handle))
        external_call["sx_overlay_end", NoneType]()
        var anchor = self.spatial.anchor(SpatialPoint(-1.1,0.95,0.25),SpatialAnchorPolicy.HIDE_OCCLUDED)
        if ok and anchor.state == SpatialAnchorState.VISIBLE:
            label(13,"●  World anchor",Float32(anchor.x),Float32(anchor.y)-23,230,24,12)
        else:
            label(13,"",244,160,230,24)
        label(14,String("Requested ",self.spatial.requested_parameter(),"  •  displayed ",self.spatial.displayed_parameter(),"  •  geometry revision ",self.spatial.metric(SpatialMetric.GEOMETRY),"\n",self.message),244,661,830,48,12)
        label(15,String("Document ",doc,"  /  camera ",self.spatial.metric(SpatialMetric.CAMERA),"  /  generation ",self.spatial.metric(SpatialMetric.GENERATION),"  /  undo ",self.spatial.metric(SpatialMetric.HISTORY),"  /  rejected work ",self.spatial.metric(SpatialMetric.REJECTED)),244,580,610,22,11)
        external_call["sx_finish", NoneType]()
        self.dirty = False


def drain(mut window: MacOSWindowInstance, mut app: Explorer) raises:
    window.pump()
    for _ in range(64):
        var event = window.poll_event()
        if event.kind == NONE_KIND:
            break
        app.dispatch(event)
        # Freeze and publish each dispatched event before routing the next one.
        app.draw()
    app.draw()


def inject(mut window: MacOSWindowInstance, mut app: Explorer, kind: Int, x: Float32 = 0, y: Float32 = 0, key: Int = 0, modifiers: Int = 0) raises:
    window.activate()
    external_call["sx_inject", NoneType](Int32(kind),x,y,Int32(key),Int32(modifiers))
    drain(window,app)


def capture(mut app: Explorer, directory: String, name: String):
    app.draw()
    var path = directory + "/" + name + ".png"
    external_call["sx_capture", NoneType](path.as_c_string_span().ptr())


def settle(mut window: MacOSWindowInstance, mut app: Explorer) raises:
    var start = perf_counter_ns()
    while app.spatial.state() == SpatialState.COMPUTING and perf_counter_ns()-start < 3_000_000_000:
        window.wait(0.01)
        drain(window,app)
    if app.spatial.state() != SpatialState.READY:
        raise Error("Spatial generation did not become ready")


def handle_point(app: Explorer) raises -> SpatialPoint:
    var lines = app.spatial.overlays(app.tool)
    for line in lines:
        if line.handle:
            return SpatialPoint((line.x1+line.x2)/2,(line.y1+line.y2)/2,0)
    raise Error("No projected handle")


def replay(mut window: MacOSWindowInstance, mut app: Explorer, directory: String) raises:
    drain(window,app)
    app.message = "Initial generated mesh. Three stable IDs; public Mojo consumer."
    app.dirty = True
    capture(app,directory,"01-initial")
    app.action(Control.PARAMETER)
    settle(window,app)
    capture(app,directory,"02-parameter")
    var uploads = app.spatial.metric(SpatialMetric.UPLOADS)
    app.action(Control.ORBIT)
    inject(window,app,POINTER_DOWN_KIND,600,350)
    var control_builds = external_call["sx_controls_count", Int32]()
    inject(window,app,DRAG_UPDATE_KIND,660,375)
    if app.spatial.metric(SpatialMetric.UPLOADS) != uploads:
        raise Error("Camera drag uploaded geometry")
    if external_call["sx_controls_count", Int32]() != control_builds:
        raise Error("Camera drag rebuilt unrelated controls")
    capture(app,directory,"03-camera")
    inject(window,app,POINTER_UP_KIND,660,375)
    app.action(Control.SELECT)
    var target = app.spatial.anchor(SpatialPoint(0.55,0.1,-0.45),SpatialAnchorPolicy.ALWAYS_VISIBLE)
    inject(window,app,POINTER_DOWN_KIND,Float32(target.x),Float32(target.y))
    inject(window,app,POINTER_UP_KIND,Float32(target.x),Float32(target.y))
    capture(app,directory,"04-pick-annotation")
    app.action(Control.PROJECTION)
    capture(app,directory,"05-orthographic")
    app.action(Control.SLOW)
    drain(window,app)
    # Let the worker take the slow request, then supersede it with another slow
    # request. Poll while navigating, so the first completion is actually rejected.
    window.wait(0.03)
    drain(window,app)
    app.action(Control.SLOW)
    app.action(Control.ORBIT)
    inject(window,app,KEY_DOWN_KIND,key=118)
    inject(window,app,KEY_DOWN_KIND,key=KEY_RIGHT)
    capture(app,directory,"06-slow-responsive")
    var started = perf_counter_ns()
    while app.spatial.metric(SpatialMetric.REJECTED) == 0 and perf_counter_ns()-started < 2_000_000_000:
        window.wait(0.01)
        drain(window,app)
    if app.spatial.metric(SpatialMetric.REJECTED) == 0:
        raise Error("No actual stale worker rejection observed")
    app.message = "Slow completion rejected. Newer request still pending; camera remains live."
    app.dirty = True
    capture(app,directory,"07-stale-rejected")
    settle(window,app)
    app.action(Control.CORAL)
    app.action(Control.FIT)
    app.action(Control.AXIS_X)
    var p = handle_point(app)
    var history = app.spatial.metric(SpatialMetric.HISTORY)
    inject(window,app,POINTER_DOWN_KIND,Float32(p.x),Float32(p.y))
    inject(window,app,DRAG_UPDATE_KIND,Float32(p.x+50),Float32(p.y))
    capture(app,directory,"08-axis-preview")
    if app.spatial.metric(SpatialMetric.HISTORY) != history:
        raise Error("Preview changed committed history")
    inject(window,app,POINTER_UP_KIND,Float32(p.x+50),Float32(p.y))
    if app.spatial.metric(SpatialMetric.HISTORY) != history+1:
        raise Error("Gesture did not create exactly one commit")
    app.action(Control.PLANE_XY)
    p = handle_point(app)
    inject(window,app,POINTER_DOWN_KIND,Float32(p.x),Float32(p.y))
    inject(window,app,DRAG_UPDATE_KIND,Float32(p.x+25),Float32(p.y-20))
    capture(app,directory,"09-plane-preview")
    inject(window,app,POINTER_UP_KIND,Float32(p.x+25),Float32(p.y-20))
    app.action(Control.ROTATE)
    p = handle_point(app)
    inject(window,app,POINTER_DOWN_KIND,Float32(p.x),Float32(p.y))
    inject(window,app,DRAG_UPDATE_KIND,Float32(p.x-25),Float32(p.y-35))
    capture(app,directory,"10-rotation-preview")
    inject(window,app,POINTER_UP_KIND,Float32(p.x-25),Float32(p.y-35))
    app.action(Control.SCALE)
    p = handle_point(app)
    inject(window,app,POINTER_DOWN_KIND,Float32(p.x),Float32(p.y))
    inject(window,app,DRAG_UPDATE_KIND,Float32(p.x+15),Float32(p.y-15))
    capture(app,directory,"11-scale-preview")
    inject(window,app,POINTER_UP_KIND,Float32(p.x+15),Float32(p.y-15))
    app.action(Control.SNAP)
    app.action(Control.AXIS_Y)
    p = handle_point(app)
    inject(window,app,POINTER_DOWN_KIND,Float32(p.x),Float32(p.y))
    inject(window,app,DRAG_UPDATE_KIND,Float32(p.x),Float32(p.y-37))
    capture(app,directory,"12-snap-preview")
    inject(window,app,KEY_DOWN_KIND,key=KEY_ESCAPE)
    capture(app,directory,"13-cancel")
    inject(window,app,POINTER_DOWN_KIND,900,450)
    var numeric_value: String = "0.75"
    external_call["sx_numeric_input", NoneType](numeric_value.as_c_string_span().ptr())
    drain(window,app)
    inject(window,app,KEY_DOWN_KIND,key=KEY_ENTER)
    inject(window,app,KEY_DOWN_KIND,key=KEY_ESCAPE)
    inject(window,app,KEY_DOWN_KIND,key=KEY_UP)
    capture(app,directory,"14-numeric-keyboard")
    app.action(Control.UNDO)
    capture(app,directory,"15-undo")
    # Actual host event queue routes for cancellation, without human input claims.
    app.action(Control.AXIS_X)
    for cancellation in [POINTER_CANCEL_KIND, FOCUS_KIND, WINDOW_RESIZED_KIND]:
        p = handle_point(app)
        var before_x = app.spatial.transform(101,SpatialComponent.X)
        var before_history = app.spatial.metric(SpatialMetric.HISTORY)
        inject(window,app,POINTER_DOWN_KIND,Float32(p.x),Float32(p.y))
        inject(window,app,DRAG_UPDATE_KIND,Float32(p.x+20),Float32(p.y))
        inject(window,app,cancellation)
        inject(window,app,POINTER_UP_KIND,Float32(p.x+20),Float32(p.y))
        if before_x != app.spatial.transform(101,SpatialComponent.X) or before_history != app.spatial.metric(SpatialMetric.HISTORY):
            raise Error("Host cancellation committed a preview")
    print("PASS host queue: pointer capture loss, focus loss, resize discard previews")
    app.action(Control.DISPOSE)
    capture(app,directory,"16-disposed")
    app.action(Control.DISPOSE)
    settle(window,app)
    capture(app,directory,"17-recreated")
    # Retained mesh, derived geometry and surrounding UI across camera-only frames.
    uploads = app.spatial.metric(SpatialMetric.UPLOADS)
    var builds = app.spatial.metric(SpatialMetric.FRAME_BUILDS)
    control_builds = external_call["sx_controls_count", Int32]()
    for _ in range(60):
        _ = app.spatial.navigate(yaw=0.008)
        app.dirty = True
        app.draw()
        print("TIMING",app.spatial.timing(SpatialTiming.CPU),app.spatial.timing(SpatialTiming.ENCODE),app.spatial.timing(SpatialTiming.WAIT),app.spatial.timing(SpatialTiming.GPU),app.spatial.timing(SpatialTiming.READBACK),app.spatial.timing(SpatialTiming.PUBLICATION),app.spatial.timing(SpatialTiming.TOTAL))
    if uploads != app.spatial.metric(SpatialMetric.UPLOADS) or builds != app.spatial.metric(SpatialMetric.FRAME_BUILDS) or control_builds != external_call["sx_controls_count", Int32]():
        raise Error("Camera-only frame invalidated retained mesh or unrelated controls")
    var submissions = app.spatial.metric(SpatialMetric.SUBMISSIONS)
    window.wait(0.3)
    app.draw()
    if submissions != app.spatial.metric(SpatialMetric.SUBMISSIONS):
        raise Error("Idle submitted a spatial frame")
    print("PASS native public Mojo replay: 17 captures; camera uploads=0 derived mesh rebuilds=0 unrelated controls=0; idle submissions=0 / 0.3 seconds")


def main() raises:
    var window = MacOSWindowInstance()
    var config = WindowConfig("Moxi · D06 geometry explorer",1100,760)
    config.resizable = False
    window.open(config,60,850)
    var scale = external_call["moxi_window_scale_factor", Float32]()
    var app = Explorer(window.handle,Float64(scale))
    var args = argv()
    if len(args) >= 3 and args[1] == "--replay":
        replay(window,app,args[2])
    else:
        while window.is_open():
            drain(window,app)
            window.wait(Float32(0.016 if app.spatial.state() == SpatialState.COMPUTING else 60.0))
    app.spatial.close()
    window.close()
