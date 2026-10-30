"""Run the composition gate and retain source provenance for the result."""
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]


def capture(command):
    return subprocess.check_output(command, cwd=ROOT, text=True).strip()


def main():
    command = ["pixi", "run", "--locked", "mojo", "run", "-I", "src", "-I",
               "experiments/handler-api", "-I", "experiments/composition-gate",
               "experiments/composition-gate/check.mojo"]
    paths = [ROOT / "pixi.lock", HERE / "check.py", *HERE.rglob("*.mojo")]
    for folder in ("src", "experiments/handler-api"):
        paths.extend((ROOT / folder).rglob("*.mojo"))
    report = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "baseline": capture(["git", "rev-parse", "HEAD"]),
        "branch": capture(["git", "branch", "--show-current"]),
        "compiler": capture(["pixi", "run", "--locked", "mojo", "--version"]),
        "scope": "Real App with synthetic events; current-state composition only. No native, performance, three-way UI or usability comparison.",
        "sources": {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
                    for p in sorted(set(paths))},
        "command": command,
    }
    with tempfile.NamedTemporaryFile(prefix="moxi-composition-", suffix=".log", delete=False) as log:
        result = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
        log_path = Path(log.name)
    report["exit_code"] = result.returncode
    report["output"] = log_path.read_text()
    (HERE / "results.json").write_text(json.dumps(report, indent=2) + "\n")
    print("PASS" if result.returncode == 0 else "FAIL", log_path)
    print("\n".join(report["output"].splitlines()[:12]))
    raise SystemExit(int(result.returncode != 0))


if __name__ == "__main__":
    main()
