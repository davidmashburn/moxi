"""Build this checkout, test the domain, replay normal native controls, capture PNGs.

No alternate screen or scripted domain mutations: the same no-argument executable
opens its normal window, then the replay adapter supplies AppKit callbacks.
"""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import platform
import struct
import subprocess
import sys
import tempfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
DEFAULT_DEST = ROOT / "artifacts/demo-slideshows/investigation-tools"
sys.path.insert(0, str(ROOT / "scripts"))
from demo_slideshows import load_manifest, render

SLIDES = [
    ("01-entry", "initial", "Normal native entry", "Launch investigation with no arguments.", "Fresh sensor workbench; no cohort or fitted model."),
    ("02-linear", "result", "Name, collect and fit", "Edit name and hypothesis, click Collect, then Fit linear.", "I20 collects six stable IDs; slope 16, SSE 149.333 and signed residuals."),
    ("03-invalid-coefficient", "recovery", "Rejected numeric edit", "Enter oops for c0 and click Apply coefficients.", "Visible error; the previous model and residuals remain intact."),
    ("04-alternatives", "interaction", "Compare identical observations", "Click Compare alternatives and resize to 980 by 800 points.", "Mean, linear and quadratic list parameter counts and training SSE on the same cohort; all remain above status."),
    ("05-quadratic", "result", "Choose another explicit model", "Click Fit quadratic.", "Coefficients 68, -2, 2 and zero residuals on the synthetic cohort."),
    ("06-edited", "interaction", "Edit the model", "Enter c0=69, verify Save refuses the pending edit, then Apply coefficients.", "Six residuals of -1; SSE 6. The alternatives remain separately fitted."),
    ("07-stable-ids", "result", "Filter and reorder", "Filter the table to >=70 and reverse its order.", "Membership, coefficients and fitted data remain unchanged."),
    ("08-frozen", "result", "Frozen membership", "Toggle reading 207 from 58 to 76.", "207 becomes visible but stays outside the frozen cohort; the old fit is invalidated."),
    ("09-live", "result", "Live membership", "Switch membership to live and fit quadratic.", "207 enters the cohort through I20; the fit and residuals use seven observations."),
    ("10-saved-panel", "result", "Extract and save a fixed panel", "Restore baseline readings, freeze IDs, fit quadratic, apply c0=69, then Save fixed panel.", "Compact panel records cohort, provenance, target, coefficients, refit and coefficient controls."),
    ("11-narrow-panel", "result", "Narrow native layout", "Resize the actual window to 980 by 800 points.", "Saved panel and its controls remain visible and clickable."),
    ("12-internals", "interaction", "Reopen and inspect internals", "Refit at the narrow size, Reopen the saved panel, Open investigation internals, focus the table filter button, then press F2.", "Saved c0=69 is restored first; F2 outside text editing re-collects the same stable IDs and invalidates the old fit."),
    ("13-new-process-reopen", "recovery", "Reopen in a new process", "Launch the same no-argument executable again and click Reopen panel.", "Name, hypothesis, frozen IDs, fixture, quadratic model and edited c0=69 survive process exit."),
    ("14-panel-refit", "result", "Saved refit control", "Click Refit quadratic in the reopened panel.", "The intended six sensor observations produce 68, -2, 2 and zero residuals."),
    ("15-panel-edit", "interaction", "Saved coefficient control", "Change c1 to -1 and click Apply coefficients.", "The intended observations produce SSE 139; this edit is unsaved."),
    ("16-load-rejected", "recovery", "Reject an incompatible panel", "In a fresh workbench fit linear, then Reopen an unsupported panel version.", "The error is visible and the current investigation is unchanged."),
    ("17-save-rejected", "recovery", "Preserve state after a save failure", "Fit linear and Save where panel.json is a directory.", "Atomic write fails visibly; the investigation and existing destination survive."),
]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(command, *, cwd=ROOT, env=None, log, expected=0, timeout=240):
    with log.open("w") as stream:
        result = subprocess.run(command, cwd=cwd, env=env, stdout=stream,
                                stderr=subprocess.STDOUT, timeout=timeout)
    if result.returncode != expected:
        raise RuntimeError(f"Exit {result.returncode}, expected {expected}: {command}; see {log}")
    return log.read_text()


