"""macOS entrypoint; application and solver shared with the Linux lane."""
from moxi.backend import BACKEND_MACOS_APPKIT
from fdg_runtime import render, run

def main() raises:
    run[BACKEND_MACOS_APPKIT]()
