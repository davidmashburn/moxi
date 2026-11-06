"""S4 probe: one ordinary App model, two explicit presentation modes."""
from std.ffi import external_call
from std.collections import List
from std.sys import argv
from std.time import perf_counter_ns
from std.testing import assert_true, assert_equal
from moxi import App, Rect, Point, WindowConfig
from moxi.macos import MacOSRenderer
from moxi.native_instance import MacOSWindowInstance
from moxi.event import *
from moxi_spatial import (SpatialViewport,SpatialPoint,SpatialObject,SpatialClip,SpatialCommand,SpatialMetric,SpatialTiming,WorldPanel,PanelMode,PanelPhase,PanelResult)
from controls import Controls

struct Probe:
    var app: App[Controls]
    var mode: PanelMode
    var message: String
    var saved_level: Float32
    var dragging: Bool
    var frames: Int
    def __init__(out self):
        self.app = App[Controls](Controls(),Rect(0,0,400,240))
        self.mode = PanelMode.WORLD
        self.message = "Oblique ordinary controls. Text focus can be probed; use F6 for native editing."
        self.saved_level = 40
        self.dragging = False
        self.frames = 0
    def cancel(mut self,panel: WorldPanel):
        _ = panel.route(PanelPhase.CANCEL,0,0)
        var e = Event()
        e.kind = POINTER_CANCEL_KIND
        _ = self.app.dispatch(e)
        if self.dragging:
            _ = self.app.component.slider.set_value(self.saved_level)
            self.app.rebuild()
        self.dragging = False
    def event(mut self,panel: WorldPanel,event: Event) raises:
        var e = event
        if e.kind == WINDOW_RESIZED_KIND or e.kind == NONE_KIND:
            return
        if (e.kind == KEY_DOWN_KIND and e.key == KEY_F6) or (e.kind == POINTER_DOWN_KIND and e.position.y >= 60 and e.position.y <= 95):
            self.cancel(panel)
            self.mode = PanelMode.SCREEN if self.mode == PanelMode.WORLD else PanelMode.WORLD
            self.message = "Same text, button count and level. Screen route retains native text / semantic coordinates."
            return
        if e.kind == POINTER_CANCEL_KIND:
            self.cancel(panel)
            return
        if e.kind == KEY_DOWN_KIND and e.key == KEY_ESCAPE:
            if self.app.component.input.has_composition():
                self.app.component.input.clear_composition()
            else:
                self.cancel(panel)
                _ = self.app.dispatch(Event(FocusEvent(self.app.focus_id(),False)))
            self.message = "Cancelled; provisional slider value restored. Tab re-enters ordinary controls."
            return
        var pointer = e.kind == POINTER_DOWN_KIND or e.kind == POINTER_MOVE_KIND or e.kind == DRAG_UPDATE_KIND or e.kind == POINTER_UP_KIND or e.kind == DROP_KIND or e.kind == DRAG_BEGIN_KIND
        if pointer:
            if e.kind == DRAG_BEGIN_KIND:
                return
            if e.kind == POINTER_DOWN_KIND:
                self.saved_level = self.app.component.slider.value
            if self.mode == PanelMode.WORLD:
                var phase = PanelPhase.PROBE
                if e.kind == POINTER_DOWN_KIND:
                    phase = PanelPhase.DOWN
                elif e.kind == DRAG_UPDATE_KIND:
                    phase = PanelPhase.MOVE
                elif e.kind == POINTER_UP_KIND or e.kind == DROP_KIND:
                    phase = PanelPhase.UP
                var result = panel.route(phase,Float64(e.position.x),Float64(e.position.y))
                if result != PanelResult.HIT:
                    if self.dragging:
                        self.cancel(panel)
                    return
                e.position = Point(Float32(panel.local_x()),Float32(panel.local_y()))
            if e.kind == POINTER_DOWN_KIND:
                self.dragging = self.app.hit_test(e.position) == 3
            if e.kind == DROP_KIND:
                e.kind = POINTER_UP_KIND
            _ = self.app.dispatch(e)
            if e.kind == POINTER_UP_KIND:
                self.dragging = False
            return
        # World keyboard control is scoped; native composition is explicitly
        # unsupported there. Synthetic source-owner protocol is replayed below.
        if self.mode == PanelMode.WORLD and self.app.focus_id() == 1 and e.kind == TEXT_INPUT_KIND:
            self.message = "World native text geometry FAILED. Press F6 to edit this same field on screen."
            return
        _ = self.app.dispatch(e)


