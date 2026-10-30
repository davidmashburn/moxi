"""Compare root, explicit scoped, and binding-assisted committed text updates.

Run: pixi run --locked mojo run -I src experiments/scoped-bindings/probe.mojo
This is an authoring/work probe, not automatic dependency inference.
"""

from moxi import (
    ActionEvent, ColumnRuntime, ColumnView, Event, LocalizedExecution,
    PaintCommands, Rect, TEXT_INPUT_KIND, TextInputControl, TextInputEvent,
    TextInputState, test_check,
)

comptime ROOT = 0
comptime FORM = 1
comptime SIBLING = 2
comptime ROOT_MODE = 0
comptime EXPLICIT_MODE = 1
comptime BINDING_MODE = 2
comptime PASSES = 100


def same_editor(a: TextInputState, b: TextInputState) -> Bool:
    return (
        a.text == b.text and a.cursor == b.cursor and a.anchor == b.anchor
        and a.composition == b.composition
        and a.composition_selection_start == b.composition_selection_start
        and a.composition_selection_end == b.composition_selection_end
    )


def replace_committed(mut input: TextInputState, event: Event) -> Bool:
    """Detect visible editor changes, including selection/composition cleanup."""
    if event.kind != TEXT_INPUT_KIND:
        return False
    var before = input
    if event.replacement_start >= 0 and event.replacement_end >= 0:
        _ = input.replace_text_range(
            event.text, event.replacement_start, event.replacement_end,
        )
    else:
        _ = input.insert_text(event.text)
    return not same_editor(before, input)


struct TextBinding(ImplicitlyCopyable):
    """A non-owning value descriptor; the caller supplies the owned editor.

    No borrowed pointer, callback registry, inferred dependency, or cached value.
    The scope must be registered before mutation. Scope lifetime stays explicit.
    """

    var scope_id: Int

    def __init__(out self, scope_id: Int):
        self.scope_id = scope_id

    def replace(
        self, mut input: TextInputState, event: Event,
        mut execution: LocalizedExecution,
    ) -> Bool:
        if execution.scope_index(self.scope_id) == -1:
            return False
        if not replace_committed(input, event):
            return False
        return execution.invalidate_scope(self.scope_id)


def form_view(input: TextInputState) -> ColumnView:
    var view = ColumnView(Rect(0, 0, 480, 100), 0, 2)
    var field = TextInputControl(1, input.text, input.cursor, input.anchor, 28)
    field.set_composition(
        input.composition, input.composition_selection_start,
        input.composition_selection_end,
    )
    view.add(field.node())
    # Derived values are computed when the form builds, with no stored copies.
    view.add_label(2, String("Hello, ", input.text), 24)
    view.add_label(3, String("Characters: ", input.text.count_codepoints()), 24)
    view.layout()
    return view^


def sibling_view(count: Int) -> ColumnView:
    var view = ColumnView(Rect(0, 100, 480, Float32(count * 20)), 0, 0)
    for index in range(count):
        view.add_label(10 + index, String("Independent row ", index), 20)
    view.layout()
    return view^


struct Work(ImplicitlyCopyable):
    var form_builds: Int
    var sibling_builds: Int
    var parent_builds: Int
    var layout_input_nodes: Int
    var reconciled_nodes: Int
    var emitted_commands: Int
    var changed_commands: Int

    def __init__(out self):
        self.form_builds = 0
        self.sibling_builds = 0
        self.parent_builds = 0
        self.layout_input_nodes = 0
        self.reconciled_nodes = 0
        self.emitted_commands = 0
        self.changed_commands = 0


