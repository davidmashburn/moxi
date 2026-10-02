"""A small executable probe for the proposed adaptive layout boundary.

This is a reference model, not a production layout engine.  It deliberately
models only the identity and lifecycle questions that are easy to get wrong
when an adaptive layout changes its strategy:

* content slots are keyed component state;
* a layout owner has its own keyed state;
* Split divider chrome is ephemeral layout presentation;
* a mount generation changes on removal or type replacement; and
* commits are transactional with respect to a monotonically increasing
  layout generation.

The concrete API boundary is ``Layout(key, policy, children)``.  An adaptive
selector can choose a policy and submit the resulting layout description to
``AdaptiveRuntime.commit``.  The selector is intentionally outside this
probe: it must choose from incoming environment data, while the runtime owns
identity, state retention, and publication.
"""

from __future__ import annotations

from dataclasses import dataclass, field, replace
import math
from typing import Any, Dict, Optional, Tuple, Union


class LayoutContractError(ValueError):
    """A declaration or lifecycle operation violates the reference contract."""


class DuplicateKeyError(LayoutContractError):
    """Two active component slots use the same local key."""


class UnknownKeyError(LayoutContractError):
    """An operation refers to a component or layout that is not active."""


@dataclass(frozen=True)
class Slot:
    """A component slot in the active layout description."""

    key: str
    component_type: str = "component"

    def __post_init__(self) -> None:
        if not self.key:
            raise LayoutContractError("component keys must be non-empty")
        if not self.component_type:
            raise LayoutContractError("component types must be non-empty")


@dataclass(frozen=True)
class LayoutPolicy:
    """A strategy selected for one keyed layout owner."""

    kind: str
    key: str
    gap: float = 0.0
    initial_fraction: float = 0.5

    def __post_init__(self) -> None:
        if self.kind not in {"row", "column", "split"}:
            raise LayoutContractError("unsupported layout policy: %s" % self.kind)
        if not self.key:
            raise LayoutContractError("layout keys must be non-empty")
        if not math.isfinite(self.gap) or self.gap < 0:
            raise LayoutContractError("gap must be finite and non-negative")
        if not math.isfinite(self.initial_fraction):
            raise LayoutContractError("initial split fraction must be finite")
        if not 0 < self.initial_fraction < 1:
            raise LayoutContractError("initial split fraction must be between zero and one")

    @property
    def is_split(self) -> bool:
        return self.kind == "split"


def Row(key: str, gap: float = 0.0) -> LayoutPolicy:
    """Construct an ordered inline flow policy."""

    return LayoutPolicy("row", key, gap=gap)


def Column(key: str, gap: float = 0.0) -> LayoutPolicy:
    """Construct an ordered block flow policy."""

    return LayoutPolicy("column", key, gap=gap)


def Split(key: str, initial_fraction: float = 0.5) -> LayoutPolicy:
    """Construct the stateful split policy for a keyed layout owner."""

    return LayoutPolicy("split", key, initial_fraction=initial_fraction)


@dataclass(frozen=True)
class Layout:
    """The immutable declaration submitted for one layout generation.

    ``children`` are declared once by the caller.  Adaptive selection changes
    ``policy`` while retaining these slots when the structure is compatible.
    """

    key: str
    policy: LayoutPolicy
    children: Tuple[Slot, ...]

    def __post_init__(self) -> None:
        if self.key != self.policy.key:
            raise LayoutContractError(
                "layout owner key and policy key must match: %r != %r"
                % (self.key, self.policy.key)
            )
        object.__setattr__(self, "children", tuple(self.children))


# The name used by the design prose is useful to callers that want to make
# the selector explicit.  It is the same declaration boundary as Layout.
AdaptiveLayout = Layout


@dataclass(frozen=True)
class ComponentIdentity:
    owner_namespace: str
    key: str
    mount_generation: int


@dataclass(frozen=True)
class LayoutIdentity:
    owner_namespace: str
    key: str


@dataclass(frozen=True)
class DividerIdentity:
    """Ephemeral Split chrome identity, separate from component identity."""

    owner_namespace: str
    layout_key: str
    index: int
    materialization_generation: int


@dataclass
class ComponentState:
    """Application-owned state retained for one mounted component slot."""

    identity: ComponentIdentity
    component_type: str
    application_value: Any = None


@dataclass(frozen=True)
class ResizeSession:
    divider: DividerIdentity
    before_key: str
    after_key: str


@dataclass
class LayoutState:
    """State owned by a keyed layout owner, including Split allocation."""

    identity: LayoutIdentity
    allocations: Dict[str, float] = field(default_factory=dict)
    resize_session: Optional[ResizeSession] = None
    divider_materialization_generation: int = 0


