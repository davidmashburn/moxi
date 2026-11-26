"""Drive identical X11 inputs into three separate compiled workbench processes."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import time

import gi
gi.require_version("GdkPixbuf", "2.0")
from gi.repository import GdkPixbuf

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
from linux_ui_smoke import Smoke, focused, nodes, require


def capture(smoke, frame, name, expected_renderer):
    draw = next(r for r in reversed(smoke.records)
                if r["type"] == "draw" and r["frame"] == frame["frame"])
    if expected_renderer:
        require(draw["renderer"] == expected_renderer and draw["custom"] == 125,
                f"unexpected renderer or chart command count: {draw}")
    # GTK can snapshot a frame before the X server presents it under emulation.
    scale = int(os.getenv("GDK_SCALE", "1"))
    expected_size = (frame["width"] * scale, frame["height"] * scale)
    path = str(smoke.run / (name + ".png"))
    deadline = time.monotonic() + smoke.args.timeout
    while time.monotonic() < deadline:
        time.sleep(0.5)
        require(smoke.command("getactivewindow").stdout.strip() == smoke.window,
                "capture would include another application")
        subprocess.run(["scrot", "-o", "-u", path], check=True)
        _, width, height = GdkPixbuf.Pixbuf.get_file_info(path)
        sample = GdkPixbuf.Pixbuf.new_from_file_at_scale(path, 150, 100, True)
        if (width, height) == expected_size and len(set(sample.get_pixels())) > 32:
            break
    else:
        raise RuntimeError(f"{name}: timed out waiting for the presented client image")
    chart = nodes(frame).get(22)
    return {"state": name, "frame": frame["frame"], "renderer": draw.get("renderer", "GTK Cairo"),
            "viewport": [frame["width"], frame["height"]], "scale": int(os.getenv("GDK_SCALE", "1")),
            "chart": [chart[k] for k in ("x","y","width","height")] if chart else None,
            "canvas_offset": [frame["canvas_x"],frame["canvas_y"]]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    parser.add_argument("mode", choices=("oracle", "ngl", "fallback", "scale2"))
    args = parser.parse_args()
    args.app = ROOT / "dist/layout-workbench-linux"
    args.screenshot = None
    args.timeout = 60
    run = args.output.resolve() / args.mode
    run.mkdir(parents=True)
    os.environ.pop("MOXI_LINUX_SCENE", None)
    if args.mode != "oracle":
        os.environ["MOXI_LINUX_SCENE"] = "gsk"
    if args.mode == "scale2":
        os.environ["GDK_SCALE"] = "2"
    if args.mode == "fallback":
        os.environ["GDK_DEBUG"] = "gl-disable,vulkan-disable"
    expected = {"oracle": None, "ngl": "GskNglRenderer", "scale2": "GskNglRenderer", "fallback": "GskCairoRenderer"}[args.mode]
    smoke = Smoke(args, run, renderer="cairo" if args.mode == "oracle" else "ngl")
    frames = []

    def save(frame, name):
        frames.append(capture(smoke, frame, name, expected))

    try:
        frame = smoke.start()
        save(frame, "initial")
        if args.mode in ("oracle", "ngl"):
            cell = smoke.visible_cell(frame)
            frame = smoke.rapid_click_type(frame, cell, "q", clip_key=21)
            save(frame, "collection")
            frame = smoke.focus_dataset(frame)
            frame = smoke.begin_preedit(frame)
            smoke.command("key", "Return")
            frame = smoke.frame(frame["frame"], lambda f: "あ" in nodes(f)[13]["value"])
            save(frame, "unicode")
            smoke.click(frame, 46)
            frame = smoke.frame(frame["frame"], lambda f: 90 in nodes(f) and 13 not in nodes(f))
            save(frame, "popup")
            smoke.command("key", "Escape")
            frame = smoke.frame(frame["frame"], lambda f: 90 not in nodes(f) and focused(f, 13))
            height = smoke.geometry()["HEIGHT"]
            smoke.command("windowsize", smoke.window, 540, height)
            frame = smoke.frame(frame["frame"], lambda f: f["width"] < 760 and
                                nodes(f)[20]["y"] >= nodes(f)[10]["y"] + nodes(f)[10]["height"] - 0.5)
            save(frame, "narrow")
        smoke.close()
        (run / "states.json").write_text(json.dumps(frames, indent=2) + "\n")
    finally:
        smoke.cleanup()


if __name__ == "__main__":
    main()
