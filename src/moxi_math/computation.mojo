"""Optional D01 SymPy adapter; owns its process session and never owns notation."""
from std.python import Python, PythonObject
from .model import MathDocument, parse_math
from .editor import MathEditorState

struct MathOperation(ImplicitlyCopyable):
    var value: String
    comptime EXPAND = Self("expand")
    comptime DIFFERENTIATE = Self("differentiate")
    comptime EVALUATE = Self("evaluate")
    comptime SUBSTITUTE = Self("substitute")
    def __init__(out self, value: String):
        self.value = value

def _source(module: PythonObject, builtins: PythonObject, doc: MathDocument, index: Int) raises -> PythonObject:
    var n=doc.nodes[index]
    var children=builtins.list()
    for child in n.children:
        children.append(_source(module,builtins,doc,child))
    return module.source(n.kind.value,n.text,n.extra,children,n.id)

struct MathComputation:
    var module: PythonObject
    var builtins: PythonObject
    var session: PythonObject
    var target: Int
    var revision: Int
    def __init__(out self) raises:
        self.target = -1
        self.revision = -1
        self.module=Python.import_module("moxi_math.backend")
        self.builtins=Python.import_module("builtins")
        self.session=self.module.Computation()
    def submit(mut self, state: MathEditorState, operation: MathOperation = MathOperation.EXPAND, replacement: String = "?") raises -> Bool:
        if state.composition!="":
            return False
        var ancestors=self.builtins.list()
        var index=state.target()
        var parent=state.document.parent(index)
        while parent>=0:
            ancestors.append(state.document.nodes[parent].kind.value)
            parent=state.document.parent(parent)
        var replacement_doc=parse_math(replacement)
        var accepted=Bool(self.session.submit(_source(self.module,self.builtins,state.document,index),ancestors,operation.value,state.document.revision,_source(self.module,self.builtins,replacement_doc,replacement_doc.root)))
        if accepted:
            self.target=state.document.nodes[index].id
            self.revision=state.document.revision
        return accepted
    def tick(mut self, revision: Int) raises -> Bool:
        return Bool(self.session.tick(revision))
    def apply(mut self, mut state: MathEditorState, result: String) raises -> Bool:
        if not Bool(self.session.eligible(state.document.revision)):
            state.status="Stale or unavailable result · original notation retained"
            return False
        return state.apply_fragment(result,self.target,self.revision)
    def message(self) raises -> String:
        return String(self.session.message)
    def result(self) raises -> String:
        return String(self.session.result)
    def has_new_result(self) raises -> Bool:
        return Bool(self.session.new_result)
    def cancel(mut self) raises:
        self.session.cancel()
    def close(mut self) raises:
        self.session.close()
