"""Drive a fullscreen workbench on a private Sway output and record its drawn states."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time
from types import SimpleNamespace

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts"))
from linux_ui_smoke import Smoke, focused, nodes, require, utc_now


def command(*args):
    return subprocess.check_output(args, timeout=60, text=True)


def exercise(run):
    app = Path("dist/layout-workbench-linux").resolve()
    smoke = Smoke(SimpleNamespace(app=app, timeout=45), run)
    checks = []

    def press(key):
        command("wtype", "-s", "300", "-k", key, "-s", "300")

    def capture(name, frame):
        # Allow the compositor to present the frame after GTK's draw callback.
        time.sleep(.3)
        image = run / (name + ".png")
        command("grim", "-l", "1", "-o", "HEADLESS-1", str(image))
        checks.append({"capture": name, "frame": frame["frame"],
                       "canvas": [frame["width"], frame["height"]],
                       "png_sha256": hashlib.sha256(image.read_bytes()).hexdigest(),
                       "focus": [k for k in nodes(frame) if focused(frame, k)],
                       "summary_y": nodes(frame).get(8, {}).get("y"),
                       "dataset": nodes(frame).get(13, {}).get("value"),
                       "modal": 90 in nodes(frame)})

    env = dict(os.environ, MOXI_LINUX_TRACE_FILE=str(smoke.trace_path))
    with smoke.log_path.open("wb") as log:
        process = subprocess.Popen([app], env=env, stdout=log, stderr=log)
        smoke.process = process
        try:
            initial = smoke.frame(predicate=lambda f: focused(f, 13) and f["width"] == 1024)
            tree = json.loads(command("swaymsg", "-rt", "get_tree"))

            def descendants(node):
                yield node
                for child in node["nodes"] + node["floating_nodes"]:
                    yield from descendants(child)

            view, = [n for n in descendants(tree) if n.get("pid") == process.pid]
            require(view["shell"] == "xdg_shell" and view["rect"]["x"] == view["rect"]["y"] == 0,
                    "expected a native Wayland workbench at the origin")
            capture("01-initial", initial)
            press("Tab")
            tab = smoke.frame(initial["frame"], lambda f: focused(f, 40), "Summary focus")
            capture("02-focus", tab)
            press("space")
            result = smoke.frame(tab["frame"], lambda f: nodes(f)[8]["y"] > nodes(initial)[8]["y"],
                                 "expanded summary")
            capture("03-summary", result)
            current = result
            for key in range(41, 47):
                press("Tab")
                current = smoke.frame(current["frame"], lambda f: focused(f, key),
                                      f"toolbar focus {key}")
            press("Return")
            modal = smoke.frame(result["frame"], lambda f: 90 in nodes(f) and 13 not in nodes(f),
                                "modal scope")
            require(focused(modal, 92), "expected first modal control to have focus")
            capture("04-dialog", modal)
            press("Escape")
            restored = smoke.frame(modal["frame"], lambda f: 90 not in nodes(f) and focused(f, 46),
                                   "restored Dialog button focus")
            require(nodes(restored)[13]["value"] == nodes(initial)[13]["value"], "Dataset changed")
            capture("05-recovery", restored)
            command("swaymsg", "output HEADLESS-1 mode 680x768")
            narrow = smoke.frame(restored["frame"], lambda f: f["width"] == 680 and 18 not in nodes(f),
                                 "narrow layout without splitter")
            capture("06-narrow", narrow)
            command("swaymsg", "output HEADLESS-1 mode 1024x768")
            wide = smoke.frame(narrow["frame"], lambda f: f["width"] == 1024 and 18 in nodes(f),
                               "restored wide splitter")
            require(nodes(wide)[13]["value"] == nodes(initial)[13]["value"], "resize changed Dataset")
            capture("07-wide", wide)
            command("swaymsg", f"[pid={process.pid}] kill")
            require(process.wait(timeout=15) == 0, "workbench close failed")
            report = {"utc": utc_now(), "binary_sha256": hashlib.sha256(app.read_bytes()).hexdigest(),
                      "shell": view["shell"], "rect": view["rect"], "checks": checks, "close_exit": 0}
            (run / "results.json").write_text(json.dumps(report, indent=2) + "\n")
        finally:
            if process.poll() is None:
                process.kill()
                process.wait()


if __name__ == "__main__":
    exercise(Path(sys.argv[1]))
