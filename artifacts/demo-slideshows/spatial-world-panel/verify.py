#!/usr/bin/env python3
"""Verify the D08 review against its source commit, logs, binary and six frames."""
from collections import Counter
from enum import Enum
from pathlib import Path
import hashlib
import importlib.util
import json
import subprocess

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]


class Outcome(str, Enum):
    PASS = "pass"
    PARTIAL = "partial"
    BLOCKED = "blocked"


def sha(data):
    return hashlib.sha256(data).hexdigest()


def read(name):
    return json.loads((HERE / name).read_text())


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def main():
    provenance = read("provenance.json")
    review = read("review.json")
    timing = read("timing.json")
    capture = module("d08_capture", ROOT / "examples/spatial-world-panel/gallery.py")
    slideshow = module("d08_slideshow", ROOT / "scripts/demo_slideshows.py")
    manifest = slideshow.load_manifest(HERE / "manifest.json")
    revision = review["revision"]
    assert revision == manifest["revision"] == provenance["base_revision"]
    files = provenance["files"]
    source_sha = sha(json.dumps(files, sort_keys=True).encode())
    assert source_sha == provenance["source_sha256_before"] == provenance["source_sha256_after"]
    assert capture.sources() == files, "Current scoped source differs from the captured source"
    assert provenance["sources_unchanged"] and not provenance["uncommitted_source"]
    assert not provenance["scoped_git_status_before_build"]
    before = read("review-logs/source-before.json")
    assert before == {"revision": revision, "files": files, "source_sha256": source_sha,
                      "scoped_git_status": ""}
    runner = provenance["capture_tool"]
    assert sha((ROOT / runner["path"]).read_bytes()) == runner["sha256"]
    assert runner["command_timeout_seconds"] == 900

    # Check every captured source against Git bytes, independently of the worktree.
    paths = sorted(files)
    objects = subprocess.check_output(
        ["git", "cat-file", "--batch"], cwd=ROOT,
        input="".join(f"{revision}:{path}\n" for path in paths).encode(),
    )
    offset = 0
    for path in paths:
        end = objects.index(b"\n", offset)
        header = objects[offset:end].split()
        assert len(header) == 3 and header[1] == b"blob", path
        size = int(header[2])
        start = end + 1
        assert sha(objects[start:start + size]) == files[path], path
        assert objects[start + size:start + size + 1] == b"\n"
        offset = start + size + 1
    assert offset == len(objects)

    binary = ROOT / "dist/spatial-world-panel/panel"
    assert sha(binary.read_bytes()) == provenance["executable_sha256"]
    assert binary.stat().st_size == provenance["executable_bytes"]
    slides = manifest["slides"]
    assert [s["scenario_id"] for s in slides] == [s[0] for s in capture.STATES]
    assert [s["scenario_id"] for s in review["scenarios"]] == [s["scenario_id"] for s in slides]
    for slide, scenario in zip(slides, review["scenarios"]):
        assert sha((HERE / slide["image"]).read_bytes()) == slide["png_sha256"]
        assert scenario["frame"] == slide["image"]
        assert scenario["png_sha256"] == slide["png_sha256"]
        assert scenario["visually_inspected"]
        Outcome(scenario["outcome"])
    assert (HERE / "index.html").read_text() == slideshow.render(manifest)

    # Preserve/recheck complete run logs, not only the observations in provenance.
    for log in review["logs"]:
        path = (HERE / log["path"]).resolve()
        assert path.is_relative_to(HERE)
        assert sha(path.read_bytes()) == log["sha256"], str(path)
    check_log = (HERE / "review-logs/checks.log").read_text()
    assert "PASS D08 and focused D06/D07 checks; source-free import directory" in check_log
    assert len(review["checks"]) == 13 and review["check_exit_code"] == review["capture_exit_code"] == 0
    for check in review["checks"]:
        assert Outcome(check["outcome"]) is Outcome.PASS
        assert check["expected_marker"] in (HERE / check["log"]).read_text(), check["name"]
    assert len(provenance["evidence"]) == 3
    cold, whole, bridge = [], [], []
    for evidence in provenance["evidence"]:
        path = (HERE / evidence["log"]).resolve()
        assert path.is_relative_to(HERE)
        lines = path.read_text().splitlines()
        for prefix in ("WORLD_IME_FAILED", "SCREEN_CARET_PASS", "PASS native NSTextView",
                       "IDLE_REUSE 100 mappings zero submissions", "REUSE_PASS 30 draws",
                       "PASS D08 ordinary component native replay"):
            assert sum(line.startswith(prefix) for line in lines) == 1, (path, prefix)
        assert evidence["observations"] == [line for line in lines if line.startswith(
            ("WORLD_IME_FAILED", "SCREEN_CARET_PASS", "PASS native", "IDLE_REUSE", "REUSE_PASS"))]
        c = [float(line.split()[1]) for line in lines if line.startswith("COLD ")]
        w = [list(map(float, line.split()[1:])) for line in lines if line.startswith("WARM ")]
        assert len(c) == 1 and len(w) == 30
        cold.extend(c)
        whole.extend(row[0] for row in w)
        bridge.extend(row[1] for row in w)
    for key, values in (("cold_first_draw", cold), ("warm_whole_draw", whole), ("warm_bridge", bridge)):
        assert values == timing["samples"][key]
        assert capture.distribution(values) == timing[key]
    counts = Counter(s["outcome"] for s in review["scenarios"])
    assert review["counts"] == {outcome.value: counts[outcome.value] for outcome in Outcome}
    baseline = review["baseline_comparison"]
    baseline_manifest = json.loads(subprocess.check_output([
        "git", "show", f"{baseline['artifact_commit']}:artifacts/demo-slideshows/spatial-world-panel/manifest.json",
    ], cwd=ROOT))
    assert baseline_manifest["revision"] == baseline["recorded_revision"]
    baseline_provenance = json.loads(subprocess.check_output([
        "git", "show", f"{baseline['artifact_commit']}:artifacts/demo-slideshows/spatial-world-panel/provenance.json",
    ], cwd=ROOT))
    old_files = baseline_provenance["files"]
    assert baseline["source_files_added"] == sorted(files.keys() - old_files.keys())
    assert baseline["source_files_removed"] == sorted(old_files.keys() - files.keys())
    assert baseline["source_files_changed"] == sorted(
        path for path in files.keys() & old_files.keys() if files[path] != old_files[path])
    old_slides = {slide["scenario_id"]: slide for slide in baseline_manifest["slides"]}
    assert len(old_slides) == len(slides) == len(baseline["frames"])
    for slide, comparison in zip(slides, baseline["frames"]):
        old = old_slides[slide["scenario_id"]]
        for key in ("scenario_id", "phase", "capture_kind", "caption", "action", "expected"):
            assert slide[key] == old[key], (slide["scenario_id"], key)
        assert comparison == {
            "scenario_id": slide["scenario_id"],
            "old_sha256": old["png_sha256"],
            "new_sha256": slide["png_sha256"],
            "hash_equal": old["png_sha256"] == slide["png_sha256"],
            "dimensions_equal": old["dimensions"] == slide["dimensions"],
        }
    assert read("decision.json")["promotion"] == "rejected"
    print(f"PASS D08: {len(files)} published source hashes; {len(slides)} reviewed frames; "
          f"{len(review['logs'])} log hashes; binary; HTML; 3 cold / 90 warm samples")


if __name__ == "__main__":
    main()
