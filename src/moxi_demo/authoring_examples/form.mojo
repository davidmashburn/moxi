"""A form owns application values; the host retains its editor state."""
from moxi.authoring import Screen, UI
from moxi.scenarios import canonical_form_title, canonical_form_hint, canonical_form_submit_label


struct Form(Screen):
    var name: String
    var submissions: Int

    def __init__(out self):
        self.name = ""
        self.submissions = 0

    def change_name(mut self, name: String):
        self.name = name

    def submit(mut self):
        self.submissions += 1

    def render(self, mut ui: UI[Self]):
        ui.label(canonical_form_title())
        ui.label(canonical_form_hint())
        ui.text_input("Name", self.name, Self.change_name,
                      show_label=False, hint="Enter your name")
        ui.label("Submitted: " + String(self.submissions))
        ui.button(canonical_form_submit_label(), Self.submit)
