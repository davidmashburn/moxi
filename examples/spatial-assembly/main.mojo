"""Second public consumer. App glue: layout, tool choice, event dispatch and scheduling."""
from std.ffi import external_call
from std.sys import argv
from std.time import perf_counter_ns, sleep
from std.collections import List
from moxi.native_instance import MacOSWindowInstance
from moxi.window import WindowConfig
from moxi.event import (Event, NONE_KIND, POINTER_DOWN_KIND, POINTER_UP_KIND, DRAG_UPDATE_KIND, DROP_KIND, POINTER_CANCEL_KIND, WINDOW_RESIZED_KIND, KEY_DOWN_KIND, TEXT_INPUT_KIND, SCROLL_KIND, KEY_ENTER, KEY_ESCAPE, KEY_LEFT, KEY_RIGHT, MOD_SHIFT, MOD_COMMAND, FOCUS_KIND)
from moxi_spatial import (SpatialViewport, SpatialNode, SpatialObject, SpatialPoint, SpatialTool, SpatialCommand, SpatialMetric, SpatialComponent, SpatialProjection, SpatialState, SpatialClip, SpatialAnchorPolicy, SpatialTiming)

struct View(ImplicitlyCopyable):
    var value: Int32
    comptime LEFT = Self(0)
    comptime RIGHT = Self(1)
    def __init__(out self, value: Int32):
        self.value = value

struct Control(ImplicitlyCopyable):
    var value: Int32
    comptime CARRIER = Self(0)
    comptime ARM = Self(1)
    comptime JOINT = Self(2)
    comptime BALANCE = Self(3)
    comptime SELECT = Self(4)
    comptime ORBIT = Self(5)
    comptime PAN = Self(6)
    comptime AXIS = Self(7)
    comptime ROTATE = Self(8)
    comptime SCALE = Self(9)
    comptime APPLY = Self(10)
    comptime PROBE = Self(11)
    comptime CLEAR = Self(12)
    comptime CLIP = Self(13)
    comptime PLANE = Self(14)
    comptime UNDO = Self(15)
    comptime REDO = Self(16)
    comptime FIT = Self(17)
    comptime DISPOSE = Self(18)
    comptime SLOW = Self(19)
    comptime NONE = Self(-1)
    def __init__(out self, value: Int32):
        self.value = value


def label(slot: Int32, text: String, x: Float32, y: Float32, w: Float32, h: Float32, size: Float32 = 13):
    var value = text
    external_call["sa_label", NoneType](slot,value.as_c_string_span().ptr(),x,y,w,h,size)


def number(value: Float64) -> String:
    if value != value:
        return "—"
    return String(Float64(Int(value*1000))/1000)


def draw_view(view: SpatialViewport, slot: Int32, x: Float32, tool: SpatialTool):
    external_call["sa_unclip", NoneType]()
    var ok = view.render(slot)
    label(20+slot,"" if ok else "View disposed / unavailable\nRecreate to recover",x+45,285,350,90,21)
    external_call["sa_clip", NoneType](x)
    if ok:
        var lines = view.overlays(tool)
        for line in lines:
            external_call["sa_line", NoneType](Float32(line.x1),Float32(line.y1),Float32(line.x2),Float32(line.y2),Float32(line.color.x),Float32(line.color.y),Float32(line.color.z),Int32(line.handle))

    external_call["sa_unclip", NoneType]()