struct Probe[mode: Int]:
    var input: TextInputState
    var binding: TextBinding
    var execution: LocalizedExecution
    var form: ColumnView
    var sibling: ColumnView
    var runtime: ColumnRuntime
    var commands: PaintCommands
    var work: Work
    var sibling_count: Int

    def __init__(out self, sibling_count: Int):
        self.input = TextInputState()
        self.binding = TextBinding(FORM)
        self.execution = LocalizedExecution()
        self.form = ColumnView(Rect(0, 0, 480, 100), 0, 0)
        self.sibling = ColumnView(Rect(0, 100, 480, 100), 0, 0)
        self.runtime = ColumnRuntime()
        self.commands = PaintCommands()
        self.work = Work()
        self.sibling_count = sibling_count
        test_check(self.execution.add_scope(ROOT))
        test_check(self.execution.add_scope(FORM, ROOT))
        test_check(self.execution.add_scope(SIBLING, ROOT))
        test_check(self.execution.add_dependency(FORM, FORM))
        test_check(self.execution.add_dependency(SIBLING, SIBLING))
        _ = self.execution.invalidate_scope(ROOT)
        self.flush()
        # Exclude identical initial mount from the reported work.
        self.work = Work()

    def edit(mut self, event: Event) -> Bool:
        comptime if Self.mode == BINDING_MODE:
            return self.binding.replace(self.input, event, self.execution)
        else:
            if not replace_committed(self.input, event):
                return False
            comptime if Self.mode == ROOT_MODE:
                return self.execution.invalidate_scope(ROOT)
            else:
                return self.execution.invalidate_scope(FORM)

    def flush(mut self):
        if self.execution.dirty_count() == 0:
            return
        if self.execution.take_dirty(FORM):
            self.form = form_view(self.input)
            self.work.form_builds += 1
            self.work.layout_input_nodes += self.form.child_count()
        if self.execution.take_dirty(SIBLING):
            self.sibling = sibling_view(self.sibling_count)
            self.work.sibling_builds += 1
            self.work.layout_input_nodes += self.sibling.child_count()
        var parent = ColumnView(
            Rect(0, 0, 480, Float32(100 + self.sibling_count * 20)), 0, 0,
        )
        parent.add_component_view_to(-1, 100, self.form, 10000)
        parent.add_component_view_to(-1, 200, self.sibling, 20000)
        parent.layout()
        self.work.parent_builds += 1
        self.work.layout_input_nodes += parent.child_count()
        self.work.reconciled_nodes += parent.child_count()
        self.runtime.reconcile(parent)
        self.commands = self.runtime.paint()
        self.work.emitted_commands += self.commands.count()
        self.work.changed_commands += self.commands.changed_count()
        _ = self.execution.clear_scope(ROOT)
        _ = self.execution.clear_scope(FORM)
        _ = self.execution.clear_scope(SIBLING)

    def report(self, name: String):
        print(name, ",", self.sibling_count, ",", PASSES, ",",
              self.work.form_builds, ",", self.work.sibling_builds, ",",
              self.work.parent_builds, ",", self.work.layout_input_nodes, ",",
              self.work.reconciled_nodes, ",", self.work.emitted_commands, ",",
              self.work.changed_commands, sep="")


def check_output(a: PaintCommands, b: PaintCommands):
    test_check(a.count() == b.count())
    test_check(a.changed_count() == b.changed_count())
    test_check(a.removed_count() == b.removed_count())
    for index in range(a.count()):
        var left = a.command(index)
        var right = b.command(index)
        test_check(left.id == right.id and left.kind == right.kind)
        test_check(left.text == right.text and left.changed == right.changed)
        test_check(left.bounds.x == right.bounds.x)
        test_check(left.bounds.y == right.bounds.y)
        test_check(left.bounds.width == right.bounds.width)
        test_check(left.bounds.height == right.bounds.height)
        test_check(left.cursor == right.cursor)
        test_check(left.selection_start == right.selection_start)
        test_check(left.selection_end == right.selection_end)
        test_check(left.composition == right.composition)
        test_check(left.semantics.label == right.semantics.label)
        test_check(left.semantics.value == right.semantics.value)


def replace_all(text: String, old: String) -> Event:
    return Event(TextInputEvent(text, 0, old.count_codepoints()))


