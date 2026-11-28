"""A form owns application values; the host retains its editor state."""
from moxi.view_node import RecipeRole
from moxi.authoring import Screen, UI
from moxi.scenarios import canonical_form_submit_label


struct Form(Screen):
    var name: String
    var submitted_name: String
    var submissions: Int

    def __init__(out self):
        self.name = ""
        self.submitted_name = ""
        self.submissions = 0

    def change_name(mut self, name: String):
        self.name = name

    def submit(mut self):
        self.submitted_name = self.name
        self.submissions += 1

    def render(self, mut ui: UI[Self]):
        ui.text_input("Name", self.name, Self.change_name, hint="Enter your name")
        ui.button(canonical_form_submit_label(), Self.submit, role=RecipeRole.primary())
        var confirmation = String("Submissions: ", self.submissions)
        if self.submitted_name != "":
            confirmation = String("Submitted: ", self.submitted_name, " (", self.submissions, ")")
        ui.label(confirmation)