struct Assembly:
    var left: SpatialViewport
    var right: SpatialViewport
    var active: View
    var tool: SpatialTool
    var measuring: Bool
    var numeric_focus: Bool
    var numeric: String
    var armed: Control
    var dirty: Bool
    var controls_dirty: Bool
    var selected: UInt64
    var message: String

    def __init__(out self, owner: UInt64, scale: Float64) raises:
        self.left = SpatialViewport()
        self.right = SpatialViewport(self.left)
        self.active = View.LEFT
        self.tool = SpatialTool.SELECT
        self.measuring = False
        self.numeric_focus = False
        self.numeric = "0.5"
        self.armed = Control.NONE
        self.dirty = True
        self.controls_dirty = True
        self.selected = 0
        self.message = "Select a hierarchy row or a surface. Edits propagate to both views."
        var nodes = List[SpatialNode]()
        nodes.append(SpatialNode(SpatialObject(10,SpatialPoint(-0.6,-0.4,0),0,0.8,SpatialPoint(1,0.35,0.13)),0))
        nodes.append(SpatialNode(SpatialObject(72,SpatialPoint(1.8,1.2,0),0.3,0.65,SpatialPoint(0.16,0.7,1)),10))
        nodes.append(SpatialNode(SpatialObject(405,SpatialPoint(1.8,0.7,0),0,0.6,SpatialPoint(0.45,1,0.6)),72))
        nodes.append(SpatialNode(SpatialObject(93,SpatialPoint(-1.8,0.6,-0.4),-0.3,0.7,SpatialPoint(0.75,0.5,1)),10))
        if not self.left.replace_hierarchy(nodes):
            raise Error("Assembly hierarchy rejected")
        _ = self.left.viewport(252,140,440,390,scale)
        _ = self.right.viewport(728,140,440,390,scale)
        var camera = self.right.camera()
        camera.projection = SpatialProjection.ORTHOGRAPHIC
        camera.yaw = 0
        camera.pitch = 0
        camera.distance = 7.5
        _ = self.right.set_camera(camera)
        camera = self.left.camera()
        camera.distance = 7.5
        _ = self.left.set_camera(camera)
        if not self.left.mount(owner) or not self.right.mount(owner):
            raise Error("Experimental native renderer unavailable")
        external_call["sa_init", NoneType]()

    def cancel(self):
        _ = self.left.command(SpatialCommand.CANCEL)
        _ = self.right.command(SpatialCommand.CANCEL)

    def action(mut self, control: Control):
        self.cancel()
        self.controls_dirty = True
        self.dirty = True
        var i = control.value
        if i >= Control.CARRIER.value and i <= Control.BALANCE.value:
            var ids: List[UInt64] = [10,72,405,93]
            _ = self.left.select(ids[Int(i)])
        elif i == Control.SELECT.value or i == Control.ORBIT.value or i == Control.PAN.value or i == Control.AXIS.value or i == Control.ROTATE.value or i == Control.SCALE.value:
            self.measuring = False
            var tools: List[SpatialTool] = [SpatialTool.SELECT,SpatialTool.ORBIT,SpatialTool.PAN,SpatialTool.AXIS_X,SpatialTool.ROTATE_Z,SpatialTool.SCALE]
            self.tool = tools[Int(i-Control.SELECT.value)]
        elif i == Control.APPLY.value:
            var text = self.numeric
            var value = external_call["sa_parse", Float64](text.as_c_string_span().ptr())
            self.message = "Numeric edit committed through shared operation." if self.left.operation(self.tool,value) else "Numeric operation rejected; select a transform tool and a finite valid value."
        elif i == Control.PROBE.value:
            self.measuring = not self.measuring
            self.tool = SpatialTool.SELECT
            self.message = "Pick two surfaces, in either view. Cyan probe anchors follow object transforms."
        elif i == Control.CLEAR.value:
            self.left.clear_probes()
        elif i == Control.CLIP.value or i == Control.PLANE.value:
            var clip = self.left.clip()
            if i == Control.CLIP.value:
                clip.enabled = not clip.enabled
            else:
                clip.enabled = True
                clip.offset += 0.25
            _ = self.left.set_clip(clip)
        elif i == Control.UNDO.value or i == Control.REDO.value:
            _ = self.left.command(SpatialCommand.UNDO if i == Control.UNDO.value else SpatialCommand.REDO)
        elif i == Control.FIT.value:
            _ = self.left.command(SpatialCommand.FIT)
            _ = self.right.command(SpatialCommand.FIT)
        elif i == Control.DISPOSE.value:
            _ = self.right.command(SpatialCommand.DISPOSE if self.right.state() == SpatialState.READY or self.right.state() == SpatialState.COMPUTING else SpatialCommand.RECREATE)
        elif i == Control.SLOW.value:
            var p = self.left.requested_parameter()+0.12
            _ = self.left.parameter(p if p <= 0.65 else 0.06,700)
            self.message = "One bounded shared worker; cameras remain live while geometry computes."

    def dispatch(mut self, event: Event) raises:
        var x = Float64(event.position.x)
        var y = Float64(event.position.y)
        if event.kind == POINTER_DOWN_KIND:
            self.numeric_focus = x >= 24 and x <= 228 and y >= 482 and y <= 514
            if self.numeric_focus:
                self.cancel()
                self.controls_dirty = True
                self.dirty = True
                return
            self.armed = Control(external_call["sa_hit", Int32](Float32(x),Float32(y)))
            if self.armed.value >= 0:
                self.cancel()
            elif y >= 140 and y <= 530 and ((x >= 252 and x <= 692) or (x >= 728 and x <= 1168)):
                self.active = View.LEFT if x < 700 else View.RIGHT
                if self.active.value == View.LEFT.value:
                    if self.measuring:
                        _ = self.left.probe(x,y)
                    else:
                        _ = self.left.pointer_down(self.tool,x,y)
                else:
                    if self.measuring:
                        _ = self.right.probe(x,y)
                    else:
                        _ = self.right.pointer_down(self.tool,x,y)
            self.controls_dirty = True
            self.dirty = True
        elif event.kind == DRAG_UPDATE_KIND:
            if self.active.value == View.LEFT.value:
                self.dirty = self.left.pointer_move(x,y,(event.modifiers & MOD_SHIFT) != 0) or self.dirty
            else:
                self.dirty = self.right.pointer_move(x,y,(event.modifiers & MOD_SHIFT) != 0) or self.dirty
        elif event.kind == POINTER_UP_KIND or event.kind == DROP_KIND:
            if self.armed.value >= 0:
                if self.armed.value == external_call["sa_hit", Int32](Float32(x),Float32(y)):
                    var c = self.armed
                    self.action(c)
            elif self.active.value == View.LEFT.value:
                _ = self.left.pointer_up()
            else:
                _ = self.right.pointer_up()
            self.armed = Control.NONE
            self.dirty = True
        elif event.kind == POINTER_CANCEL_KIND or event.kind == WINDOW_RESIZED_KIND or (event.kind == FOCUS_KIND and not event.focused):
            self.cancel()
            self.armed = Control.NONE
            self.dirty = True
        elif event.kind == TEXT_INPUT_KIND and self.numeric_focus:
            self.numeric = event.text
            self.dirty = True
        elif event.kind == KEY_DOWN_KIND:
            var key = event.key
            if self.numeric_focus:
                if key == KEY_ENTER:
                    self.action(Control.APPLY)
                elif key == KEY_ESCAPE:
                    self.numeric_focus = False
                    self.controls_dirty = True
                self.dirty = True
                return
            if key == KEY_ESCAPE:
                self.cancel()
            elif key == 122 and (event.modifiers & MOD_COMMAND) != 0:
                self.action(Control.REDO if (event.modifiers & MOD_SHIFT) != 0 else Control.UNDO)
            elif key == 111:
                self.action(Control.ORBIT)
            elif key == 112:
                self.action(Control.PAN)
            elif key == 115:
                self.action(Control.SELECT)
            elif key == 109:
                self.action(Control.PROBE)
            elif key == 120:
                self.action(Control.AXIS)
            elif key == 114:
                self.action(Control.ROTATE)
            elif key == KEY_LEFT or key == KEY_RIGHT:
                _ = self.left.operation(SpatialTool.AXIS_X,-0.25 if key == KEY_LEFT else 0.25)
            self.dirty = True
        elif event.kind == SCROLL_KIND and y >= 140 and y <= 530:
            if x >= 252 and x <= 692:
                _ = self.left.navigate(dolly=Float64(event.scroll_delta.y)*0.04)
            elif x >= 728 and x <= 1168:
                _ = self.right.navigate(dolly=Float64(event.scroll_delta.y)*0.04)
            self.dirty = True

    def draw(mut self):
        self.dirty = self.left.poll() or self.dirty
        if not self.dirty:
            return
        var selected = self.left.metric(SpatialMetric.SELECTED)
        self.controls_dirty = self.controls_dirty or selected != self.selected
        if self.controls_dirty:
            external_call["sa_controls", NoneType](Int32(selected),self.tool.value,Int32(self.measuring),Int32(self.left.clip().enabled),Int32(self.right.state() == SpatialState.DISPOSED or self.right.state() == SpatialState.FAILED))
            var text = self.numeric
            external_call["sa_numeric", NoneType](text.as_c_string_span().ptr(),Int32(self.numeric_focus))
            self.controls_dirty = False
        self.selected = selected
        external_call["sa_paint", NoneType]()
        draw_view(self.left,0,252,self.tool)
        draw_view(self.right,1,728,self.tool)
        label(10,String("Selected ",selected,"  /  parent ",self.left.parent(selected),"  /  local X ",number(self.left.transform(selected,SpatialComponent.X)),"  /  world X ",number(self.left.world_transform(selected,SpatialComponent.X)),"  /  world Y ",number(self.left.world_transform(selected,SpatialComponent.Y))),252,84,920,20,11)
        label(11,String("PROBE  ",number(self.left.measurement())," world units\nTwo local surface anchors / shared across views"),252,597,455,44,14)
        var clip = self.left.clip()
        label(12,String("CLIP  X >= ",number(clip.offset),"  /  ","enabled" if clip.enabled else "disabled","\nPurple outline / clipped triangles also drive picking"),728,597,455,44,14)
        label(13,String("Document ",self.left.metric(SpatialMetric.DOCUMENT),"  /  history ",self.left.metric(SpatialMetric.HISTORY),"  /  selected ID ",selected,"\nOne CPU mesh build count ",self.left.metric(SpatialMetric.BUILDS),"  /  derived ",self.left.metric(SpatialMetric.FRAME_BUILDS),"  /  shared GPU uploads ",self.left.metric(SpatialMetric.UPLOADS)),252,650,455,42,12)
        label(14,self.message,252,691,920,23,12)
        label(15,String("camera ",self.left.metric(SpatialMetric.CAMERA),"  •  doc ",self.left.metric(SpatialMetric.DOCUMENT)),252,532,440,20,11)
        label(16,String("camera ",self.right.metric(SpatialMetric.CAMERA),"  •  doc ",self.right.metric(SpatialMetric.DOCUMENT)),728,532,440,20,11)
        external_call["sa_finish", NoneType]()
        self.dirty = False


