"""A cache refuses same-key remount; routes still enforce mounted authority."""
from host import WorkbenchHost
from workbench import Workbench

def main():
    var host = WorkbenchHost()
    var key = host.root.inspector_key()
    host.caches.inspector.refresh(host.root.inspector, host.root.services.document,
        Workbench.route_inspector, key, mounted=False)
    host.caches.inspector.refresh(host.root.inspector, host.root.services.document,
        Workbench.route_inspector, key)
