from runtime import Screen, UI

struct Invalid(Screen):
    var count: Int
    def __init__(out self):
        self.count = 0
    def render(self, mut ui: UI[Self]):
        self.count += 1
        ui.label(String(self.count))

def main():
    var ui = UI[Invalid]()
    ui.begin()
    Invalid().render(ui)