def drain(mut window: MacOSWindowInstance, mut app: Assembly) raises:
    window.pump()
    for _ in range(64):
        var event = window.poll_event()
        if event.kind == NONE_KIND:
            break
        app.dispatch(event)
        app.draw()
    app.draw()


def inject(mut window: MacOSWindowInstance, mut app: Assembly, kind: Int, x: Float32 = 0, y: Float32 = 0, key: Int = 0, modifiers: Int = 0) raises:
    window.activate()
    external_call["sa_inject", NoneType](Int32(kind),x,y,Int32(key),Int32(modifiers))
    drain(window,app)


def capture(mut app: Assembly, directory: String, name: String):
    app.dirty = True
    app.draw()
    var path = directory+"/"+name+".png"
    external_call["sa_capture", NoneType](path.as_c_string_span().ptr())


def handle(view: SpatialViewport, tool: SpatialTool) raises -> SpatialPoint:
    var lines = view.overlays(tool)
    for line in lines:
        if line.handle:
            return SpatialPoint((line.x1+line.x2)/2,(line.y1+line.y2)/2,0)
    raise Error("No handle in view")


def object_point(view: SpatialViewport, id: UInt64) -> SpatialPoint:
    var p = SpatialPoint(view.world_transform(id,SpatialComponent.X),view.world_transform(id,SpatialComponent.Y),view.world_transform(id,SpatialComponent.Z))
    var anchor = view.anchor(p,SpatialAnchorPolicy.ALWAYS_VISIBLE)
    return SpatialPoint(anchor.x,anchor.y,0)