def draw(mut probe: Probe,window: MacOSWindowInstance,source: MacOSWindowInstance,view: SpatialViewport,panel: WorldPanel) raises:
    var renderer = MacOSRenderer()
    if probe.mode == PanelMode.WORLD:
        source.activate()
        _ = probe.app.resize(Rect(0,0,400,240))
        probe.app.rebuild()
        probe.app.render(renderer)
        window.activate()
        external_call["wp_begin",NoneType]()
        assert_true(panel.render(source.handle,0))
        source.activate()
        external_call["wp_hide_semantics",NoneType]()
        window.activate()
        external_call["wp_hide_semantics",NoneType]()
    else:
        window.activate()
        var x = Float32(panel.project_x(0,0))
        var y = Float32(panel.project_y(0,0))
        assert_true(x == x and y == y)
        _ = probe.app.resize(Rect(x,y,400,240))
        probe.app.rebuild()
        probe.app.render(renderer)
    var mode = "WORLD / perspective texture + depth + ray mapping" if probe.mode == PanelMode.WORLD else "PROJECTED SCREEN EDITOR / ordinary native coordinates"
    var message = probe.message
    external_call["wp_chrome",NoneType](mode.as_c_string_span().ptr(),message.as_c_string_span().ptr())
    probe.frames += 1


def capture(window: MacOSWindowInstance,directory: String,name: String) raises:
    window.activate()
    var path = directory+"/"+name+".png"
    external_call["wp_capture",NoneType](path.as_c_string_span().ptr())


def drain(mut window: MacOSWindowInstance,mut probe: Probe,panel: WorldPanel) raises:
    var e = window.poll_event()
    while e.kind != NONE_KIND:
        probe.event(panel,e)
        e = window.poll_event()


def pointer(mut window: MacOSWindowInstance,mut probe: Probe,panel: WorldPanel,phase: Int32,x: Float64,y: Float64) raises:
    window.activate()
    external_call["wp_pointer",NoneType](phase,panel.project_x(x,y),panel.project_y(x,y))
    drain(window,probe,panel)


