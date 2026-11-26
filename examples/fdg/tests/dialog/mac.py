"""Bounded AppKit replay in the real viewer, with a trusted external input driver.

Run with Pillow, pypdfium2, Tesseract and rsvg-convert after scripts/build.sh.
For each ready request.json, inspect the real chooser and send Return or Escape with
the native automation tool. --local-events tries process-local NSEvents instead.
No TCC permissions are requested, panel responses stubbed, or exporters called.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

HERE = Path(__file__).resolve().parent
APP = HERE.parents[1]
SCENARIOS = [f"{stem}.{ext}" for ext in ("svg", "png", "pdf")
             for stem in ("current", "cancelled", "recovered")]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def verify(root):
    # Reuse the platform-independent SVG, PNG, PDF and native-ink assertions.
    sys.path.insert(0, str(APP / "tests"))
    from verify_artifacts import verify as verify_exports
    from linux import visible_text
    from PIL import Image, ImageChops
    import pypdfium2 as pdfium

    exports = root / "exports"
    expected = {name for name in SCENARIOS if not name.startswith("cancelled")}
    assert {p.name for p in exports.iterdir()} == expected
    steps = []
    previous = {}
    for name in SCENARIOS:
        response = json.loads((root / (name + "-response.json")).read_text())
        result = json.loads((root / (name + "-result.json")).read_text())
        cancel = name.startswith("cancelled")
        assert response["cancel"] is cancel
        assert response["response"] == (0 if cancel else 1)
        assert response["destination"] == str(exports / name)
        if not cancel:
            assert Path(response["selected_path"]).resolve() == exports / name
        assert response["before"] == previous
        after = dict(previous)
        if not cancel:
            after[name] = sha(exports / name)
        assert result["after"] == after
        assert result["destination_bytes_unchanged"] is cancel
        expected_status = "Export cancelled" if cancel else "Saved snapshot: " + response["selected_path"]
        assert expected_status in result["status"]
        with Image.open(root / (name + "-result.png")) as image:
            assert list(image.size) == [int(v * result["backing_scale"]) for v in result["content_bounds"]]
            scale = result["backing_scale"]
            painted = visible_text(image, tuple(int(v * scale) for v in (16, 136, 1084, 174)))
        # A correct AX label alone cannot establish that the result was painted.
        fragments = ["Export cancelled"] if cancel else ["Saved snapshot:", name]
        assert all("".join(fragment.split()) in "".join(painted.split()) for fragment in fragments), painted
        steps.append(dict(filename=name, response=response, result=result, painted_status=painted))
        previous = after
    assert (exports / "current.png").read_bytes() == (exports / "recovered.png").read_bytes()
    shutil.copyfile(root / "current.pdf-result.png", exports / "phase-2.png")
    verify_exports(exports)
    current = pdfium.PdfDocument(exports / "current.pdf")
    recovered = pdfium.PdfDocument(exports / "recovered.pdf")
    assert len(current) == len(recovered) == 1
    assert current[0].get_size() == recovered[0].get_size()
    assert current[0].get_textpage().get_text_range() == recovered[0].get_textpage().get_text_range()
    a, b = (pdf[0].render(scale=96/72).to_pil().convert("RGB") for pdf in (current, recovered))
    assert ImageChops.difference(a, b).getbbox() is None
    return dict(steps=steps, svg_recovery_byte_identical=True, png_recovery_byte_identical=True,
                pdf_recovery_text_geometry_raster_identical=True,
                export_check=json.loads((exports / "export-check.json").read_text()))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--local-events", action="store_true")
    args = parser.parse_args()
    root = Path(tempfile.mkdtemp(prefix="fdg-appkit-", dir="/tmp")).resolve()
    print(root, flush=True)
    (root / "exports").mkdir()
    (root / "home").mkdir()
    probe = root / "probe.dylib"
    subprocess.run(["clang", "-dynamiclib", "-Wall", "-Wextra", "-Werror", "-fobjc-arc",
                    "-framework", "Cocoa", "-framework", "ApplicationServices",
                    HERE / "mac.m", "-o", probe], check=True)
    bundle = APP / "dist/Moxi Force Graph.app"
    binary = bundle / "Contents/MacOS/moxi-fdg"
    fixture = APP / "tests/fixtures/export.json"
    repo = APP.parents[1]
    sources = [p for folder in (repo / "src", repo / "native", APP / "src", APP / "native")
               for p in folder.rglob("*") if p.is_file()]
    record = dict(started_utc=datetime.now(timezone.utc).isoformat(),
                  revision=subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=repo, text=True).strip(),
                  dirty=subprocess.check_output(["git", "status", "--porcelain"], cwd=repo, text=True).splitlines(),
                  os=subprocess.check_output(["sw_vers"], text=True),
                  binary_sha256=sha(binary), fixture_sha256=sha(fixture),
                  application_sources={str(p.relative_to(repo)): sha(p) for p in sorted(sources)},
                  replay_sources={p.name: sha(p) for p in (HERE / "mac.py", HERE / "mac.m")},
                  input_mode="local" if args.local_events else "external",
                  user_data="synthetic four-node fixture in a fresh private /tmp directory",
                  url="native AppKit window; no server", viewport=[1100, 800])
    (root / "verification.json").write_text(json.dumps(record, indent=2) + "\n")
    environment = dict(os.environ, DYLD_INSERT_LIBRARIES=str(probe), FDG_DIALOG_DIR=str(root),
                       HOME=str(root / "home"),
                       FDG_DIALOG_LOCAL_EVENTS="1" if args.local_events else "")
    print("Inspect request.json and the chooser, then send Return/ Escape using native automation.", flush=True)
    try:
        # Own the child directly. `open -W` can report success for an app that
        # exits nonzero and can leave it running when the launcher times out.
        with (root / "viewer.log").open("w") as log:
            subprocess.run([binary, fixture], cwd=root, env=environment, stdout=log, stderr=log,
                           check=True, timeout=len(SCENARIOS) * 200)
        assert json.loads((root / "complete.json").read_text()) == {"scenarios": len(SCENARIOS)}
        result = dict(passed=True, **verify(root))
    except Exception as error:
        failure = root / "failure.json"
        result = dict(passed=False, error_type=type(error).__name__, error=str(error),
                      failure=json.loads(failure.read_text()) if failure.exists() else None,
                      completed_steps=[name for name in SCENARIOS if (root / (name + "-result.json")).exists()])
        (root / "result.json").write_text(json.dumps(result, indent=2) + "\n")
        raise SystemExit("INCOMPLETE: see result.json and viewer.log in " + str(root)) from None
    (root / "result.json").write_text(json.dumps(result, indent=2) + "\n")
    print("PASS: nine native responses; cancellation bytes and all reopened exports verified", flush=True)


if __name__ == "__main__":
    main()
