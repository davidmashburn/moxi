from runtime import Screen, UI

struct Invalid(Screen):
    var count: Int
    def __init__(out self):
        self.count = 0
    def render(self, mut ui: UI[Self]):
        var amount = 2
        def increment(mut state: Self) {var amount}:
            state.count += amount
        ui.button("Increment", increment)

def main():
    var ui = UI[Invalid]()
    ui.begin()
    Invalid().render(ui)
