"""A small executable reference contract for one vertical Moxi viewport.

This module is intentionally a probe, not a production implementation.  It
models one content flow containing a fixed-height header, lazily realized
variable-height rows, and a fixed-height footer.  The source has one logical
section, and an item address is ``(section, key)``; list indices are never
identity.  The extent index is allowed to know estimates for every row while
the source only realizes rows in the visible window plus bounded overscan.

The useful boundary is deliberately small:

* ``LazyRowSource.snapshot`` captures an immutable key/order/revision view.
* ``estimated_extent`` answers prefix-index queries without realizing a row.
* ``realize`` and ``release`` are lifecycle operations, staged by the
  viewport and published only when a transaction commits.
* ``ViewportSnapshot`` publishes content-coordinate placements, a finite
  viewport/content extent pair, one clamped offset, the visible rows and
  visible gaps, and the stable scroll anchor.

The viewport is the only owner that applies the offset.  A source never
returns an already translated rectangle.  ``presented_start`` subtracts the
published offset exactly once from a content-coordinate placement.

The experiment makes these API decisions explicit:

* An anchor is ``(ItemAddress, within_item_offset, generation)``.  A changed
  estimate or measured extent before the anchor moves the prefix and changes
  the offset by the same delta.  ``within_item_offset`` is the content offset
  inside the row at the viewport top, so ``scroll = row_start + within``.
  Changes after the anchor do not move it,
  except when finite bottom clamping leaves no legal offset.
* Source replacement is atomic at a revision boundary.  Reorder keeps an
  item's address and measurement by key; removal chooses the next surviving
  old item, then the previous one.  A key reintroduced after removal receives
  a new generation and cannot inherit an old measurement.
* A plan may stage realization, but a stale source revision cannot publish it.
  Staged rows are cancelled and the previous snapshot remains intact.
* Content extent is computed from the complete estimate/measurement index and
  fixed nodes, not from realized children.  Viewport and content extents must
  be finite and non-negative; offset is clamped to
  ``[0, max(0, content_extent - viewport_extent)]``.
  If that clamp makes an anchor impossible, the snapshot reports the applied
  ``anchor_correction`` and records the actual row at the clamped offset.
* Gaps are geometry.  ``VisibleRange.gaps`` reports a gap intersecting the
  viewport even when no row rectangle intersects it, which avoids silently
  skipping a range boundary in a virtual list.

This is not a universal table protocol.  A two-dimensional ``VirtualTable``
needs at least a shared column-track snapshot (including width-dependent row
measurement), a horizontal extent/offset and visible-column range, cell
identity ``(row_key, column_key, generation)``, frozen/sticky track transforms,
and an explicit policy for global width fitting.  Those responsibilities are
kept in :data:`TABLE_EXTENSION_NOTES` rather than being faked by this
one-dimensional probe.
"""

from __future__ import annotations

from dataclasses import dataclass
import math
from typing import Dict, Iterable, List, Mapping, Optional, Sequence, Set, Tuple, Union


TABLE_EXTENSION_NOTES: Tuple[str, ...] = (
    "A 2D table needs one shared column-track snapshot for headers and cells.",
    "It needs horizontal extent/offset and visible-column range in addition to vertical row range.",
    "Cell identity must include (row_key, column_key, generation); recycling a row slot is insufficient.",
    "Frozen columns and sticky headers need explicit presentation transforms owned by the table viewport.",
    "Exact fitting over all rows is an explicit scan; viewport measurements do not establish a global width maximum.",
)


CONTRACT_LIMITATIONS: Tuple[str, ...] = (
    "The probe has one logical vertical section plus fixed header/footer nodes; it does not define arbitrary nested section headers.",
    "It does not implement horizontal layout, shared table tracks, frozen columns, or width-dependent row measurement.",
    "Realization is instrumented synchronously; production adapters still need async cancellation and commit callbacks.",
)


class ViewportContractError(ValueError):
    """A declaration or operation violates the reference contract."""


class StaleSourceError(RuntimeError):
    """A staged result was produced from a source revision that changed."""

    def __init__(self, expected_revision: int, actual_revision: int) -> None:
        self.expected_revision = expected_revision
        self.actual_revision = actual_revision
        super().__init__(
            "stale viewport source revision: "
            f"expected {expected_revision}, got {actual_revision}"
        )


