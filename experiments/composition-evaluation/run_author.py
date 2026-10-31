"""Parent verification of frozen first attempt and assisted repair."""
from datetime import datetime, timezone
from enum import Enum
import hashlib
import json
from pathlib import Path
import platform
import subprocess
import tempfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]


class Expected(str, Enum):
    PASS = "pass"
    COLLISION = "collision_counterexample"


def code_lines(path):
    inside = False
    count = 0
    for line in path.read_text().splitlines():
        stripped = line.strip()
        if '"""' in stripped:
            if stripped.count('"""') % 2:
                inside = not inside
            continue
        if stripped and not stripped.startswith('#') and not inside:
            count += 1
    return count


def main():
    logs = Path(tempfile.mkdtemp(prefix="moxi-author-parent-"))
    checks = []
    cases = [
        ("first-attempt-behavior", "author", HERE / "author/check.mojo", Expected.PASS),
        ("first-attempt-held-out", "author", HERE / "author_collision.mojo", Expected.COLLISION),
        ("assisted-repair-behavior", "author-repair", HERE / "author-repair/check.mojo", Expected.PASS),
        ("assisted-repair-held-out", "author-repair", HERE / "author_collision.mojo", Expected.PASS),
    ]
    assert (HERE / "author/attempt1.mojo").read_bytes() == (HERE / "author/screen.mojo").read_bytes()
    for name, variant, source, expected in cases:
        command = ["pixi", "run", "--locked", "mojo", "run"]
        for path in [ROOT / "src", HERE / variant, ROOT / "experiments/typed-boundaries",
                     ROOT / "experiments/state-access", ROOT / "experiments/method-binding"]:
            command += ["-I", str(path.relative_to(ROOT))]
        command += [str(source.relative_to(ROOT))]
        result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=240)
        output = result.stdout + result.stderr
        (logs / (name + ".log")).write_text(output)
        if expected is Expected.PASS:
            assert result.returncode == 0 and "PASS" in output, name + "\n" + output[-4000:]
        else:
            assert result.returncode == 1 and "duplicate identity: /k3:202" in output, name + "\n" + output[-4000:]
        checks.append(dict(name=name, expected=expected.value, exit_code=result.returncode,
                           command=command, output=output))
    paths = [*HERE.glob("author*/*.mojo"), *HERE.glob("author*/*.md"), HERE / "author_collision.mojo", Path(__file__).resolve(),
             ROOT / "experiments/simple-composition/screen.mojo", ROOT / "pixi.toml", ROOT / "pixi.lock", *ROOT.glob("src/**/*.mojo")]
    for folder in ("typed-boundaries", "state-access", "method-binding"):
        paths += list((ROOT / "experiments" / folder).glob("*.mojo"))
    report = dict(timestamp=datetime.now(timezone.utc).isoformat(), model="gpt-5.6-luna", reasoning="max",
                  baseline=subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
                  compiler=subprocess.check_output(["pixi", "run", "--locked", "mojo", "--version"], cwd=ROOT, text=True).strip(),
                  platform=platform.platform(), checks=checks,
                  first_attempt_unchanged=True, logs=str(logs),
                  line_counts={str(p.relative_to(ROOT)): code_lines(p) for p in [ROOT / "experiments/simple-composition/screen.mojo", HERE / "author/screen.mojo", HERE / "author-repair/screen.mojo"]},
                  source_hashes={str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(set(paths))},
                  limits="One example-assisted model author; second round receives the collision finding. No human study, language comparator, or general usability/scalability claim.")
    (HERE / "author-results.json").write_text(json.dumps(report, indent=2) + "\n")
    print("PASS parent verification of four author outcomes; first held-out case remains a documented failure")


if __name__ == "__main__":
    main()
