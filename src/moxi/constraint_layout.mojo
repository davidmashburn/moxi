"""Optional Kiwi region policy with staged, bounded solver ownership.

Link the pinned layout-kiwi C bridge. Numeric optional strengths are weighted
objectives, not lexicographic priorities. Parent allocation is always required.
"""
from std.collections import List, Dict
from std.memory import ArcPointer, Pointer
from std.ffi import external_call
from std.math import isfinite
from .geometry import Rect, Size

comptime REQUIRED = Float64(1001001000)
comptime EQUAL = 0
comptime AT_MOST = 1
comptime AT_LEAST = 2
comptime PARENT_WIDTH = 1
comptime PARENT_HEIGHT = 2


def coordinate(key: Int, axis: Int) raises -> Int:
    """x/y/width/height variable IDs, stable within this region."""
    if key <= 0 or key > 536870910 or axis < 0 or axis > 3:
        raise Error("Invalid constraint key or coordinate")
    return key * 4 + axis


struct LinearConstraint(ImplicitlyCopyable):
    var variables: ArcPointer[List[Int32]]
    var coefficients: ArcPointer[List[Float64]]
    var constant: Float64
    var relation: Int
    var strength: Float64

    def __init__(out self, variables: List[Int], coefficients: List[Float64],
                 constant: Float64 = 0, relation: Int = EQUAL, strength: Float64 = REQUIRED) raises:
        if len(variables) != len(coefficients) or not isfinite(constant) or not isfinite(strength) or strength < 0 or strength > REQUIRED or relation < 0 or relation > 2:
            raise Error("Invalid linear constraint")
        var ids = List[Int32]()
        for i in range(len(variables)):
            if variables[i] <= 0 or variables[i] > 2147483647 or not isfinite(coefficients[i]):
                raise Error("Invalid constraint term")
            ids.append(Int32(variables[i]))
        self.variables = ArcPointer(ids^)
        self.coefficients = ArcPointer(coefficients.copy())
        self.constant = constant
        self.relation = relation
        self.strength = strength

    def identical(self, other: Self) -> Bool:
        if self.constant != other.constant or self.relation != other.relation or self.strength != other.strength or len(self.variables[]) != len(other.variables[]):
            return False
        for i in range(len(self.variables[])):
            if self.variables[][i] != other.variables[][i] or self.coefficients[][i] != other.coefficients[][i]:
                return False
        return True


struct _ConstraintSolver:
    var handle: UInt
    def __init__(out self) raises:
        self.handle = external_call["layout_kiwi_create", UInt]()
        if self.handle == 0:
            raise Error("Cannot create constraint solver")
    def __deinit__(deinit self):
        external_call["layout_kiwi_destroy", NoneType](self.handle)
    def check(self, code: Int32) raises:
        if code != 0:
            var message = external_call["layout_kiwi_last_error", Pointer[UInt8, MutAnyOrigin]](self.handle)
            raise Error(String("Constraint failure: ", String(message)))
    def variable(self, id: Int) raises:
        self.check(external_call["layout_kiwi_add_variable", Int32](self.handle, Int32(id)))
    def constraint(self, id: Int, constraint: LinearConstraint) raises:
        self.check(external_call["layout_kiwi_add_constraint", Int32](self.handle, Int32(id), constraint.variables[].unsafe_ptr(), constraint.coefficients[].unsafe_ptr(), UInt(len(constraint.variables[])), constraint.constant, Int32(constraint.relation), constraint.strength))
    def value(self, id: Int) raises -> Float64:
        var result: Float64 = 0
        self.check(external_call["layout_kiwi_get_value", Int32](self.handle, Int32(id), Pointer(to=result)))
        if not isfinite(result):
            raise Error("Constraint solver produced a nonfinite coordinate")
        return result


struct ConstraintPlan:
    var rectangles: Dict[Int, Rect]
    var residuals: List[Float64]
    var _owner: ArcPointer[Int]
    var _solver: ArcPointer[_ConstraintSolver]
    var _revision: Int
    var _generation: Int
    var _size: Size
    def __init__(out self, owner: ArcPointer[Int], solver: ArcPointer[_ConstraintSolver],
                 revision: Int, generation: Int, size: Size):
        self.rectangles = Dict[Int, Rect]()
        self.residuals = List[Float64]()
        self._owner = owner
        self._solver = solver
        self._revision = revision
        self._generation = generation
        self._size = size


