from runtime import Screen, UI

struct Invalid(Screen):
    var name: String
    def __init__(out self):
        self.name = "Ada"
    def set_name(mut self, value: Int):
        self.name = String(value)
    def render(self, mut ui: UI[Self]):
        ui.text_input("Name", self.name, Self.set_name)

def main():
    var ui = UI[Invalid]()
    ui.begin()
    Invalid().render(ui)
