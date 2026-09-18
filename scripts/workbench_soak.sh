#!/usr/bin/env bash
set -euo pipefail

# Use the exact frozen executable of a completed benchmark run.
binary="${1:?Usage: workbench_soak.sh BENCHMARK_BINARY [SECONDS]}"
seconds="${2:-600}"
[[ -x "$binary" ]] || { echo "Missing benchmark executable: $binary" >&2; exit 2; }
[[ "$seconds" =~ ^[1-9][0-9]*$ ]] || { echo "Seconds must be positive" >&2; exit 2; }
result_dir="${MOXI_WORKBENCH_SOAK_DIR:-dist/workbench-hardening/soak}"
mkdir -p "$result_dir"
MOXI_WORKBENCH_NATIVE=1 MOXI_WORKBENCH_INSTRUMENTED=1 \
MOXI_WORKBENCH_SOAK_SECONDS="$seconds" \
  /usr/bin/time -lp "$binary" > "$result_dir/raw.stdout" 2> "$result_dir/raw.time"
python3 - "$binary" "$seconds" "$result_dir" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

binary, seconds, directory = Path(sys.argv[1]), int(sys.argv[2]), Path(sys.argv[3])
lines = (directory / "raw.stdout").read_text().splitlines()
samples = []
for line in lines:
    if line.startswith("SOAK "):
        fields = dict(token.split("=", 1) for token in line.split()[1:])
        samples.append({"elapsed_seconds": float(fields["elapsed_seconds"]),
                        "resident_bytes": int(fields["resident_bytes"]),
                        "cycles": int(fields["cycles"])})
assert any(line.startswith("SOAK_COMPLETE ") for line in lines), "Soak did not complete"
assert samples and samples[-1]["elapsed_seconds"] >= seconds + 30
assert all(sample["resident_bytes"] > 0 for sample in samples)
result = {"boundary": "persistent App, offscreen AppKit custom-command drawing; no native window",
          "binary": str(binary), "binary_sha256": hashlib.sha256(binary.read_bytes()).hexdigest(),
          "requested_seconds_after_warmup": seconds, "warmup_seconds": 30,
          "rows": 100000, "sample_interval_seconds": 30, "samples": samples,
          "leak_verdict": "not_established; inspect growth after warmup, not peak RSS alone",
          "native_window_acceptance": False}
(directory / "result.json").write_text(json.dumps(result, indent=2) + "\n")
print(f"Soak complete: {directory / 'result.json'}")
PY
