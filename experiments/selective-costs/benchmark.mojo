"""Bounded timing probe for the selective-updates experiment.

This imports the earlier experiment sources without modifying them.  Timed
frame rows use a real Moxi App event dispatch followed by App.paint(); the
paint is the backend-neutral command stream and does not call a native or GPU
renderer.
"""

from std.time import perf_counter_ns
from std.collections import List

from application import Application
from domain import Services
from runtime import HandlerHost
from selective import (
    AllInputs,
    DisplayInputs,
    ID_STRIDE,
    SelectiveHost,
    SharedInputs,
)
from moxi import (
    App,
    ClickEvent,
    ColumnView,
    CONTAINER_KIND,
    Event,
    PANEL_KIND,
    PaintCommands,
    Point,
    Rect,
    SURFACE_KIND,
    TextInputEvent,
    test_check,
)


comptime FRAME_WARMUPS = 2
comptime FRAME_SAMPLES = 3
comptime STAGE_WARMUPS = 2
comptime STAGE_SAMPLES = 2
comptime LARGE_FRAME_WARMUPS = 1
comptime LARGE_FRAME_SAMPLES = 1
comptime LARGE_STAGE_WARMUPS = 1
comptime LARGE_STAGE_SAMPLES = 1
comptime MODEL_WARMUPS = 1
comptime MODEL_SAMPLES = 3
comptime CHECKSUM_MODULUS = 1_000_000_007
comptime FRAME_WIDTH = 640
comptime FRAME_HEIGHT = 400_000


def bounds() -> Rect:
    return Rect(0, 0, FRAME_WIDTH, FRAME_HEIGHT)


def bit(value: Bool) -> Int:
    if value:
        return 1
    return 0


def text_checksum(value: String) -> Int:
    var checksum = 31
    for index in range(value.count_codepoints()):
        checksum = (
            checksum * 131
            + ord(String(value[codepoint=index:index + 1]))
        ) % CHECKSUM_MODULUS
    return checksum


def view_checksum(view: ColumnView) -> Int:
    """Observable leaf checksum, excluding IDs and composition containers."""
    var checksum = 17
    for i in range(view.child_count()):
        ref node = view.child(i)
        if node.kind == CONTAINER_KIND:
            continue
        checksum = (
            checksum * 131
            + node.kind * 17
            + text_checksum(node.text)
            + bit(node.enabled) * 7
            + bit(node.checked) * 11
        ) % CHECKSUM_MODULUS
    return checksum


def paint_checksum(commands: PaintCommands) -> Int:
    """Observable leaf-command checksum, excluding IDs and frame decorations."""
    var checksum = 23
    for i in range(commands.count()):
        var command = commands.command(i)
        if command.kind == SURFACE_KIND or command.kind == PANEL_KIND:
            continue
        checksum = (
            checksum * 137
            + command.kind * 19
            + text_checksum(command.text)
            + bit(command.enabled) * 7
            + bit(command.checked) * 11
        ) % CHECKSUM_MODULUS
    return checksum


def services_checksum(services: Services) -> Int:
    """Small checksum used after timed equality/snapshot work."""
    var checksum = 29
    checksum = (checksum * 131 + services.document.identity) % CHECKSUM_MODULUS
    checksum = (checksum * 131 + services.document.name.byte_length()) % CHECKSUM_MODULUS
    checksum = (checksum * 131 + services.document.revision) % CHECKSUM_MODULUS
    checksum = (checksum * 131 + services.document.commits) % CHECKSUM_MODULUS
    checksum = (checksum * 131 + services.settings.max_length) % CHECKSUM_MODULUS
    checksum = (checksum * 131 + bit(services.settings.writable)) % CHECKSUM_MODULUS
    checksum = (checksum * 131 + services.settings.unrelated) % CHECKSUM_MODULUS
    checksum = (checksum * 131 + len(services.document.history)) % CHECKSUM_MODULUS
    if len(services.document.history) > 0:
        checksum = (
            checksum * 131
            + services.document.history[0].byte_length()
            + services.document.history[len(services.document.history) - 1].byte_length()
        ) % CHECKSUM_MODULUS
    return checksum