class StaleViewportPlanError(RuntimeError):
    """A plan was based on an older committed viewport generation."""

    def __init__(self, expected_generation: Optional[int], actual_generation: int) -> None:
        self.expected_generation = expected_generation
        self.actual_generation = actual_generation
        super().__init__(
            "stale viewport plan generation: "
            f"expected {expected_generation}, got {actual_generation}"
        )


class UnrealizedItemError(ViewportContractError):
    """A measurement was submitted for an item not active in the viewport."""


def _finite_nonnegative(value: float, label: str) -> float:
    """Validate an extent/offset input and return it as ``float``."""

    result = float(value)
    if not math.isfinite(result) or result < 0.0:
        raise ViewportContractError(f"{label} must be finite and non-negative")
    return result


@dataclass(frozen=True)
class SectionAddress:
    """Stable logical section namespace for a vertical child source."""

    key: str

    def __post_init__(self) -> None:
        if not self.key:
            raise ViewportContractError("section key must be non-empty")

    def item(self, key: str) -> "ItemAddress":
        return ItemAddress(self, key)


@dataclass(frozen=True)
class ItemAddress:
    """Stable logical address; its position is deliberately not identity."""

    section: SectionAddress
    key: str

    def __post_init__(self) -> None:
        if not self.key:
            raise ViewportContractError("item key must be non-empty")


@dataclass(frozen=True)
class FixedAddress:
    """Address for one of the two fixed nodes in this probe."""

    slot: str

    def __post_init__(self) -> None:
        if self.slot not in ("header", "footer"):
            raise ViewportContractError("fixed slot must be 'header' or 'footer'")


Address = Union[FixedAddress, ItemAddress]


@dataclass(frozen=True)
class RowSpec:
    """A source row estimate.  ``generation`` changes when a key is reused."""

    key: str
    estimated_extent: float
    generation: int = 0

    def __post_init__(self) -> None:
        if not self.key:
            raise ViewportContractError("row key must be non-empty")
        _finite_nonnegative(self.estimated_extent, "row estimate")
        if self.generation < 0:
            raise ViewportContractError("row generation must be non-negative")


@dataclass(frozen=True)
class ItemIdentity:
    """A realized instance identity: stable logical address plus generation."""

    address: ItemAddress
    generation: int

    def __post_init__(self) -> None:
        if self.generation < 0:
            raise ViewportContractError("item generation must be non-negative")


@dataclass(frozen=True)
class RowSourceSnapshot:
    """Immutable keyed/order/revision data consumed by one viewport pass."""

    section: SectionAddress
    rows: Tuple[RowSpec, ...]
    revision: int

    def __post_init__(self) -> None:
        if self.revision < 0:
            raise ViewportContractError("source revision must be non-negative")
        keys = [row.key for row in self.rows]
        if len(keys) != len(set(keys)):
            raise ViewportContractError("source keys must be unique within a section")

    @property
    def item_count(self) -> int:
        return len(self.rows)

    def address_at(self, index: int) -> ItemAddress:
        return self.section.item(self.rows[index].key)

    def identity_at(self, index: int) -> ItemIdentity:
        row = self.rows[index]
        return ItemIdentity(self.section.item(row.key), row.generation)

    def index_of(self, address: ItemAddress) -> Optional[int]:
        if address.section != self.section:
            return None
        for index, row in enumerate(self.rows):
            if row.key == address.key:
                return index
        return None

    def identity_for(self, address: ItemAddress) -> Optional[ItemIdentity]:
        index = self.index_of(address)
        return None if index is None else self.identity_at(index)

    def contains_identity(self, identity: ItemIdentity) -> bool:
        current = self.identity_for(identity.address)
        return current == identity

    def estimate_for(self, identity: ItemIdentity) -> float:
        current = self.identity_for(identity.address)
        if current != identity:
            raise ViewportContractError(f"unknown item identity: {identity}")
        index = self.index_of(identity.address)
        assert index is not None
        return float(self.rows[index].estimated_extent)


@dataclass(frozen=True)
class RealizedItem:
    """The private result of staging a source realization."""

    identity: ItemIdentity


