"""Bounded local file operations for the standalone workbench."""

from .workbench_data import WORKBENCH_MAX_CSV_BYTES


def read_workbench_csv(path: String) raises -> String:
    """Read at most the import limit plus one byte, rejecting oversized input."""
    with open(path, "r") as source:
        var contents = source.read(WORKBENCH_MAX_CSV_BYTES + 1)
        if contents.byte_length() > WORKBENCH_MAX_CSV_BYTES:
            raise Error("CSV exceeds the 32 MiB file limit")
        return contents


def write_workbench_export(path: String, contents: String) raises:
    """Write an explicitly requested local export."""
    with open(path, "w") as destination:
        destination.write(contents)