def emit_sample(
    phase: String,
    mode: String,
    operation: String,
    editors: Int,
    sample: Int,
    elapsed: Int,
    view_sum: Int,
    paint_sum: Int,
):
    print(
        "SAMPLE|",
        phase,
        "|",
        mode,
        "|",
        operation,
        "|",
        editors,
        "|",
        sample,
        "|",
        elapsed,
        "|",
        view_sum,
        "|",
        paint_sum,
        sep="",
    )


def emit_model_sample(
    phase: String,
    history_size: Int,
    sample: Int,
    repeats: Int,
    elapsed: Int,
    total_elapsed: Int,
    result: Int,
    checksum: Int,
):
    print(
        "MODEL|",
        phase,
        "|",
        history_size,
        "|",
        sample,
        "|",
        repeats,
        "|",
        elapsed,
        "|",
        total_elapsed,
        "|",
        result,
        "|",
        checksum,
        sep="",
    )


def handler_control_id(host: HandlerHost[Application], key: Int, position: Int) -> Int:
    var path = "/k1:1/k1:1/k1:1/k"
    path += String(String(key).byte_length()) + ":" + String(key)
    path += "/p" + String(position)
    for control in host.ui.controls:
        if control.path == path and control.active:
            return control.id
    test_check(False)
    return -1


def selective_control_id[I: SharedInputs](
    host: SelectiveHost[I], key: Int, position: Int
) -> Int:
    var index = host.lookup.find(key)
    test_check(index >= 0)
    var path = "/k" + String(String(key).byte_length()) + ":" + String(key)
    path += "/p" + String(position)
    for control in host.regions[index].ui.controls:
        if control.path == path and control.active:
            return key * ID_STRIDE + control.id
    test_check(False)
    return -1


def local_event(target: Int) -> Event:
    var event = Event(TextInputEvent("Local", 0, 3))
    event.set_target(target)
    return event


def prepare_shared_handler(mut app: App[HandlerHost[Application]], count: Int) -> ClickEvent:
    var draft = local_event(handler_control_id(app.component, count, 2))
    test_check(app.update(draft))
    var prepared = app.paint()
    test_check(paint_checksum(prepared) >= 0)
    var apply_id = handler_control_id(app.component, count, 5)
    var apply_bounds = app.view.bounds_for(apply_id)
    return ClickEvent(Point(apply_bounds.x + 8, apply_bounds.y + 8))


def prepare_shared_selective[I: SharedInputs](
    mut app: App[SelectiveHost[I]], count: Int
) -> ClickEvent:
    var draft = local_event(selective_control_id(app.component, count, 2))
    test_check(app.update(draft))
    var prepared = app.paint()
    test_check(paint_checksum(prepared) >= 0)
    var apply_id = selective_control_id(app.component, count, 5)
    var apply_bounds = app.view.bounds_for(apply_id)
    return ClickEvent(Point(apply_bounds.x + 8, apply_bounds.y + 8))


def handler_frame(
    count: Int, operation: String, sample: Int, emit: Bool
) -> Int:
    var app = App(HandlerHost(Application(count)), bounds())
    var initial = app.paint()
    test_check(paint_checksum(initial) >= 0)

    var event: Event
    if operation == "local":
        event = local_event(handler_control_id(app.component, count, 2))
    else:
        var click = prepare_shared_handler(app, count)
        event = Event(click)

    var start = perf_counter_ns()
    var changed = app.update(event)
    var commands = app.paint()
    var elapsed = perf_counter_ns() - start

    var view_sum = view_checksum(app.view)
    var paint_sum = paint_checksum(commands)
    test_check(changed)
    if operation == "local":
        test_check(
            app.component.root.shell.workspace.group.entries[count - 1].value.draft
            == "Local"
        )
    else:
        test_check(app.component.root.services.document.name == "Local")
        test_check(app.component.root.services.document.commits == 1)
    if emit:
        emit_sample("frame", "handler", operation, count, sample, elapsed, view_sum, paint_sum)
    return elapsed


