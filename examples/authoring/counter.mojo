"""A model owns values and methods; render describes its controls."""
from moxi import App, Rect
from moxi.authoring import HandlerHost, Screen, UI, update_model


struct Counter(Screen):
    var count: Int

    def __init__(out self):
        self.count = 0

    def increment(mut self):
        self.count += 1

    def render(self, mut ui: UI[Self]):
        ui.label("Count: " + String(self.count))
        ui.button("Increment", Self.increment)


def main():
    var app = App(HandlerHost(Counter()), Rect(0, 0, 320, 200))
    # Stand in for an external update. A button dispatch publishes automatically.
    update_model(app, Counter.increment)
    print("Count:", app.component.root.count)
