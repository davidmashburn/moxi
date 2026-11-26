"""Click a funnel stage to inspect its source row, change its value, or export."""
import argparse
import tkinter as tk
from pathlib import Path
from tkinter import ttk

from moxi import PlotSpec, plot


def figure(values):
    spec = PlotSpec()
    spec.specialize(spec.add_catalog_mark("funnel", "Pipeline", "stage", "value"))
    return plot({"stage": ["A", "B", "C"], "value": values}, spec, width=640, height=420)


class Inspector:
    def __init__(self, root, output):
        self.output = output
        self.values = [3, 9, 6]
        self.canvas = tk.Canvas(root, width=640, height=420, highlightthickness=0)
        self.canvas.pack()
        self.canvas.bind("<Button-1>", self.pick)
        self.table = ttk.Treeview(root, columns=("stage", "value", "rank"),
                                  show="headings", height=3, selectmode="browse")
        for column in self.table["columns"]:
            self.table.heading(column, text=column.capitalize())
        self.table.pack()
        controls = ttk.Frame(root)
        controls.pack()
        self.change = ttk.Button(controls, text="Set A to 12", command=self.update)
        self.change.pack(side="left")
        self.save = ttk.Button(controls, text="Export SVG, PNG and PDF", command=self.export)
        self.save.pack(side="left")
        self.status = tk.StringVar()
        ttk.Label(root, textvariable=self.status).pack()
        self.render()

    def render(self):
        self.chart = figure(self.values)
        self.image = tk.PhotoImage(data=self.chart.to_png())
        self.canvas.delete("all")
        self.canvas.create_image(0, 0, anchor="nw", image=self.image)
        self.table.delete(*self.table.get_children())
        for row in self.chart.table():
            self.table.insert("", "end", iid=str(row["row_index"]),
                              values=(row["category"], row["value"], row["rank"]))

    def pick(self, event):
        hit = self.chart.hit_test(event.x, event.y, tolerance=0)
        if hit:
            self.table.selection_set(str(hit["row_index"]))
            self.status.set(f"Selected stage {hit['label']}")

    def update(self):
        self.values[0] = 12
        self.render()
        self.status.set("A now ranks first")

    def export(self):
        self.output.mkdir(parents=True, exist_ok=True)
        for suffix in ("svg", "png", "pdf"):
            self.chart.save(self.output / f"funnel.{suffix}")
        self.status.set(f"Saved to {self.output}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--replay", action="store_true")
    args = parser.parse_args()
    root = tk.Tk()
    root.title("Funnel stage inspector")
    app = Inspector(root, args.output)
    if args.replay:
        root.update()
        for y, row in [(72, "1"), (200, "2"), (320, "0")]:
            app.canvas.event_generate("<Button-1>", x=338, y=y)
            assert app.table.selection() == (row,)
        app.save.invoke()
        app.change.invoke()
        app.canvas.event_generate("<Button-1>", x=338, y=72)
        assert app.table.selection() == ("0",)
        assert app.table.item("0", "values") == ("A", "12", "1")
        root.destroy()
        print("Tk replay passed: three pointer picks, export, update and re-selection.")
    else:
        root.mainloop()


if __name__ == "__main__":
    main()