def check_case(count: Int):
    var root = Probe[ROOT_MODE](count)
    var explicit = Probe[EXPLICIT_MODE](count)
    var bound = Probe[BINDING_MODE](count)
    check_output(root.commands, explicit.commands)
    check_output(explicit.commands, bound.commands)
    var field_slot = bound.runtime.retained_index(10001)
    var sibling_slot = bound.runtime.retained_index(20010)
    for index in range(PASSES):
        var value = String("Name ", index, " 日本語")
        var event = replace_all(value, root.input.text)
        test_check(root.edit(event))
        test_check(explicit.edit(event))
        test_check(bound.edit(event))
        # State is immediate; derived render output is a previous snapshot.
        test_check(bound.input.text == value)
        root.flush()
        explicit.flush()
        bound.flush()
        check_output(root.commands, explicit.commands)
        check_output(explicit.commands, bound.commands)
        test_check(bound.form.child(1).text == String("Hello, ", value))
        test_check(bound.form.child(2).text == String(
            "Characters: ", value.count_codepoints(),
        ))
        test_check(bound.runtime.retained_index(10001) == field_slot)
        test_check(bound.runtime.retained_index(20010) == sibling_slot)
    test_check(root.work.sibling_builds == PASSES)
    test_check(explicit.work.sibling_builds == 0)
    test_check(bound.work.sibling_builds == 0)
    test_check(explicit.work.form_builds == bound.work.form_builds)
    test_check(explicit.work.layout_input_nodes == bound.work.layout_input_nodes)
    test_check(explicit.work.reconciled_nodes == bound.work.reconciled_nodes)
    test_check(explicit.work.emitted_commands == bound.work.emitted_commands)
    root.report("root")
    explicit.report("explicit")
    bound.report("binding")
    # An identical replacement must leave every lane idle.
    var no_op = replace_all(bound.input.text, bound.input.text)
    test_check(not root.edit(no_op))
    test_check(not explicit.edit(no_op))
    test_check(not bound.edit(no_op))
    bound.flush()
    test_check(bound.work.parent_builds == PASSES)


def check_transactions[mode: Int]():
    var bound = Probe[mode](1)
    test_check(bound.edit(replace_all("Ada", "")))
    test_check(bound.edit(replace_all("Grace", "Ada")))
    test_check(bound.work.form_builds == 0)
    test_check(bound.input.text == "Grace")
    test_check(bound.form.child(1).text == "Hello, ")
    bound.flush()
    test_check(bound.work.form_builds == 1)
    test_check(bound.form.child(1).text == "Hello, Grace")
    # Same text can still change selection or clear marked composition.
    bound.input.anchor = 0
    bound.input.set_composition("候補", 0, 2)
    test_check(bound.edit(replace_all("Grace", "Grace")))
    bound.flush()
    test_check(bound.input.anchor == -1)
    test_check(bound.input.composition == "")
    test_check(bound.work.form_builds == 2)
    # Missing scope rejects the edit before changing source state.
    var detached = TextBinding(999)
    test_check(not detached.replace(
        bound.input, replace_all("Lost", "Grace"), bound.execution,
    ))
    test_check(bound.input.text == "Grace")
    test_check(bound.execution.dirty_count() == 0)
    # Empty replacement removes Unicode text through real editor semantics.
    test_check(bound.edit(replace_all("日本語", "Grace")))
    bound.flush()
    test_check(bound.edit(Event(TextInputEvent("", 1, 2))))
    bound.flush()
    test_check(bound.input.text == "日語")
    test_check(bound.input.cursor == 1)
    # Without a replacement range, insert at the real editor cursor.
    test_check(bound.edit(Event(TextInputEvent("!"))))
    bound.flush()
    test_check(bound.input.text == "日!語")
    test_check(bound.input.cursor == 2)
    test_check(not bound.edit(Event(ActionEvent(42))))
    test_check(bound.input.text == "日!語")
    test_check(bound.execution.dirty_count() == 0)


def main():
    check_transactions[ROOT_MODE]()
    check_transactions[EXPLICIT_MODE]()
    check_transactions[BINDING_MODE]()
    print("mode,siblings,edits,form_builds,sibling_builds,parent_builds,"
          "layout_input_nodes,reconciled_nodes,emitted_commands,changed_commands")
    check_case(1)
    check_case(100)
    check_case(1000)
    print("PASS: output parity, derived values, stable slots, no-op, batching, "
          "selection/composition cleanup, Unicode replacement/insertion, "
          "missing scope, unrelated event")