def settle(mut window: MacOSWindowInstance, mut app: Assembly) raises:
    var start = perf_counter_ns()
    while app.left.state() == SpatialState.COMPUTING and perf_counter_ns()-start < 3_000_000_000:
        window.wait(0.01)
        drain(window,app)
    if app.left.state() != SpatialState.READY:
        raise Error("Shared worker failed to settle")


def replay(mut window: MacOSWindowInstance, mut app: Assembly, directory: String) raises:
    drain(window,app)
    capture(app,directory,"01-initial")
    if app.left.metric(SpatialMetric.GEOMETRY_ID) != app.right.metric(SpatialMetric.GEOMETRY_ID) or app.left.metric(SpatialMetric.UPLOADS) != 1 or app.left.metric(SpatialMetric.FRAME_BUILDS) != 1:
        raise Error("Views did not reuse one geometry buffer")
    print("REUSE initial",app.left.metric(SpatialMetric.VERTICES),app.left.metric(SpatialMetric.GPU_BYTES),app.left.metric(SpatialMetric.GEOMETRY_ID),app.right.metric(SpatialMetric.GEOMETRY_ID),app.left.metric(SpatialMetric.TARGET_ID),app.right.metric(SpatialMetric.TARGET_ID))
    app.action(Control.ORBIT)
    var right_camera = app.right.metric(SpatialMetric.CAMERA)
    inject(window,app,POINTER_DOWN_KIND,470,340)
    inject(window,app,DRAG_UPDATE_KIND,505,355)
    inject(window,app,POINTER_UP_KIND,505,355)
    if app.right.metric(SpatialMetric.CAMERA) != right_camera or app.left.metric(SpatialMetric.UPLOADS) != 1:
        raise Error("Camera independence or geometry reuse failed")
    app.message = "Perspective camera changed. Orthographic camera, shared geometry and document stayed fixed."
    capture(app,directory,"02-linked-views")
    # Real AppKit callback routes into the same dispatch used by interactive mode.
    inject(window,app,POINTER_DOWN_KIND,80,190)
    inject(window,app,POINTER_UP_KIND,80,190)
    if app.right.metric(SpatialMetric.SELECTED) != 72:
        raise Error("Hierarchy selection did not propagate")
    app.action(Control.AXIS)
    var p = handle(app.right,app.tool)
    var history = app.left.metric(SpatialMetric.HISTORY)
    var child_x = app.left.world_transform(405,SpatialComponent.X)
    inject(window,app,POINTER_DOWN_KIND,Float32(p.x),Float32(p.y))
    inject(window,app,DRAG_UPDATE_KIND,Float32(p.x+30),Float32(p.y))
    if app.left.metric(SpatialMetric.HISTORY) != history or app.left.world_transform(405,SpatialComponent.X) == child_x:
        raise Error("Hierarchy preview failed")
    if app.left.world_transform(405,SpatialComponent.X) != app.right.world_transform(405,SpatialComponent.X):
        raise Error("Preview not linked")
    capture(app,directory,"03-hierarchy-preview")
    inject(window,app,POINTER_UP_KIND,Float32(p.x+30),Float32(p.y))
    if app.left.metric(SpatialMetric.HISTORY) != history+1:
        raise Error("Drag did not commit once")
    app.message = "Arm translation committed once; the Joint descendant follows through parent composition."
    capture(app,directory,"04-transform-commit")
    app.action(Control.PROBE)
    p = object_point(app.left,10)
    inject(window,app,POINTER_DOWN_KIND,Float32(p.x),Float32(p.y))
    inject(window,app,POINTER_UP_KIND,Float32(p.x),Float32(p.y))
    p = object_point(app.right,72)
    inject(window,app,POINTER_DOWN_KIND,Float32(p.x),Float32(p.y))
    inject(window,app,POINTER_UP_KIND,Float32(p.x),Float32(p.y))
    var distance = app.left.measurement()
    if distance != distance or distance <= 0 or distance != app.right.measurement():
        raise Error("Cross-view surface measurement failed")
    app.message = "Two actual surface picks, one per view. Cyan segment reports world-space Euclidean distance."
    capture(app,directory,"05-measurement")
    app.action(Control.CLIP)
    app.message = "Retain X >= 0 in both views. Rendering, picking and occlusion use the same clipped triangles."
    capture(app,directory,"06-clipping")
    app.action(Control.PLANE)
    capture(app,directory,"07-plane-moved")
    app.action(Control.UNDO)
    app.action(Control.UNDO)
    if app.left.clip().enabled:
        raise Error("Clipping undo failed")
    capture(app,directory,"08-clip-undo")
    app.action(Control.AXIS)
    p = handle(app.right,app.tool)
    history = app.left.metric(SpatialMetric.HISTORY)
    child_x = app.left.world_transform(405,SpatialComponent.X)
    inject(window,app,POINTER_DOWN_KIND,Float32(p.x),Float32(p.y))
    inject(window,app,DRAG_UPDATE_KIND,Float32(p.x+30),Float32(p.y))
    capture(app,directory,"09-cancel-preview")
    inject(window,app,KEY_DOWN_KIND,key=KEY_ESCAPE)
    if app.left.metric(SpatialMetric.HISTORY) != history or app.left.world_transform(405,SpatialComponent.X) != child_x:
        raise Error("Cancel changed committed hierarchy")
    app.message = "Escape discarded the preview in both views; history and committed descendant transform unchanged."
    capture(app,directory,"10-cancelled")
    # Numeric editing uses the same operation validator and commit/history as pointer.
    inject(window,app,POINTER_DOWN_KIND,80,495)
    var text: String = "0.25"
    external_call["sa_numeric_input", NoneType](text.as_c_string_span().ptr())
    drain(window,app)
    inject(window,app,KEY_DOWN_KIND,key=KEY_ENTER)
    inject(window,app,KEY_DOWN_KIND,key=KEY_ESCAPE)
    if app.left.metric(SpatialMetric.HISTORY) != history+1:
        raise Error("Numeric input did not commit")
    capture(app,directory,"11-numeric")
    app.action(Control.UNDO)
    app.action(Control.SLOW)
    sleep(0.08)
    app.action(Control.SLOW)
    sleep(0.72)
    drain(window,app)
    if app.left.metric(SpatialMetric.REJECTED) == 0:
        raise Error("Stale worker rejection not observed")
    app.message = "Old worker completion rejected by shared revision; both views retain the last accepted geometry."
    capture(app,directory,"12-stale-rejected")
    settle(window,app)
    app.action(Control.DISPOSE)
    if app.left.state() != SpatialState.READY:
        raise Error("Disposing right invalidated left")
    app.message = "Right target disposed. The left view and shared document remain live."
    capture(app,directory,"13-right-disposed")
    var geometry_id = app.left.metric(SpatialMetric.GEOMETRY_ID)
    var uploads = app.left.metric(SpatialMetric.UPLOADS)
    app.action(Control.DISPOSE)
    app.draw()
    if app.right.metric(SpatialMetric.GEOMETRY_ID) != geometry_id or app.left.metric(SpatialMetric.UPLOADS) != uploads:
        raise Error("Recreation duplicated retained geometry")
    app.message = "Right view recreated with its own target and the surviving shared GPU geometry buffer."
    capture(app,directory,"14-recovered")
    # Both camera targets render each iteration, but shared geometry and UI controls are retained.
    var builds = app.left.metric(SpatialMetric.FRAME_BUILDS)
    var controls = external_call["sa_controls_count", Int32]()
    for _ in range(60):
        _ = app.left.navigate(yaw=0.004)
        _ = app.right.navigate(pan_x=0.002)
        app.dirty = True
        app.draw()
        for view in range(2):
            if view == 0:
                print("TIMING",view,app.left.timing(SpatialTiming.CPU),app.left.timing(SpatialTiming.ENCODE),app.left.timing(SpatialTiming.WAIT),app.left.timing(SpatialTiming.GPU),app.left.timing(SpatialTiming.READBACK),app.left.timing(SpatialTiming.PUBLICATION),app.left.timing(SpatialTiming.TOTAL))
            else:
                print("TIMING",view,app.right.timing(SpatialTiming.CPU),app.right.timing(SpatialTiming.ENCODE),app.right.timing(SpatialTiming.WAIT),app.right.timing(SpatialTiming.GPU),app.right.timing(SpatialTiming.READBACK),app.right.timing(SpatialTiming.PUBLICATION),app.right.timing(SpatialTiming.TOTAL))
    if uploads != app.left.metric(SpatialMetric.UPLOADS) or builds != app.left.metric(SpatialMetric.FRAME_BUILDS) or controls != external_call["sa_controls_count", Int32]():
        raise Error("Camera frames rebuilt shared geometry or unrelated controls")
    var left_frames = app.left.metric(SpatialMetric.SUBMISSIONS)
    var right_frames = app.right.metric(SpatialMetric.SUBMISSIONS)
    sleep(0.3)
    app.draw()
    if app.left.metric(SpatialMetric.SUBMISSIONS) != left_frames or app.right.metric(SpatialMetric.SUBMISSIONS) != right_frames:
        raise Error("Idle submitted a frame")
    print("PASS assembly native public replay: 14 captures; two views / one geometry; camera uploads=0 derived=0 controls=0; idle submissions=0")


def main() raises:
    var window = MacOSWindowInstance()
    var config = WindowConfig("Moxi · D07 assembly inspector",1200,790)
    config.resizable = False
    window.open(config,60,850)
    var scale = external_call["moxi_window_scale_factor", Float32]()
    var app = Assembly(window.handle,Float64(scale))
    var args = argv()
    if len(args) >= 3 and args[1] == "--replay":
        replay(window,app,args[2])
    else:
        while window.is_open():
            drain(window,app)
            window.wait(Float32(0.016 if app.left.state() == SpatialState.COMPUTING else 60.0))
    app.right.close()
    app.left.close()
    window.close()
