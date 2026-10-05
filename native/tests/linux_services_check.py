#!/usr/bin/env python3
"""Inspect the real GTK AT-SPI tree and external X11 clipboard service.

Run within a display and DBus session, for example:
  dbus-run-session -- xvfb-run -a /usr/bin/python3 native/tests/linux_services_check.py
Ubuntu prerequisites: python3-pyatspi xclip xdotool dbus-x11 xvfb openbox.
The window manager must be running for the native focus assertions.
"""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time

import pyatspi


def wait_until(probe, message, timeout=20):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        result = probe()
        if result:
            return result
        time.sleep(0.1)
    raise AssertionError(message)


def descendants(node):
    pending = [node]
    while pending:
        current = pending.pop()
        yield current
        try:
            pending.extend(current[index] for index in range(current.childCount))
        except Exception:
            pass  # An unrelated desktop application may disappear mid-query.


def find_nodes():
    for node in descendants(pyatspi.Registry.getDesktop(0)):
        if node.name == "Service group":
            return {child.name: child for child in descendants(node)}
    return None


def main():
    if not os.environ.get("DISPLAY") or not os.environ.get("DBUS_SESSION_BUS_ADDRESS"):
        raise RuntimeError("This check requires an X11 display and DBus session; use dbus-run-session and xvfb-run.")
    for command in ("xclip", "xdotool"):
        if not shutil.which(command):
            raise RuntimeError(f"Missing {command}; install the Ubuntu {command} package.")
    binary = Path(sys.argv[1] if len(sys.argv) > 1 else "dist/moxi-linux-services-test").resolve()
    with tempfile.TemporaryDirectory(prefix="moxi-native-services-") as directory:
        finish = Path(directory) / "finish"
        log_path = Path(directory) / "fixture.log"
        env = dict(os.environ, GTK_A11Y="atspi", GDK_BACKEND="x11", MOXI_SERVICES_FINISH_FILE=str(finish))
        with log_path.open("w+") as log:
            process = subprocess.Popen([str(binary), "--fixture"], env=env, stdout=log, stderr=log)
            try:
                def ready():
                    assert process.poll() is None, log_path.read_text()
                    return "READY" in log_path.read_text()

                wait_until(ready, "GTK service fixture did not become ready")
                windows = subprocess.check_output(["xdotool", "search", "--name", "^Moxi desktop service fixture$"], text=True).split()
                assert windows, "Fixture window not found"
                subprocess.run(["xdotool", "windowactivate", "--sync", windows[-1]], check=True, timeout=10)
                nodes = wait_until(find_nodes, "Published semantics not found through the external AT-SPI registry")
                group = nodes["Service group"]
                button = nodes["Invoke service"]
                disabled = nodes["Disabled service"]
                checked = nodes["Checked service"]
                editor = nodes["Service editor"]
                assert button.parent == group and editor.parent == group
                assert button.getRole() == pyatspi.ROLE_PUSH_BUTTON, button.getRoleName()
                assert checked.getRole() == pyatspi.ROLE_CHECK_BOX, checked.getRoleName()
                assert editor.getRole() in (pyatspi.ROLE_TEXT, pyatspi.ROLE_ENTRY), editor.getRoleName()
                assert button.description == "action hint" and editor.description == "editor hint"
                # GTK 4.14 maps its DISABLED state to AT-SPI SENSITIVE.
                assert button.getState().contains(pyatspi.STATE_SENSITIVE)
                assert not disabled.getState().contains(pyatspi.STATE_SENSITIVE)
                assert checked.getState().contains(pyatspi.STATE_CHECKED)
                assert checked.getState().contains(pyatspi.STATE_SELECTED)
                text = editor.queryText()
                assert text.getText(0, -1) == "A🙂日"
                assert text.characterCount == 3 and text.caretOffset == 2
                assert text.getNSelections() == 1 and text.getSelection(0) == (1, 2)
                wait_until(lambda: editor.getState().contains(pyatspi.STATE_FOCUSED), "Published editor focus not exposed")
                # GTK 4.14 exposes window-relative bounds; its AT-SPI backend
                # deliberately reports (0,0) for screen coordinates.
                group_box = group.queryComponent().getExtents(pyatspi.WINDOW_COORDS)
                button_box = button.queryComponent().getExtents(pyatspi.WINDOW_COORDS)
                assert (button_box.x-group_box.x, button_box.y-group_box.y, button_box.width, button_box.height) == (20, 20, 120, 32), (group_box, button_box)
                print("External AT-SPI hierarchy, roles, hints, enabled/checked/selected state, UTF-8 text/caret/selection, focus and window-relative bounds: pass")

                # A focused non-canvas proxy must still route keys to Mojo's
                # window capture controller, including the native IM service.
                subprocess.run(["xdotool", "key", "--clearmodifiers", "Left"], check=True, timeout=10)
                wait_until(lambda: "KEY key=1000" in log_path.read_text(), "Focused semantic proxy swallowed keyboard navigation")
                print("Focused GTK semantic proxy preserves portable keyboard routing: pass")
                subprocess.run(["xclip", "-selection", "clipboard"], input="outside🙂日", text=True, check=True, timeout=10)
                action = button.queryAction()
                actions = [action.getName(index) for index in range(action.nActions)]
                index = next(index for index, name in enumerate(actions) if name.endswith("press"))
                assert action.doAction(index)
                wait_until(lambda: "ACTION target=41 action=1" in log_path.read_text(), "External AT-SPI action did not enqueue its stable Mojo target")
                wait_until(lambda: button.getState().contains(pyatspi.STATE_FOCUSED), "Action publication did not move native accessibility focus")
                value = subprocess.check_output(["xclip", "-selection", "clipboard", "-out"], text=True, timeout=10)
                assert value == "Moxi🙂日", value
                print("External AT-SPI activation enqueues ACTION target=41 action=1; external Unicode clipboard read/write and snapshot stability: pass")
                finish.touch()
                assert process.wait(timeout=10) == 0, log_path.read_text()
            finally:
                if process.poll() is None:
                    process.terminate()
                    process.wait(timeout=5)
                print(log_path.read_text().strip())


if __name__ == "__main__":
    main()