struct ConstraintRegion:
    var _owner: ArcPointer[Int]
    var _keys: List[Int]
    var _constraints: List[LinearConstraint]
    var _revision: Int
    var _generation: Int
    var _solver: ArcPointer[_ConstraintSolver]
    var _published_revision: Int
    var _published_size: Size
    var _rectangles: Dict[Int, Rect]
    var _residuals: List[Float64]
    var solver_builds: Int

    def __init__(out self) raises:
        self._owner = ArcPointer(0)
        self._keys = List[Int]()
        self._constraints = List[LinearConstraint]()
        self._revision = 0
        self._generation = 0
        self._solver = ArcPointer(_ConstraintSolver())
        self._published_revision = -1
        self._published_size = Size(0,0)
        self._rectangles = Dict[Int, Rect]()
        self._residuals = List[Float64]()
        self.solver_builds = 0

    def model(mut self, keys: List[Int], constraints: List[LinearConstraint]) raises:
        var seen = Dict[Int, Bool]()
        for key in keys:
            _ = coordinate(key, 3)
            if key in seen:
                raise Error("Duplicate child in constraint region")
            seen[key] = True
        for constraint in constraints:
            for variable in constraint.variables[]:
                var id = Int(variable)
                if id != PARENT_WIDTH and id != PARENT_HEIGHT and id // 4 not in seen:
                    raise Error("Constraint refers to a foreign region variable")
        var same = len(keys) == len(self._keys) and len(constraints) == len(self._constraints)
        if same:
            for i in range(len(keys)):
                same = same and keys[i] == self._keys[i]
            for i in range(len(constraints)):
                same = same and constraints[i].identical(self._constraints[i])
        if same:
            return
        self._keys = keys.copy()
        self._constraints = constraints.copy()
        self._revision += 1

    def stage(mut self, size: Size) raises -> ConstraintPlan:
        if not isfinite(size.width) or not isfinite(size.height) or size.width < 0 or size.height < 0:
            raise Error("Invalid required parent allocation")
        if self._published_revision == self._revision and self._published_size.width == size.width and self._published_size.height == size.height:
            var plan = ConstraintPlan(self._owner, self._solver, self._revision, self._generation, size)
            plan.rectangles = self._rectangles.copy()
            plan.residuals = self._residuals.copy()
            return plan^
        var solver = ArcPointer(_ConstraintSolver())
        self.solver_builds += 1
        solver[].variable(PARENT_WIDTH)
        solver[].variable(PARENT_HEIGHT)
        for key in self._keys:
            for axis in range(4):
                solver[].variable(coordinate(key,axis))
        solver[].constraint(1, LinearConstraint([PARENT_WIDTH], [Float64(1)], -Float64(size.width)))
        solver[].constraint(2, LinearConstraint([PARENT_HEIGHT], [Float64(1)], -Float64(size.height)))
        var id = 3
        for key in self._keys:
            var x = coordinate(key,0)
            var y = coordinate(key,1)
            var w = coordinate(key,2)
            var h = coordinate(key,3)
            for variable in [x,y,w,h]:
                solver[].constraint(id, LinearConstraint([variable], [Float64(1)], relation=AT_LEAST))
                id += 1
            solver[].constraint(id, LinearConstraint([x,w,PARENT_WIDTH], [Float64(1),1,-1], relation=AT_MOST))
            id += 1
            solver[].constraint(id, LinearConstraint([y,h,PARENT_HEIGHT], [Float64(1),1,-1], relation=AT_MOST))
            id += 1
        for constraint in self._constraints:
            solver[].constraint(id,constraint)
            id += 1
        solver[].check(external_call["layout_kiwi_update", Int32](solver[].handle))
        var plan = ConstraintPlan(self._owner, solver, self._revision, self._generation, size)
        for key in self._keys:
            var rect = Rect(Float32(solver[].value(coordinate(key,0))), Float32(solver[].value(coordinate(key,1))), Float32(max(Float64(0),solver[].value(coordinate(key,2)))), Float32(max(Float64(0),solver[].value(coordinate(key,3)))))
            if not isfinite(rect.x) or not isfinite(rect.y) or not isfinite(rect.width) or not isfinite(rect.height):
                raise Error("Constraint coordinates exceed geometry precision")
            plan.rectangles[key] = rect
        for constraint in self._constraints:
            var lhs = constraint.constant
            for i in range(len(constraint.variables[])):
                lhs += solver[].value(Int(constraint.variables[][i])) * constraint.coefficients[][i]
            var residual = abs(lhs)
            if constraint.relation == AT_MOST:
                residual = max(Float64(0),lhs)
            elif constraint.relation == AT_LEAST:
                residual = max(Float64(0),-lhs)
            plan.residuals.append(residual)
        return plan^

    def validate(self, plan: ConstraintPlan) raises:
        if plan._owner.ptr() != self._owner.ptr() or plan._revision != self._revision or plan._generation != self._generation:
            raise Error("Stale or foreign constraint plan")

    def commit(mut self, plan: ConstraintPlan) raises:
        self.validate(plan)
        self._solver = plan._solver
        self._rectangles = plan.rectangles.copy()
        self._residuals = plan.residuals.copy()
        self._published_size = plan._size
        self._published_revision = plan._revision
        self._generation += 1

    def bounds(self, key: Int) raises -> Rect:
        if key not in self._rectangles:
            raise Error("No published constraint rectangle for key")
        return self._rectangles[key]
