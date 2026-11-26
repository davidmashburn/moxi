"""I19's two bounded native consumers. No shared framework or private imports."""
from std.ffi import external_call
from std.sys import argv
from std.math import round
from moxi import Rect, Point
from moxi.native_instance import MacOSWindowInstance
from moxi.window import WindowConfig
from moxi.event import (Event, NONE_KIND, POINTER_DOWN_KIND, POINTER_UP_KIND,
    DRAG_UPDATE_KIND, DROP_KIND, POINTER_CANCEL_KIND, WINDOW_RESIZED_KIND,
    KEY_DOWN_KIND, TEXT_INPUT_KIND, FOCUS_KIND, KEY_ENTER, KEY_ESCAPE,
    KEY_LEFT, KEY_RIGHT, MOD_COMMAND)
from moxi_canvas import (CanvasDocument, CanvasObject, CanvasState, CanvasCommand,
    CanvasSnapshot, Camera, SessionKind)
from moxi_spatial import (SpatialViewport, SpatialTool, SpatialCommand, SpatialMetric,
    SpatialObject, SpatialPoint, SpatialComponent, SpatialAnchorPolicy,
    SpatialProjection, SpatialRoute)


@fieldwise_init
struct Consumer(Equatable, ImplicitlyCopyable):
    var value: Int32
    comptime CANVAS = Self(0)
    comptime SPATIAL = Self(1)

    def operation(self) -> String:
        return "canvas.move-x" if self == Self.CANVAS else "spatial.position-x"

    def target(self) -> String:
        return "canvas/card-1" if self == Self.CANVAS else "spatial/object-101/x"

    def valid(self, value: Int) -> Bool:
        return self.minimum() <= value <= self.maximum()

    def minimum(self) -> Int:
        return 0 if self == Self.CANVAS else -1000

    def maximum(self) -> Int:
        return 360 if self == Self.CANVAS else 1000

    def constrain(self, value: Int) -> Int:
        return min(self.maximum(),max(self.minimum(),value))


@fieldwise_init
struct Control(Equatable, ImplicitlyCopyable):
    var value: Int32
    comptime NONE = Self(-1)
    comptime PREVIEW = Self(0)
    comptime CANCEL = Self(1)
    comptime COMMIT = Self(2)
    comptime UNDO = Self(3)
    comptime REPROJECT = Self(4)
    comptime REPLAY = Self(5)
    comptime UNDO_COPY = Self(6)


@fieldwise_init
struct Record(ImplicitlyCopyable):
    var revision: Int
    var before: Int
    var after: Int

    def encode(self, kind: Consumer) -> String:
        return String('{"version":1,"operation":"',kind.operation(),'","target":"',kind.target(),
                      '","revision":',self.revision,',"from":',self.before,',"to":',self.after,'}')


def decode(text: String, kind: Consumer) raises -> Record:
    var value = text
    var operation = kind.operation()
    var target = kind.target()
    if external_call["it_decode", Int32](value.as_c_string_span().ptr(),operation.as_c_string_span().ptr(),target.as_c_string_span().ptr()) != 1:
        raise Error("Unrecognized command: version, operation, target or integer fields invalid.")
    var result = Record(Int(external_call["it_value", Int64](Int32(0))),Int(external_call["it_value", Int64](Int32(1))),Int(external_call["it_value", Int64](Int32(2))))
    if not kind.valid(result.before) or not kind.valid(result.after):
        raise Error("Command exceeds this consumer's X constraint.")
    return result


def label(slot: Int32, text: String, x: Float32, y: Float32, w: Float32, h: Float32, size: Float32 = 13):
    var owned = text
    external_call["it_label", NoneType](slot,owned.as_c_string_span().ptr(),x,y,w,h,size)


