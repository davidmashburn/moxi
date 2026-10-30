"""A duplicate control key must fail, never fire two button actions."""
from runtime import UI


def main():
    var ui = UI()
    _ = ui.button("same", "First")
    _ = ui.button("same", "Second")
