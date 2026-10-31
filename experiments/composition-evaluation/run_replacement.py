"""Record reproducible lifetime observations, including known counterexamples."""
from datetime import datetime, timezone
from enum import Enum
import hashlib
import json
from pathlib import Path
import platform
import subprocess

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]


class Outcome(str, Enum):
    PRESERVED_IDENTITY = "preserved_identity"
    SAFE_REPLACEMENT = "safe_replacement"
    COUNTEREXAMPLE = "counterexample"


EXPECTED = {
    "same-owner-update": (False, False, Outcome.PRESERVED_IDENTITY),
    "remove-append": (True, True, Outcome.SAFE_REPLACEMENT),
    "replace-collection-reused-keys": (False, False, Outcome.COUNTEREXAMPLE),
    "replace-root-reused-generation": (False, False, Outcome.COUNTEREXAMPLE),
    "replace-root-fresh-generation-same-host": (True, True, Outcome.SAFE_REPLACEMENT),
    "replace-entire-host-reuses-event-id": (True, False, Outcome.COUNTEREXAMPLE),
}


def main():
    command = ["pixi", "run", "--locked", "mojo", "run", "-I", "src", "-I",
               "experiments/method-binding", "-I", "experiments/state-access",
               "experiments/composition-evaluation/replacement.mojo"]
    result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, timeout=240)
    Path("/tmp/moxi-replacement-evaluation.log").write_text(result.stdout + result.stderr)
    if result.returncode:
        raise RuntimeError(result.stderr[-4000:])
    observations = []
    for line in result.stdout.splitlines():
        if not line.startswith("CASE "):
            continue
        _, name, callback_label, callback_value, event_label, event_value = line.split()
        assert callback_label == "callback_rejected" and event_label == "event_rejected"
        assert callback_value in ("True", "False") and event_value in ("True", "False")
        callback, event = callback_value == "True", event_value == "True"
        expected_callback, expected_event, outcome = EXPECTED[name]
        assert (callback, event) == (expected_callback, expected_event)
        observations.append(dict(name=name, callback_rejected=callback,
                                 event_rejected=event, outcome=outcome.value))
    assert {row["name"] for row in observations} == set(EXPECTED)
    assert len(observations) == len(EXPECTED)
    sources = [HERE / "replacement.mojo", Path(__file__).resolve(), ROOT / "pixi.toml", ROOT / "pixi.lock",
               ROOT / "experiments/state-access/adapters.mojo",
               ROOT / "experiments/state-access/domain.mojo",
               ROOT / "experiments/method-binding/runtime.mojo",
               ROOT / "experiments/method-binding/bindings.mojo", *ROOT.glob("src/**/*.mojo")]
    report = dict(timestamp=datetime.now(timezone.utc).isoformat(),
                  baseline=subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
                  compiler=subprocess.check_output(["pixi", "run", "--locked", "mojo", "--version"], cwd=ROOT, text=True).strip(),
                  platform=platform.platform(), command=command,
                  source_hashes={str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(sources)},
                  observations=observations, stdout=result.stdout,
                  interpretation="Characterization passed; three new-lifetime safety counterexamples remain. No runtime fix is included.")
    (HERE / "replacement-results.json").write_text(json.dumps(report, indent=2) + "\n")
    print(result.stdout, end="")


if __name__ == "__main__":
    main()
