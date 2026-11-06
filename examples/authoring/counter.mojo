"""Run the shared Counter model without a native window.

The model is in src/moxi_demo/authoring_examples/counter.mojo.
"""
from moxi import App, Rect
from moxi.authoring import HandlerHost, update_model
from moxi_demo.authoring_examples.counter import Counter

def main():
    var app = App(HandlerHost(Counter()), Rect(0, 0, 320, 200))
    # Stand in for an external update. A button dispatch publishes automatically.
    update_model(app, Counter.increment)
    print("Count:", app.component.root.count)