struct Body:
    var kind: Consumer
    var doc: CanvasDocument
    var canvas: CanvasState
    var spatial: SpatialViewport
    var bounds: Rect
    var draft: Bool
    var history_floor: Int
    var pointer_origin: Point

    def __init__(out self, kind: Consumer, owner: UInt64, scale: Float64, x: Float32) raises:
        self.kind = kind
        self.doc = CanvasDocument()
        self.bounds = Rect(x,192,530,330)
        self.canvas = CanvasState(Camera(self.bounds))
        self.spatial = SpatialViewport()
        self.draft = False
        self.history_floor = 0
        self.pointer_origin = Point(0,0)
        if kind == Consumer.CANVAS:
            self.doc.add(CanvasObject(1,Rect(80,100,150,110),"Card 1"))
            self.canvas.select(1)
        else:
            var objects = List[SpatialObject]()
            objects.append(SpatialObject(101,SpatialPoint(0,0,0),0,0.65,SpatialPoint(0.15,0.75,0.65)))
            if not self.spatial.replace_objects(objects):
                raise Error("Public spatial fixture rejected")
            _ = self.spatial.select(101)
            _ = self.spatial.viewport(Float64(x),192,530,330,scale)
            var camera = self.spatial.camera()
            camera.yaw = 0.35
            camera.pitch = 0.2
            camera.distance = 5
            _ = self.spatial.set_camera(camera)
            if not self.spatial.mount(owner):
                raise Error("Experimental native Metal renderer unavailable")
            # Public replace_objects is itself undoable. Keep fixture creation
            # outside this consumer's edit history without resetting native revs.
            self.history_floor = self.native_depth()

    def value(self, preview: Bool = False) -> Int:
        if self.kind == Consumer.CANVAS:
            var doc = self.canvas.preview(self.doc) if preview else self.doc
            return Int(round(Float64(doc.objects[0].bounds.x)))
        return Int(round(self.spatial.transform(101,SpatialComponent.X,preview)*1000))

    def revision(self) -> Int:
        return self.doc.revision if self.kind == Consumer.CANVAS else Int(self.spatial.metric(SpatialMetric.DOCUMENT))

    def native_depth(self) -> Int:
        return self.canvas.history.cursor if self.kind == Consumer.CANVAS else Int(self.spatial.metric(SpatialMetric.HISTORY))

    def depth(self) -> Int:
        return self.native_depth()-self.history_floor

    def observation(self) -> String:
        return String('{"committed_x":',self.value(),',"preview_x":',self.value(True),
                      ',"revision":',self.revision(),',"undo":',self.depth(),
                      ',"native_undo":',self.native_depth(),',"fixture_history_floor":',self.history_floor,
                      ',"draft":',Int(self.draft),',"viewport_points":[',self.bounds.x,',',self.bounds.y,',',self.bounds.width,',',self.bounds.height,']}')

    def cancel(mut self):
        self.canvas.cancel()
        _ = self.spatial.command(SpatialCommand.CANCEL)
        self.draft = False

    def preview(mut self, value: Int) -> Bool:
        # Numeric input and completed drags share one constrained native preview.
        self.cancel()
        if not self.kind.valid(value):
            return False
        if self.kind == Consumer.CANVAS:
            self.canvas.begin(self.doc,SessionKind.MOVE)
            self.canvas.nudge(Float32(value-self.value()),0)
            self.draft = True
        else:
            var base = Float64(self.value())/1000
            var start = self.spatial.anchor(SpatialPoint(base+0.6,0,0),SpatialAnchorPolicy.ALWAYS_VISIBLE)
            var end = self.spatial.anchor(SpatialPoint(Float64(value)/1000+0.6,0,0),SpatialAnchorPolicy.ALWAYS_VISIBLE)
            if self.spatial.pointer_down(SpatialTool.AXIS_X,start.x,start.y) != SpatialRoute.MANIPULATION:
                return False
            self.draft = self.spatial.pointer_move(end.x,end.y)
        return self.draft

    def begin(mut self, x: Float32, y: Float32) -> Bool:
        self.cancel()
        self.pointer_origin = Point(x,y)
        if self.kind == Consumer.CANVAS:
            var snapshot = CanvasSnapshot(self.doc,self.canvas.camera)
            if snapshot.hit_object(Point(x,y)) != 1:
                return False
            self.canvas.begin(self.doc,SessionKind.MOVE,Point(x,y),0)
            return True
        return self.spatial.pointer_down(SpatialTool.AXIS_X,Float64(x),Float64(y)) == SpatialRoute.MANIPULATION

    def move(mut self, x: Float32, y: Float32):
        if self.kind == Consumer.CANVAS:
            _ = self.canvas.motion(self.doc,Point(x,y),0)
            # This consumer constrains motion to world X; the native session still
            # owns projection and transient state.
            self.canvas.dy = 0
            self.canvas.dx = Float32(self.kind.constrain(self.value(True))-self.value())
            self.draft = self.canvas.active
        else:
            # Evaluate every absolute pointer position against the original
            # native grab, then retain a constrained, whole-unit preview. This
            # also permits a drag to return smoothly from either range limit.
            self.cancel()
            if self.spatial.pointer_down(SpatialTool.AXIS_X,Float64(self.pointer_origin.x),Float64(self.pointer_origin.y)) == SpatialRoute.MANIPULATION:
                if self.spatial.pointer_move(Float64(x),Float64(y)):
                    _ = self.preview(self.kind.constrain(self.value(True)))

    def commit(mut self) -> Bool:
        if not self.draft or self.value(True) == self.value():
            return False
        var before_depth = self.native_depth()
        var ok = self.canvas.commit(self.doc) if self.kind == Consumer.CANVAS else self.spatial.pointer_up()
        if ok:
            self.draft = False
            # If bounded native history evicts the oldest entry, fixture setup
            # has left the stack and must no longer reserve an undo slot.
            if self.native_depth() == before_depth and self.history_floor > 0:
                self.history_floor -= 1
        return ok

    def undo(mut self) -> Bool:
        self.cancel()
        if self.depth() == 0:
            return False
        return self.canvas.dispatch(CanvasCommand.UNDO,self.doc) if self.kind == Consumer.CANVAS else self.spatial.command(SpatialCommand.UNDO)

    def layout(mut self, width: Float32, changed: Bool, scale: Float64):
        self.cancel()
        self.bounds.width = width
        self.canvas.camera.viewport = self.bounds
        self.canvas.camera.zoom = 0.7 if changed else 1
        self.canvas.camera.x = -40 if changed else 0
        if self.kind == Consumer.SPATIAL:
            _ = self.spatial.viewport(Float64(self.bounds.x),192,Float64(width),330,scale)
            var camera = self.spatial.camera()
            camera.projection = SpatialProjection.ORTHOGRAPHIC if changed else SpatialProjection.PERSPECTIVE
            camera.yaw = -0.5 if changed else 0.35
            camera.pitch = 0.35 if changed else 0.2
            _ = self.spatial.set_camera(camera)

    def paint(mut self, slot: Int32) raises:
        external_call["it_clip", NoneType](self.bounds.x,self.bounds.y,self.bounds.width,self.bounds.height)
        if self.kind == Consumer.SPATIAL and not self.spatial.render(slot):
            raise Error("Native spatial frame failed to render/compose")
        if self.kind == Consumer.CANVAS:
            # Paint and hit-test the same public Moxi CanvasSnapshot publication.
            var snapshot = CanvasSnapshot(self.canvas.preview(self.doc),self.canvas.camera)
            for bounds in snapshot.bounds:
                external_call["it_card", NoneType](bounds.x,bounds.y,bounds.width,bounds.height)
        else:
            for line in self.spatial.overlays(SpatialTool.AXIS_X):
                external_call["it_line", NoneType](Float32(line.x1),Float32(line.y1),Float32(line.x2),Float32(line.y2),Float32(line.color.x),Float32(line.color.y),Float32(line.color.z),Float32(3 if line.handle else 1))