def replay(mut window: MacOSWindowInstance,mut source: MacOSWindowInstance,mut probe: Probe,view: SpatialViewport,panel: WorldPanel,directory: String) raises:
    window.activate()
    external_call["wp_clear_events",NoneType]()
    var cold = perf_counter_ns()
    draw(probe,window,source,view,panel)
    print("COLD",Float64(perf_counter_ns()-cold)/1e6)
    capture(window,directory,"01-oblique")
    var bounds = probe.app.view.bounds_for(3)
    var slider_y = Float64(bounds.y+bounds.height/2)
    pointer(window,probe,panel,0,100,slider_y)
    pointer(window,probe,panel,1,500,slider_y)
    assert_true(probe.dragging)
    assert_equal(probe.app.component.slider.value,Float32(100))
    probe.message = "Ray slider capture continues to local x=500, beyond the 400-point panel. Level = 100."
    draw(probe,window,source,view,panel)
    capture(window,directory,"02-capture-outside")
    pointer(window,probe,panel,2,500,slider_y)
    assert_true(not probe.dragging)
    var b = probe.app.view.bounds_for(2)
    pointer(window,probe,panel,0,100,Float64(b.y+10))
    pointer(window,probe,panel,2,100,Float64(b.y+10))
    assert_equal(probe.app.component.clicks,1)
    b = probe.app.view.bounds_for(1)
    pointer(window,probe,panel,0,110,Float64(b.y+14))
    pointer(window,probe,panel,2,110,Float64(b.y+14))
    assert_equal(probe.app.focus_id(),1)
    draw(probe,window,source,view,panel)
    source.activate()
    var renderer = MacOSRenderer()
    probe.app.rebuild()
    probe.app.render(renderer)
    assert_equal(external_call["wp_contract",Int32](),Int32(7))
    var identity = external_call["wp_editor_identity",UInt64]()
    var caret_x = external_call["wp_caret",Float64](Int32(0))
    var caret_y = external_call["wp_caret",Float64](Int32(1))
    var expected_x = panel.project_x(caret_x,caret_y)
    var expected_y = panel.project_y(caret_x,caret_y)
    assert_true(abs(expected_x-caret_x)>50)
    print("WORLD_IME_FAILED local_caret",caret_x,caret_y,"required_projected",expected_x,expected_y)
    external_call["wp_marked",NoneType]()
    # Drain source-owner protocol events directly to the ordinary runtime.
    var e = source.poll_event()
    while e.kind != NONE_KIND:
        if e.kind == COMPOSITION_UPDATE_KIND or e.kind == COMPOSITION_END_KIND:
            _ = probe.app.dispatch(e)
        e = source.poll_event()
    assert_true(not probe.app.component.input.has_composition())
    probe.message = "Native source has text/button/slider roles, but caret / AX frames are source-local: WORLD FAILED."
    draw(probe,window,source,view,panel)
    source.activate()
    assert_equal(external_call["wp_editor_identity",UInt64](),identity)
    capture(window,directory,"03-text-focus-failure")
    # Half-space clips the left side; foreground real scene geometry occludes right.
    assert_true(view.set_clip(SpatialClip(True,SpatialPoint(1,0,0),0)))
    var objects = List[SpatialObject]()
    objects.append(SpatialObject(91,SpatialPoint(.8,0,.8),0,.8,SpatialPoint(.9,.25,.18)))
    assert_true(view.replace_objects(objects))
    assert_true(panel.route(PanelPhase.DOWN,panel.project_x(50,100),panel.project_y(50,100)) == PanelResult.HIDDEN)
    assert_true(panel.route(PanelPhase.DOWN,panel.project_x(250,120),panel.project_y(250,120)) == PanelResult.HIDDEN)
    probe.message = "Clip removes left half; red scene geometry depth-occludes panel. Hidden click rejected."
    draw(probe,window,source,view,panel)
    capture(window,directory,"04-hidden-click")
    assert_true(view.set_clip(SpatialClip(False,SpatialPoint(1,0,0),0)))
    objects.clear()
    assert_true(view.replace_objects(objects))
    probe.event(panel,Event(KeyEvent(KEY_F6)))
    draw(probe,window,source,view,panel)
    window.activate()
    assert_equal(external_call["wp_contract",Int32](),Int32(7))
    external_call["wp_marked",NoneType]()
    external_call["wp_insert",NoneType]()
    drain(window,probe,panel)
    assert_true("native" in probe.app.component.input.text)
    # Selection / clipboard command semantics use the ordinary App contract.
    _ = probe.app.dispatch(Event(KeyEvent(KEY_A,MOD_COMMAND)))
    assert_true(probe.app.component.input.has_selection())
    _ = probe.app.dispatch(Event(KeyEvent(KEY_C,MOD_COMMAND)))
    assert_equal(probe.app.clipboard,probe.app.component.input.text)
    _ = probe.app.dispatch(Event(KeyEvent(KEY_V,MOD_COMMAND)))
    assert_true("native" in probe.app.component.input.text)
    var old_text = probe.app.component.input.text
    _ = probe.app.dispatch(Event(KeyEvent(KEY_TAB)))
    assert_equal(probe.app.focus_id(),2)
    _ = probe.app.dispatch(Event(KeyEvent(KEY_ENTER)))
    assert_equal(probe.app.component.clicks,2)
    _ = probe.app.dispatch(Event(KeyEvent(KEY_TAB)))
    assert_equal(probe.app.focus_id(),3)
    _ = probe.app.dispatch(Event(KeyEvent(KEY_LEFT)))
    assert_equal(probe.app.component.slider.value,Float32(99))
    assert_equal(probe.app.component.input.text,old_text)
    _ = probe.app.dispatch(Event(FocusEvent(1)))
    probe.message = "Screen: same model; native insert / marked-text callbacks, selection, clipboard, Tab and arrows verified."
    draw(probe,window,source,view,panel)
    window.activate()
    external_call["wp_field_protocol",NoneType]()
    drain(window,probe,panel)
    assert_equal(probe.app.component.input.text,old_text)
    var screen_caret_x = external_call["wp_caret",Float64](Int32(0))
    var screen_caret_y = external_call["wp_caret",Float64](Int32(1))
    var screen_bounds = probe.app.view.bounds_for(1)
    assert_true(screen_caret_x >= Float64(screen_bounds.x) and screen_caret_x <= Float64(screen_bounds.x+screen_bounds.width))
    assert_true(screen_caret_y >= Float64(screen_bounds.y) and screen_caret_y <= Float64(screen_bounds.y+screen_bounds.height))
    print("SCREEN_CARET_PASS",screen_caret_x,screen_caret_y)
    capture(window,directory,"05-screen-editor")
    probe.event(panel,Event(KeyEvent(KEY_F6)))
    draw(probe,window,source,view,panel)
    pointer(window,probe,panel,0,100,slider_y)
    pointer(window,probe,panel,1,240,slider_y)
    probe.event(panel,Event(KeyEvent(KEY_ESCAPE)))
    assert_equal(probe.app.component.slider.value,Float32(99))
    assert_true(not probe.dragging)
    probe.message = "PASS ray/capture/cancel, shared state, native screen contracts. FAIL world IME/AX geometry. NOT PROMOTED."
    draw(probe,window,source,view,panel)
    capture(window,directory,"06-cancel-recovery")
    var submissions = view.metric(SpatialMetric.SUBMISSIONS)
    for _ in range(100):
        assert_true(panel.route(PanelPhase.PROBE,panel.project_x(200,100),panel.project_y(200,100)) == PanelResult.HIT)
    assert_equal(view.metric(SpatialMetric.SUBMISSIONS),submissions)
    print("IDLE_REUSE 100 mappings zero submissions; frames",probe.frames)
    var target = view.metric(SpatialMetric.TARGET_ID)
    var geometry = view.metric(SpatialMetric.GEOMETRY_ID)
    var uploads = view.metric(SpatialMetric.UPLOADS)
    for _ in range(30):
        var start = perf_counter_ns()
        draw(probe,window,source,view,panel)
        print("WARM",Float64(perf_counter_ns()-start)/1e6,view.timing(SpatialTiming.TOTAL))
    assert_equal(view.metric(SpatialMetric.TARGET_ID),target)
    assert_equal(view.metric(SpatialMetric.GEOMETRY_ID),geometry)
    assert_equal(view.metric(SpatialMetric.UPLOADS),uploads)
    print("REUSE_PASS 30 draws stable target and geometry; zero scene uploads; panel snapshots/uploads 30")
    print("PASS D08 ordinary component native replay; synthetic protocols only; world promotion rejected")