class LazyRowSource:
    """Instrumented vertical source implementing the reference child protocol.

    ``estimate_calls`` can be large because the extent index may query every
    row.  ``realize_calls`` remains bounded by the visible range and overscan.
    Realization is staged until ``commit_realizations``; cancelled staging does
    not become mounted state.
    """

    def __init__(self, section: str, rows: Iterable[RowSpec]) -> None:
        self.section = SectionAddress(section)
        self._rows: Tuple[RowSpec, ...] = self._normalize_rows(rows)
        self._revision = 0
        self._known_generations: Dict[str, int] = {
            row.key: row.generation for row in self._rows
        }
        self._realize_calls: List[ItemIdentity] = []
        self._estimate_calls: List[Tuple[int, ItemIdentity, float]] = []
        self._cancelled: List[ItemIdentity] = []
        self._released: List[ItemIdentity] = []
        self._mounted: Set[ItemIdentity] = set()

    @staticmethod
    def _normalize_rows(rows: Iterable[RowSpec]) -> Tuple[RowSpec, ...]:
        normalized = tuple(rows)
        # RowSpec validates its own extent/key; this check gives a useful
        # source-level error before any transaction can stage work.
        keys = [row.key for row in normalized]
        if len(keys) != len(set(keys)):
            raise ViewportContractError("source keys must be unique within a section")
        return normalized

    @property
    def revision(self) -> int:
        return self._revision

    def snapshot(self) -> RowSourceSnapshot:
        return RowSourceSnapshot(self.section, self._rows, self._revision)

    def replace(self, rows: Iterable[RowSpec]) -> RowSourceSnapshot:
        """Atomically replace order/content and advance the source revision."""

        incoming = self._normalize_rows(rows)
        old_keys = {row.key for row in self._rows}
        next_rows: List[RowSpec] = []
        for row in incoming:
            if row.key in old_keys:
                # A surviving key keeps its logical instance generation.  The
                # source owns this rule; callers cannot accidentally reset it
                # by supplying RowSpec's default generation.
                generation = self._known_generations[row.key]
            else:
                generation = self._known_generations.get(row.key, -1) + 1
            next_rows.append(RowSpec(row.key, row.estimated_extent, generation))

        self._rows = tuple(next_rows)
        self._known_generations.update({row.key: row.generation for row in self._rows})
        self._revision += 1
        return self.snapshot()

    def estimated_extent(
        self,
        snapshot: RowSourceSnapshot,
        identity: ItemIdentity,
        cross_extent: float,
    ) -> float:
        """Return a snapshot estimate and record the query.

        ``cross_extent`` is present because a real row estimate can depend on
        the offered width.  This probe keeps the estimate scalar and does not
        pretend to solve width-dependent measurement.
        """

        cross_extent = _finite_nonnegative(cross_extent, "cross extent")
        if snapshot.section != self.section or snapshot.revision != self._revision:
            raise StaleSourceError(snapshot.revision, self._revision)
        value = snapshot.estimate_for(identity)
        self._estimate_calls.append((snapshot.revision, identity, cross_extent))
        return value

    def realize(self, identity: ItemIdentity) -> RealizedItem:
        current = self.snapshot().identity_for(identity.address)
        if current != identity:
            raise StaleSourceError(self._revision, self._revision)
        self._realize_calls.append(identity)
        return RealizedItem(identity)

    def commit_realizations(self, staged: Iterable[RealizedItem]) -> None:
        for item in staged:
            self._mounted.add(item.identity)

    def cancel_realizations(self, staged: Iterable[RealizedItem]) -> None:
        self._cancelled.extend(item.identity for item in staged)

    def release(self, identity: ItemIdentity) -> None:
        self._mounted.discard(identity)
        self._released.append(identity)

    @property
    def estimate_calls(self) -> Tuple[Tuple[int, ItemIdentity, float], ...]:
        return tuple(self._estimate_calls)

    @property
    def realize_calls(self) -> Tuple[ItemIdentity, ...]:
        return tuple(self._realize_calls)

    @property
    def cancelled(self) -> Tuple[ItemIdentity, ...]:
        return tuple(self._cancelled)

    @property
    def released(self) -> Tuple[ItemIdentity, ...]:
        return tuple(self._released)

    @property
    def mounted(self) -> Tuple[ItemIdentity, ...]:
        return tuple(sorted(self._mounted, key=lambda item: (item.address.key, item.generation)))


@dataclass(frozen=True)
class ScrollAnchor:
    """A stable row plus the offset within that row in content coordinates."""

    address: ItemAddress
    within_item_offset: float
    generation: Optional[int] = None

    def __post_init__(self) -> None:
        _finite_nonnegative(self.within_item_offset, "anchor within-item offset")
        if self.generation is not None and self.generation < 0:
            raise ViewportContractError("anchor generation must be non-negative")


