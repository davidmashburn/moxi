"""Verify recorded source provenance and join matched projection work counts.

Run check.py and solid/check.mjs first. This is not a latency benchmark.
"""
import hashlib
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    mojo_path = HERE / "results.json"
    solid_path = HERE / "solid/results.json"
    mojo = json.loads(mojo_path.read_text())
    solid = json.loads(solid_path.read_text())
    for base, hashes in ((ROOT, mojo["source_hashes"]),
                         (HERE / "solid", solid["sourceHashes"])):
        for name, expected in hashes.items():
            assert digest(base / name) == expected, f"Stale result: {name}"
    assert all(check["passed"] for check in mojo["checks"])
    assert all(check["passed"] for check in solid["assertions"])
    operations = {
        "draft": "draftEdit", "note": "noteEdit", "name": "sharedNameRename",
        "writable": "writableToggle", "unrelated": "irrelevantSettingsProperty",
    }
    rows = []
    for count in (2, 100, 1000):
        for operation, solid_operation in operations.items():
            measured = solid["scale"][str(count)]["operations"][solid_operation]
            evaluations = sum(measured["evaluations"].values())
            writes = sum(measured["changedWrites"].values())
            row = {"editors": count, "operation": operation,
                   "solid_evaluations": evaluations, "sink_writes": writes}
            for mode in ("full", "memo"):
                matches = [r for r in mojo["update_work"]
                           if (r["editors"], r["operation"], r["mode"]) ==
                           (count, operation, mode)]
                assert len(matches) == 1
                recorded = matches[0]
                assert recorded["sink_writes"] == writes
                row[f"{mode}_evaluations"] = recorded["output_evaluations"]
                row[f"{mode}_key_checks"] = recorded["key_checks"]
            rows.append(row)
    report = {
        "scope": "Matched five-output projection work, not total runtime or latency. Memo scans all editors. Solid uses actual client tracking; Mojo projection is separate from App.",
        "input_result_hashes": {str(p.relative_to(HERE)): digest(p)
                                for p in (mojo_path, solid_path)},
        "mojo_checks": len(mojo["checks"]),
        "solid_assertions": solid["assertionCount"],
        "rows": rows,
    }
    (HERE / "comparison.json").write_text(json.dumps(report, indent=2) + "\n")
    print(f"PASS provenance and equal sink-write counts for {len(rows)} cases")


if __name__ == "__main__":
    main()