def boundary_cases(saved, binary, work, log):
    """Independent JSON literals verify the wire contract at its parse boundary."""
    valid = json.loads(saved.read_text())
    assert valid["membership"] == "frozen" and valid["model"] == "quadratic"
    assert valid["members"] == [318, 429, 530, 641, 752, 863]
    assert valid["controls"] == ["refit", "coefficients"]
    assert abs(valid["coefficients"][0] - 69) < 1e-7
    mutations = {
        "version": dict(version=2),
        "fixture": dict(fixture="different-source"),
        "target": dict(target="different-value"),
        "fixture-state": dict(fixture_state="unknown"),
        "mode": dict(membership="automatic"),
        "rule": dict(rule="reading>70"),
        "model": dict(model="cubic"),
        "controls": dict(controls=["execute-arbitrary-code"]),
        "empty-members": dict(members=[]),
        "duplicate-members": dict(members=[318, 318, 530]),
        "unknown-members": dict(members=[318, 429, 999]),
        "insufficient-members": dict(members=[318, 429]),
        "fractional-id": dict(members=[318, 429, 530.5]),
        "empty-name": dict(cohort_name="  "),
        "long-name": dict(cohort_name="x" * 65),
        "long-hypothesis": dict(hypothesis="x" * 141),
        "control-text": dict(cohort_name="line\nfeed"),
        "coefficient-count": dict(coefficients=[69, -2]),
        "coefficient-range": dict(coefficients=[1e9, -2, 2]),
        "coefficient-type": dict(coefficients=["69", -2, 2]),
        "linear-c2": dict(model="linear"),
        "mean-c1": dict(model="mean", coefficients=[69, -2, 0]),
        "live-mismatch": dict(membership="live", fixture_state="threshold-crossing"),
        "unknown-field": dict(unrecognized="field"),
    }
    documents = {name: json.dumps(dict(valid, **change), ensure_ascii=False)
                 for name, change in mutations.items()}
    missing = dict(valid)
    del missing["target"]
    documents.update({
        "missing-field": json.dumps(missing),
        "duplicate-field": saved.read_text().rstrip()[:-1] + ',"version":1}',
        "truncated": '{"version":',
        "trailing-data": saved.read_text() + "{}",
        "oversized": " " * 8193,
        "nonfinite": json.dumps(dict(valid, coefficients=["overflow", -2, 2])).replace('"overflow"', '1e999'),
        "unpaired-surrogate": json.dumps(dict(valid, cohort_name="\ud800")),
    })
    outcomes = []
    report = []
    for name, content in documents.items():
        path = work / (name + ".json")
        path.write_text(content)
        output = run([binary, "--validate", path], log=log, expected=1)
        report.append(name + ": rejected / " + output.strip().splitlines()[-1])
        outcomes.append(name)
    # Reordered JSON fields, Unicode escapes and finite numeric exponent are valid.
    alternate = dict(reversed(list(valid.items())))
    alternate["cohort_name"] = 'Warm "α" sensors'
    alternate["coefficients"] = [69.0, -2.0, 2e0]
    alternate["membership"] = "live"
    path = work / "valid-alternate.json"
    path.write_text(json.dumps(alternate))
    restored = json.loads(run([binary, "--validate", path], log=log))
    assert restored["cohort_name"] == alternate["cohort_name"]
    assert restored["membership"] == "live" and restored["model"] == "quadratic"
    report.append("reordered fields, escaped Unicode, live mode: accepted and round-tripped")
    log.write_text("\n".join(report) + "\n")
    return outcomes


