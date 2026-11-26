"""I10's bounded investigation model. Membership uses I20's actual operation.

Observations have stable IDs; their source index is the synthetic time coordinate.
View filtering/sorting never supplies membership or changes the fitted data.
"""
from std.math import isfinite, sqrt
from cohort import Notebook, Observation, OPERATION, THRESHOLD
from moxi.capability_bus import CapabilityBus
from moxi.capability_types import CALLER_UI, CapabilityInvocation

comptime FIXTURE_ID = "sensor-curve-v1"
comptime TARGET_ID = "sensor.reading.by.sample-index.v1"
comptime PANEL_CONTROLS = '["refit","coefficients"]'


@fieldwise_init
struct MembershipMode(Equatable, ImplicitlyCopyable):
    var value: String
    comptime FROZEN = Self("frozen")
    comptime LIVE = Self("live")

    @staticmethod
    def parse(value: String) raises -> Self:
        if value != Self.FROZEN.value and value != Self.LIVE.value:
            raise Error("Unsupported membership mode")
        return Self(value)


@fieldwise_init
struct ModelKind(Equatable, ImplicitlyCopyable):
    var value: String
    comptime MEAN = Self("mean")
    comptime LINEAR = Self("linear")
    comptime QUADRATIC = Self("quadratic")

    @staticmethod
    def parse(value: String) raises -> Self:
        if value != Self.MEAN.value and value != Self.LINEAR.value and value != Self.QUADRATIC.value:
            raise Error("Unsupported model kind")
        return Self(value)

    def parameter_count(self) -> Int:
        return 3 if self == Self.QUADRATIC else (2 if self == Self.LINEAR else 1)


@fieldwise_init
struct FixtureState(Equatable, ImplicitlyCopyable):
    var value: String
    comptime BASELINE = Self("baseline")
    comptime CROSSING = Self("threshold-crossing")

    @staticmethod
    def parse(value: String) raises -> Self:
        if value != Self.BASELINE.value and value != Self.CROSSING.value:
            raise Error("Unsupported fixture state")
        return Self(value)


struct Fit(ImplicitlyCopyable):
    var kind: ModelKind
    var c0: Float64
    var c1: Float64
    var c2: Float64

    def __init__(out self, kind: ModelKind = ModelKind.LINEAR, c0: Float64 = 0, c1: Float64 = 0, c2: Float64 = 0):
        self.kind = kind
        self.c0 = c0
        self.c1 = c1
        self.c2 = c2

    def predict(self, x: Float64) -> Float64:
        return self.c0 + self.c1 * x + self.c2 * x * x

    def validate(self) raises:
        for value in [self.c0, self.c1, self.c2]:
            if not isfinite(value) or abs(value) > 1000000:
                raise Error("Coefficients must be finite and within +/- 1000000")
        if self.kind != ModelKind.QUADRATIC and self.c2 != 0:
            raise Error("Only a quadratic model supports c2")
        if self.kind == ModelKind.MEAN and self.c1 != 0:
            raise Error("A mean model supports only c0")


