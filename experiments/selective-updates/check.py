"""Reproduce the selective-update experiment, with exact source provenance."""
from datetime import datetime, timezone
from enum import Enum
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
BASELINE = ROOT / "experiments/state-access"
AUTHORING = ("application.mojo", "adapters.mojo", "domain.mojo", "editor.mojo")


class Policy(str, Enum):
    ALL = "all"
    DISPLAY = "display"


class Operation(str, Enum):
    DRAFT = "draft"
    NOTE = "note"
    NAME = "name"
    WRITABLE = "writable"
    UNRELATED = "unrelated"
    MAX_LENGTH = "max_length"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    logs = Path(tempfile.mkdtemp(prefix="moxi-selective-"))
    report = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "implementation_head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "compiler": subprocess.check_output(["pixi", "run", "--locked", "mojo", "--version"], cwd=ROOT, text=True).strip(),
        "scope": "Real Moxi App behavior at N=2; cached editor declarations/retained controls at N=2/100/1000. No whole-frame performance claim; explicit adapter for the existing ownership tree.",
        "checks": [],
        "authoring_sources": {name: digest(BASELINE / name) for name in AUTHORING},
    }
    base = ["pixi", "run", "--locked", "mojo", "run", "-I", "src"]

    def run(name, source, includes):
        command = base + [item for path in includes for item in ("-I", str(path))] + [str(source)]
        result = subprocess.run(command, cwd=ROOT, text=True, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, timeout=240)
        (logs / f"{name}.log").write_text(result.stdout)
        report["checks"].append({"name": name, "passed": result.returncode == 0,
                                 "exit_code": result.returncode, "output": result.stdout,
                                 "command": command})
        if result.returncode:
            raise AssertionError(f"{name}: {result.stdout[-4000:]}\nFull log: {logs}")
        return result.stdout

    bindings = ROOT / "experiments/method-binding"
    output = run("app_and_scale", HERE / "check.mojo", [BASELINE, bindings])
    rows = []
    for line in output.splitlines():
        if not line.startswith("WORK "):
            continue
        _, count, policy, operation, checks, renders, declarations, fallbacks = line.split()
        n = int(count)
        policy, operation = Policy(policy), Operation(operation)
        expected = (1 if operation in (Operation.DRAFT, Operation.NOTE) else
                    0 if policy is Policy.DISPLAY and operation in (Operation.UNRELATED, Operation.MAX_LENGTH) else n)
        row = {"editors": n, "policy": policy, "operation": operation,
               "shared_checks": int(checks), "editor_renders": int(renders),
               "declarations": int(declarations), "full_fallbacks": int(fallbacks)}
        assert row["editor_renders"] == expected, row
        assert row["shared_checks"] == 1, row
        assert row["declarations"] == 9 * expected, row
        assert row["full_fallbacks"] == 0, row
        rows.append(row)
    assert len(rows) == 36
    report["update_work"] = rows

    # New local state and a newly visible shared dependency. No host edits.
    extension = logs / "extension"
    extension.mkdir()
    for name in AUTHORING:
        source = (BASELINE / name).read_text()
        if name == "editor.mojo":
            source = source.replace("    var note: String", "    var reviewer: String\n    var note: String")
            source = source.replace('        self.note = ""', '        self.reviewer = ""\n        self.note = ""')
            source = source.replace("    def set_note(", "    def set_reviewer(mut self, text: String):\n        self.reviewer = text\n\n    def set_note(")
            source += '        ui.text_input("Reviewer", self.reviewer, Self.set_reviewer)\n'
            source += '        ui.label("Limit: " + String(services.settings.max_length))\n'
        (extension / name).write_text(source)
    for name in ("check.mojo", "selective.mojo", "extension.mojo"):
        (extension / name).write_bytes((HERE / name).read_bytes())
    for name in AUTHORING:
        if name != "editor.mojo":
            assert (extension / name).read_bytes() == (BASELINE / name).read_bytes()
    assert (extension / "selective.mojo").read_bytes() == (HERE / "selective.mojo").read_bytes()
    report["extension_sources"] = {p.name: digest(p) for p in sorted(extension.glob("*.mojo"))}
    report["generated_editor"] = (extension / "editor.mojo").read_text()
    run("authoring_extension_and_dependency_negative_control", extension / "extension.mojo", [extension, bindings])

    # Baseline behavior is rerun, including its documented identity-reuse limit.
    run("unchanged_baseline_behavior", BASELINE / "behavior.mojo", [BASELINE, bindings])
    paths = [ROOT / "pixi.toml", ROOT / "pixi.lock", *ROOT.glob("src/**/*.mojo"),
             *BASELINE.glob("*.mojo"), *bindings.glob("*.mojo"),
             *HERE.glob("*.mojo"), HERE / "check.py"]
    report["source_hashes"] = {str(p.relative_to(ROOT)): digest(p) for p in sorted(paths)}
    assert report["authoring_sources"] == {name: digest(BASELINE / name) for name in AUTHORING}
    report["logs"] = str(logs)
    (HERE / "results.json").write_text(json.dumps(report, indent=2) + "\n")
    print(f"PASS {len(report['checks'])} programs, {len(rows)} measured cases; logs: {logs}")


if __name__ == "__main__":
    main()
