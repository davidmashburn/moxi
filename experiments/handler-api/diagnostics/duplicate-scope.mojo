from runtime import UI

def main():
    var ui = UI[Int]()
    ui.begin()
    ui.begin_scope("same")
    ui.end_scope()
    ui.begin_scope("same")
