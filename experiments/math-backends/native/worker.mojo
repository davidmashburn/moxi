"""SymEngine C wrapper probe. Move-only owners never enter document data."""
from std.ffi import external_call
from std.memory import Pointer
from std.collections import Span
from std.python import Python, PythonObject

comptime Raw = Pointer[UInt8, MutUntrackedOrigin]

# Wire vocabulary is centralized in the shared Python Kind/Operation enums.
# Mojo dispatch compares their members, not independently spelled policy values.
struct Expression(Movable):
    var handle: Raw

    def __init__(out self) raises:
        self.handle = external_call["moxi_math_new", Raw]()

    def __deinit__(deinit self):
        external_call["moxi_math_free", NoneType](self.handle)

    def text(self, type_name: Bool = False) -> String:
        var p: Raw
        if type_name:
            p = external_call["moxi_math_type", Raw](self.handle)
        else:
            p = external_call["moxi_math_text", Raw](self.handle)
        var result = String(unsafe_from_utf8=Span(unsafe_ptr=p, length=Int(external_call["strlen", UInt](p))))
        external_call["moxi_math_text_free", NoneType](p)
        return result


def checked(code: Int32) raises:
    if code != 0:
        raise Error(String("SymEngine C error ", code))


def construct(n: PythonObject, kinds: PythonObject) raises -> Expression:
    var result = Expression()
    var kind = n["kind"]
    var values = n["values"]
    var children = n["children"]
    if Bool(kind == kinds.INTEGER):
        var text_storage = String(values[0])
        var text = text_storage.as_c_string_span()
        checked(external_call["integer_set_str", Int32](result.handle, text.ptr()))
    elif Bool(kind == kinds.SYMBOL):
        var text_storage = String(values[0])
        var text = text_storage.as_c_string_span()
        checked(external_call["symbol_set", Int32](result.handle, text.ptr()))
    elif Bool(kind == kinds.RATIONAL):
        var p = Expression()
        var q = Expression()
        var ps_storage = String(values[0])
        var ps = ps_storage.as_c_string_span()
        var qs_storage = String(values[1])
        var qs = qs_storage.as_c_string_span()
        checked(external_call["integer_set_str", Int32](p.handle, ps.ptr()))
        checked(external_call["integer_set_str", Int32](q.handle, qs.ptr()))
        checked(external_call["rational_set", Int32](result.handle, p.handle, q.handle))
    elif Bool(kind == kinds.ADD) or Bool(kind == kinds.MUL):
        var first = construct(children[0], kinds)
        checked(external_call["basic_assign", Int32](result.handle, first.handle))
        for i in range(1, len(children)):
            var child = construct(children[i], kinds)
            var next_value = Expression()
            if Bool(kind == kinds.ADD):
                checked(external_call["basic_add", Int32](next_value.handle, result.handle, child.handle))
            else:
                checked(external_call["basic_mul", Int32](next_value.handle, result.handle, child.handle))
            checked(external_call["basic_assign", Int32](result.handle, next_value.handle))
    elif Bool(kind == kinds.POW):
        var base = construct(children[0], kinds)
        var exponent = construct(children[1], kinds)
        checked(external_call["basic_pow", Int32](result.handle, base.handle, exponent.handle))
    elif Bool(kind == kinds.SIN) or Bool(kind == kinds.COS):
        var argument = construct(children[0], kinds)
        if Bool(kind == kinds.SIN):
            checked(external_call["basic_sin", Int32](result.handle, argument.handle))
        else:
            checked(external_call["basic_cos", Int32](result.handle, argument.handle))
    else:
        raise Error("Unsupported native input")
    return result^


