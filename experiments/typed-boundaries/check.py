"""Reproduce behavior, extension, and missing-context negative checks."""
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
STATE = ROOT / "experiments/state-access"
BINDINGS = ROOT / "experiments/method-binding"
SELECTIVE = ROOT / "experiments/selective-updates"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    logs = Path(tempfile.mkdtemp(prefix="moxi-typed-boundaries-"))
    report = {"timestamp": datetime.now(timezone.utc).isoformat(),
              "implementation_head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
              "compiler": subprocess.check_output(["pixi", "run", "--locked", "mojo", "--version"], cwd=ROOT, text=True).strip(),
              "scope": "Eight heterogeneous boundaries; same composition with cached vs forced declarations; actual App dispatch, complete ViewNode and PaintCommand equality. No native renderer or timing claim.",
              "checks": [], "logs": str(logs)}
    original = {p.name: sha(p) for p in STATE.glob("*.mojo")}

    def run(name, source, includes, expected_failure=False, diagnostic=""):
        cmd = ["pixi", "run", "--locked", "mojo", "run", "-I", "src"]
        cmd += [arg for path in includes for arg in ("-I", str(path))] + [str(source)]
        r = subprocess.run(cmd, cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=240)
        (logs / f"{name}.log").write_text(r.stdout)
        passed = r.returncode != 0 and diagnostic in r.stdout if expected_failure else r.returncode == 0
        report["checks"].append({"name": name, "passed": passed, "expected_failure": expected_failure, "exit_code": r.returncode, "output": r.stdout, "command": cmd})
        assert passed, f"{name}: {r.stdout[-4000:]}"

    run("heterogeneous_app", HERE / "check.mojo", [STATE, BINDINGS, SELECTIVE])
    extension = logs / "extension"
    extension.mkdir()
    for directory in (HERE, STATE):
        for path in directory.glob("*.mojo"):
            (extension / path.name).write_bytes(path.read_bytes())
    editor = (STATE / "editor.mojo").read_text()
    editor = editor.replace("    var note: String", "    var reviewer: String\n    var note: String")
    editor = editor.replace('        self.note = ""', '        self.reviewer = ""\n        self.note = ""')
    editor = editor.replace("    def set_note(", "    def set_reviewer(mut self, text: String):\n        self.reviewer = text\n\n    def set_note(")
    editor += '        ui.text_input("Reviewer", self.reviewer, Self.set_reviewer)\n'
    editor += '        ui.label("New limit read: " + String(services.settings.max_length))\n'
    (extension / "editor.mojo").write_text(editor)
    (extension / "extension.mojo").write_text('''from check import main as original_checks, text, act
from host import WorkbenchHost
from workbench import LEFT, SETTINGS
from moxi import App, Rect, test_check

def main():
    original_checks()
    var a = App(WorkbenchHost[True](), Rect(0, 0, 800, 4000))
    var b = App(WorkbenchHost[False](), Rect(0, 0, 800, 4000))
    a.component.reset_counts()
    text(a, b, LEFT, 9, "Reviewer")
    test_check(a.component.root.left.reviewer == "Reviewer")
    test_check(a.component.root.right.reviewer == "")
    test_check(a.component.render_count() == 1)
    act(a, b, SETTINGS, 3)
    var matches = 0
    for i in range(a.view.child_count()):
        if a.view.child(i).text == "New limit read: 3":
            matches += 1
    test_check(matches == 3)
    print("PASS extension: new field, setter, and shared read; unchanged host and cache")
''')
    for name in ("host.mojo", "boundary.mojo", "workbench.mojo"):
        assert sha(extension / name) == sha(HERE / name)
    run("new_field_and_read", extension / "extension.mojo", [extension, BINDINGS, SELECTIVE])
    report["generated_editor"] = editor
    report["extension_sources"] = {p.name: sha(p) for p in extension.glob("*.mojo")}
    missing = logs / "missing-context"
    missing.mkdir()
    for path in HERE.glob("*.mojo"):
        (missing / path.name).write_bytes(path.read_bytes())
    path = missing / "workbench.mojo"
    path.write_text(path.read_text().replace('        ui.label("Inspect: " + document.name)', '        ui.label("Inspect: " + document.name)\n        ui.label(String(document.settings.max_length))'))
    run("missing_context_rejected", missing / "smoke.mojo", [missing, STATE, BINDINGS, SELECTIVE], expected_failure=True, diagnostic="'Document' value has no attribute 'settings'")
    mismatch = logs / "wrong_context.mojo"
    mismatch.write_text('from boundary import Boundary\nfrom workbench import Workbench, Inspector\nfrom domain import Services\ndef main():\n    var bad = Boundary[Workbench, Inspector, Services](Inspector(), Services(), 100)\n')
    run("mismatched_context_rejected", mismatch, [HERE, STATE, BINDINGS, SELECTIVE], expected_failure=True, diagnostic="Boundary context must match the pane Context")
    run("scoped_conditional_identity", HERE / "identity.mojo", [BINDINGS])
    unscoped = logs / "unscoped.mojo"
    unscoped.write_text((HERE / "identity.mojo").read_text().replace("comptime SCOPED = True", "comptime SCOPED = False"))
    run("unscoped_conditional_rejected", unscoped, [BINDINGS], expected_failure=True, diagnostic="control kind changed: /p1")
    run("hidden_setting_overinvalidation", HERE / "overinvalidation.mojo", [STATE, BINDINGS, SELECTIVE])
    run("same_key_remount_rejected", HERE / "remount.mojo", [STATE, BINDINGS, SELECTIVE], expected_failure=True, diagnostic="remount requires a fresh increasing key")
    assert original == {p.name: sha(p) for p in STATE.glob("*.mojo")}
    paths = [ROOT / "pixi.toml", ROOT / "pixi.lock", *ROOT.glob("src/**/*.mojo"),
             *STATE.glob("*.mojo"), *BINDINGS.glob("*.mojo"), *SELECTIVE.glob("*.mojo"),
             *HERE.glob("*.mojo"), HERE / "check.py"]
    report["source_hashes"] = {str(p.relative_to(ROOT)): sha(p) for p in sorted(paths)}
    (HERE / "results.json").write_text(json.dumps(report, indent=2) + "\n")
    print(f"PASS {len(report['checks'])} programs (two compile rejections, two runtime negative controls); logs: {logs}")


if __name__ == "__main__":
    main()