def selective_frame[I: SharedInputs](
    count: Int, operation: String, mode: String, sample: Int, emit: Bool
) -> Int:
    var app = App(SelectiveHost[I](Application(count)), bounds())
    var initial = app.paint()
    test_check(paint_checksum(initial) >= 0)

    var event: Event
    if operation == "local":
        event = local_event(selective_control_id(app.component, count, 2))
    else:
        var click = prepare_shared_selective(app, count)
        event = Event(click)

    var start = perf_counter_ns()
    var changed = app.update(event)
    var commands = app.paint()
    var elapsed = perf_counter_ns() - start

    var view_sum = view_checksum(app.view)
    var paint_sum = paint_checksum(commands)
    test_check(changed)
    if operation == "local":
        test_check(
            app.component.root.shell.workspace.group.entries[count - 1].value.draft
            == "Local"
        )
    else:
        test_check(app.component.root.services.document.name == "Local")
        test_check(app.component.root.services.document.commits == 1)
    if emit:
        emit_sample("frame", mode, operation, count, sample, elapsed, view_sum, paint_sum)
    return elapsed


def handler_build(count: Int, sample: Int, emit: Bool) -> Int:
    var host = HandlerHost(Application(count))
    var start = perf_counter_ns()
    var view = host.build(bounds())
    var elapsed = perf_counter_ns() - start
    var view_sum = view_checksum(view)
    test_check(view_sum >= 0)
    if emit:
        emit_sample("build_layout", "handler", "none", count, sample, elapsed, view_sum, 0)
    return elapsed


def selective_build[I: SharedInputs](
    count: Int, mode: String, sample: Int, emit: Bool
) -> Int:
    var host = SelectiveHost[I](Application(count))
    var start = perf_counter_ns()
    var view = host.build(bounds())
    var elapsed = perf_counter_ns() - start
    var view_sum = view_checksum(view)
    test_check(view_sum >= 0)
    if emit:
        emit_sample("build_layout", mode, "none", count, sample, elapsed, view_sum, 0)
    return elapsed


def handler_rebuild(count: Int, sample: Int, emit: Bool) -> Int:
    var app = App(HandlerHost(Application(count)), bounds())
    var initial = app.paint()
    test_check(paint_checksum(initial) >= 0)
    var start = perf_counter_ns()
    app.rebuild()
    var elapsed = perf_counter_ns() - start
    var view_sum = view_checksum(app.view)
    var after = app.paint()
    var paint_sum = paint_checksum(after)
    if emit:
        emit_sample("app_rebuild_idle", "handler", "none", count, sample, elapsed, view_sum, paint_sum)
    return elapsed


def selective_rebuild[I: SharedInputs](
    count: Int, mode: String, sample: Int, emit: Bool
) -> Int:
    var app = App(SelectiveHost[I](Application(count)), bounds())
    var initial = app.paint()
    test_check(paint_checksum(initial) >= 0)
    var start = perf_counter_ns()
    app.rebuild()
    var elapsed = perf_counter_ns() - start
    var view_sum = view_checksum(app.view)
    var after = app.paint()
    var paint_sum = paint_checksum(after)
    if emit:
        emit_sample("app_rebuild_idle", mode, "none", count, sample, elapsed, view_sum, paint_sum)
    return elapsed


def handler_paint_after_update(count: Int, sample: Int, emit: Bool) -> Int:
    var app = App(HandlerHost(Application(count)), bounds())
    var initial = app.paint()
    test_check(paint_checksum(initial) >= 0)
    var event = local_event(handler_control_id(app.component, count, 2))
    test_check(app.update(event))
    var start = perf_counter_ns()
    var commands = app.paint()
    var elapsed = perf_counter_ns() - start
    var view_sum = view_checksum(app.view)
    var paint_sum = paint_checksum(commands)
    if emit:
        emit_sample("paint_after_update", "handler", "local", count, sample, elapsed, view_sum, paint_sum)
    return elapsed