def convert(expr: Expression, envelope: PythonObject, support: PythonObject, model: PythonObject, builtins: PythonObject, budget: PythonObject, depth: Int = 0) raises -> PythonObject:
    budget[0] = budget[0] - 1
    if depth > 64 or Bool(budget[0] < 0):
        raise Error("Unsupported result: import budget exceeded")
    var name = expr.text(True)
    var values = builtins.list()
    var children = builtins.list()
    var kind = model.Kind.INTEGER
    # These are pinned C API class names, not document kinds.
    if name == "Integer":
        values.append(expr.text())
    elif name == "Rational":
        kind = model.Kind.RATIONAL
        var p = Expression()
        var q = Expression()
        checked(external_call["basic_as_numer_denom", Int32](p.handle, q.handle, expr.handle))
        values.append(p.text())
        values.append(q.text())
    elif name == "Symbol":
        return support.symbol_result(expr.text(), envelope)
    else:
        if name == "Add":
            kind = model.Kind.ADD
        elif name == "Mul":
            kind = model.Kind.MUL
        elif name == "Pow":
            kind = model.Kind.POW
        elif name == "Sin":
            kind = model.Kind.SIN
        elif name == "Cos":
            kind = model.Kind.COS
        else:
            raise Error(String("Unsupported native result type: ", name))
        var count = external_call["moxi_math_arg_count", Int64](expr.handle)
        if count < 0 or count > 4096:
            raise Error("Unsupported native result argument count")
        for i in range(Int(count)):
            var child = Expression()
            checked(external_call["moxi_math_arg", Int32](child.handle, expr.handle, Int64(i)))
            children.append(convert(child, envelope, support, model, builtins, budget, depth + 1))
    return support.make_node(kind, values, children)


def execute(envelope: PythonObject, support: PythonObject, model: PythonObject, builtins: PythonObject, clock: PythonObject) raises -> PythonObject:
    var started = clock.perf_counter_ns()
    var request = support.prepare(envelope)
    var expr = construct(request["expression"], model.Kind)
    var result = Expression()
    var constructed = clock.perf_counter_ns()
    var op = request["operation"]
    if Bool(op == model.Operation.EVALUATE):
        checked(external_call["basic_assign", Int32](result.handle, expr.handle))
    elif Bool(op == model.Operation.EXPAND):
        checked(external_call["basic_expand", Int32](result.handle, expr.handle))
    elif Bool(op == model.Operation.DIFFERENTIATE):
        var variable = construct(request["variable"], model.Kind)
        checked(external_call["basic_diff", Int32](result.handle, expr.handle, variable.handle))
    elif Bool(op == model.Operation.SUBSTITUTE):
        var variable = construct(request["variable"], model.Kind)
        var replacement = construct(request["replacement"], model.Kind)
        checked(external_call["basic_subs2", Int32](result.handle, expr.handle, variable.handle, replacement.handle))
    else:
        raise Error("Unsupported operation")
    var computed = clock.perf_counter_ns()
    var budget = builtins.list()
    budget.append(4096)
    var output = convert(result, envelope, support, model, builtins, budget)
    var packet = builtins.list()
    packet.append(output)
    packet.append(started)
    packet.append(constructed)
    packet.append(computed)
    packet.append(clock.perf_counter_ns())
    return packet


def main() raises:
    var support = Python.import_module("moxi_math_probe.native_support")
    var model = Python.import_module("moxi_math_probe.model")
    var builtins = Python.import_module("builtins")
    var clock = Python.import_module("time")
    var p = external_call["symengine_version", Raw]()
    support.ready(String(unsafe_from_utf8=Span(unsafe_ptr=p, length=Int(external_call["strlen", UInt](p)))))
    while True:
        var envelope = support.next_request()
        if not Bool(envelope):
            break
        try:
            # All Expression owners die at execute's return, before reporting.
            var result = execute(envelope, support, model, builtins, clock)
            support.finish(envelope, result[0], result[1], result[2], result[3], result[4], external_call["moxi_math_live", Int64](), external_call["moxi_math_peak", Int64]())
        except e:
            support.failure(envelope, String(e), external_call["moxi_math_live", Int64]())
