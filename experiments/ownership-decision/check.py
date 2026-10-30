"""Run bounded ownership evidence and record exact source hashes and results."""
from pathlib import Path
import hashlib
import json
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
LOGS = Path(tempfile.mkdtemp(prefix="moxi-ownership-decision-"))
MOJO = ["pixi", "run", "--locked", "mojo", "run", "-I", "src"]
CHECKS = [
    ("contract", MOJO + ["experiments/ownership-decision/contract.mojo"]),
    ("mechanics", MOJO + ["-I", "experiments/handler-api", "experiments/ownership-decision/mechanics.mojo"]),
    ("reactivity-tasks", MOJO + ["tests/reactivity_tasks.mojo"]),
    ("request-adapter", MOJO + ["tests/request_adapter.mojo"]),
    ("controlled-settlement", MOJO + ["-I", "experiments/handler-api", "-I", "experiments/child-routing", "experiments/child-routing/check_settled.mojo"]),
    ("handler-contracts", ["bash", "experiments/handler-api/check.sh"]),
]


def capture(command):
    return subprocess.check_output(command, cwd=ROOT, text=True).strip()


def main():
    report = {
        "date": "2026-10-29",
        "baseline": capture(["git", "rev-parse", "HEAD"]),
        "branch": capture(["git", "branch", "--show-current"]),
        "compiler": capture(["pixi", "run", "--locked", "mojo", "--version"]),
        "scope": "Headless transport/policy and compiler probes plus existing focused runtime checks; not three UI implementations or a performance comparison.",
        "sources": {},
        "checks": [],
    }
    paths = [ROOT / "pixi.lock", *HERE.glob("*.mojo"), HERE / "check.py"]
    for folder in ("src", "experiments/handler-api", "experiments/child-routing"):
        paths.extend(path for path in (ROOT / folder).rglob("*.mojo")
                     if "generated" not in path.relative_to(ROOT / folder).parts)
    paths.extend(ROOT / path for path in ("tests/reactivity_tasks.mojo", "tests/request_adapter.mojo", "experiments/handler-api/check.sh"))
    for path in sorted(set(paths)):
        report["sources"][str(path.relative_to(ROOT))] = hashlib.sha256(path.read_bytes()).hexdigest()
    for name, command in CHECKS:
        log = LOGS / (name + ".log")
        with log.open("w") as output:
            result = subprocess.run(command, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT)
        report["checks"].append({"name": name, "command": command, "exit_code": result.returncode, "output": log.read_text()})
        print(f"{name}: {'PASS' if result.returncode == 0 else 'FAIL'} ({log})", flush=True)
    (HERE / "results.json").write_text(json.dumps(report, indent=2) + "\n")
    raise SystemExit(int(any(check["exit_code"] for check in report["checks"])))


if __name__ == "__main__":
    main()
