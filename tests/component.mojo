"""Component lifecycle and trait-conformance contract test."""

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
    assert built_child_count(greeting) == 1

    var component = CounterState()
    assert built_child_count(component) == 3

    var app = App[CounterState](component, Rect(0.0, 0.0, 384.0, 184.0))
    assert app.view.child_count() == 3
    assert app.paint().count() == 5
    assert not app.update(ClickEvent(Point(12.0, 12.0)))
    assert app.component.count == 0
    assert app.update(ClickEvent(Point(72.0, 130.0)))
    assert app.component.count == 1
    assert app.view.child(1).text == "Count: 1"
    assert app.resize(Rect(0.0, 0.0, 480.0, 240.0))
    assert app.view.child(0).bounds.width == 416.0

    print("Moxi component test passed")