def selective_paint_after_update[I: SharedInputs](
    count: Int, mode: String, sample: Int, emit: Bool
) -> Int:
    var app = App(SelectiveHost[I](Application(count)), bounds())
    var initial = app.paint()
    test_check(paint_checksum(initial) >= 0)
    var event = local_event(selective_control_id(app.component, count, 2))
    test_check(app.update(event))
    var start = perf_counter_ns()
    var commands = app.paint()
    var elapsed = perf_counter_ns() - start
    var view_sum = view_checksum(app.view)
    var paint_sum = paint_checksum(commands)
    if emit:
        emit_sample("paint_after_update", mode, "local", count, sample, elapsed, view_sum, paint_sum)
    return elapsed


def run_frame_case(count: Int):
    var warmups = FRAME_WARMUPS
    var samples = FRAME_SAMPLES
    if count >= 1000:
        # Keep the quadratic full-render baseline bounded at the largest
        # requested size while still exercising every mode and operation.
        warmups = LARGE_FRAME_WARMUPS
        samples = LARGE_FRAME_SAMPLES
    for _ in range(warmups):
        _ = handler_frame(count, "local", -1, False)
        _ = handler_frame(count, "shared", -1, False)
        _ = selective_frame[AllInputs](count, "local", "all_inputs", -1, False)
        _ = selective_frame[AllInputs](count, "shared", "all_inputs", -1, False)
        _ = selective_frame[DisplayInputs](count, "local", "display_inputs", -1, False)
        _ = selective_frame[DisplayInputs](count, "shared", "display_inputs", -1, False)
    for sample in range(samples):
        _ = handler_frame(count, "local", sample, True)
        _ = handler_frame(count, "shared", sample, True)
        _ = selective_frame[AllInputs](count, "local", "all_inputs", sample, True)
        _ = selective_frame[AllInputs](count, "shared", "all_inputs", sample, True)
        _ = selective_frame[DisplayInputs](count, "local", "display_inputs", sample, True)
        _ = selective_frame[DisplayInputs](count, "shared", "display_inputs", sample, True)


def run_stage_case(count: Int):
    var warmups = STAGE_WARMUPS
    var samples = STAGE_SAMPLES
    if count >= 1000:
        # Stage coverage remains present, but the largest case is deliberately
        # one warm-up plus one sample to avoid an unbounded baseline run.
        warmups = LARGE_STAGE_WARMUPS
        samples = LARGE_STAGE_SAMPLES
    for _ in range(warmups):
        _ = handler_build(count, -1, False)
        _ = handler_rebuild(count, -1, False)
        _ = handler_paint_after_update(count, -1, False)
        _ = selective_build[AllInputs](count, "all_inputs", -1, False)
        _ = selective_rebuild[AllInputs](count, "all_inputs", -1, False)
        _ = selective_paint_after_update[AllInputs](count, "all_inputs", -1, False)
        _ = selective_build[DisplayInputs](count, "display_inputs", -1, False)
        _ = selective_rebuild[DisplayInputs](count, "display_inputs", -1, False)
        _ = selective_paint_after_update[DisplayInputs](count, "display_inputs", -1, False)
    for sample in range(samples):
        _ = handler_build(count, sample, True)
        _ = handler_rebuild(count, sample, True)
        _ = handler_paint_after_update(count, sample, True)
        _ = selective_build[AllInputs](count, "all_inputs", sample, True)
        _ = selective_rebuild[AllInputs](count, "all_inputs", sample, True)
        _ = selective_paint_after_update[AllInputs](count, "all_inputs", sample, True)
        _ = selective_build[DisplayInputs](count, "display_inputs", sample, True)
        _ = selective_rebuild[DisplayInputs](count, "display_inputs", sample, True)
        _ = selective_paint_after_update[DisplayInputs](count, "display_inputs", sample, True)


def history_services(history_size: Int, variant: Int) -> Services:
    var services = Services()
    services.document.name = String("Base-", variant)
    for i in range(history_size):
        services.document.history.append(String("history-", variant, "-", i))
    return services^


def model_checksum(snapshot: AllInputs) -> Int:
    return services_checksum(snapshot.snapshot)


def model_repeats(history_size: Int) -> Int:
    # Empty-state operations are below the counter's useful single-call
    # resolution. Repeat only that case and report the normalized per-call
    # timing plus the raw total below.
    if history_size == 0:
        return 1024
    return 1


