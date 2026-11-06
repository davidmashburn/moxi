"""CLI failures, real artifacts and recovery, without a display."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

binary = Path(sys.argv[1]).resolve()
fixture = Path(__file__).parent / "fixtures/export.json"
with tempfile.TemporaryDirectory(prefix="moxi-p06-formats-") as tmp:
    root = Path(tmp)
    for suffix, signature in [("svg", b"<svg"), ("png", b"\x89PNG"), ("pdf", b"%PDF")]:
        output = root / ("space ' quote ; graph."+suffix)
        subprocess.run([binary, fixture, "--export", output], check=True, capture_output=True, timeout=30)
        assert output.read_bytes().startswith(signature)
    target = root / "keep.png"
    target.write_bytes(b"keep-existing-destination")
    env = dict(os.environ, MOXI_FDG_RSVG=str(root / "missing-converter"))
    result = subprocess.run([binary, fixture, "--export", target], env=env, capture_output=True, timeout=30)
    assert result.returncode != 0 and b"requires rsvg-convert" in result.stderr, result.stderr
    assert target.read_bytes() == b"keep-existing-destination"
    converter = root / "failing converter"
    converter.write_text("#!/bin/sh\nexit 7\n")
    converter.chmod(0o700)
    env["MOXI_FDG_RSVG"] = str(converter)
    result = subprocess.run([binary, fixture, "--export", target], env=env, capture_output=True, timeout=30)
    assert result.returncode != 0 and b"rsvg-convert failed" in result.stderr
    assert target.read_bytes() == b"keep-existing-destination"
    converter.write_text("#!/bin/sh\nexit 0\n")
    result = subprocess.run([binary, fixture, "--export", target], env=env, capture_output=True, timeout=30)
    assert result.returncode != 0 and b"rsvg-convert failed" in result.stderr
    assert target.read_bytes() == b"keep-existing-destination"
    assert not list(root.glob("*.tmp.*"))
    result = subprocess.run([binary, fixture, "--export", root / "unsupported.jpg"], capture_output=True, timeout=30)
    assert result.returncode != 0 and b"Unsupported export format" in result.stderr
    assert not (root / "unsupported.jpg").exists()
    subprocess.run([binary, fixture, "--export", target], check=True, capture_output=True, timeout=30)
    assert target.read_bytes().startswith(b"\x89PNG")
    # Real production cap is retained; these are deliberately oversized inputs.
    for count, edges, diagnostic in [(257,0,b"256 nodes"),(256,1025,b"1024 links")]:
        graph = {"nodes":[{"id":str(i)} for i in range(count)],
                 "links":[{"source":"0","target":"1"} for _ in range(edges)]}
        result = subprocess.run([binary,"/dev/stdin","--export",root/"limit.svg"],
                                input=json.dumps(graph).encode(), capture_output=True, timeout=30)
        assert result.returncode != 0 and diagnostic in result.stderr, result.stderr
print("PASS: PNG/PDF signatures, Unicode/space paths, optional exporter failure, atomic destination preservation, recovery, production caps")