struct Demo:
    var source: Body
    var copy: Body
    var numeric: String
    var record: String
    var message: String
    var copy_message: String
    var focus: Bool
    var dragging: Bool
    var armed: Control
    var changed: Bool
    var scale: Float64

    def __init__(out self, kind: Consumer, owner: UInt64, scale: Float64) raises:
        self.source = Body(kind,owner,scale,24)
        self.copy = Body(kind,owner,scale,644)
        self.numeric = "80" if kind == Consumer.CANVAS else "0"
        self.record = ""
        self.message = "Ready. Preview changes no document revision or undo history."
        self.copy_message = "Ready. Reproject / resize, then replay a committed command once."
        self.focus = False
        self.dragging = False
        self.armed = Control.NONE
        self.changed = False
        self.scale = scale
        var title = "I19  /  Move a canvas card" if kind == Consumer.CANVAS else "I19  /  Edit a projected spatial X parameter"
        var units = "World X: whole canvas points, 0 to 360. Vertical position is fixed." if kind == Consumer.CANVAS else "World X: integer milliworld units, -1000 to 1000 (1000 = 1 world unit). Public Moxi + experimental Metal."
        external_call["it_init", NoneType](title.as_c_string_span().ptr(),units.as_c_string_span().ptr())

    def preview(mut self):
        var text = self.numeric
        var value = Int(external_call["it_integer", Int64](text.as_c_string_span().ptr()))
        self.message = "Preview only. Enter or Commit accepts one undo unit; Escape cancels." if self.source.preview(value) else "Invalid X: use a whole value within the displayed constraint. No commit available."

    def apply(mut self, text: String) -> Bool:
        # Parse and check all semantic preconditions before changing native state.
        try:
            var command = decode(text,self.copy.kind)
            if command.revision != self.copy.revision() or command.before != self.copy.value():
                self.copy_message = "Stale target. Value, revision, preview and undo history preserved."
                return False
            if not self.copy.preview(command.after) or not self.copy.commit():
                self.copy_message = "Native consumer rejected command."
                return False
            self.copy_message = "Semantic replay committed one undo unit in the changed projection."
            return True
        except e:
            self.copy_message = String(e)
            return False

    def action(mut self, control: Control):
        self.dragging = False
        if control == Control.PREVIEW:
            self.preview()
        elif control == Control.CANCEL:
            self.source.cancel()
            self.numeric = String(self.source.value())
            self.message = "Cancelled. Committed value, revision and history unchanged."
        elif control == Control.COMMIT:
            var command = Record(self.source.revision(),self.source.value(),self.source.value(True))
            if self.source.commit():
                self.record = command.encode(self.source.kind)
                self.numeric = String(command.after)
                self.message = "Committed exactly one native undo unit. Command available for replay."
            else:
                self.message = "No commit: preview a different valid X first."
        elif control == Control.UNDO:
            self.message = "Undo restored X and advanced the document revision." if self.source.undo() else "No committed edit to undo."
            self.numeric = String(self.source.value())
        elif control == Control.REPROJECT:
            self.changed = not self.changed
            self.copy.layout(Float32(410 if self.changed else 530),self.changed,self.scale)
            self.copy_message = "Copy camera and viewport changed; semantic value, revision and undo preserved."
        elif control == Control.REPLAY:
            var record = self.record
            _ = self.apply(record)
        elif control == Control.UNDO_COPY:
            self.copy_message = "Copy undone. Its value is restored but the old command is still stale." if self.copy.undo() else "Copy has no edit to undo."

    def dispatch(mut self, event: Event):
        var x = event.position.x
        var y = event.position.y
        if event.kind == POINTER_CANCEL_KIND or (event.kind == FOCUS_KIND and not event.focused) or event.kind == WINDOW_RESIZED_KIND:
            self.source.cancel()
            self.copy.cancel()
            self.dragging = False
            self.armed = Control.NONE
            self.message = "Capture cancelled by focus loss, pointer cancellation or window resize."
            if event.kind == WINDOW_RESIZED_KIND:
                self.copy.layout(max(Float32(300),event.size.width-670-Float32(120 if self.changed else 0)),self.changed,self.scale)
        elif event.kind == POINTER_DOWN_KIND:
            self.focus = x >= 88 and x <= 202 and y >= 84 and y <= 122
            self.armed = Control(external_call["it_hit", Int32](x,y))
            if self.focus:
                self.dragging = False
            elif self.armed == Control.NONE and x < 620 and y >= 192 and y <= 522:
                self.dragging = self.source.begin(x,y)
        elif event.kind == DRAG_UPDATE_KIND and self.dragging:
            self.source.move(x,y)
            self.numeric = String(self.source.value(True))
            self.message = "Pointer preview. Release retains it; Enter commits and Escape cancels."
        elif event.kind == POINTER_UP_KIND or event.kind == DROP_KIND:
            if self.armed != Control.NONE:
                var control = self.armed
                self.armed = Control.NONE
                if control.value == external_call["it_hit", Int32](x,y):
                    self.action(control)
            elif self.dragging:
                self.dragging = False
                self.numeric = String(self.source.value(True))
                self.preview()
        elif event.kind == TEXT_INPUT_KIND and self.focus:
            self.numeric = event.text
            self.preview()
        elif event.kind == KEY_DOWN_KIND:
            if event.key == KEY_ESCAPE:
                self.action(Control.CANCEL)
            elif event.key == KEY_ENTER:
                self.action(Control.COMMIT)
            elif event.key == 122 and event.modifiers & MOD_COMMAND != 0:
                self.action(Control.UNDO)
            elif not self.focus and (event.key == KEY_LEFT or event.key == KEY_RIGHT):
                var step = 10 if self.source.kind == Consumer.CANVAS else 50
                self.numeric = String(self.source.value(True)+(step if event.key == KEY_RIGHT else -step))
                self.preview()

    def draw(mut self) raises:
        _ = self.source.spatial.poll()
        _ = self.copy.spatial.poll()
        external_call["it_numeric", NoneType](self.numeric.as_c_string_span().ptr(),Int32(self.focus))
        label(7,String("Committed X ",self.source.value(),"  /  preview X ",self.source.value(True),"  /  revision ",self.source.revision(),"  /  undo ",self.source.depth()),24,532,585,28)
        label(8,String("Committed X ",self.copy.value(),"  /  revision ",self.copy.revision(),"  /  undo ",self.copy.depth()),644,532,530,28)
        label(9,self.record if self.record != "" else "No command yet. Commit a source preview.",24,604,1150,46,12)
        label(10,self.message,24,124,590,30,12)
        label(11,self.copy_message,644,124,530,30,12)
        label(12,"Preconditions: exact target identity, expected document revision, original world X; undo never rewinds revision.",24,662,1140,32,12)
        external_call["it_paint_begin", NoneType]()
        self.source.paint(0)
        self.copy.paint(1)
        external_call["it_paint_end", NoneType]()