@dataclass(frozen=True)
class SlotPlacement:
    key: str
    index: int
    allocation: Optional[float]


@dataclass(frozen=True)
class LayoutSnapshot:
    generation: int
    layout_key: str
    policy: LayoutPolicy
    placements: Tuple[SlotPlacement, ...]
    component_identities: Tuple[ComponentIdentity, ...]
    dividers: Tuple[DividerIdentity, ...]

    @property
    def active_keys(self) -> Tuple[str, ...]:
        return tuple(placement.key for placement in self.placements)

    def component_identity(self, key: str) -> ComponentIdentity:
        for identity in self.component_identities:
            if identity.key == key:
                return identity
        raise UnknownKeyError("component is not active: %s" % key)


@dataclass(frozen=True)
class CommitResult:
    accepted: bool
    stale: bool
    snapshot: LayoutSnapshot


FocusTarget = Union[ComponentIdentity, DividerIdentity]


class AdaptiveRuntime:
    """Transactional identity/state model for the adaptive layout probe."""

    def __init__(self, owner_namespace: str) -> None:
        if not owner_namespace:
            raise LayoutContractError("owner namespace must be non-empty")
        self.owner_namespace = owner_namespace
        self._components: Dict[str, ComponentState] = {}
        self._last_mount_generation: Dict[str, int] = {}
        self._layout_states: Dict[str, LayoutState] = {}
        self._snapshot: Optional[LayoutSnapshot] = None
        self._layout_generation = 0
        self._next_divider_materialization_generation = 0
        self._focus_target: Optional[FocusTarget] = None
        self._active_editor: Optional[ComponentIdentity] = None
        self._pointer_capture: Optional[DividerIdentity] = None

    @property
    def snapshot(self) -> LayoutSnapshot:
        if self._snapshot is None:
            raise LayoutContractError("no layout has been committed")
        return self._snapshot

    @property
    def component_focus(self) -> Optional[ComponentIdentity]:
        if isinstance(self._focus_target, ComponentIdentity):
            return self._focus_target
        return None

    @property
    def divider_focus(self) -> Optional[DividerIdentity]:
        if isinstance(self._focus_target, DividerIdentity):
            return self._focus_target
        return None

    @property
    def active_editor(self) -> Optional[ComponentIdentity]:
        return self._active_editor

    @property
    def pointer_capture(self) -> Optional[DividerIdentity]:
        return self._pointer_capture

    def component_state(self, key: str) -> ComponentState:
        try:
            return self._components[key]
        except KeyError as exc:
            raise UnknownKeyError("component is not active: %s" % key) from exc

    def layout_state(self, key: str) -> LayoutState:
        try:
            return self._layout_states[key]
        except KeyError as exc:
            raise UnknownKeyError("layout is not active: %s" % key) from exc

    def set_application_value(self, key: str, value: Any) -> None:
        self.component_state(key).application_value = value

    def focus_component(self, key: str) -> ComponentIdentity:
        identity = self.component_state(key).identity
        self._focus_target = identity
        return identity

    def begin_edit(self, key: str) -> ComponentIdentity:
        identity = self.component_state(key).identity
        self._active_editor = identity
        return identity

    def focus_divider(self, index: int) -> DividerIdentity:
        divider = self._divider(index)
        self._focus_target = divider
        return divider

    def begin_resize(self, index: int) -> DividerIdentity:
        divider = self._divider(index)
        snapshot = self.snapshot
        before_key = snapshot.active_keys[index]
        after_key = snapshot.active_keys[index + 1]
        state = self.layout_state(snapshot.layout_key)
        state.resize_session = ResizeSession(divider, before_key, after_key)
        self._pointer_capture = divider
        return divider

    def resize_divider(self, delta: float) -> LayoutSnapshot:
        """Apply a bounded normalized delta and publish a new snapshot."""

        if not math.isfinite(delta):
            raise LayoutContractError("resize delta must be finite")
        snapshot = self.snapshot
        if not snapshot.policy.is_split:
            raise LayoutContractError("resize requires an active split policy")
        state = self.layout_state(snapshot.layout_key)
        session = state.resize_session
        if session is None or session.divider not in snapshot.dividers:
            raise LayoutContractError("resize has no active divider session")

        before = state.allocations[session.before_key]
        after = state.allocations[session.after_key]
        minimum = 0.05
        applied = max(-before + minimum, min(after - minimum, delta))
        state.allocations[session.before_key] = before + applied
        state.allocations[session.after_key] = after - applied
        state.allocations = _normalize_allocations(state.allocations)

        self._layout_generation += 1
        self._snapshot = replace(
            snapshot,
            generation=self._layout_generation,
            placements=self._placements(snapshot.policy, snapshot.active_keys, state),
        )
        return self._snapshot

    def end_resize(self) -> None:
        if self._snapshot is None:
            return
        state = self.layout_state(self._snapshot.layout_key)
        state.resize_session = None
        self._pointer_capture = None

    def commit(self, layout: Layout, generation: int) -> CommitResult:
        """Validate and atomically publish a candidate layout.

        A generation at or below the committed generation is a stale result.
        It is ignored before declaration processing, so stale asynchronous work
        cannot replace state or geometry.
        """

        if generation <= 0:
            raise LayoutContractError("layout generations must be positive")
        if generation <= self._layout_generation:
            return CommitResult(False, True, self.snapshot)
        self._validate_layout(layout)

        previous = self._snapshot
        owner_changed = previous is not None and previous.layout_key != layout.key
        previous_layout_state = self._layout_states.get(layout.key)
        if previous is None or previous.layout_key != layout.key or previous_layout_state is None:
            planned_layout_state = LayoutState(
                LayoutIdentity(self.owner_namespace, layout.key)
            )
            existing_layout_state = None
        else:
            planned_layout_state = _copy_layout_state(previous_layout_state)
            existing_layout_state = previous_layout_state

        active_keys = tuple(slot.key for slot in layout.children)
        _reconcile_allocations(planned_layout_state, layout.policy, active_keys)

        previous_split = (
            previous is not None
            and previous.layout_key == layout.key
            and previous.policy.is_split
        )
        pane_structure_changed = previous_split and previous.active_keys != active_keys
        if layout.policy.is_split:
            if not previous_split or pane_structure_changed:
                self._next_divider_materialization_generation += 1
                planned_layout_state.divider_materialization_generation = (
                    self._next_divider_materialization_generation
                )
            if planned_layout_state.divider_materialization_generation == 0:
                self._next_divider_materialization_generation += 1
                planned_layout_state.divider_materialization_generation = (
                    self._next_divider_materialization_generation
                )
            dividers = tuple(
                DividerIdentity(
                    self.owner_namespace,
                    layout.key,
                    index,
                    planned_layout_state.divider_materialization_generation,
                )
                for index in range(max(0, len(active_keys) - 1))
            )
        else:
            planned_layout_state.resize_session = None
            dividers = ()

        if planned_layout_state.resize_session is not None:
            if planned_layout_state.resize_session.divider not in dividers:
                planned_layout_state.resize_session = None

        next_mount_generations = dict(self._last_mount_generation)
        next_components: Dict[str, ComponentState] = {}
        for slot in layout.children:
            previous_state = self._components.get(slot.key)
            if (
                not owner_changed
                and previous_state is not None
                and previous_state.component_type == slot.component_type
            ):
                next_components[slot.key] = previous_state
                continue

            mount_generation = max(
                next_mount_generations.get(slot.key, 0),
                previous_state.identity.mount_generation if previous_state is not None else 0,
            ) + 1
            next_mount_generations[slot.key] = mount_generation
            next_components[slot.key] = ComponentState(
                ComponentIdentity(self.owner_namespace, slot.key, mount_generation),
                slot.component_type,
            )

        next_focus = self._preserve_focus(next_components, dividers, previous)
        next_editor = self._preserve_editor(next_components)
        next_capture = self._pointer_capture if self._pointer_capture in dividers else None

        snapshot = LayoutSnapshot(
            generation=generation,
            layout_key=layout.key,
            policy=layout.policy,
            placements=self._placements(layout.policy, active_keys, planned_layout_state),
            component_identities=tuple(state.identity for state in next_components.values()),
            dividers=dividers,
        )

        # All validation and candidate construction is complete.  Updating the
        # existing layout state in place preserves its keyed owner identity,
        # while stale or invalid candidates never reach this point.
        if existing_layout_state is not None:
            _overwrite_layout_state(existing_layout_state, planned_layout_state)
            committed_layout_state = existing_layout_state
        else:
            committed_layout_state = planned_layout_state

        self._components = next_components
        self._last_mount_generation = next_mount_generations
        self._layout_states = {layout.key: committed_layout_state}
        self._layout_generation = generation
        self._snapshot = snapshot
        self._focus_target = next_focus
        self._active_editor = next_editor
        self._pointer_capture = next_capture
        return CommitResult(True, False, snapshot)

    def _validate_layout(self, layout: Layout) -> None:
        if not isinstance(layout, Layout):
            raise LayoutContractError("commit expects a Layout declaration")
        seen = set()
        for slot in layout.children:
            if slot.key in seen:
                raise DuplicateKeyError("duplicate active component key: %s" % slot.key)
            seen.add(slot.key)
        if layout.policy.is_split and len(layout.children) < 2:
            raise LayoutContractError("a split requires at least two active panes")

    def _preserve_focus(
        self,
        components: Dict[str, ComponentState],
        dividers: Tuple[DividerIdentity, ...],
        previous: Optional[LayoutSnapshot],
    ) -> Optional[FocusTarget]:
        target = self._focus_target
        if isinstance(target, ComponentIdentity):
            if any(state.identity == target for state in components.values()):
                return target
            return None
        if isinstance(target, DividerIdentity) and target in dividers:
            return target
        if isinstance(target, DividerIdentity) and previous is not None:
            # A divider is layout chrome.  If the policy hides or rebuilds it,
            # move keyboard focus to the nearest surviving pane instead of
            # leaving focus attached to a destroyed chrome instance.
            if target.layout_key == previous.layout_key:
                adjacent = previous.active_keys[target.index : target.index + 2]
                for key in adjacent:
                    state = components.get(key)
                    if state is not None:
                        return state.identity
        return None

    def _preserve_editor(
        self, components: Dict[str, ComponentState]
    ) -> Optional[ComponentIdentity]:
        if self._active_editor is None:
            return None
        if any(state.identity == self._active_editor for state in components.values()):
            return self._active_editor
        return None

    def _divider(self, index: int) -> DividerIdentity:
        snapshot = self.snapshot
        if not snapshot.policy.is_split:
            raise LayoutContractError("divider is unavailable outside Split")
        if index < 0 or index >= len(snapshot.dividers):
            raise UnknownKeyError("divider index is not active: %s" % index)
        return snapshot.dividers[index]

    def _placements(
        self,
        policy: LayoutPolicy,
        active_keys: Tuple[str, ...],
        state: LayoutState,
    ) -> Tuple[SlotPlacement, ...]:
        allocations = state.allocations if policy.is_split else {}
        return tuple(
            SlotPlacement(key, index, allocations.get(key))
            for index, key in enumerate(active_keys)
        )