def main() raises:
    var source = MacOSWindowInstance()
    var config = WindowConfig("D08 component texture owner",400,240)
    config.resizable = False
    source.open(config,80,600)
    external_call["wp_hide",NoneType]()
    var window = MacOSWindowInstance()
    config = WindowConfig("Moxi · S4 world panel experiment",1000,710)
    config.resizable = False
    window.open(config,40,850)
    var view = SpatialViewport()
    var objects = List[SpatialObject]()
    assert_true(view.replace_objects(objects))
    assert_true(view.viewport(30,110,940,420,1))
    var camera = view.camera()
    camera.yaw = 0.55
    camera.pitch = 0.22
    camera.distance = 6
    assert_true(view.set_camera(camera))
    assert_true(view.mount(window.handle))
    var panel = WorldPanel(view)
    assert_true(panel.configure(SpatialPoint(-2,1.2,0),SpatialPoint(4,0,0),SpatialPoint(0,-2.4,0)))
    var probe = Probe()
    var args = argv()
    if len(args)>=3 and args[1]=="--replay":
        replay(window,source,probe,view,panel,args[2])
    else:
        draw(probe,window,source,view,panel)
        while window.is_open():
            var e = window.poll_event()
            if e.kind != NONE_KIND:
                probe.event(panel,e)
                draw(probe,window,source,view,panel)
            else:
                window.wait(0.05)
    view.close()
    source.close()
    window.close()