def drain(mut window: MacOSWindowInstance, mut app: Demo) raises:
    window.pump()
    for _ in range(128):
        var event = window.poll_event()
        if event.kind == NONE_KIND:
            break
        app.dispatch(event)
    app.draw()


def require(ok: Bool, message: String) raises:
    if not ok:
        raise Error(message)


def inject(mut window: MacOSWindowInstance, mut app: Demo, kind: Int, x: Float32 = 0, y: Float32 = 0, key: Int = 0, modifiers: Int = 0) raises:
    external_call["it_inject", NoneType](Int32(kind),x,y,Int32(key),Int32(modifiers))
    drain(window,app)


def click(mut window: MacOSWindowInstance, mut app: Demo, x: Float32, y: Float32 = 100) raises:
    inject(window,app,POINTER_DOWN_KIND,x,y)
    inject(window,app,POINTER_UP_KIND,x,y)


def input(mut window: MacOSWindowInstance, mut app: Demo, text: String) raises:
    click(window,app,140)
    var value = text
    external_call["it_input", NoneType](value.as_c_string_span().ptr())
    drain(window,app)


def capture(mut window: MacOSWindowInstance, mut app: Demo, directory: String, name: String) raises:
    drain(window,app)
    var path = String(directory,"/",name,".png")
    external_call["it_capture", NoneType](path.as_c_string_span().ptr())
    path = String(directory,"/",name,".json")
    var state = String('{"window_points":[',external_call["it_extent", Float64](Int32(0)),',',external_call["it_extent", Float64](Int32(1)),
                       '],"scale":',app.scale,',"reprojected":',Int(app.changed),',"source":',app.source.observation(),',"copy":',app.copy.observation(),'}')
    external_call["it_write", NoneType](path.as_c_string_span().ptr(),state.as_c_string_span().ptr())