@dataclass(frozen=True)
class NodePlacement:
    """A node rectangle in content coordinates."""

    address: Address
    content_start: float
    extent: float

    @property
    def content_end(self) -> float:
        return self.content_start + self.extent

    def presented_start(self, offset: float) -> float:
        """Translate from content to viewport coordinates exactly once."""

        return self.content_start - _finite_nonnegative(offset, "offset")


@dataclass(frozen=True)
class GapPlacement:
    """A gap between adjacent content nodes, also in content coordinates."""

    before: Address
    after: Address
    content_start: float
    extent: float

    @property
    def content_end(self) -> float:
        return self.content_start + self.extent

    def presented_start(self, offset: float) -> float:
        return self.content_start - _finite_nonnegative(offset, "offset")


@dataclass(frozen=True)
class VisibleRange:
    """Visible node addresses plus gaps intersecting the viewport."""

    addresses: Tuple[Address, ...]
    row_indices: Tuple[int, ...]
    gaps: Tuple[GapPlacement, ...]

    @property
    def first_row(self) -> Optional[int]:
        return self.row_indices[0] if self.row_indices else None

    @property
    def last_row_exclusive(self) -> Optional[int]:
        return self.row_indices[-1] + 1 if self.row_indices else None


@dataclass(frozen=True)
class ViewportSnapshot:
    """Atomically published geometry and realization metadata."""

    generation: int
    source_revision: int
    viewport_extent: float
    content_extent: float
    offset: float
    anchor: Optional[ScrollAnchor]
    anchor_correction: float
    placements: Tuple[NodePlacement, ...]
    gaps: Tuple[GapPlacement, ...]
    visible: VisibleRange
    realized: Tuple[ItemIdentity, ...]

    def placement(self, address: Address) -> NodePlacement:
        for placement in self.placements:
            if placement.address == address:
                return placement
        raise KeyError(address)

    def presented_start(self, address: Address) -> float:
        """Return one offset application for a content-coordinate node."""

        return self.placement(address).presented_start(self.offset)

    @property
    def max_offset(self) -> float:
        return max(0.0, self.content_extent - self.viewport_extent)

    @property
    def realized_addresses(self) -> Tuple[ItemAddress, ...]:
        return tuple(item.address for item in self.realized)


@dataclass(frozen=True)
class ViewportPlan:
    """Private staged result; it becomes visible only after ``commit``."""

    source_snapshot: RowSourceSnapshot
    base_viewport_generation: Optional[int]
    snapshot: ViewportSnapshot
    staged: Tuple[RealizedItem, ...]
    to_release: Tuple[ItemIdentity, ...]
    measurements: Tuple[Tuple[ItemIdentity, float], ...]


_ANCHOR_UNSET = object()


