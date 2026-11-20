"""One session-local source draft for the scene-backed live ABI lesson."""

from moxi.controls_text import MultilineTextControl, MultilineTextState
from moxi.column_view import ColumnView
from moxi.event import (
    Event, COMPOSITION_UPDATE_KIND, COMPOSITION_END_KIND, TEXT_INPUT_KIND,
    KEY_DOWN_KIND, KEY_TAB, MOD_COMMAND, MOD_CONTROL,
)
from .demo_style import _code_style


comptime EDITABLE_DEMO_SOURCE = "examples/editable_showcase.mojo"


struct DemoBuildPhase(ImplicitlyCopyable):
    var value: Int
    comptime IDLE = Self(0)
    comptime BUILDING = Self(1)
    comptime READY = Self(2)
    comptime FAILED = Self(3)

    def __init__(out self, value: Int):
        self.value = value


struct DemoSourceEditor(ImplicitlyCopyable):
    """Drafts never write back to the example; builds use immutable snapshots."""

    var original: String
    var input: MultilineTextState
    var phase: DemoBuildPhase
    var available: Bool
    var pending_run: Bool
    var revision: Int
    var loaded_revision: Int
    var running_source: String
    var loaded_source: String
    var diagnostics: String

    def __init__(out self):
        self.original = ""
        self.available = False
        self.diagnostics = ""
        try:
            with open(EDITABLE_DEMO_SOURCE, "r") as file:
                self.original = file.read()
            self.available = True
        except:
            self.diagnostics = String("Cannot read ", EDITABLE_DEMO_SOURCE, ". Launch from the repository root.")
        self.input = MultilineTextState(self.original)
        self.input.input.cursor = 0
        self.phase = DemoBuildPhase.IDLE
        self.pending_run = False
        self.revision = 0
        self.loaded_revision = 0
        self.running_source = ""
        self.loaded_source = ""

    def building(self) -> Bool:
        return self.phase.value == DemoBuildPhase.BUILDING.value

    def request_run(mut self) -> Bool:
        if not self.available or self.building():
            return False
        self.revision += 1
        self.running_source = self.input.text()
        self.phase = DemoBuildPhase.BUILDING
        self.pending_run = True
        self.diagnostics = ""
        return True

    def revert(mut self) -> Bool:
        """Restore the exact original bytes, then rebuild that source."""
        if not self.available or self.building():
            return False
        self.input = MultilineTextState(self.original)
        self.input.input.cursor = 0
        return self.request_run()

    def complete(mut self, succeeded: Bool, diagnostics: String):
        self.pending_run = False
        self.diagnostics = diagnostics
        if succeeded:
            self.loaded_source = self.running_source
            self.loaded_revision = self.revision
            self.phase = DemoBuildPhase.READY
        else:
            self.phase = DemoBuildPhase.FAILED

    def status(self) -> String:
        if not self.available:
            return self.diagnostics
        if self.building():
            return String("Building rev #", self.revision, " · window and editor remain available.")
        if self.phase.value == DemoBuildPhase.FAILED.value:
            if self.loaded_revision > 0:
                return String("Compilation failed · previous scene retained (rev #", self.loaded_revision, ").")
            return "Compilation failed · fix the diagnostics and Run again."
        if self.loaded_revision == 0:
            return "Ready · edit the source and Run (Cmd+Enter / Ctrl+Enter)."
        if self.input.text() != self.loaded_source:
            return String("Running rev #", self.loaded_revision, " · draft changed; Run to apply.")
        if self.input.text() == self.original:
            return String("Running rev #", self.loaded_revision, " · original source · no errors.")
        return String("Running rev #", self.loaded_revision, " · edited source · no errors.")

    def add_editor(self, mut root: ColumnView, parent: Int, id: Int, height: Float32):
        var control = MultilineTextControl(id, self.input.text(), height)
        control.cursor = self.input.cursor()
        control.selection_anchor = self.input.input.anchor
        control.style = _code_style()
        control.enabled = self.available
        root.add_to(parent, control.node())
        root.set_accessibility_label(id, "Editable Mojo source")
        root.set_accessibility_hint(id, "Edit this session's draft. Cmd+Enter or Ctrl+Enter rebuilds only the scene.")

    def update(mut self, event: Event) -> Bool:
        if event.kind == COMPOSITION_UPDATE_KIND:
            self.input.input.set_composition(event.text, event.selection_start, event.selection_end)
            return True
        if event.kind == COMPOSITION_END_KIND:
            self.input.input.clear_composition()
            return True
        if event.kind == TEXT_INPUT_KIND:
            if event.replacement_start >= 0 and event.replacement_end >= 0:
                return self.input.input.replace_text_range(event.text, event.replacement_start, event.replacement_end)
            return self.input.insert_text(event.text)
        if event.kind == KEY_DOWN_KIND:
            if event.key == KEY_TAB and (event.modifiers & (MOD_COMMAND | MOD_CONTROL)) == 0:
                return self.input.insert_text("    ")
            return self.input.handle_key(event.key, event.modifiers)
        return False