def run_model_case(history_size: Int):
    var repeats = model_repeats(history_size)
    for _ in range(MODEL_WARMUPS):
        var warm = history_services(history_size, 0)
        var warm_snapshot = AllInputs(warm)
        test_check(warm_snapshot.matches(warm))
        _ = model_checksum(warm_snapshot)

    for sample in range(MODEL_SAMPLES):
        var services = history_services(history_size, sample % 2)
        var alternate = services
        if history_size > 0:
            alternate.document.history[history_size - 1] = String("alternate-", sample)
        else:
            alternate.document.name = String("Alternate-", sample)

        var created = AllInputs(services)
        var repeated_snapshots = List[AllInputs]()
        if history_size == 0:
            # Use runtime-indexed, prebuilt snapshots for the sub-resolution
            # empty-history equality cases so the optimizer cannot replace a
            # repeated call with one known boolean constant.
            for _ in range(repeats):
                repeated_snapshots.append(AllInputs(services))
        var snapshot_sink = 0
        var start_snapshot = perf_counter_ns()
        for _ in range(repeats):
            var candidate = AllInputs(services)
            snapshot_sink = (
                snapshot_sink
                + candidate.snapshot.document.name.byte_length()
                + len(candidate.snapshot.document.history)
            ) % CHECKSUM_MODULUS
        var snapshot_total = perf_counter_ns() - start_snapshot
        var snapshot_elapsed = (snapshot_total + repeats - 1) // repeats
        test_check(snapshot_total > 0)
        test_check(snapshot_elapsed > 0)
        var snapshot_sum = (model_checksum(created) + snapshot_sink) % CHECKSUM_MODULUS
        test_check(created.matches(services))
        test_check(not created.matches(alternate))
        emit_model_sample(
            "snapshot_create",
            history_size,
            sample,
            repeats,
            snapshot_elapsed,
            snapshot_total,
            1,
            snapshot_sum,
        )

        var same_sink = 0
        var start_same = perf_counter_ns()
        for iteration in range(repeats):
            var observed_same: Bool
            if history_size == 0:
                observed_same = repeated_snapshots[iteration].matches(services)
            else:
                observed_same = created.matches(services)
            same_sink += bit(observed_same)
        var same_total = perf_counter_ns() - start_same
        var same_elapsed = (same_total + repeats - 1) // repeats
        test_check(same_total > 0)
        test_check(same_elapsed > 0)
        var same = created.matches(services)
        var same_sum = (model_checksum(created) + same_sink) % CHECKSUM_MODULUS
        test_check(same)
        emit_model_sample(
            "equality_same",
            history_size,
            sample,
            repeats,
            same_elapsed,
            same_total,
            bit(same),
            same_sum,
        )

        var alternate_sink = 0
        var start_alternate = perf_counter_ns()
        for iteration in range(repeats):
            var observed_alternate: Bool
            if history_size == 0:
                observed_alternate = repeated_snapshots[iteration].matches(alternate)
            else:
                observed_alternate = created.matches(alternate)
            alternate_sink += bit(observed_alternate)
        var alternate_total = perf_counter_ns() - start_alternate
        var alternate_elapsed = (alternate_total + repeats - 1) // repeats
        test_check(alternate_total > 0)
        test_check(alternate_elapsed > 0)
        var differs = created.matches(alternate)
        var alternate_sum = (model_checksum(created) + alternate_sink) % CHECKSUM_MODULUS
        test_check(not differs)
        emit_model_sample(
            "equality_alternate_tail",
            history_size,
            sample,
            repeats,
            alternate_elapsed,
            alternate_total,
            bit(differs),
            alternate_sum,
        )


def main():
    # The 1,000-editor cases are intentionally last so smaller correctness and
    # timing rows complete before the most expensive baseline work.
    run_stage_case(2)
    run_frame_case(2)
    run_stage_case(100)
    run_frame_case(100)
    run_stage_case(1000)
    run_frame_case(1000)
    run_model_case(0)
    run_model_case(10_000)
    run_model_case(100_000)
    print("PASS|benchmark correctness and timing protocol")
