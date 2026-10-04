#!/usr/bin/env python3
"""Exercise the compiled Linux workbench through X11 and its opt-in trace.

These are synthetic X11/GTK-simple-input checks. They do not verify physical
scrolling, a Japanese IME, or an AT-SPI accessibility implementation.
"""

import argparse
import datetime
import hashlib
import json
import math
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time


TITLE = "Moxi · Composed layout workbench"
TITLE_PATTERN = "^" + TITLE + "$"
REPO = Path(__file__).resolve().parents[1]
EPSILON = 0.5


class SmokeFailure(RuntimeError):
    pass


def utc_now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def nodes(frame):
    return {node["id"]: node for node in frame["nodes"]}


def focused(frame, key):
    return bool(nodes(frame).get(key, {}).get("focused"))


def require(condition, message):
    if not condition:
        raise SmokeFailure(message)


class Smoke:
    def __init__(self, args, run):
        self.args = args
        self.run = run
        self.trace_path = run / "trace.jsonl"
        self.log_path = run / "app.log"
        self.summary_path = run / "summary.json"
        self.process = None
        self.window = None
        self.log = None
        self.trace_offset = 0
        self.trace_pending = b""
        self.records = []
        self.frames = {}
        self.painted = {}
        self.current_check = "startup"
        self.summary = {
            "status": "running",
            "started_at": utc_now(),
            "app": str(args.app),
            "artifacts": {"trace": str(self.trace_path), "log": str(self.log_path)},
            "checks": [],
            "scope": "synthetic X11 input into the actual compiled GTK4 workbench",
            "not_verified": ["physical keyboard/trackpad input", "real Japanese IME",
                             "AT-SPI accessibility", "Wayland input"],
        }

    def command(self, *args, check=True):
        try:
            result = subprocess.run(["xdotool", *map(str, args)], capture_output=True,
                                    text=True, timeout=self.args.timeout)
        except subprocess.TimeoutExpired as error:
            raise SmokeFailure(f"xdotool timed out: {args[0]}") from error
        if check and result.returncode:
            raise SmokeFailure(f"xdotool {args[0]} failed: {result.stderr.strip()}")
        return result

    def alive(self):
        if self.process is not None and self.process.poll() is not None:
            raise SmokeFailure(f"workbench exited unexpectedly with {self.process.returncode}")

    def read_trace(self):
        if not self.trace_path.exists():
            return
        with self.trace_path.open("rb") as stream:
            stream.seek(self.trace_offset)
            new = stream.read()
            self.trace_offset = stream.tell()
        lines = (self.trace_pending + new).split(b"\n")
        self.trace_pending = lines.pop()
        for line in lines:
            if not line:
                continue
            try:
                record = json.loads(line)
            except (ValueError, UnicodeError) as error:
                raise SmokeFailure("invalid JSONL trace record") from error
            self.records.append(record)
            if record.get("type") == "frame":
                self.validate_frame(record)
                number = record["frame"]
                require(number not in self.frames, f"duplicate frame {number}")
                self.frames[number] = record
            elif record.get("type") == "draw":
                number = record.get("frame")
                require(number in self.frames, f"draw precedes publication for frame {number}")
                self.painted[number] = self.frames[number]

    def validate_frame(self, frame):
        require(isinstance(frame.get("frame"), int), "frame has no integer generation")
        for field in ("width", "height", "canvas_x", "canvas_y"):
            require(isinstance(frame.get(field), (int, float)) and
                    math.isfinite(frame[field]), f"frame has no finite {field}")
        require(frame["width"] > 0 and frame["height"] > 0, "empty published canvas")
        require(frame.get("overflow") == 0 and frame.get("dropped") == 0,
                "native frame reports overflow or dropped events")
        require(isinstance(frame.get("nodes"), list), "frame has no semantic nodes")
        seen = set()
        for node in frame["nodes"]:
            require(isinstance(node.get("id"), int) and node["id"] not in seen,
                    "missing or duplicate semantic node id")
            seen.add(node["id"])
            for field in ("x", "y", "width", "height"):
                require(isinstance(node.get(field), (int, float)) and
                        math.isfinite(node[field]), f"node {node['id']} has invalid {field}")
            require(node["width"] >= 0 and node["height"] >= 0,
                    f"node {node['id']} has negative dimensions")

    def wait(self, description, predicate):
        deadline = time.monotonic() + self.args.timeout
        while True:
            self.alive()
            self.read_trace()
            result = predicate()
            if result is not None and result is not False:
                return result
            if time.monotonic() >= deadline:
                raise SmokeFailure(f"timed out waiting for {description}")
            time.sleep(0.05)

    def frame(self, after=0, predicate=lambda frame: True, description="fresh painted frame"):
        def find():
            for number in sorted(self.painted, reverse=True):
                if number > after and predicate(self.painted[number]):
                    return self.painted[number]
            return None
        return self.wait(description, find)

    def event(self, since, kind, target=None, axis=None, text=None):
        return any(record.get("type") == "event" and record.get("kind") == kind and
                   (target is None or record.get("target") == target) and
                   (axis is None or record.get(axis, 0) > 0) and
                   (text is None or text in record.get("text", ""))
                   for record in self.records[since:])

    def mark(self):
        self.alive()
        self.read_trace()
        return len(self.records)

    def point(self, frame, key, clip_key=None):
        node = nodes(frame).get(key)
        require(node is not None, f"node {key} is not published")
        left = max(0, node["x"])
        top = max(0, node["y"])
        right = min(frame["width"], node["x"] + node["width"])
        bottom = min(frame["height"], node["y"] + node["height"])
        if clip_key is not None:
            clip = nodes(frame).get(clip_key)
            require(clip is not None, f"clip node {clip_key} is not published")
            left = max(left, clip["x"])
            top = max(top, clip["y"])
            right = min(right, clip["x"] + clip["width"])
            bottom = min(bottom, clip["y"] + clip["height"])
        require(right - left > 2 and bottom - top > 2, f"node {key} has no clickable area")
        return round(frame["canvas_x"] + (left + right) / 2), \
            round(frame["canvas_y"] + (top + bottom) / 2)

    def click(self, frame, key, *following, clip_key=None):
        x, y = self.point(frame, key, clip_key)
        self.command("mousemove", "--window", self.window, x, y,
                     "click", "1", *following)

    def focus_dataset(self, frame):
        self.click(frame, 13)
        return self.frame(frame["frame"], lambda current: focused(current, 13),
                          "Dataset focus")

    def composition(self, frame, key=13):
        node = nodes(frame).get(key)
        require(node is not None and isinstance(node.get("composition"), str),
                f"node {key} lacks traced composition state")
        return node["composition"]

    def begin_preedit(self, frame, key=13):
        self.command("key", "--clearmodifiers", "--delay", "0", "ctrl+shift+u",
                     "type", "--clearmodifiers", "--delay", "0", "3042")
        return self.frame(frame["frame"], lambda current: focused(current, key) and
                          "3042" in self.composition(current, key), "GTK simple preedit")

    def visible_cell(self, frame, exclude=None):
        candidates = [key for key in nodes(frame) if key >= 1020 and
                      (key - 1000) % 10 == 2 and key != exclude]
        for candidate in sorted(candidates):
            try:
                self.point(frame, candidate, 21)
            except SmokeFailure:
                continue
            return candidate
        raise SmokeFailure("no visible non-header column-2 cell is available")

    def passed(self, name, **evidence):
        self.summary["checks"].append({"name": name, "status": "pass", **evidence})
        print(f"PASS {name}", flush=True)

    def start(self):
        require(os.environ.get("DISPLAY"), "DISPLAY is required for X11 automation")
        require(shutil.which("xdotool"), "xdotool is required")
        require(self.args.app.is_file() and os.access(self.args.app, os.X_OK),
                f"compiled executable is unavailable: {self.args.app}")
        if self.args.screenshot:
            require(shutil.which("xfce4-screenshooter"),
                    "--screenshot requires xfce4-screenshooter")
        existing = self.command("search", "--onlyvisible", "--name", TITLE_PATTERN, check=False)
        require(existing.returncode == 1 and not existing.stdout.strip(),
                "an existing workbench window or an X11 search error prevents isolated testing")
        self.summary["executable_sha256"] = hashlib.sha256(self.args.app.read_bytes()).hexdigest()
        env = os.environ.copy()
        env.update(GTK_IM_MODULE="simple", GSK_RENDERER="cairo", GDK_BACKEND="x11",
                   MOXI_LINUX_TRACE_FILE=str(self.trace_path))
        self.summary["environment"] = {key: env[key] for key in
                                       ("DISPLAY", "GTK_IM_MODULE", "GSK_RENDERER", "GDK_BACKEND")}
        self.log = self.log_path.open("wb")
        self.process = subprocess.Popen([str(self.args.app)], cwd=REPO, env=env,
                                        stdout=self.log, stderr=subprocess.STDOUT)
        self.summary["pid"] = self.process.pid

        def find_window():
            result = self.command("search", "--all", "--onlyvisible", "--pid", self.process.pid,
                                  "--name", TITLE_PATTERN, check=False)
            require(result.returncode in (0, 1), "X11 window search failed")
            found = result.stdout.split()
            require(len(found) <= 1, "multiple workbench windows belong to the launched process")
            return found[0] if found else None

        self.window = self.wait("visible workbench window", find_window)
        require(self.command("getwindowname", self.window).stdout.strip() == TITLE,
                "visible window title does not match")
        require(int(self.command("getwindowpid", self.window).stdout.strip()) == self.process.pid,
                "visible window does not belong to the launched process")
        self.summary["window"] = self.window
        self.command("windowactivate", "--sync", self.window)
        frame = self.frame(description="initial publication and matching draw")
        require(focused(frame, 13), "initial Dataset editor is not focused")
        require(nodes(frame)[10]["x"] < nodes(frame)[20]["x"], "initial panes are not LTR")
        self.passed("visible_drawn_workbench", frame=frame["frame"],
                    canvas=[frame["width"], frame["height"]],
                    canvas_offset=[frame["canvas_x"], frame["canvas_y"]])
        return frame

    def exercise(self, frame):
        self.current_check = "summary_reflow"
        previous_y = nodes(frame)[8]["y"]
        self.click(frame, 40)
        frame = self.frame(frame["frame"], lambda current: nodes(current)[8]["y"] >
                           previous_y + EPSILON, "summary reflow")
        self.passed(self.current_check, frame=frame["frame"], before_y=previous_y,
                    after_y=nodes(frame)[8]["y"])

        self.current_check = "rtl_pane_order"
        self.click(frame, 41)
        frame = self.frame(frame["frame"], lambda current: nodes(current)[10]["x"] >
                           nodes(current)[20]["x"], "RTL pane order")
        self.passed(self.current_check, frame=frame["frame"],
                    form_x=nodes(frame)[10]["x"], results_x=nodes(frame)[20]["x"])

        self.current_check = "tab_focus"
        frame = self.focus_dataset(frame)
        self.command("key", "--clearmodifiers", "Tab")
        frame = self.frame(frame["frame"], lambda current: focused(current, 40), "Summary Tab focus")
        self.passed(self.current_check, frame=frame["frame"], focused=40)

        self.current_check = "rapid_tab_space_routing"
        frame = self.focus_dataset(frame)
        dataset = nodes(frame)[13]["value"]
        previous_y = nodes(frame)[8]["y"]
        self.command("key", "--clearmodifiers", "--delay", "0", "Tab", "space")
        frame = self.frame(frame["frame"], lambda current: focused(current, 40) and
                           nodes(current)[8]["y"] < previous_y - EPSILON,
                           "rapid Tab+Space activation")
        require(nodes(frame)[13]["value"] == dataset, "rapid Tab+Space inserted into Dataset")
        self.passed(self.current_check, frame=frame["frame"], dataset_unchanged=True,
                    summary_reflowed=True, focused=40)

        self.current_check = "gtk_simple_unicode_input"
        frame = self.focus_dataset(frame)
        before = nodes(frame)[13]["value"]
        since = self.mark()
        old_frame = frame["frame"]
        frame = self.begin_preedit(frame)
        self.command("key", "--clearmodifiers", "Return")
        frame = self.frame(old_frame, lambda current: nodes(current)[13]["value"] != before and
                           "あ" in nodes(current)[13]["value"] and
                           self.composition(current) == "" and
                           self.event(since, 8, 13) and self.event(since, 3, 13, text="あ"),
                           "addressed Unicode commit")
        self.passed(self.current_check, frame=frame["frame"], target=13,
                    composition_event_kind=8, text_event_kind=3, committed="あ")

        self.current_check = "preedit_focus_cancellation"
        before = nodes(frame)[13]["value"]
        frame = self.begin_preedit(frame)
        since = self.mark()
        self.command("key", "--clearmodifiers", "Tab")
        frame = self.frame(frame["frame"], lambda current: focused(current, 40) and
                           self.composition(current) == "" and self.event(since, 9, 13),
                           "addressed preedit cancellation on focus change")
        require(nodes(frame)[13]["value"] == before, "focus change committed cancelled preedit")
        self.command("key", "--clearmodifiers", "shift+Tab")
        frame = self.frame(frame["frame"], lambda current: focused(current, 13) and
                           self.composition(current) == "", "clean Dataset focus restoration")
        require(nodes(frame)[13]["value"] == before, "returning focus changed Dataset")
        self.passed(self.current_check, frame=frame["frame"], target=13,
                    composition_end_event_kind=9, dataset_unchanged=True)

        self.current_check = "resize_preserves_preedit_and_stacks_panes"
        frame = self.begin_preedit(frame)
        preedit = self.composition(frame)
        before = nodes(frame)[13]["value"]
        self.command("windowsize", self.window, "540", "900")
        frame = self.frame(frame["frame"], lambda current: current["width"] < 760 and
                           nodes(current)[20]["y"] >= nodes(current)[10]["y"] +
                           nodes(current)[10]["height"] - EPSILON,
                           "narrow stacked pane publication")
        require(focused(frame, 13) and self.composition(frame) == preedit,
                "same-key resize lost Dataset preedit or focus")
        require(nodes(frame)[13]["value"] == before, "resize committed pending preedit")
        geometry = self.command("getwindowgeometry", "--shell", self.window).stdout
        actual = dict(line.split("=", 1) for line in geometry.splitlines() if "=" in line)
        require(actual.get("WIDTH") == "540" and actual.get("HEIGHT") == "900",
                "X11 window did not resize to 540x900")
        self.passed(self.current_check, frame=frame["frame"], requested=[540, 900],
                    canvas=[frame["width"], frame["height"]], preedit_preserved=preedit,
                    form_y=nodes(frame)[10]["y"], results_y=nodes(frame)[20]["y"])
        since = self.mark()
        self.command("key", "--clearmodifiers", "Return")
        frame = self.frame(frame["frame"], lambda current: self.composition(current) == "" and
                           nodes(current)[13]["value"] != before and
                           self.event(since, 3, 13, text="あ"), "post-resize Unicode commit")

        self.current_check = "modal_scope_and_preedit_cancellation"
        before = nodes(frame)[13]["value"]
        frame = self.begin_preedit(frame)
        since = self.mark()
        self.click(frame, 46)
        frame = self.frame(frame["frame"], lambda current: nodes(current).get(90, {}).get("role") == 18
                           and 13 not in nodes(current) and self.event(since, 9, 13),
                           "modal scope and addressed background composition cleanup")
        require(any(focused(frame, key) for key in (92, 93, 94)), "modal controls are not focused")
        modal_frame = frame["frame"]
        self.command("key", "--clearmodifiers", "Escape")
        frame = self.frame(frame["frame"], lambda current: 90 not in nodes(current) and
                           focused(current, 13) and self.composition(current) == "",
                           "modal dismissal and clean Dataset focus restoration")
        require(nodes(frame)[13]["value"] == before, "modal cancellation changed Dataset text")
        self.passed(self.current_check, modal_frame=modal_frame, restored_frame=frame["frame"],
                    dialog_id=90, dialog_role=18, background_dataset_absent=True,
                    restored_focus=13, composition_cleared=True, dataset_unchanged=True)

        self.current_check = "rapid_cell_click_type_routing"
        cell = self.visible_cell(frame)
        dataset = nodes(frame)[13]["value"]
        since = self.mark()
        self.click(frame, cell, "type", "--clearmodifiers", "--delay", "0", "q", clip_key=21)
        frame = self.frame(frame["frame"], lambda current: focused(current, cell) and
                           "q" in nodes(current).get(cell, {}).get("value", "") and
                           self.event(since, 3, cell, text="q"), "addressed cell click+type")
        require(nodes(frame)[13]["value"] == dataset, "cell click+type changed Dataset")
        self.passed(self.current_check, frame=frame["frame"], target=cell,
                    text_event_kind=3, dataset_unchanged=True)

        self.current_check = "cell_preedit_row_switch_cancellation"
        committed = nodes(frame)[cell]["value"]
        frame = self.begin_preedit(frame, cell)
        next_cell = self.visible_cell(frame, exclude=cell)
        since = self.mark()
        self.click(frame, next_cell, clip_key=21)
        frame = self.frame(frame["frame"], lambda current: focused(current, next_cell) and
                           self.composition(current, next_cell) == "" and
                           self.event(since, 9, cell), "row-switch cell preedit cancellation")
        require(nodes(frame)[next_cell]["value"] == committed,
                "row switch committed cancelled cell preedit")
        require(nodes(frame)[13]["value"] == dataset, "cell row switch changed Dataset")
        self.passed(self.current_check, frame=frame["frame"], old_target=cell,
                    new_target=next_cell, composition_end_event_kind=9,
                    composition_cleared=True, committed_cell_text_unchanged=True,
                    dataset_unchanged=True)
        frame = self.focus_dataset(frame)

        frame = self.scroll(frame, "horizontal_scroll", "7", "dx", "x")
        frame = self.scroll(frame, "vertical_scroll", "5", "dy", "y")
        if self.args.screenshot:
            self.current_check = "desktop_screenshot"
            self.args.screenshot.parent.mkdir(parents=True, exist_ok=True)
            result = subprocess.run(["xfce4-screenshooter", "-f", "-s", str(self.args.screenshot)],
                                    capture_output=True, text=True, timeout=self.args.timeout)
            require(result.returncode == 0 and self.args.screenshot.is_file() and
                    self.args.screenshot.stat().st_size > 0, "desktop screenshot was not saved")
            self.summary["artifacts"]["screenshot"] = str(self.args.screenshot)
            self.passed(self.current_check, path=str(self.args.screenshot), frame=frame["frame"])

    def scroll(self, frame, name, button, delta, position):
        self.current_check = name
        before = nodes(frame)
        since = self.mark()
        x, y = self.point(frame, 21)
        self.command("mousemove", "--window", self.window, x, y, "click", button)

        def changes(current):
            after = nodes(current)
            return [key for key in before.keys() & after.keys() if key >= 1000 and
                    ((key - 1000) % 10 != 1 if position == "x" else (key - 1000) // 10 > 1) and
                    abs(after[key][position] - before[key][position]) > EPSILON]

        frame = self.frame(frame["frame"], lambda current: self.event(since, 11, axis=delta) and
                           bool(changes(current)), f"positive {delta} event and {position} geometry change")
        evidence = {"frame": frame["frame"], "button": int(button), "positive_event_axis": delta,
                    "changed_cell_ids": sorted(changes(frame))}
        if position == "x":
            after = nodes(frame)
            frozen = sorted(key for key in before.keys() & after.keys() if key >= 1000 and
                            (key - 1000) % 10 == 1)
            if frozen:
                require(all(abs(after[key]["x"] - before[key]["x"]) <= EPSILON for key in frozen),
                        "frozen first-column cells moved horizontally")
                evidence["frozen_first_column_ids"] = frozen
                evidence["frozen_first_column_unchanged"] = True
            else:
                evidence["frozen_first_column"] = "not observed: no common first-column nodes"
        self.passed(name, **evidence)
        return frame

    def close(self):
        self.current_check = "clean_window_close"
        self.command("windowactivate", "--sync", self.window,
                     "key", "--clearmodifiers", "alt+F4")
        try:
            code = self.process.wait(timeout=self.args.timeout)
        except subprocess.TimeoutExpired as error:
            raise SmokeFailure("workbench did not exit after window-manager Alt+F4") from error
        require(code == 0, f"workbench Alt+F4 close exited with {code}")
        self.summary["returncode"] = code
        self.passed(self.current_check, returncode=code)

    def cleanup(self):
        if self.process is not None and self.process.poll() is None:
            if self.window:
                try:
                    self.command("windowactivate", "--sync", self.window,
                                 "key", "--clearmodifiers", "alt+F4", check=False)
                    self.process.wait(timeout=3)
                except (SmokeFailure, subprocess.TimeoutExpired):
                    pass
            if self.process.poll() is None:
                self.summary["forced_cleanup"] = True
                self.process.terminate()
                try:
                    self.process.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    self.process.kill()
                    self.process.wait(timeout=3)
        if self.process is not None:
            self.summary["returncode"] = self.process.returncode
        if self.log:
            self.log.close()

    def save(self):
        self.summary["finished_at"] = utc_now()
        self.summary_path.write_text(json.dumps(self.summary, indent=2, ensure_ascii=False) + "\n")
        print(f"Summary: {self.summary_path}", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app", type=Path, default=REPO / "dist/layout-workbench-linux")
    parser.add_argument("--artifacts", type=Path, default=REPO / "dist/linux-native-artifacts")
    parser.add_argument("--timeout", type=float, default=20,
                        help="bounded wait per operation in seconds (default: 20; maximum: 60)")
    parser.add_argument("--screenshot", type=Path,
                        help="optionally save a full-desktop screenshot with xfce4-screenshooter")
    args = parser.parse_args()
    if not math.isfinite(args.timeout) or not 1 <= args.timeout <= 60:
        parser.error("--timeout must be between 1 and 60 seconds")
    args.app = args.app.resolve()
    args.artifacts = args.artifacts.resolve()
    if args.screenshot:
        args.screenshot = args.screenshot.resolve()
    args.artifacts.mkdir(parents=True, exist_ok=True)
    run = Path(tempfile.mkdtemp(prefix="ui-", dir=args.artifacts))
    smoke = Smoke(args, run)
    code = 1
    try:
        frame = smoke.start()
        smoke.exercise(frame)
        smoke.close()
        smoke.summary["status"] = "pass"
        code = 0
    except (SmokeFailure, OSError, ValueError, KeyError, subprocess.TimeoutExpired) as error:
        smoke.summary.update(status="fail", error=str(error))
        smoke.summary["checks"].append({"name": smoke.current_check, "status": "fail",
                                       "error": str(error)})
        print(f"FAIL {smoke.current_check}: {error}", file=sys.stderr, flush=True)
    except KeyboardInterrupt:
        smoke.summary.update(status="interrupted", error="interrupted")
        code = 130
    finally:
        smoke.cleanup()
        smoke.save()
    return code


if __name__ == "__main__":
    raise SystemExit(main())
