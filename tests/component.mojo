"""Component lifecycle and trait-conformance contract test."""

from moxi import test_check
from moxi import App, ClickEvent, ColumnView, Component, CounterState, Point, Rect


struct GreetingComponent(Component):
    def __init__(out self):
        pass

    def build(self, bounds: Rect) -> ColumnView:
        var view = ColumnView(bounds, 10.0, 4.0)
        view.add_label(7, "Hello from a component", 24.0)
        view.layout()
        return view^


def built_child_count[ComponentType: Component](component: ComponentType) -> Int:
    var view = component.build(Rect(0.0, 0.0, 200.0, 80.0))
    return view.child_count()


def main():
    var greeting = GreetingComponent()
    test_check(built_child_count(greeting) == 1)

    var component = CounterState()
    test_check(built_child_count(component) == 3)

    var app = App[CounterState](component, Rect(0.0, 0.0, 384.0, 184.0))
    test_check(app.view.child_count() == 3)
    test_check(app.execution_build_count(0) == 1)
    test_check(app.paint().count() == 5)
    test_check(not app.update(ClickEvent(Point(12.0, 12.0))))
    test_check(app.component.count == 0)
    test_check(app.update(ClickEvent(Point(72.0, 130.0))))
    test_check(app.component.count == 1)
    test_check(app.execution_build_count(0) == 2)
    test_check(app.view.child(1).text == "Count: 1")
    test_check(app.resize(Rect(0.0, 0.0, 480.0, 240.0)))
    test_check(app.execution_build_count(0) == 3)
    test_check(app.view.child(0).bounds.width == 416.0)

    print("Moxi component test passed")
