"""Adapter-only prototype: reuse App's scheduler, preserve ordinary model values.

One bridge belongs to one live App. It owns only scopes it creates. This sample
supports successful parameterless button completions, not a public effects API.
"""
from moxi import App, RequestHandle, RequestScopeHandle, RequestResult, TASK_COMPLETED
from moxi.event import Event, TaskEvent
from runtime import HandlerHost, Screen, require, deliver, reset, update_model
from delivery import DeliveryScope, CapturedAction


struct OwnedScope(ImplicitlyCopyable):
    var target: Int
    var handle: RequestScopeHandle
    def __init__(out self, target: Int, handle: RequestScopeHandle):
        self.target = target
        self.handle = handle


struct Completion[R: Screen & Deinitable](ImplicitlyCopyable):
    var request: RequestHandle
    var action: CapturedAction[Self.R]
    def __init__(out self, request: RequestHandle, action: CapturedAction[Self.R]):
        self.request = request
        self.action = action


struct RequestBridge[R: Screen & Deinitable]:
    var scope: DeliveryScope
    var owners: List[OwnedScope]
    var pending: List[Completion[Self.R]]
    def __init__(out self, app: App[HandlerHost[Self.R]]):
        self.scope = app.component.scope
        self.owners = List[OwnedScope]()
        self.pending = List[Completion[Self.R]]()

    def reconcile(mut self, mut app: App[HandlerHost[Self.R]]):
        require(self.scope.matches(app.component.scope), "bridge belongs to one App lifetime; reset through adapter")
        var retained = List[OwnedScope]()
        for owner in self.owners:
            if app.component.ui.index(owner.target) >= 0:
                retained.append(owner)
            else:
                _ = app.cancel_request_scope(owner.handle)
        self.owners = retained^
        # The scheduler may have dropped bounded-ready-queue entries. Do not
        # retain adapter callbacks after their request metadata is gone/stale.
        var pending = List[Completion[Self.R]]()
        for item in self.pending:
            if app.request_is_current(item.request):
                pending.append(item)
        self.pending = pending^

    def submit(mut self, mut app: App[HandlerHost[Self.R]], target: Int, key: Int = 1) -> Completion[Self.R]:
        self.reconcile(app)
        var action = app.component.capture(target)
        var scope = RequestScopeHandle()
        for owner in self.owners:
            if owner.target == target:
                scope = owner.handle
        if not scope.is_valid():
            scope = app.create_request_scope()
            self.owners.append(OwnedScope(target, scope))
        var handle = app.schedule_scoped_request(scope, key, "adapter work", 60.0)
        require(handle.is_valid(), "request capacity")
        var completion = Completion(handle, action)
        self.pending.append(completion)
        return completion

    def complete(mut self, mut app: App[HandlerHost[Self.R]], completion: Completion[Self.R]) -> Bool:
        # Reject cross-host work before looking at potentially equal numeric handles.
        if not self.scope.matches(app.component.scope) or not app.component.scope.matches(completion.action.scope):
            return False
        self.reconcile(app)
        return app.complete_request(completion.request, TASK_COMPLETED)

    def drain(mut self, mut app: App[HandlerHost[Self.R]]) -> Int:
        app.requests.advance(0.0)
        self.reconcile(app)
        var delivered = 0
        while app.requests.has_ready():
            var result = app.requests.pop_ready()
            var owned = False
            var retained = List[Completion[Self.R]]()
            for pending in self.pending:
                if result.matches(pending.request):
                    owned = True
                    if app.requests.should_deliver(result) and result.status == TASK_COMPLETED:
                        if deliver(app, pending.action):
                            delivered += 1
                else:
                    retained.append(pending)
            self.pending = retained^
            if not owned and app.requests.should_deliver(result):
                _ = app.dispatch(Event(TaskEvent(result.task_id, result.status, result.payload, result.key, result.generation, result.scope_id)))
            self.reconcile(app)
        return delivered

    def change(mut self, mut app: App[HandlerHost[Self.R]], command: def(mut Self.R) thin -> None):
        self.reconcile(app)
        update_model(app, command)
        self.reconcile(app)

    def reset(mut self, mut app: App[HandlerHost[Self.R]], root: Self.R):
        self.reconcile(app)
        for owner in self.owners:
            _ = app.cancel_request_scope(owner.handle)
        self.owners = List[OwnedScope]()
        reset(app, root)
        self.scope = app.component.scope
        self.pending = List[Completion[Self.R]]()
