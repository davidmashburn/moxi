"""Exercise the compiled GTK FDG viewer on a fresh, private X11 display."""
from datetime import datetime, timezone
import hashlib
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time

from PIL import Image, ImageGrab

APP = Path(__file__).resolve().parents[2]
VIEWER = APP / "dist/moxi-fdg"
FIXTURE = APP / "tests/fixtures/export.json"
TITLE = r"^Export graph \(\.svg, \.png or \.pdf\)$"


def xdo(*args):
    return subprocess.check_output(["xdotool", *map(str, args)], text=True, timeout=10).strip()


def windows(title):
    found = subprocess.run(["xdotool", "search", "--onlyvisible", "--name", title],
                           capture_output=True, text=True, check=False)
    if found.returncode not in (0, 1):
        raise RuntimeError(found.stderr)
    return found.stdout.splitlines()


def wait(test, description):
    deadline = time.monotonic() + 15
    while time.monotonic() < deadline:
        result = test()
        if result:
            return result
        time.sleep(.1)
    raise TimeoutError(description)


def geometry(window):
    values = dict(line.split("=", 1) for line in xdo("getwindowgeometry", "--shell", window).splitlines())
    return tuple(int(values[key]) for key in ("X", "Y", "WIDTH", "HEIGHT"))


def visible_text(frame, bounds):
    crop = frame.crop(bounds).convert("RGB")
    crop = crop.resize((crop.width * 2, crop.height * 2), Image.Resampling.LANCZOS)
    png = io.BytesIO()
    crop.save(png, format="PNG")
    text = subprocess.check_output(["tesseract", "stdin", "stdout", "-l", "eng", "--psm", "6"],
                                   input=png.getvalue(), stderr=subprocess.PIPE, timeout=10,
                                   env=dict(os.environ, OMP_THREAD_LIMIT="1"))
    return " ".join(text.decode().split())


def capture(root, name, regions):
    # A mapped X11 title, or two equal frames, can precede GTK's first paint.
    # Require text in the actual screen pixels before starting frame stability.
    previous = None
    frame = None
    observed = {}

    def stable_frame():
        nonlocal previous, frame, observed
        time.sleep(.2)
        frame = ImageGrab.grab(xdisplay=os.environ["DISPLAY"])
        if previous is not None and frame.tobytes() == previous.tobytes():
            return frame  # These identical pixels already passed every text check.
        observed = {key: visible_text(frame, region["bounds"]) for key, region in regions.items()}
        # OCR can insert spaces around filename punctuation. Ignore whitespace,
        # but require every expected character; do not use fuzzy text matching.
        painted = all(all("".join(fragment.split()) in "".join(observed[key].split())
                          for fragment in region["contains"])
                      for key, region in regions.items())
        previous = frame if painted else None
        return None

    def retain(suffix, verified):
        path = root / (name + suffix + ".png")
        frame.save(path)
        evidence = dict(captured_utc=datetime.now(timezone.utc).isoformat(),
                        regions=regions, observed=observed, verified=verified,
                        screenshot_sha256=hashlib.sha256(path.read_bytes()).hexdigest())
        path.with_suffix(".json").write_text(json.dumps(evidence, indent=2) + "\n")

    try:
        wait(stable_frame, "painted text and stable display after " + name)
    except TimeoutError:
        retain("-timeout", False)
        raise TimeoutError(f"Expected rendered text after {name}: {regions}; observed: {observed}") from None
    retain("", True)
    return frame


