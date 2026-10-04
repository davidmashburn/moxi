"""GTK acceptance screen using the shared Mojo layout workbench."""

from moxi.backend import BACKEND_LINUX
from native_layout_workbench import run_layout_workbench


def main() raises:
    run_layout_workbench[BACKEND_LINUX]()