struct Investigation(ImplicitlyCopyable):
    var notebook: Notebook
    var bus: CapabilityBus
    var members: List[Int]
    var name: String
    var hypothesis: String
    var mode: MembershipMode
    var fixture: FixtureState
    var fit: Fit
    var fitted: Bool
    var requests: Int

    def __init__(out self):
        self.notebook = Notebook()
        self.notebook.rows = [
            Observation(104, 42), Observation(207, 58), Observation(318, 72),
            Observation(429, 80), Observation(530, 92), Observation(641, 108),
            Observation(752, 128), Observation(863, 152),
        ]
        self.bus = CapabilityBus()
        _ = self.bus.register_handler(self.notebook)
        self.members = []
        self.name = "Warm sensors"
        self.hypothesis = "A curved response may explain the high readings."
        self.mode = MembershipMode.FROZEN
        self.fixture = FixtureState.BASELINE
        self.fit = Fit()
        self.fitted = False
        self.requests = 0

    def __init__(out self, *, copy: Self):
        self.notebook = copy.notebook
        self.bus = copy.bus
        self.members = copy.members.copy()
        self.name = copy.name
        self.hypothesis = copy.hypothesis
        self.mode = copy.mode
        self.fixture = copy.fixture
        self.fit = copy.fit
        self.fitted = copy.fitted
        self.requests = copy.requests

    def contains(self, id: Int) -> Bool:
        for member in self.members:
            if member == id:
                return True
        return False

    def ids(self) -> String:
        var result = String("[")
        for i in range(len(self.members)):
            if i:
                result += ","
            result += String(self.members[i])
        return result + "]"

    def collect(mut self) raises:
        if self.name.strip().count_codepoints() == 0 or self.name.count_codepoints() > 64:
            raise Error("Give the cohort a name of 1 to 64 characters")
        self.requests += 1
        var result = self.bus.invoke_handler(self.notebook, CapabilityInvocation(String(self.requests), OPERATION, CALLER_UI, "{}"))
        if not result.completed():
            raise Error(result.recovery_hint)
        self.members = self.notebook.members.copy()
        self.fitted = False

    def set_fixture(mut self, state: FixtureState) raises:
        var updated = self
        updated.fixture = state
        updated.notebook.rows[1].reading = 76 if state == FixtureState.CROSSING else 58
        # Data changes invalidate coefficients, even if frozen membership stayed put.
        updated.fitted = False
        if updated.mode == MembershipMode.LIVE and len(updated.members):
            updated.collect()
        self = updated^

    def set_mode(mut self, mode: MembershipMode) raises:
        var updated = self
        updated.mode = mode
        updated.fitted = False
        if len(updated.members):
            updated.collect()
        self = updated^

    def least_squares(self, kind: ModelKind) raises -> Fit:
        var n = kind.parameter_count()
        if len(self.members) < n:
            raise Error("Not enough cohort observations for this model")
        var mean: Float64 = 0
        for i in range(len(self.notebook.rows)):
            if self.contains(self.notebook.rows[i].id):
                mean += Float64(i)
        mean /= Float64(len(self.members))
        # Center x, then solve the small normal equations with partial pivoting.
        var matrix = List[Float64]()
        for _ in range(12):
            matrix.append(0)
        for i in range(len(self.notebook.rows)):
            if not self.contains(self.notebook.rows[i].id):
                continue
            var x = Float64(i) - mean
            var basis: List[Float64] = [1, x, x*x]
            for row in range(n):
                for col in range(n):
                    matrix[row*4+col] += basis[row] * basis[col]
                matrix[row*4+3] += basis[row] * Float64(self.notebook.rows[i].reading)
        for col in range(n):
            var pivot = col
            for row in range(col+1, n):
                if abs(matrix[row*4+col]) > abs(matrix[pivot*4+col]):
                    pivot = row
            if abs(matrix[pivot*4+col]) < 1e-10:
                raise Error("The cohort cannot identify this model")
            for k in range(4):
                var temp = matrix[col*4+k]
                matrix[col*4+k] = matrix[pivot*4+k]
                matrix[pivot*4+k] = temp
            var scale = matrix[col*4+col]
            for k in range(4):
                matrix[col*4+k] /= scale
            for row in range(n):
                if row == col:
                    continue
                var factor = matrix[row*4+col]
                for k in range(4):
                    matrix[row*4+k] -= factor * matrix[col*4+k]
        var b0 = matrix[3]
        var b1 = matrix[7] if n >= 2 else Float64(0)
        var b2 = matrix[11] if n >= 3 else Float64(0)
        return Fit(kind, b0 - b1*mean + b2*mean*mean, b1 - 2*b2*mean, b2)

    def fit_model(mut self, kind: ModelKind) raises:
        self.fit = self.least_squares(kind)
        self.fitted = True

    def residual(self, source: Int, model: Fit) -> Float64:
        return Float64(self.notebook.rows[source].reading) - model.predict(Float64(source))

    def sse(self, model: Fit) -> Float64:
        var result: Float64 = 0
        for i in range(len(self.notebook.rows)):
            if self.contains(self.notebook.rows[i].id):
                var residual = self.residual(i, model)
                result += residual * residual
        return result

    def rmse(self, model: Fit) -> Float64:
        return sqrt(self.sse(model) / Float64(max(1, len(self.members))))

    def validate_panel(self) raises:
        if not self.fitted or not len(self.members):
            raise Error("Create a cohort and fit a model before saving a panel")
        if self.name.strip().count_codepoints() == 0 or self.name.count_codepoints() > 64:
            raise Error("Give the cohort a name of 1 to 64 characters")
        if self.hypothesis.count_codepoints() > 140:
            raise Error("Hypothesis exceeds 140 characters")
        for text in [self.name, self.hypothesis]:
            for i in range(text.count_codepoints()):
                if ord(String(text[codepoint=i:i+1])) < 32:
                    raise Error("Panel text cannot contain control characters")
        self.fit.validate()
        if len(self.members) < self.fit.kind.parameter_count():
            raise Error("Not enough cohort observations for this model")
        for i in range(len(self.members)):
            var found = False
            for row in self.notebook.rows:
                found = found or row.id == self.members[i]
            if not found:
                raise Error("Unknown observation ID")
            for j in range(i):
                if self.members[j] == self.members[i]:
                    raise Error("Duplicate observation ID")
        if self.mode == MembershipMode.LIVE:
            for row in self.notebook.rows:
                if self.contains(row.id) != (row.reading >= THRESHOLD):
                    raise Error("Live membership disagrees with the saved rule")
