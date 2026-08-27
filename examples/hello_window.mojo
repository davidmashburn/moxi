"""Minimal visible Moxi demo."""

from std.python import Python
from moxi import Label, Rect, Runtime


def main() raises:
    var runtime = Runtime()
    var view = Label(1, "Hello from Moxi", Rect(32.0, 28.0, 320.0, 56.0))
    runtime.reconcile(view)
    var command = runtime.paint()

    var tkinter = Python.import_module("tkinter")
    var root = tkinter.Tk()
    root.title("Moxi")
    root.geometry("384x144")
    var label = tkinter.Label(root, text=command.text)
    label.pack(expand=True)
    root.mainloop()