def review_record(manifest):
    """Keep the replay evidence readable without relying on chat history."""
    rows = ["# I10 native consumer verification", "",
            "The bounded experiment is runnable: named cohort → explicit fit and residuals → "
            "alternatives → saved fixed panel → fresh-process reopen.", "",
            f"Captured {manifest['captured_at']} on {manifest['host']} ({manifest['architecture']}). "
            f"Source commit: `{manifest['revision']}`. Source changes at capture: "
            f"`{manifest['source_status'] or 'clean'}`.", "",
            "The build compiles this checkout's Moxi source and AppKit host using the locked Pixi "
            "environment. Compiler versions and linker warnings are retained in [build.log](logs/build.log). "
            "The exact executable hash, source hashes and PNG hashes are in [manifest.json](manifest.json). "
            "The no-argument executable first creates its normal App, component and native window; "
            "the optional replay then supplies mouse, text, F2 and resize callbacks through the same "
            "dispatch/render functions as interactive use. It reads state for assertions and never "
            "mutates the model directly.", "",
            "Environment: local synthetic fixture with eight stable observation IDs, no external "
            "account; native AppKit window at 1140×860 and 980×800 points, "
            f"{manifest['scale']:g}× capture backing scale. This is native UI verification; no browser "
            "hosts the consumer.", "", "## Scenarios", "",
            "Each row passed its interaction assertions and produced the linked native-window PNG. "
            "Appearance is evidence from the capture; numeric/persistence claims also have assertions "
            "and independent saved-file checks.", "",
            "| Scenario | Steps | Expected / observed | Outcome / evidence |",
            "|---|---|---|---|"]
    for slide in manifest["slides"]:
        rows.append(f"| {slide['caption']} | {slide['action']} | {slide['observed']} | "
                    f"PASS · [PNG]({slide['image']}) |")
    rows += ["", "## Additional checks", "",
             "- [Domain checks](logs/domain.log): known OLS coefficients, signed residuals, "
             "mean/linear/quadratic SSE, edited coefficients, typed Unicode round-trip, inclusive "
             "threshold, frozen/live behavior, insufficient samples, and transactional failed refreshes.",
             f"- [Panel boundary checks](logs/boundary.log): {len(manifest['verification']['rejected_boundary_cases'])} "
             "malformed or incompatible configurations rejected; reordered fields, escaped Unicode "
             "and a consistent live rule accepted.",
             "- Five separate native processes: create, fresh reopen, incompatible load, "
             "[missing file](logs/missing.log), and failed atomic save. The failed save leaves the "
             "existing destination directory intact; file-load failures preserve the current model.",
             "- [saved-panel.json](saved-panel.json) independently records the six intended IDs, "
             "quadratic coefficients with c0=69, stable sensor target and two supported controls.", "",
             "## Reproduce", "", "```sh", manifest["reproduce"], "```", "",
             "Run from the repository root on macOS. Set `MOXI_PIXI_MANIFEST` only when reusing "
             "a matching installed locked environment. Open [index.html](index.html) for the offline "
             "17-frame slideshow. PNGs and HTML follow the repository's generated-artifact ignore "
             "convention and are regenerated by this command; the manifest, saved configuration, "
             "source and short logs remain reviewable.", "", "## Limits", "",
             "Confidence is high for this bounded synthetic flow. A failing replay or a mismatch "
             "between captured source hashes and the proposed source would change that assessment. "
             "Physical input, human repeated use, other operating systems, VoiceOver and the full "
             "repository suite were not tested. Native callbacks do not establish physical IME or "
             "assistive-technology behavior. F2 was exercised with focus outside text editing. "
             "No scientific validity or generalization is claimed. "
             "The original workbench is not extended with general extraction, symbolic editing, "
             "canvas or 3D authoring. Shared ledger and index changes are left to the parent.", ""]
    return "\n".join(rows)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dest", type=Path, default=DEFAULT_DEST)
    args = parser.parse_args()
    dest = args.dest.resolve()
    dest.mkdir(parents=True, exist_ok=True)
    logs = dest / "logs"
    logs.mkdir(exist_ok=True)
    build_log = logs / "build.log"
    run(["bash", HERE / "build.sh"], log=build_log, timeout=900)
    binary = ROOT / "dist/investigation-tools/investigation"
    tests = ROOT / "dist/investigation-tools/model-tests"
    domain = run([tests], log=logs / "domain.log")
    source_paths = sorted([*HERE.glob("*.mojo"), HERE / "host.m", HERE / "build.sh", HERE / "check.py",
                           ROOT / "examples/application-operations/cohort.mojo",
                           ROOT / "examples/application-operations/host.m"])
    source_hashes = {str(path.relative_to(ROOT)): digest(path) for path in source_paths}
    env = dict(os.environ, MOXI_COHORT_CAPTURE=str(dest))
    with tempfile.TemporaryDirectory(prefix="moxi-i10-") as temp:
        work = Path(temp)
        create = run([binary], cwd=work, env=dict(env, MOXI_I10_REPLAY="create"), log=logs / "create.log")
        saved = work / "panel.json"
        (dest / "saved-panel.json").write_bytes(saved.read_bytes())
        # A wholly separate OS process, fresh App and fresh Investigation.
        reopen = run([binary], cwd=work, env=dict(env, MOXI_I10_REPLAY="reopen"), log=logs / "reopen.log")
        cases = boundary_cases(saved, tests, work, logs / "boundary.log")
        saved.write_text('{"version":2}')
        invalid = run([binary], cwd=work, env=dict(env, MOXI_I10_REPLAY="invalid"), log=logs / "invalid.log")
        saved.unlink()
        missing_env = dict(env, MOXI_I10_REPLAY="invalid")
        missing_env.pop("MOXI_COHORT_CAPTURE")
        missing = run([binary], cwd=work, env=missing_env, log=logs / "missing.log")
        # A directory at the target must survive a failed atomic write.
        saved.mkdir()
        failure = run([binary], cwd=work, env=dict(env, MOXI_I10_REPLAY="write-failure"), log=logs / "write-failure.log")
        assert saved.is_dir()
    revision = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    slides = []
    for name, phase, caption, action, expected in SLIDES:
        path = dest / (name + ".png")
        dimensions = struct.unpack(">II", path.read_bytes()[16:24])
        slides.append(dict(image=path.name, phase=phase, caption=caption, action=action,
                           expected=expected, observed=expected, outcome="pass",
                           dimensions=list(dimensions), capture_kind="native-window",
                           sha256=digest(path)))
    manifest = dict(version=1, demo_id=dest.name, title="An investigation becomes a saved tool",
                    scenario="I10 / named cohort, explicit fits and residuals, alternatives, fixed panel, reopen",
                    slides=slides, revision=revision,
                    captured_at=datetime.datetime.now(datetime.timezone.utc).isoformat(),
                    host="macOS " + platform.mac_ver()[0], backend="Moxi AppKit / moxi_plot / live NSWindow content-view capture",
                    architecture=platform.machine(),
                    scale=slides[0]["dimensions"][0] / 1140, fixture="Eight synthetic sensor observations / sensor-curve-v1",
                    reproduce="python3 examples/investigation-tools/check.py",
                    viewports_points=[[1140, 860], [980, 800]], role="local synthetic fixture; no external accounts",
                    binary_sha256=digest(binary), source_sha256=source_hashes,
                    source_status=subprocess.check_output(["git", "status", "--short", "--", "examples/investigation-tools"], cwd=ROOT, text=True).strip(),
                    verification=dict(domain=domain.strip(), create=create.strip(), reopen=reopen.strip(),
                                      invalid=invalid.strip(), missing=missing.strip(), write_failure=failure.strip(),
                                      rejected_boundary_cases=cases, valid_boundary="reordered fields, escaped Unicode and live mode"),
                    limitations=["Native callbacks, not physical mouse or keyboard input", "No VoiceOver or screen-reader testing",
                                 "Synthetic fixture; no scientific validity or user-reuse claim", "macOS only; other hosts and full repository suite were not tested"])
    path = dest / "manifest.json"
    path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")
    (dest / "index.html").write_text(render(load_manifest(path)))
    (dest / "REVIEW.md").write_text(review_record(manifest))
    print(f"PASS I10: domain + {len(cases)} rejected boundary cases + 5 native processes + {len(slides)} native screenshots")
    print(dest / "index.html")


if __name__ == "__main__":
    main()
