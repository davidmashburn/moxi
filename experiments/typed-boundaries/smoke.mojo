from host import WorkbenchHost
from moxi import App, Rect

def main():
    var app = App(WorkbenchHost(), Rect(0, 0, 800, 4000))
    print(app.view.child_count(), app.component.render_count())
