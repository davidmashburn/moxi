"""Counterexample to treating structural reflection as universal value equality."""
from application import Application
from selective import equal_value
from moxi import test_check


def main():
    var a = Application(2)
    var b = a
    test_check(equal_value(a.services, b.services))
    test_check(a.shell.workspace.group.next_key == b.shell.workspace.group.next_key)
    test_check(len(a.shell.workspace.group.entries) == len(b.shell.workspace.group.entries))
    for i in range(len(a.shell.workspace.group.entries)):
        test_check(equal_value(a.shell.workspace.group.entries[i], b.shell.workspace.group.entries[i]))
    # Both applications have the same logical values but separate list storage.
    test_check(not equal_value(a, b))
    print("PASS logically equal owned collections can compare unequal through reflection")
