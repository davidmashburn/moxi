"""Executable sizing contract probe; toy metrics, not a native text renderer."""
from dataclasses import dataclass
from math import ceil, isfinite


@dataclass(frozen=True)
class Proposal:
    kind: str
    value: float | None = None

    def __post_init__(self):
        if self.kind not in ("exactly", "at_most", "unbounded"):
            raise ValueError("unsupported probe proposal")
        if self.kind == "unbounded":
            if self.value is not None:
                raise ValueError("unbounded has no numeric sentinel")
        elif self.value is None or not isfinite(self.value) or self.value < 0:
            raise ValueError("finite nonnegative extent required")


@dataclass
class Leaf:
    key: str
    text: str
    generation: int = 1
    measure_revision: int = 0
    paint_revision: int = 0
    ascent: float = 8
    descent: float = 2

    @property
    def stamp(self):
        return self.key, self.generation, self.measure_revision

    def replace_text(self, text):
        self.text = text
        self.measure_revision += 1


@dataclass(frozen=True)
class Measurement:
    stamp: tuple
    environment: int
    proposal: Proposal
    width: float
    height: float
    baseline: float
    overflow: bool


class Context:
    def __init__(self):
        self.environment = 0
        self.cache = {}
        self.calls = 0

    def measure(self, child, proposal):
        key = child.stamp, self.environment, proposal
        if key in self.cache:
            return self.cache[key]
        self.calls += 1
        natural = len(child.text) * 5.0
        if proposal.kind == "unbounded":
            width = natural
        elif proposal.kind == "at_most":
            width = min(natural, proposal.value)
        else:
            width = proposal.value
        # A deliberately limited fixture: one five-point glyph per character.
        # At zero width keep a finite line box and explicitly report overflow.
        lines = max(1, ceil(natural / width)) if width else 1
        result = Measurement(child.stamp, self.environment, proposal, width,
                             lines * (child.ascent + child.descent),
                             child.ascent, natural > 0 and width == 0)
        self.cache[key] = result
        return result


@dataclass(frozen=True)
class Placement:
    key: str
    x: float
    y: float
    measurement: Measurement


@dataclass(frozen=True)
class Plan:
    width: float
    height: float
    placements: tuple[Placement, ...]

    def validate(self, children, context):
        child_map = {child.key: child for child in children}
        if len(child_map) != len(children):
            raise ValueError("duplicate child key")
        placed = [p.key for p in self.placements]
        if len(set(placed)) != len(placed) or set(placed) != set(child_map):
            raise ValueError("each active child needs one placement")
        for placement in self.placements:
            token = placement.measurement
            if (token.stamp != child_map[placement.key].stamp
                    or token.environment != context.environment):
                raise ValueError("stale measurement")
            if token.proposal.kind != "exactly":
                raise ValueError("final inline allocation must be measured exactly")
            if not all(isfinite(v) and v >= 0 for v in
                       (token.width, token.height)):
                raise ValueError("invalid child size")
        return self


def baseline_pair(context, children, width, first_width, gap=4):
    """Two-child custom layout, with a fixed leader and wrapping follower."""
    if len(children) != 2 or width < first_width + gap:
        raise ValueError("pair needs two children and a feasible allocation")
    widths = first_width, width - first_width - gap
    tokens = tuple(context.measure(child, Proposal("exactly", w))
                   for child, w in zip(children, widths))
    baseline = max(t.baseline for t in tokens)
    height = baseline + max(t.height - t.baseline for t in tokens)
    placements = tuple(Placement(child.key, x, baseline - token.baseline, token)
                       for child, x, token in zip(children, (0, first_width + gap), tokens))
    return Plan(width, height, placements).validate(children, context)
