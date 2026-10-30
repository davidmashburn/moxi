"""A hidden setting still invalidates whole Services/Settings contexts."""
from host import WorkbenchHost
from runtime import require

def main():
    var host = WorkbenchHost()
    host.reset_counts()
    host.root.services.settings.unrelated += 1
    host.refresh()
    require(host.render_count() == 5, "hidden setting rebuilds all broad-context readers")
    require(host.caches.header.renders == 0, "header remains cached")
    require(host.caches.scratch.renders == 0, "scratch remains cached")
    require(host.caches.inspector.renders == 0, "document-only inspector remains cached")
    print("PASS conservative cost: hidden setting rerenders five broad-context readers")