class Viewport:
    """Reference owner for one finite vertical viewport."""

    def __init__(
        self,
        *,
        header_extent: float,
        footer_extent: float,
        viewport_extent: float,
        gap: float = 0.0,
        cross_extent: float = 0.0,
        overscan: int = 0,
    ) -> None:
        self.header_extent = _finite_nonnegative(header_extent, "header extent")
        self.footer_extent = _finite_nonnegative(footer_extent, "footer extent")
        self.viewport_extent = _finite_nonnegative(viewport_extent, "viewport extent")
        self.gap = _finite_nonnegative(gap, "gap")
        self.cross_extent = _finite_nonnegative(cross_extent, "cross extent")
        if overscan < 0:
            raise ViewportContractError("overscan must be non-negative")
        self.overscan = int(overscan)

        self._snapshot: Optional[ViewportSnapshot] = None
        self._source_snapshot: Optional[RowSourceSnapshot] = None
        self._measurements: Dict[ItemIdentity, float] = {}
        self._active: Set[ItemIdentity] = set()

    @property
    def snapshot(self) -> Optional[ViewportSnapshot]:
        return self._snapshot

    def layout(
        self,
        source: LazyRowSource,
        *,
        offset: Optional[float] = None,
        anchor: Union[ScrollAnchor, None, object] = _ANCHOR_UNSET,
    ) -> ViewportSnapshot:
        """Prepare and publish one source revision.

        Omitting ``anchor`` preserves the current anchor when a newer source
        revision arrives.  Passing ``anchor=None`` explicitly requests ordinary
        offset clamping, which is what a user scroll uses.  Passing an anchor
        keeps that row at its within-item offset while extents are recomputed.
        """

        plan = self.prepare(source, offset=offset, anchor=anchor)
        return self.commit(plan, source)

    def prepare(
        self,
        source: LazyRowSource,
        *,
        offset: Optional[float] = None,
        anchor: Union[ScrollAnchor, None, object] = _ANCHOR_UNSET,
        measurements: Optional[Mapping[ItemIdentity, float]] = None,
    ) -> ViewportPlan:
        source_snapshot = source.snapshot()
        if (
            self._snapshot is not None
            and source_snapshot.revision < self._snapshot.source_revision
        ):
            raise StaleSourceError(self._snapshot.source_revision, source_snapshot.revision)

        if offset is None:
            requested_offset = 0.0 if self._snapshot is None else self._snapshot.offset
        else:
            requested_offset = _finite_nonnegative(offset, "offset")

        if anchor is _ANCHOR_UNSET:
            if (
                self._snapshot is not None
                and source_snapshot.revision != self._snapshot.source_revision
            ):
                requested_anchor: Optional[ScrollAnchor] = self._snapshot.anchor
            else:
                requested_anchor = None
        else:
            requested_anchor = anchor  # type: ignore[assignment]

        current_measurements = dict(self._measurements if measurements is None else measurements)
        current_ids = set(self._identities(source_snapshot))
        # A removed/replaced identity cannot donate a measured extent to a new
        # instance, even if the logical key is later reused.
        current_measurements = {
            identity: extent
            for identity, extent in current_measurements.items()
            if identity in current_ids
        }
        for identity, extent in current_measurements.items():
            _finite_nonnegative(extent, "measured extent")

        extents: Dict[ItemIdentity, float] = {}
        for identity in self._identities(source_snapshot):
            if identity in current_measurements:
                extents[identity] = current_measurements[identity]
            else:
                extents[identity] = source.estimated_extent(
                    source_snapshot, identity, self.cross_extent
                )

        resolved_anchor = self._resolve_anchor(requested_anchor, source_snapshot, extents)
        placements, gaps, content_extent = self._make_geometry(
            source_snapshot, extents
        )

        if resolved_anchor is not None:
            anchor_placement = self._placement_for_item(resolved_anchor.address, placements)
            requested_offset = anchor_placement.content_start + resolved_anchor.within_item_offset

        max_offset = max(0.0, content_extent - self.viewport_extent)
        clamped_offset = min(max(requested_offset, 0.0), max_offset)
        anchor_correction = clamped_offset - requested_offset
        if resolved_anchor is None or anchor_correction != 0.0:
            resolved_anchor = self._anchor_at_offset(source_snapshot, placements, clamped_offset)

        visible = self._visible_range(placements, gaps, clamped_offset)
        candidate_indices = self._candidate_indices(
            source_snapshot, placements, visible, clamped_offset
        )
        candidate_ids = tuple(
            source_snapshot.identity_at(index) for index in candidate_indices
        )
        previous_active = set(self._active)
        staged = tuple(
            source.realize(identity)
            for identity in candidate_ids
            if identity not in previous_active
        )
        to_release = tuple(
            identity for identity in previous_active if identity not in set(candidate_ids)
        )
        generation = 1 if self._snapshot is None else self._snapshot.generation + 1
        candidate_snapshot = ViewportSnapshot(
            generation=generation,
            source_revision=source_snapshot.revision,
            viewport_extent=self.viewport_extent,
            content_extent=content_extent,
            offset=clamped_offset,
            anchor=resolved_anchor,
            anchor_correction=anchor_correction,
            placements=placements,
            gaps=gaps,
            visible=visible,
            realized=candidate_ids,
        )
        return ViewportPlan(
            source_snapshot=source_snapshot,
            base_viewport_generation=(
                None if self._snapshot is None else self._snapshot.generation
            ),
            snapshot=candidate_snapshot,
            staged=staged,
            to_release=to_release,
            measurements=tuple(current_measurements.items()),
        )

    def commit(self, plan: ViewportPlan, source: LazyRowSource) -> ViewportSnapshot:
        """Publish a plan only if the source still has its captured revision."""

        if source.revision != plan.source_snapshot.revision:
            source.cancel_realizations(plan.staged)
            raise StaleSourceError(plan.source_snapshot.revision, source.revision)
        if (
            self._snapshot is not None
            and plan.source_snapshot.revision < self._snapshot.source_revision
        ):
            source.cancel_realizations(plan.staged)
            raise StaleSourceError(self._snapshot.source_revision, plan.source_snapshot.revision)
        actual_generation = None if self._snapshot is None else self._snapshot.generation
        if actual_generation != plan.base_viewport_generation:
            source.cancel_realizations(plan.staged)
            raise StaleViewportPlanError(
                plan.base_viewport_generation,
                actual_generation if actual_generation is not None else 0,
            )

        source.commit_realizations(plan.staged)
        for identity in plan.to_release:
            source.release(identity)
        self._snapshot = plan.snapshot
        self._source_snapshot = plan.source_snapshot
        self._active = set(plan.snapshot.realized)
        self._measurements = dict(plan.measurements)
        return plan.snapshot

    def apply_measured_extent(
        self,
        source: LazyRowSource,
        address: ItemAddress,
        extent: float,
    ) -> ViewportSnapshot:
        """Apply a realized row measurement and preserve the current anchor."""

        if self._snapshot is None or self._source_snapshot is None:
            raise ViewportContractError("cannot measure before the first layout")
        if source.revision != self._snapshot.source_revision:
            raise StaleSourceError(self._snapshot.source_revision, source.revision)
        identity = source.snapshot().identity_for(address)
        if identity is None:
            raise ViewportContractError(f"unknown item address: {address}")
        if identity not in self._active:
            raise UnrealizedItemError(f"item is not realized: {address}")
        measured = _finite_nonnegative(extent, "measured extent")
        next_measurements = dict(self._measurements)
        next_measurements[identity] = measured
        plan = self.prepare(
            source,
            offset=self._snapshot.offset,
            anchor=self._snapshot.anchor,
            measurements=next_measurements,
        )
        return self.commit(plan, source)

    @staticmethod
    def _identities(snapshot: RowSourceSnapshot) -> Tuple[ItemIdentity, ...]:
        return tuple(snapshot.identity_at(index) for index in range(snapshot.item_count))

    def _make_geometry(
        self,
        snapshot: RowSourceSnapshot,
        extents: Mapping[ItemIdentity, float],
    ) -> Tuple[Tuple[NodePlacement, ...], Tuple[GapPlacement, ...], float]:
        nodes: List[Tuple[Address, float]] = [(FixedAddress("header"), self.header_extent)]
        for identity in self._identities(snapshot):
            nodes.append((identity.address, extents[identity]))
        nodes.append((FixedAddress("footer"), self.footer_extent))

        placements: List[NodePlacement] = []
        gaps: List[GapPlacement] = []
        cursor = 0.0
        for index, (address, extent) in enumerate(nodes):
            placements.append(NodePlacement(address, cursor, extent))
            cursor += extent
            if index + 1 < len(nodes):
                next_address = nodes[index + 1][0]
                gaps.append(GapPlacement(address, next_address, cursor, self.gap))
                cursor += self.gap
        return tuple(placements), tuple(gaps), cursor

    @staticmethod
    def _placement_for_item(
        address: ItemAddress, placements: Sequence[NodePlacement]
    ) -> NodePlacement:
        for placement in placements:
            if placement.address == address:
                return placement
        raise ViewportContractError(f"anchor item has no placement: {address}")

    def _resolve_anchor(
        self,
        anchor: Optional[ScrollAnchor],
        snapshot: RowSourceSnapshot,
        extents: Mapping[ItemIdentity, float],
    ) -> Optional[ScrollAnchor]:
        if anchor is None:
            return None
        identity = snapshot.identity_for(anchor.address)
        if identity is not None and (
            anchor.generation is None or anchor.generation == identity.generation
        ):
            within = min(anchor.within_item_offset, extents[identity])
            return ScrollAnchor(identity.address, within, identity.generation)

        # The old identity is gone.  Resolve by old declaration order: next
        # surviving old item first, then previous.  This handles removal and
        # also prevents a reused key with a new generation from inheriting the
        # old anchor.
        old_snapshot = self._source_snapshot
        old_identity = (
            None
            if old_snapshot is None
            else old_snapshot.identity_for(anchor.address)
        )
        old_ids = () if old_snapshot is None else self._identities(old_snapshot)
        old_index = None if old_identity is None else old_ids.index(old_identity)
        current_ids = set(self._identities(snapshot))
        replacement: Optional[ItemIdentity] = None
        if old_index is not None:
            for candidate in old_ids[old_index + 1 :]:
                if candidate in current_ids:
                    replacement = candidate
                    break
            if replacement is None:
                for candidate in reversed(old_ids[:old_index]):
                    if candidate in current_ids:
                        replacement = candidate
                        break
        if replacement is None and snapshot.item_count:
            # If the old source was unavailable, choose the nearest current
            # index.  This is only a recovery rule; normal transactions retain
            # the old immutable snapshot.
            fallback_index = min(
                old_index if old_index is not None else 0,
                snapshot.item_count - 1,
            )
            replacement = snapshot.identity_at(fallback_index)
        if replacement is None:
            return None
        within = min(anchor.within_item_offset, extents[replacement])
        return ScrollAnchor(replacement.address, within, replacement.generation)

    @staticmethod
    def _intersects(start: float, end: float, viewport_start: float, viewport_end: float) -> bool:
        return end > viewport_start and start < viewport_end

    def _visible_range(
        self,
        placements: Sequence[NodePlacement],
        gaps: Sequence[GapPlacement],
        offset: float,
    ) -> VisibleRange:
        viewport_end = offset + self.viewport_extent
        addresses: List[Address] = []
        row_indices: List[int] = []
        row_index = 0
        for placement in placements:
            if isinstance(placement.address, ItemAddress):
                if self._intersects(
                    placement.content_start,
                    placement.content_end,
                    offset,
                    viewport_end,
                ):
                    addresses.append(placement.address)
                    row_indices.append(row_index)
                row_index += 1
            elif self._intersects(
                placement.content_start,
                placement.content_end,
                offset,
                viewport_end,
            ):
                addresses.append(placement.address)
        visible_gaps = tuple(
            gap
            for gap in gaps
            if self._intersects(gap.content_start, gap.content_end, offset, viewport_end)
        )
        return VisibleRange(tuple(addresses), tuple(row_indices), visible_gaps)

    def _candidate_indices(
        self,
        snapshot: RowSourceSnapshot,
        placements: Sequence[NodePlacement],
        visible: VisibleRange,
        offset: float,
    ) -> Tuple[int, ...]:
        count = snapshot.item_count
        if count == 0:
            return ()
        indices = list(visible.row_indices)
        if not indices:
            # A viewport can be wholly inside a large gap/header/footer.  Keep
            # the nearest row active so a gap never causes an unbounded or
            # empty realization decision.
            row_placements = [
                placement
                for placement in placements
                if isinstance(placement.address, ItemAddress)
            ]
            nearest = next(
                (
                    index
                    for index, placement in enumerate(row_placements)
                    if placement.content_end > offset
                ),
                len(row_placements) - 1,
            )
            indices = [nearest]
        lo = max(0, min(indices) - self.overscan)
        hi = min(count - 1, max(indices) + self.overscan)
        return tuple(range(lo, hi + 1))

    def _anchor_at_offset(
        self,
        snapshot: RowSourceSnapshot,
        placements: Sequence[NodePlacement],
        offset: float,
    ) -> Optional[ScrollAnchor]:
        rows = [
            placement
            for placement in placements
            if isinstance(placement.address, ItemAddress)
        ]
        if not rows:
            return None
        for index, placement in enumerate(rows):
            if placement.content_start <= offset < placement.content_end:
                identity = snapshot.identity_at(index)
                return ScrollAnchor(
                    identity.address,
                    offset - placement.content_start,
                    identity.generation,
                )
        # There is no row anchor while the scroll origin is in a fixed node or
        # a gap.  Retaining an absolute offset is the least surprising bounded
        # rule for this one-section probe; a richer section model can define a
        # cross-section anchor policy later.
        return None


__all__ = [
    "Address",
    "CONTRACT_LIMITATIONS",
    "FixedAddress",
    "GapPlacement",
    "ItemAddress",
    "ItemIdentity",
    "LazyRowSource",
    "NodePlacement",
    "RealizedItem",
    "RowSourceSnapshot",
    "RowSpec",
    "ScrollAnchor",
    "SectionAddress",
    "StaleSourceError",
    "StaleViewportPlanError",
    "TABLE_EXTENSION_NOTES",
    "UnrealizedItemError",
    "Viewport",
    "ViewportContractError",
    "ViewportPlan",
    "ViewportSnapshot",
    "VisibleRange",
]