def _normalize_allocations(allocations: Dict[str, float]) -> Dict[str, float]:
    if not allocations:
        return {}
    total = sum(allocations.values())
    if not math.isfinite(total) or total <= 0:
        equal = 1.0 / len(allocations)
        return {key: equal for key in allocations}
    return {key: value / total for key, value in allocations.items()}


def _reconcile_allocations(
    state: LayoutState,
    policy: LayoutPolicy,
    active_keys: Tuple[str, ...],
) -> None:
    if not policy.is_split:
        # Keep the keyed allocation while Row/Column is active.  If Split is
        # restored later, surviving pane keys can recover their last values.
        state.resize_session = None
        return

    old = state.allocations
    if not old:
        if len(active_keys) == 2:
            values = {
                active_keys[0]: policy.initial_fraction,
                active_keys[1]: 1.0 - policy.initial_fraction,
            }
        else:
            equal = 1.0 / len(active_keys)
            values = {key: equal for key in active_keys}
        state.allocations = values
        return

    values = {key: old[key] for key in active_keys if key in old and old[key] > 0}
    missing = [key for key in active_keys if key not in values]
    if not values:
        equal = 1.0 / len(active_keys)
        state.allocations = {key: equal for key in active_keys}
        return
    for key in missing:
        values[key] = 1.0
    state.allocations = _normalize_allocations(values)


def _copy_layout_state(state: LayoutState) -> LayoutState:
    return LayoutState(
        state.identity,
        dict(state.allocations),
        state.resize_session,
        state.divider_materialization_generation,
    )


def _overwrite_layout_state(target: LayoutState, source: LayoutState) -> None:
    target.allocations = source.allocations
    target.resize_session = source.resize_session
    target.divider_materialization_generation = source.divider_materialization_generation


__all__ = [
    "AdaptiveLayout",
    "AdaptiveRuntime",
    "Column",
    "CommitResult",
    "ComponentIdentity",
    "ComponentState",
    "DividerIdentity",
    "DuplicateKeyError",
    "Layout",
    "LayoutContractError",
    "LayoutIdentity",
    "LayoutPolicy",
    "LayoutSnapshot",
    "LayoutState",
    "ResizeSession",
    "Row",
    "Slot",
    "Split",
    "UnknownKeyError",
]
