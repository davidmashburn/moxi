"""Linux GTK entrypoint for the same FDG application."""
from moxi.backend import BACKEND_LINUX
from fdg_runtime import run

def main() raises:
    run[BACKEND_LINUX]()
