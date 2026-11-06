"""A model owns values and methods; render describes its controls."""
from moxi.authoring import Screen, UI


struct Counter(Screen):
    var count: Int

    def __init__(out self):
        self.count = 0

    def increment(mut self):
        self.count += 1

    def render(self, mut ui: UI[Self]):
        ui.label("Moxi Counter")
        ui.label("Count: " + String(self.count))
        ui.button("Increment", Self.increment)