def drag_start(mut window: MacOSWindowInstance, mut app: Demo) raises -> Point:
    var start = Point(0,0)
    if app.source.kind == Consumer.CANVAS:
        var box = app.source.canvas.camera.rect(app.source.doc.objects[0].bounds)
        start = Point(box.x+box.width/2,box.y+box.height/2)
    else:
        for line in app.source.spatial.overlays(SpatialTool.AXIS_X):
            if line.handle:
                start = Point(Float32((line.x1+line.x2)/2),Float32((line.y1+line.y2)/2))
    inject(window,app,POINTER_DOWN_KIND,start.x,start.y)
    require(app.dragging,"Native card/handle pointer down did not start a session")
    return start


def drag_to(mut window: MacOSWindowInstance, mut app: Demo, start: Point, value: Int) raises -> Point:
    var end = start
    if app.source.kind == Consumer.CANVAS:
        end.x += Float32(value-app.source.value())*Float32(app.source.canvas.camera.zoom)
    else:
        # The visible handle runs from pivot to pivot+1.2. Its screen midpoint
        # is intentionally used above, just as a user can grab anywhere on it.
        # Translate that grab by a projected world delta at its actual depth.
        # Numerical replay still uses exact semantic X, independent of this grab.
        var base = Float64(app.source.value())/1000
        var anchor = app.source.spatial.anchor(SpatialPoint(base+0.6,0,0),SpatialAnchorPolicy.ALWAYS_VISIBLE)
        var destination = app.source.spatial.anchor(SpatialPoint(Float64(value)/1000+0.6,0,0),SpatialAnchorPolicy.ALWAYS_VISIBLE)
        end.x += Float32(destination.x-anchor.x)
        end.y += Float32(destination.y-anchor.y)
    inject(window,app,DRAG_UPDATE_KIND,end.x,end.y)
    return end


