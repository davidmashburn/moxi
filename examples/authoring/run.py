"""Compile and run the guide examples plus their behavioral checks."""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
INCLUDES = ["src"]


def main():
    for name in ("counter", "editors", "shared", "workspace", "check", "workspace_check", "draft_revert_check"):
        command = ["pixi", "run", "--locked", "mojo", "run"]
        for include in INCLUDES:
            command += ["-I", str(ROOT / include)]
        command.append(str(Path(__file__).parent / (name + ".mojo")))
        subprocess.run(command, cwd=ROOT, check=True, timeout=240)


if __name__ == "__main__":
    main()
