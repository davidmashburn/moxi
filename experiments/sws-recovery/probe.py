"""Interrupt the pinned consumer's real save calls in disposable child processes."""
import argparse
from contextlib import chdir, closing
from datetime import datetime, timezone
from enum import Enum
import hashlib
import json
import os
from pathlib import Path
import platform
import signal
import subprocess
import sys
import tempfile
from unittest.mock import patch

from sws import persistence
from sws.app import Action, App
from sws.contracts import EditKind
from sws.model import Document
from sws.worker import compute


class Target(Enum):
    PRIMARY = "cells.json"
    PREVIOUS = "cells.json.previous"
    CHECKPOINT = "cells.json.recovery"
    RECOVERED = "recovered.json"


class Edge(Enum):
    BEFORE = "before"
    AFTER = "after"


PRIMARY = Path(Target.PRIMARY.value)
SCRIPT = Path(__file__).resolve()


def sha(data):
    return hashlib.sha256(data).hexdigest()


def check(condition, message):
    if not condition:
        raise AssertionError(message)


def advance(doc):
    doc.edit(EditKind.PLACE, x=90, y=20)
    check(doc.accept(compute(doc.request())), "watershed rejected")


def seed_case(target):
    doc = Document.fixture()
    doc.dataset = "p07-synthetic"
    persistence.save(doc, PRIMARY)
    initial = sha(persistence.encode(doc))
    doc.edit(EditKind.PLACE, x=80, y=25)
    persistence.save(doc, PRIMARY)
    persistence.save(doc, PRIMARY, recovery=True)
    saved = sha(persistence.encode(doc))
    advance(doc)
    if target is not Target.CHECKPOINT:
        persistence.save(doc, PRIMARY, recovery=True)
    return initial, saved, sha(persistence.encode(doc))


def interrupt(target, edge):
    doc = persistence.reopen(PRIMARY)
    advance(doc)
    name = "link" if target is Target.RECOVERED else "replace"
    publish = getattr(os, name)

    def injected(src, dst):
        if Path(dst) == Path(target.value):
            if edge is Edge.AFTER:
                publish(src, dst)
            os.kill(os.getpid(), signal.SIGKILL)
        return publish(src, dst)

    with patch.object(os, name, injected):
        if target is Target.RECOVERED:
            persistence.save(persistence.reopen(PRIMARY, recover=True), target.value, exclusive=True)
        else:
            persistence.save(doc, PRIMARY, recovery=target is Target.CHECKPOINT)
    raise AssertionError("publication hook missed")


def native_flow(out, checkpoint):
    def click(action):
        x, y, w, h = app.buttons[action]
        for down in (1, 0):
            check(app.native.sws_inject_pointer(app.native.owner, down, x+w/2, y+h/2),
                  f"native pointer failed for {action}")
        app.tick()

    originals = {p: sha(p.read_bytes()) for p in Path(".").glob("cells.json*")}
    with closing(App(PRIMARY)) as app:
        app.draw()
        click(Action.RECOVER)
        check(app.doc.dirty and app.new_recovered_file and not app.path.exists(), "recover")
        check(sha(persistence.encode(app.doc)) == checkpoint, "recovery payload")
        app.native.capture(out / "interrupted-save-recovery.png")
        size = [app.native.width(), app.native.height()]
        click(Action.SAVE)
        check(not app.doc.dirty and app.path != PRIMARY, "save to fresh sibling")
        check(sha(app.path.read_bytes()) == checkpoint, "new sibling payload")
        prior = app.doc.session
        click(Action.REOPEN)
        check(app.doc.session != prior and sha(persistence.encode(app.doc)) == checkpoint, "reopen")
        check(all(sha(p.read_bytes()) == h for p, h in originals.items()), "sources changed")
        return {"controls": ["Recover", "Save", "Reopen"], "reopened_payload": checkpoint,
                "sources_preserved": len(originals), "viewport_points": size,
                "capture_sha256": sha((out / "interrupted-save-recovery.png").read_bytes())}


def run_case(target, edge, out):
    initial, saved, edited = seed_case(target)
    result = subprocess.run([sys.executable, str(SCRIPT), "--interrupt", target.value, edge.value],
                            timeout=30)
    check(result.returncode == -signal.SIGKILL, f"child status {result.returncode}")
    published = edge is Edge.AFTER
    previous_replaced = target is Target.PRIMARY or (target is Target.PREVIOUS and published)
    expected = {
        Target.PRIMARY: edited if target is Target.PRIMARY and published else saved,
        Target.PREVIOUS: saved if previous_replaced else initial,
        Target.CHECKPOINT: saved if target is Target.CHECKPOINT and not published else edited,
        Target.RECOVERED: edited if target is Target.RECOVERED and published else None,
    }
    versions = {initial: "initial", saved: "saved", edited: "edited", None: "absent"}
    actual = {}
    for key, required in expected.items():
        p = Path(key.value)
        observed = sha(p.read_bytes()) if p.exists() else None
        check(observed == required, f"{target} {edge} {p}: {observed} != {required}")
        if observed:
            check(sha(persistence.encode(persistence.read(p))) == observed, f"decode {p}")
        actual[key.value] = versions[observed]
    check(sha(persistence.encode(persistence.reopen(PRIMARY, recover=True))) ==
          expected[Target.CHECKPOINT], "explicit recovery selected wrong document")
    row = {"target": target.value, "edge": edge.value, "child_status": result.returncode,
           "observed": actual, "temporary_files_left": len(list(Path(".").glob(".moxi-sws-*")))}
    if target is Target.PRIMARY and edge is Edge.BEFORE:
        row["native"] = native_flow(out, edited)
        row["document_sha256"] = {"initial": initial, "saved": saved, "edited": edited}
    return row


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", nargs="?", type=Path)
    parser.add_argument("--interrupt", nargs=2, help=argparse.SUPPRESS)
    args = parser.parse_args()
    if args.interrupt:
        interrupt(Target(args.interrupt[0]), Edge(args.interrupt[1]))
        return
    if args.output is None:
        parser.error("supply an output directory")
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    records = []
    for target in Target:
        for edge in Edge:
            with tempfile.TemporaryDirectory(prefix="sws-probe-") as root, chdir(root):
                records.append(run_case(target, edge, out))
    app_root = Path(persistence.__file__).resolve().parents[1]
    fixture = app_root / "fixtures/asymmetric.npz"
    library = app_root / "dist/consumer/libmoxi_sws.dylib"
    record = {"utc": datetime.now(timezone.utc).isoformat(), "platform": platform.platform(),
              "python": platform.python_version(), "fixture_sha256": sha(fixture.read_bytes()), "dylib_sha256": sha(library.read_bytes()), "cases": records}
    (out / "interrupted-save.json").write_text(json.dumps(record, indent=2) + "\n")


if __name__ == "__main__":
    main()
