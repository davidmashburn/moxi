"""Smoke test compiled against the installed distributable package."""

from moxi import test_check
from moxi import (
    App,
    BACKEND_MACOS_APPKIT,
    CheckboxControl,
    Color,
    CapabilityBus,
    CapabilityDescriptor,
    CapabilityInvocation,
    CALLER_AGENT,
    COMPOSED_COUNTER_ID_OFFSET,
    ComposedState,
    FormState,
    Rect,
    RowState,
    ROLE_CONTAINER,
    ROLE_BUTTON,
    ROLE_CHECKBOX,
    ROLE_TEXT_INPUT,
    TestRenderer,
    Scene,
    SoftwareSceneRenderer,
    backend_capabilities,
    TextInputState,
    WxStyleState,
    WX_NAME_FIELD_ID,
    make_row,
    measure_text,
    measure_text_wrapped,
    moxi_version,
)


def main() raises:
    test_check(moxi_version() == "0.5.1")

    var editing = TextInputState("package")
    test_check(editing.select_all())
    test_check(editing.selected_text() == "package")
    test_check(editing.copy_selection())

    var row = make_row(Rect(0.0, 0.0, 240.0, 80.0), 8.0, 4.0)
    row.add_button(1, "Installed", 32.0)
    row.layout()
    test_check(row.child(0).bounds.width == 224.0)

    var form = App[FormState](FormState(), Rect(0.0, 0.0, 320.0, 220.0))
    var semantics = form.accessibility()
    test_check(semantics.node(2).role == ROLE_TEXT_INPUT)
    test_check(semantics.node(4).role == ROLE_BUTTON)

    var wx = App[WxStyleState](WxStyleState(), Rect(0.0, 0.0, 560.0, 840.0))
    var wx_semantics = wx.accessibility()
    test_check(wx_semantics.node(0).role == ROLE_CONTAINER)
    test_check(wx_semantics.node(6).id == WX_NAME_FIELD_ID)
    test_check(wx_semantics.node(6).role == ROLE_TEXT_INPUT)
    test_check(wx_semantics.node(8).role == ROLE_CHECKBOX)
    test_check(measure_text("package", wx.view.child(2).style).width > 0.0)
    var wrapped = measure_text_wrapped(
        "package consumer wrapping",
        wx.view.child(2).style,
        80.0,
    )
    test_check(wrapped.line_count > 1)

    var checkbox = CheckboxControl(90, "Installed checkbox", True, 24.0)
    test_check(checkbox.node().semantics.role == ROLE_CHECKBOX)
    var caps = backend_capabilities(BACKEND_MACOS_APPKIT)
    test_check(caps.text_shaping)
    var bus = CapabilityBus()
    _ = bus.register(CapabilityDescriptor("package.read", "Read package state"))
    var request = CapabilityInvocation("package-1", "package.read", CALLER_AGENT)
    var authorization = bus.authorize(request)
    test_check(authorization.ok())
    test_check(not authorization.executed)

    var composed = App[ComposedState](
        ComposedState(),
        Rect(0.0, 0.0, 480.0, 360.0),
    )
    test_check(composed.view.child(2).id == COMPOSED_COUNTER_ID_OFFSET + 1)

    var renderer = TestRenderer()
    form.render(renderer)
    test_check(renderer.count() == 7)

    var scene = Scene()
    scene.append_rect(1, Rect(0.0, 0.0, 8.0, 8.0), Color(1.0, 0.0, 0.0, 1.0))
    var software = SoftwareSceneRenderer(12, 12)
    software.render_scene(scene)
    test_check(software.pixel(2, 2).red > 0.5)
    print("Moxi package consumer passed")
