"""Run the Mojo comparison and record exact source provenance and measured work."""
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]


def main():
    logs = Path(tempfile.mkdtemp(prefix="moxi-state-access-"))
    def capture(command):
        return subprocess.check_output(command, cwd=ROOT, text=True).strip()
    report = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "implementation_head": capture(["git", "rev-parse", "HEAD"]),
        "compiler": capture(["pixi", "run", "--locked", "mojo", "--version"]),
        "scope": "Mojo field/keyed adapters through real App; separate headless full/memo output projections. Not real Xilem, no native UI, latency, allocator or usability benchmark.",
        "checks": [],
    }
    base = ["pixi", "run", "--locked", "mojo", "run", "-I", "src",
            "-I", "experiments/method-binding", "-I", "experiments/composition-gate"]
    def run(name, source, expected_error=None):
        command = base + [str(source.relative_to(ROOT)) if source.is_relative_to(ROOT) else str(source)]
        result = subprocess.run(command, cwd=ROOT, text=True, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, timeout=120)
        (logs / f"{name}.log").write_text(result.stdout)
        passed = result.returncode == 0 if expected_error is None else (
            result.returncode != 0 and expected_error in result.stdout and
            "Please submit a bug report" not in result.stdout)
        report["checks"].append({"name": name, "command": command,
                                 "exit_code": result.returncode, "passed": passed,
                                 "expected_error": expected_error, "output": result.stdout})
        if not passed:
            print(result.stdout[-5000:])
            raise AssertionError(f"{name}: see {logs}")
        return result.stdout

    run("existing_binding_baseline", ROOT / "experiments/method-binding/check.mojo")
    run("field_projection", HERE / "probe.mojo")
    run("nested_app_behavior", HERE / "behavior.mojo")
    extension = logs / "extension"
    extension.mkdir()
    for name in ("application.mojo", "adapters.mojo", "domain.mojo", "editor.mojo", "behavior.mojo"):
        source = (HERE / name).read_text()
        if name == "editor.mojo":
            source = source.replace("    var note: String", "    var reviewer: String\n    var note: String")
            source = source.replace('        self.note = ""', '        self.reviewer = ""\n        self.note = ""')
            source = source.replace("    def set_note(", "    def set_reviewer(mut self, text: String):\n        self.reviewer = text\n\n    def set_note(")
            source += '        ui.text_input("Reviewer", self.reviewer, Self.set_reviewer)\n'
        if name == "behavior.mojo":
            source += '''    var app = App(HandlerHost(Application()), Rect(0, 0, 640, 2000))
    replace(app, path(1, 9), "Reviewer")
    test_check(app.component.root.shell.workspace.group.entries[0].value.reviewer == "Reviewer")
    test_check(app.component.root.shell.workspace.group.entries[1].value.reviewer == "")
    print("PASS local field extension without application or adapter changes")
'''
        (extension / name).write_text(source)
    assert (extension / "application.mojo").read_bytes() == (HERE / "application.mojo").read_bytes()
    assert (extension / "adapters.mojo").read_bytes() == (HERE / "adapters.mojo").read_bytes()
    run("local_field_extension", extension / "behavior.mojo")
    output = run("update_work", HERE / "update_work.mojo")
    rows = []
    for line in output.splitlines():
        if not line.startswith("WORK "):
            continue
        _, count, operation, memo, keys, evaluations, writes = line.split()
        n, is_memo = int(count), memo == "True"
        row = {"editors": n, "operation": operation,
               "mode": "memo" if is_memo else "full",
               "key_checks": int(keys), "output_evaluations": int(evaluations),
               "sink_writes": int(writes)}
        expected_writes = 0 if operation == "unrelated" else n if operation in ("name", "writable") else 1
        expected_eval = 5*n if not is_memo or operation in ("name", "writable") else 0 if operation == "unrelated" else 5
        assert row["sink_writes"] == expected_writes, row
        assert row["output_evaluations"] == expected_eval, row
        assert row["key_checks"] == (n if is_memo else 0), row
        rows.append(row)
    assert len(rows) == 30
    report["update_work"] = rows
    run("generic_lens_origin_rejection", HERE / "diagnostics/generic_lens.mojo",
        "does not implement all requirements for 'Lens'")
    probe = (HERE / "probe.mojo").read_text()
    invalid_field = logs / "invalid_field.mojo"
    invalid_field.write_text(probe.replace('field["leaf"]', 'field["missing"]'))
    # Generated files live outside HERE; supply its import path explicitly.
    base.extend(["-I", "experiments/state-access"])
    run("missing_field_rejection", invalid_field, "missing")
    bad_context = logs / "bad_context.mojo"
    bad_context.write_text(probe.replace('field["leaf"](ui, self, document, key=1)',
        'var wrong = UI[Self, Int]()\n        field["leaf"](wrong, self, 1, key=1)'))
    run("wrong_context_rejection", bad_context, "rebind")
    instrumented = logs / "instrumented"
    instrumented.mkdir()
    for name in ("application.mojo", "adapters.mojo", "domain.mojo", "editor.mojo"):
        (instrumented / name).write_bytes((HERE / name).read_bytes())
    for name in ("runtime.mojo", "bindings.mojo"):
        source = (ROOT / "experiments/method-binding" / name).read_text()
        if name == "bindings.mojo":
            source = source.replace("        self.drop = _destroy[T]", "        self.drop = _destroy[T]\n        print(1)")
            source = source.replace("        self.drop(self.raw)", "        self.drop(self.raw)\n        print(-1)")
        (instrumented / name).write_text(source)
    (instrumented / "descriptors.mojo").write_text('''from application import Application
from runtime import UI
def main():
    var app = Application()
    var ui = UI[Application]()
    app.render(ui)
    print("RENDERED")
    _ = ui
''')
    descriptors = run("nested_descriptor_lifetimes", instrumented / "descriptors.mojo")
    live = peak = created = destroyed = 0
    for line in descriptors.splitlines():
        if line in ("1", "-1"):
            delta = int(line)
            live += delta
            peak = max(peak, live)
            created += delta == 1
            destroyed += delta == -1
            assert live >= 0
    assert created == destroyed == peak == 40 and live == 0
    report["nested_descriptors"] = {"editors": 2, "renders": 1,
        "created": created, "destroyed": destroyed, "peak": peak,
        "final_live": live, "allocation_sites_per_descriptor": 2,
        "note": "Instrumented descriptor counts; allocation sites from source, not allocator profiling. No timing claim."}
    paths = [ROOT / "pixi.lock", ROOT / "pixi.toml"]
    paths += list((ROOT / "src").rglob("*.mojo"))
    for folder in (HERE, ROOT / "experiments/method-binding", ROOT / "experiments/composition-gate"):
        paths += list(folder.glob("*.mojo")) + list(folder.glob("*.py"))
    paths += list((HERE / "diagnostics").glob("*.mojo"))
    report["source_hashes"] = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
                               for p in sorted(set(paths))}
    (HERE / "results.json").write_text(json.dumps(report, indent=2) + "\n")
    print(f"PASS {len(report['checks'])} checks; 30 measured rows; logs: {logs}")


if __name__ == "__main__":
    main()
