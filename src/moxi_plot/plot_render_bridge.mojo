"""Renderer-facing bridge between the plot model and Moxi's scene renderers.

These free functions call only the public renderer surface (`begin_scene`,
`end_scene`, `render_scene`, `draw_scene_command`, `draw_plot_packet`), so the
plot model never needs to live alongside the renderers. Each function is
overloaded by renderer type rather than defined as a method, keeping
`moxi.metal` and `moxi.software` free of plot-model imports.
"""

from moxi.metal import MacOSMetalRenderer
from moxi.software import SoftwareSceneRenderer
from .plotting import Plot
from .plot_view import PlotView


def render_plot(mut renderer: MacOSMetalRenderer, plot: Plot) raises -> Bool:
    """Render a complete plot, using the packet for supported dense marks.

    The packet is placed after the chrome scene and clipped to the plot
    area.  If a mark family still requires the generic Scene path, the
    complete portable scene is rendered instead.
    """
    var packet = plot.build_render_packet()
    if packet.fallback_required:
        renderer.render_scene(plot.build_scene())
        return False
    renderer.begin_scene()
    var chrome = plot.build_scene(False)
    for index in range(chrome.count()):
        renderer.draw_scene_command(chrome.command(index))
    var rendered = renderer.draw_plot_packet(packet)
    renderer.end_scene()
    return rendered


def render_plot(mut renderer: SoftwareSceneRenderer, plot: Plot) raises -> Bool:
    """Render a complete plot using the packet when it is safe to do so."""
    var packet = plot.build_render_packet()
    if packet.fallback_required:
        renderer.render_scene(plot.build_scene())
        return False
    renderer.begin_scene()
    var chrome = plot.build_scene(False)
    for index in range(chrome.count()):
        renderer.draw_scene_command(chrome.command(index))
    renderer.draw_plot_packet(packet)
    renderer.end_scene()
    return True


def render_plot_view(mut renderer: MacOSMetalRenderer, mut view: PlotView) raises -> Bool:
    """Render an interactive PlotView with the dense packet fast path."""
    var packet = view.build_render_packet()
    if packet.fallback_required:
        renderer.render_scene(view.build_scene())
        return False
    renderer.begin_scene()
    var chrome = view.build_chrome_scene()
    for index in range(chrome.count()):
        renderer.draw_scene_command(chrome.command(index))
    var rendered = renderer.draw_plot_packet(packet)
    var overlay = view.build_overlay_scene()
    for index in range(overlay.count()):
        renderer.draw_scene_command(overlay.command(index))
    renderer.end_scene()
    return rendered


def render_plot_view(mut renderer: SoftwareSceneRenderer, mut view: PlotView) raises -> Bool:
    """Render an interactive PlotView with packet-safe overlays."""
    var packet = view.build_render_packet()
    if packet.fallback_required:
        renderer.render_scene(view.build_scene())
        return False
    renderer.begin_scene()
    var chrome = view.build_chrome_scene()
    for index in range(chrome.count()):
        renderer.draw_scene_command(chrome.command(index))
    renderer.draw_plot_packet(packet)
    var overlay = view.build_overlay_scene()
    for index in range(overlay.count()):
        renderer.draw_scene_command(overlay.command(index))
    renderer.end_scene()
    return True