def boundary_record(kind: Consumer, version: String, revision: String, before: String, after: String) -> String:
    # Independent literal wire fixtures exercise parsing, rather than round-trip
    # tests which could share the encoder's mistake.
    return String('{"version":',version,',"operation":"',kind.operation(),'","target":"',kind.target(),
                  '","revision":',revision,',"from":',before,',"to":',after,'}')


def replay(mut window: MacOSWindowInstance, mut app: Demo, directory: String) raises:
    drain(window,app)
    var initial = app.source.value()
    var revision = app.source.revision()
    var copy_revision = app.copy.revision()
    var target = 230 if app.source.kind == Consumer.CANVAS else 700
    require(revision == copy_revision and app.source.depth() == 0 and app.copy.depth() == 0,"Independent baselines differ")
    require(not app.source.undo() and app.source.value() == initial and app.source.revision() == revision,"Undo exposed fixture initialization")
    capture(window,app,directory,"01-initial")
    input(window,app,String(target))
    require(app.source.value() == initial and app.source.value(True) == target and app.source.revision() == revision and app.source.depth() == 0,"Numeric preview mutated committed state")
    capture(window,app,directory,"02-numeric-preview")
    inject(window,app,KEY_DOWN_KIND,key=KEY_ESCAPE)
    require(not app.source.draft and app.source.value(True) == initial and app.source.revision() == revision,"Escape did not cancel numeric preview")
    var start = drag_start(window,app)
    var end = drag_to(window,app,start,target)
    require(app.source.value(True) != initial and app.source.value() == initial,"Pointer failed to preview native transform")
    var dragged_value = app.source.value(True)
    inject(window,app,KEY_DOWN_KIND,key=KEY_ESCAPE)
    inject(window,app,DRAG_UPDATE_KIND,end.x+15,end.y)
    inject(window,app,POINTER_UP_KIND,end.x+15,end.y)
    require(not app.source.draft and app.source.value() == initial and app.source.value(True) == initial and app.source.depth() == 0,"Held-pointer Escape leaked into release")
    capture(window,app,directory,"03-held-pointer-cancel")
    start = drag_start(window,app)
    end = drag_to(window,app,start,target)
    inject(window,app,POINTER_UP_KIND,end.x,end.y)
    require(app.source.draft and app.source.value() == initial and app.source.revision() == revision,"Release must retain uncommitted preview")
    capture(window,app,directory,"04-pointer-preview")
    # Exact entry refines the same draft; one Commit creates one native undo.
    input(window,app,String(target))
    click(window,app,460)
    require(app.source.value() == target and app.source.revision() == revision+1 and app.source.depth() == 1 and not app.source.draft,"Commit did not produce exactly one native undo unit")
    var record = app.record
    # Literal boundary fixtures pin wire compatibility independently of the
    # consumer's operation/target methods and the encoder/decoder round trip.
    var expected = '{"version":1,"operation":"canvas.move-x","target":"canvas/card-1","revision":1,"from":80,"to":230}' if app.source.kind == Consumer.CANVAS else '{"version":1,"operation":"spatial.position-x","target":"spatial/object-101/x","revision":2,"from":0,"to":700}'
    require(record == expected,"Recorded command changed the public wire fixture")
    var parsed = decode(record,app.source.kind)
    require(parsed.revision == revision and parsed.before == initial and parsed.after == target,"Wrong semantic recording")
    var path = directory+"/command.json"
    external_call["it_write", NoneType](path.as_c_string_span().ptr(),record.as_c_string_span().ptr())
    capture(window,app,directory,"05-committed-command")
    inject(window,app,KEY_DOWN_KIND,key=122,modifiers=MOD_COMMAND)
    require(app.source.value() == initial and app.source.revision() == revision+2 and app.source.depth() == 0,"Undo rewound revision or failed to restore original X")
    capture(window,app,directory,"06-source-undo")
    click(window,app,730)
    external_call["it_resize", NoneType](Int32(1320),Int32(800))
    drain(window,app)
    require(app.changed and app.copy.value() == initial and app.copy.revision() == copy_revision and app.copy.depth() == 0,"Layout change mutated semantic document")
    click(window,app,920)
    require(app.copy.value() == target and app.copy.revision() == copy_revision+1 and app.copy.depth() == 1,"Replay after actual resize/reprojection failed")
    capture(window,app,directory,"07-reprojected-replay")
    click(window,app,920)
    require(app.copy.value() == target and app.copy.revision() == copy_revision+1 and app.copy.depth() == 1 and app.copy_message.find("Stale") >= 0,"Repeated replay was not rejected atomically")
    click(window,app,1090)
    click(window,app,920)
    require(app.copy.value() == initial and app.copy.revision() == copy_revision+2 and app.copy.depth() == 0 and app.copy_message.find("Stale") >= 0,"Old command accepted after undo restored its from value")
    capture(window,app,directory,"08-stale-after-undo")
    # Fault-injection checks below deliberately exercise the record boundary.
    # Native callbacks above establish the ordinary UI path independently.
    var draft_target = 100 if app.source.kind == Consumer.CANVAS else 300
    require(app.copy.preview(draft_target),"Copy preview failed")
    require(not app.apply(record) and app.copy.draft and app.copy.value(True) == draft_target,"Stale rejection changed an existing preview")
    var other = Consumer.SPATIAL if app.source.kind == Consumer.CANVAS else Consumer.CANVAS
    var wrong_target = Record(copy_revision+2,initial,draft_target).encode(other)
    require(not app.apply(wrong_target) and app.copy.draft and app.copy.value(True) == draft_target,"Wrong identity mutated native preview")
    var malformed: List[String] = ["null","[]","{}",'{"version":true}',
        '{"version":1,"operation":"cursor.move","target":"signal/cursor","revision":0,"from":25,"to":70}']
    malformed.append(String('{"version":1,"operation":"unknown","target":"',app.copy.kind.target(),
        '","revision":',copy_revision+2,',"from":',initial,',"to":',draft_target,'}'))
    malformed.append(String('{"version":1,"operation":"',app.copy.kind.operation(),'","target":"unknown",',
        '"revision":',copy_revision+2,',"from":',initial,',"to":',draft_target,'}'))
    for version in ["true","2","\"1\"","1.5"]:
        malformed.append(boundary_record(app.copy.kind,version,String(copy_revision+2),String(initial),String(draft_target)))
    for rev in ["-1","true","1.5","9007199254740992"]:
        malformed.append(boundary_record(app.copy.kind,"1",rev,String(initial),String(draft_target)))
    for value in ["null","true","1.5","\"100\"","1001"]:
        malformed.append(boundary_record(app.copy.kind,"1",String(copy_revision+2),String(initial),value))
    malformed.append(boundary_record(app.copy.kind,"1",String(copy_revision+2),String(initial),String(initial)))
    for text in malformed:
        require(not app.apply(text) and app.copy.draft and app.copy.value(True) == draft_target and app.copy.revision() == copy_revision+2 and app.copy.depth() == 0,"Malformed command changed copy state")
    var wrong_before = Record(copy_revision+2,initial+1,draft_target).encode(app.copy.kind)
    require(not app.apply(wrong_before) and app.copy.draft and app.copy.value(True) == draft_target,"Mismatched original value was not rejected atomically")
    app.copy.cancel()
    input(window,app,"361" if app.source.kind == Consumer.CANVAS else "1001")
    click(window,app,460)
    require(app.source.value() == initial and app.source.revision() == revision+2 and app.source.depth() == 0 and not app.source.draft,"Out-of-range input committed")
    input(window,app,"1.5")
    require(not app.source.draft,"Fractional input accepted")
    start = drag_start(window,app)
    end = drag_to(window,app,start,600 if app.source.kind == Consumer.CANVAS else 1400)
    require(app.source.value(True) == (360 if app.source.kind == Consumer.CANVAS else 1000),"Held drag exceeded upper constraint")
    end = drag_to(window,app,start,-200 if app.source.kind == Consumer.CANVAS else -1400)
    require(app.source.value(True) == (0 if app.source.kind == Consumer.CANVAS else -1000),"Held drag exceeded lower constraint")
    end = drag_to(window,app,start,target)
    require(app.source.value(True) == dragged_value and app.source.value() == initial and app.source.depth() == 0,String("Returning from range limit changed drag origin or committed state: expected ",dragged_value,", observed ",app.source.value(True)))
    inject(window,app,KEY_DOWN_KIND,key=KEY_ESCAPE)
    input(window,app,"360" if app.source.kind == Consumer.CANVAS else "1000")
    require(app.source.draft and app.source.value(True) == (360 if app.source.kind == Consumer.CANVAS else 1000),"Upper endpoint preview failed")
    inject(window,app,KEY_DOWN_KIND,key=KEY_ESCAPE)
    input(window,app,"0" if app.source.kind == Consumer.CANVAS else "-1000")
    inject(window,app,KEY_DOWN_KIND,key=KEY_ENTER)
    require(app.source.value() == (0 if app.source.kind == Consumer.CANVAS else -1000) and app.source.depth() == 1 and app.source.revision() == revision+3,"Keyboard commit of lower endpoint failed")
    click(window,app,550)
    # Source endpoint commit+undo advanced its revision twice, so advance the
    # copy too; later replay must work beyond the initial document baseline.
    var sync = Record(app.copy.revision(),app.copy.value(),draft_target).encode(app.copy.kind)
    require(app.apply(sync),"Valid later revision rejected")
    require(app.copy.undo(),"Later copy undo failed")
    require(app.copy.revision() == app.source.revision(),"Histories did not advance monotonically")
    input(window,app,String(draft_target))
    inject(window,app,KEY_DOWN_KIND,key=KEY_ENTER)
    var later = app.record
    require(app.apply(later) and app.copy.value() == app.source.value() and app.copy.depth() == 1,"Later command did not replay from matched advanced baseline")
    # Native capture loss and resize cancellation during an active pointer.
    for cancellation in [POINTER_CANCEL_KIND,FOCUS_KIND,WINDOW_RESIZED_KIND]:
        start = drag_start(window,app)
        end = drag_to(window,app,start,initial)
        inject(window,app,cancellation)
        inject(window,app,POINTER_UP_KIND,end.x,end.y)
        require(not app.source.draft and app.source.value() == draft_target and app.source.depth() == 1,"Capture loss changed committed state")
    # Exercise fixture protection when native spatial history evicts its oldest
    # entry. Reuse the real consumer; no alternate history model is installed.
    if app.source.kind == Consumer.SPATIAL:
        for index in range(65):
            require(app.source.preview(100 if index%2 == 0 else 200) and app.source.commit(),"Native history rollover commit failed")
        require(app.source.history_floor == 0 and app.source.depth() == 64,"Native history eviction did not retire fixture reservation")
        for _ in range(64):
            require(app.source.undo(),"Retained native edit could not undo")
        require(not app.source.undo() and app.source.depth() == 0,"Undo escaped retained native history")
    print("PASS native field-editor insertion and AppKit key dispatch; numeric and pointer preview; held Escape; commit/one undo; semantic recording; resize/reproject/replay; repeat stale; undo ABA stale; identity/malformed/from rejection; invalid input; drag range/return; endpoints; later revision; capture loss; spatial history rollover")


def main() raises:
    var args = argv()
    if (len(args) != 2 and len(args) != 4) or (args[1] != "canvas" and args[1] != "spatial"):
        raise Error("Usage: transforms canvas|spatial [--replay OUTPUT_DIRECTORY]")
    if len(args) == 4 and args[2] != "--replay":
        raise Error("Usage: transforms canvas|spatial [--replay OUTPUT_DIRECTORY]")
    var kind = Consumer.CANVAS if args[1] == "canvas" else Consumer.SPATIAL
    var window = MacOSWindowInstance()
    var config = WindowConfig("Moxi · I19 inspectable transforms",1200,760)
    window.open(config,60,850)
    var app = Demo(kind,window.handle,Float64(external_call["moxi_window_scale_factor", Float32]()))
    if len(args) == 4 and args[2] == "--replay":
        replay(window,app,args[3])
    else:
        while window.is_open():
            drain(window,app)
            window.wait(Float32(0.02))
    app.source.spatial.close()
    app.copy.spatial.close()
    window.close()