def run(root):
    exports = root / "exports"
    exports.mkdir()
    log = (root / "viewer.log").open("w")
    viewer = subprocess.Popen([VIEWER, FIXTURE], stdout=log, stderr=log, cwd=root)
    try:
        window, = wait(lambda: windows("^Moxi Force Graph$"), "graph window")

        def button(x):
            xdo("windowfocus", "--sync", window, "mousemove", "--window", window,
                x, 70, "click", "1")

        button(70)  # Pause; keep identical live scene geometry for every export.
        xdo("mousemove", "--window", window, 125, 113, "click", "1", "type", "A")
        xdo("mousemove", "--window", window, 310, 113, "click", "1")
        button(575)  # Neighbors of the selected Unicode node.
        for name in ["current.svg", "cancelled.svg", "current.png", "current.pdf", "recovered.svg"]:
            before = {p.name: p.read_bytes() for p in exports.iterdir()}
            button(700)  # Export… in the fixed initial 1100x800 content window.
            panel, = wait(lambda: windows(TITLE), "GTK export chooser for " + name)
            xdo("windowfocus", "--sync", panel)
            xdo("key", "ctrl+l")
            xdo("key", "ctrl+a")
            xdo("type", "--clearmodifiers", str(exports / name))
            x, y, width, height = geometry(panel)
            capture(root, name + "-chooser", {
                "filename": {"bounds": [x, y, x + width, y + 40], "contains": [name]},
                "actions": {"bounds": [x, y + height - 50, x + width, y + height],
                            "contains": ["Cancel", "Save"]},
            })
            if name == "cancelled.svg":
                xdo("key", "Escape")
            else:
                xdo("key", "Return")
            wait(lambda: not windows(TITLE), "chooser response for " + name)
            if name != "cancelled.svg":
                wait(lambda: (exports / name).is_file(), "saved " + name)
            x, y, width, height = geometry(window)
            status = ["Export cancelled"] if name == "cancelled.svg" else ["Saved snapshot:", name]
            frame = capture(root, name + "-result", {
                "status": {"bounds": [x + 16, y + 136, x + width - 16, y + 174], "contains": status},
            })
            if name == "cancelled.svg":
                after = {p.name: p.read_bytes() for p in exports.iterdir()}
                assert after == before, "Cancellation changed destination bytes"
                digests = lambda files: {name: hashlib.sha256(data).hexdigest() for name, data in files.items()}
                (root / "cancellation.json").write_text(json.dumps(dict(
                    destination_bytes_unchanged=True, before=digests(before), after=digests(after)), indent=2) + "\n")
            if name == "current.pdf":
                # No window manager; the 1100x800 client is at the display origin.
                frame.crop((0, 0, 1100, 800)).save(exports / "phase-2.png")
            print("completed", name, flush=True)
        assert sorted(p.name for p in exports.iterdir()) == ["current.pdf", "current.png", "current.svg", "phase-2.png", "recovered.svg"]
    finally:
        viewer.terminate()
        try:
            viewer.wait(timeout=3)
        except subprocess.TimeoutExpired:
            viewer.kill()
            viewer.wait()
        log.close()


def main():
    root = Path(tempfile.mkdtemp(prefix="fdg-dialog-"))
    print(root, flush=True)
    home = root / "home"
    home.mkdir()
    # Never target an existing session, portal, chooser history or display.
    runtime = root / "runtime"
    runtime.mkdir(mode=0o700)
    env = dict(os.environ, PYTHONDONTWRITEBYTECODE="1", XDG_RUNTIME_DIR=str(runtime),
               HOME=str(home), XDG_CONFIG_HOME=str(home / ".config"),
               XDG_DATA_HOME=str(home / ".local/share"), GSETTINGS_BACKEND="memory",
               GTK_USE_PORTAL="0", GDK_BACKEND="x11", GSK_RENDERER="cairo",
               LANG="C.UTF-8", LC_ALL="C.UTF-8")
    subprocess.run(["xvfb-run", "-a", "-s", "-screen 0 1280x1024x24 -nolisten tcp",
                    "dbus-run-session", "--", sys.executable, "-c",
                    "from pathlib import Path; import linux, sys; linux.run(Path(sys.argv[1]))", str(root)],
                   env=env, cwd=Path(__file__).parent, check=True)
    subprocess.run([sys.executable, APP / "tests/verify_artifacts.py", root / "exports"], check=True)
    hashes = {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
              for p in [VIEWER, FIXTURE, *sorted((root / "exports").iterdir())]}
    result = dict(captured_utc=datetime.now(timezone.utc).isoformat(),
                  hashes=hashes, checks=json.loads((root / "exports/export-check.json").read_text()),
                  cancellation=json.loads((root / "cancellation.json").read_text()),
                  captures={p.stem: json.loads(p.read_text())
                            for p in sorted([*root.glob("*-chooser.json"), *root.glob("*-result.json")])})
    (root / "result.json").write_text(json.dumps(result, indent=2) + "\n")


if __name__ == "__main__":
    main()
