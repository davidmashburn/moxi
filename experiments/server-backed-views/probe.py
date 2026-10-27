"""Bounded in-process probe for server-backed reduced views.

This file deliberately models the data and adapter contracts without starting a
server, opening a listener, or claiming browser/network timing results.
"""

from array import array
from dataclasses import dataclass, replace
import json
import math
import random
import time
from numbers import Real
from typing import Any, Callable, Dict, List, Optional, Sequence, Tuple


SOURCE_POINT_COUNT = 1_000_000
SOURCE_SEED = 0x5EED2026
SOURCE_REVISION = 1

MAX_GRID_CELLS = 4_096
MAX_GRID_DIMENSION = 128
MAX_SERIALIZED_RESPONSE_BYTES = 64 * 1024

Viewport = Tuple[float, float, float, float]


def _is_real(value: Any) -> bool:
    return isinstance(value, Real) and not isinstance(value, bool)


def validate_viewport(viewport: Sequence[Real]) -> Viewport:
    """Validate and normalize a viewport with strict positive spans."""

    try:
        if len(viewport) != 4:
            raise ValueError("viewport must contain xmin, ymin, xmax, ymax")
    except TypeError as exc:
        raise ValueError("viewport must contain xmin, ymin, xmax, ymax") from exc

    if any(not _is_real(value) for value in viewport):
        raise ValueError("viewport coordinates must be finite real numbers")
    values = tuple(float(value) for value in viewport)
    if not all(math.isfinite(value) for value in values):
        raise ValueError("viewport coordinates must be finite real numbers")

    xmin, ymin, xmax, ymax = values
    if xmin >= xmax or ymin >= ymax:
        raise ValueError("viewport must have positive width and height")
    if not math.isfinite(xmax - xmin) or not math.isfinite(ymax - ymin):
        raise ValueError("viewport spans must be finite")
    return values  # type: ignore[return-value]


def validate_grid_dimensions(width: int, height: int) -> Tuple[int, int]:
    """Validate dimensions against the fixed first-slice grid cap."""

    if (
        not isinstance(width, int)
        or isinstance(width, bool)
        or not isinstance(height, int)
        or isinstance(height, bool)
    ):
        raise ValueError("grid dimensions must be integers")
    if width < 1 or height < 1:
        raise ValueError("grid dimensions must be positive")
    if width > MAX_GRID_DIMENSION or height > MAX_GRID_DIMENSION:
        raise ValueError(
            "grid dimensions exceed the per-axis cap of "
            f"{MAX_GRID_DIMENSION}"
        )
    if width * height > MAX_GRID_CELLS:
        raise ValueError(
            "grid dimensions exceed the cell cap of " f"{MAX_GRID_CELLS}"
        )
    return width, height


@dataclass
class SpatialPoints:
    """Synthetic source data held in compact typed arrays."""

    x: array
    y: array
    source_ids: array

    def __post_init__(self) -> None:
        if not (len(self.x) == len(self.y) == len(self.source_ids)):
            raise ValueError("point arrays must have equal lengths")

    def __len__(self) -> int:
        return len(self.x)

    @property
    def representation_bytes(self) -> int:
        """Bytes in the three array buffers, excluding Python object overhead."""

        return sum(memoryview(values).nbytes for values in (self.x, self.y, self.source_ids))


def generate_points(count: int = SOURCE_POINT_COUNT, seed: int = SOURCE_SEED) -> SpatialPoints:
    """Generate reproducible points in [0, 1) with stable 1-based IDs."""

    if count < 0:
        raise ValueError("point count must be non-negative")

    rng = random.Random(seed)
    xs = array("d")
    ys = array("d")
    source_ids = array("I", range(1, count + 1))
    for _ in range(count):
        xs.append(rng.random())
        ys.append(rng.random())
    return SpatialPoints(xs, ys, source_ids)


@dataclass(frozen=True)
class QueryRequest:
    query_id: str
    session_id: str
    dataset_revision: int
    generation: int
    viewport: Viewport
    width: int
    height: int


@dataclass(frozen=True)
class GridResponse:
    """Reduced response; source coordinates and source IDs are intentionally absent."""

    query_id: str
    source_revision: int
    width: int
    height: int
    x_edges: Tuple[float, ...]
    y_edges: Tuple[float, ...]
    counts: Tuple[int, ...]

    def as_payload(self) -> Dict[str, Any]:
        # Parallel edge arrays describe every cell as
        # [x_edges[col], y_edges[row], x_edges[col + 1], y_edges[row + 1]].
        return {
            "query_id": self.query_id,
            "source_revision": self.source_revision,
            "grid": {"width": self.width, "height": self.height},
            "cell_bounds": {
                "x_edges": list(self.x_edges),
                "y_edges": list(self.y_edges),
            },
            "counts": list(self.counts),
        }

    def serialized(self) -> bytes:
        return json.dumps(
            self.as_payload(), sort_keys=True, separators=(",", ":"), allow_nan=False
        ).encode("ascii")


class DensityGridBackend:
    """In-process backend query over compact source arrays."""

    def __init__(self, points: SpatialPoints, source_revision: int = SOURCE_REVISION):
        self.points = points
        self.source_revision = source_revision

    def query(self, request: QueryRequest) -> GridResponse:
        viewport = validate_viewport(request.viewport)
        width, height = validate_grid_dimensions(request.width, request.height)
        if request.dataset_revision != self.source_revision:
            raise ValueError("request dataset revision does not match backend revision")

        xmin, ymin, xmax, ymax = viewport
        x_span = xmax - xmin
        y_span = ymax - ymin
        # Divide before multiplying to avoid overflowing finite spans/offsets.
        x_edges = tuple(xmin + x_span * (index / width) for index in range(width + 1))
        y_edges = tuple(ymin + y_span * (index / height) for index in range(height + 1))
        for edges in (x_edges, y_edges):
            if not all(math.isfinite(v) for v in edges) or not all(
                a < b for a, b in zip(edges, edges[1:])
            ):
                raise ValueError("grid edges are not representable at this viewport precision")
        counts = [0] * (width * height)

        # Viewport and cell bounds are half-open: lower edges are included and
        # upper edges are excluded. Clamping protects the last cell from a
        # round-off result at exactly width/height for an in-range coordinate.
        for x, y in zip(self.points.x, self.points.y):
            if xmin <= x < xmax and ymin <= y < ymax:
                column = int(((x - xmin) / x_span) * width)
                row = int(((y - ymin) / y_span) * height)
                if column >= width:
                    column = width - 1
                if row >= height:
                    row = height - 1
                counts[row * width + column] += 1

        response = GridResponse(
            query_id=request.query_id,
            source_revision=self.source_revision,
            width=width,
            height=height,
            x_edges=x_edges,
            y_edges=y_edges,
            counts=tuple(counts),
        )
        serialized_bytes = len(response.serialized())
        if serialized_bytes > MAX_SERIALIZED_RESPONSE_BYTES:
            raise AssertionError(
                "capped grid produced an oversized serialized response: "
                f"{serialized_bytes} bytes"
            )
        return response


SuccessCallback = Callable[[QueryRequest, GridResponse], None]
ErrorCallback = Callable[[QueryRequest, Exception], None]


@dataclass
class _BackendDelivery:
    request: QueryRequest
    on_success: SuccessCallback
    on_error: ErrorCallback


class ManualBackend:
    """Manually released callbacks for deterministic queue/reply tests."""

    def __init__(self) -> None:
        self._pending: Dict[str, _BackendDelivery] = {}
        self.history: List[_BackendDelivery] = []
        self.max_pending = 0

    @property
    def pending_ids(self) -> Tuple[str, ...]:
        return tuple(self._pending)

    @property
    def pending_count(self) -> int:
        return len(self._pending)

    def submit(
        self,
        request: QueryRequest,
        on_success: SuccessCallback,
        on_error: ErrorCallback,
    ) -> None:
        if request.query_id in self._pending:
            raise AssertionError("query IDs must be unique")
        self._pending[request.query_id] = _BackendDelivery(
            request=request, on_success=on_success, on_error=on_error
        )
        self.history.append(self._pending[request.query_id])
        self.max_pending = max(self.max_pending, len(self._pending))

    def complete_success(self, query_id: str, response: GridResponse) -> None:
        delivery = self._pending.pop(query_id)
        delivery.on_success(delivery.request, response)

    def complete_error(self, query_id: str, error: Exception) -> None:
        delivery = self._pending.pop(query_id)
        delivery.on_error(delivery.request, error)

    def replay_success(
        self,
        query_id: str,
        response: GridResponse,
        request: Optional[QueryRequest] = None,
    ) -> None:
        """Replay a previously delivered callback to exercise stale replies."""

        for delivery in reversed(self.history):
            if delivery.request.query_id == query_id:
                delivery.on_success(request or delivery.request, response)
                return
        raise KeyError(query_id)


class AsyncViewAdapter:
    """Synchronous camera state plus one active and one replaceable request."""

    def __init__(self, backend: ManualBackend, session_id: str, dataset_revision: int):
        self.backend = backend
        self.session_id = session_id
        self.dataset_revision = dataset_revision
        self.disposed = False

        self._generation = 0
        self._query_number = 0
        self._active: Optional[QueryRequest] = None
        self._pending: Optional[QueryRequest] = None
        self._displayed: Optional[GridResponse] = None
        self._displayed_stamp: Optional[Tuple[str, int, int]] = None
        self._last_failed: Optional[QueryRequest] = None
        self._error: Optional[str] = None
        self.camera_viewport: Optional[Viewport] = None
        self.camera_dimensions: Optional[Tuple[int, int]] = None
        self.rejected_replies: List[str] = []
        self.max_queue_depth = 0

    @property
    def generation(self) -> int:
        return self._generation

    @property
    def active_request(self) -> Optional[QueryRequest]:
        return self._active

    @property
    def pending_request(self) -> Optional[QueryRequest]:
        return self._pending

    @property
    def displayed(self) -> Optional[GridResponse]:
        return self._displayed

    @property
    def displayed_is_current(self) -> bool:
        return self._displayed_stamp == (
            self.session_id,
            self.dataset_revision,
            self._generation,
        )

    @property
    def error(self) -> Optional[str]:
        return self._error

    @property
    def queue_depth(self) -> int:
        return int(self._active is not None) + int(self._pending is not None)

    def _record_queue_depth(self) -> None:
        self.max_queue_depth = max(self.max_queue_depth, self.queue_depth)

    def _next_query_id(self) -> str:
        self._query_number += 1
        return f"{self.session_id}:{self._generation}:{self._query_number}"

    def _submit(self, request: QueryRequest) -> None:
        self._active = request
        self.backend.submit(request, self._on_success, self._on_error)
        self._record_queue_depth()

    def update_camera(
        self, viewport: Sequence[Real], width: int, height: int
    ) -> Optional[QueryRequest]:
        """Apply camera state immediately and coalesce a request if necessary."""

        if self.disposed:
            return None
        normalized_viewport = validate_viewport(viewport)
        normalized_dimensions = validate_grid_dimensions(width, height)
        self._generation += 1
        self.camera_viewport = normalized_viewport
        self.camera_dimensions = normalized_dimensions
        self._error = None
        self._last_failed = None
        request = QueryRequest(
            query_id=self._next_query_id(),
            session_id=self.session_id,
            dataset_revision=self.dataset_revision,
            generation=self._generation,
            viewport=normalized_viewport,
            width=normalized_dimensions[0],
            height=normalized_dimensions[1],
        )
        if self._active is None:
            self._submit(request)
        else:
            self._pending = request
            self._record_queue_depth()
        return request

    def change_context(self, session_id: str, dataset_revision: int) -> None:
        """Invalidate prior requests while retaining the prior display."""

        if self.disposed:
            return
        if not session_id:
            raise ValueError("session ID must be non-empty")
        if not isinstance(dataset_revision, int) or isinstance(dataset_revision, bool):
            raise ValueError("dataset revision must be an integer")
        self.session_id = session_id
        self.dataset_revision = dataset_revision
        self._generation += 1
        self._pending = None
        self._last_failed = None
        self._error = None
        self._record_queue_depth()

    def retry(self) -> bool:
        if (
            self.disposed
            or self._active is not None
            or self._pending is not None
            or self._last_failed is None
        ):
            return False
        failed = self._last_failed
        if not self._request_matches_context(failed) or failed.generation != self._generation:
            return False
        retry_request = replace(
            failed,
            query_id=self._next_query_id(),
            session_id=self.session_id,
            dataset_revision=self.dataset_revision,
        )
        self._last_failed = None
        self._error = None
        self._submit(retry_request)
        return True

    def dispose(self) -> None:
        if self.disposed:
            return
        self.disposed = True
        self._active = None
        self._pending = None
        self._last_failed = None
        self._error = None
        self._record_queue_depth()

    def _request_matches_context(self, request: QueryRequest) -> bool:
        return (
            request.session_id == self.session_id
            and request.dataset_revision == self.dataset_revision
            and request.generation == self._generation
        )

    def _response_matches(self, request: QueryRequest, response: GridResponse) -> bool:
        return (
            self._request_matches_context(request)
            and response.query_id == request.query_id
            and response.source_revision == self.dataset_revision
            and response.width == request.width
            and response.height == request.height
            and len(response.x_edges) == request.width + 1
            and len(response.y_edges) == request.height + 1
            and len(response.counts) == request.width * request.height
        )

    def _reject(self, reason: str) -> None:
        self.rejected_replies.append(reason)

    def _dispatch_pending(self) -> None:
        if self.disposed or self._active is not None or self._pending is None:
            return
        pending = self._pending
        self._pending = None
        self._submit(pending)

    def _on_success(self, request: QueryRequest, response: GridResponse) -> None:
        if self.disposed:
            return
        if self._active is None or self._active.query_id != request.query_id:
            self._reject("reply-not-active")
            return

        self._active = None
        if self._response_matches(request, response):
            self._displayed = response
            self._displayed_stamp = (
                request.session_id,
                request.dataset_revision,
                request.generation,
            )
            self._error = None
            self._last_failed = None
        else:
            if request.session_id != self.session_id:
                self._reject("wrong-session")
            elif request.dataset_revision != self.dataset_revision:
                self._reject("wrong-revision")
            elif request.generation != self._generation:
                self._reject("stale-generation")
            else:
                self._reject("response-identity")
                self._error = "invalid backend response"
                self._last_failed = request
        self._record_queue_depth()
        self._dispatch_pending()

    def _on_error(self, request: QueryRequest, error: Exception) -> None:
        if self.disposed:
            return
        if self._active is None or self._active.query_id != request.query_id:
            self._reject("error-not-active")
            return

        self._active = None
        if self._request_matches_context(request):
            self._error = str(error)
            self._last_failed = request
        else:
            self._reject("stale-error")
        self._record_queue_depth()
        self._dispatch_pending()


def _fixture_points() -> SpatialPoints:
    return SpatialPoints(
        array("d", [0.0, 0.5, 0.999999, 0.25, 1.0, 0.5, -0.1, 0.25]),
        array("d", [0.0, 0.0, 0.999999, 0.5, 0.5, 1.0, 0.25, -0.1]),
        array("I", [101, 102, 103, 104, 105, 106, 107, 108]),
    )


def _fixture_request(
    query_id: str = "fixture",
    viewport: Viewport = (0.0, 0.0, 1.0, 1.0),
    width: int = 2,
    height: int = 2,
) -> QueryRequest:
    return QueryRequest(
        query_id=query_id,
        session_id="fixture-session",
        dataset_revision=SOURCE_REVISION,
        generation=1,
        viewport=viewport,
        width=width,
        height=height,
    )


def _stub_response(request: QueryRequest, source_revision: int, marker: int) -> GridResponse:
    xmin, ymin, xmax, ymax = request.viewport
    x_span = xmax - xmin
    y_span = ymax - ymin
    x_edges = tuple(
        xmin + x_span * index / request.width for index in range(request.width + 1)
    )
    y_edges = tuple(
        ymin + y_span * index / request.height for index in range(request.height + 1)
    )
    return GridResponse(
        query_id=request.query_id,
        source_revision=source_revision,
        width=request.width,
        height=request.height,
        x_edges=x_edges,
        y_edges=y_edges,
        counts=(marker,) * (request.width * request.height),
    )


def _expect_raises(expected: type, callback: Callable[[], Any]) -> None:
    try:
        callback()
    except expected:
        return
    raise AssertionError(f"expected {expected.__name__}")


def test_deterministic_generation() -> None:
    first = generate_points(count=8, seed=SOURCE_SEED)
    second = generate_points(count=8, seed=SOURCE_SEED)
    assert first.x == second.x
    assert first.y == second.y
    assert first.source_ids == second.source_ids
    assert first.x.typecode == "d"
    assert first.y.typecode == "d"
    assert first.source_ids.typecode == "I"


def test_small_fixture() -> None:
    backend = DensityGridBackend(_fixture_points())
    response = backend.query(_fixture_request())
    assert response.counts == (1, 1, 1, 1), response.counts
    assert sum(response.counts) == 4
    assert response.x_edges == (0.0, 0.5, 1.0)
    assert response.y_edges == (0.0, 0.5, 1.0)
    assert response.query_id == "fixture"
    assert response.source_revision == SOURCE_REVISION

    right_half = backend.query(
        _fixture_request(
            query_id="fixture-right-half",
            viewport=(0.5, 0.0, 1.0, 1.0),
            width=1,
            height=1,
        )
    )
    assert right_half.counts == (2,), right_half.counts

    payload = response.as_payload()
    assert set(payload) == {
        "query_id",
        "source_revision",
        "grid",
        "cell_bounds",
        "counts",
    }
    assert "source_ids" not in payload
    assert "coordinates" not in payload


def test_validation() -> None:
    backend = DensityGridBackend(_fixture_points())
    request = _fixture_request()

    _expect_raises(
        ValueError,
        lambda: backend.query(replace(request, viewport=(0.0, 0.0, 0.0, 1.0))),
    )
    _expect_raises(
        ValueError,
        lambda: backend.query(replace(request, viewport=(0.0, 0.0, math.nan, 1.0))),
    )
    _expect_raises(
        ValueError,
        lambda: backend.query(replace(request, viewport=(0.0, 0.0, 1.0))),
    )
    _expect_raises(
        ValueError,
        lambda: backend.query(replace(request, width=0)),
    )
    _expect_raises(
        ValueError,
        lambda: backend.query(replace(request, height=-1)),
    )
    _expect_raises(
        ValueError,
        lambda: backend.query(replace(request, width=MAX_GRID_DIMENSION + 1)),
    )
    _expect_raises(
        ValueError,
        lambda: backend.query(replace(request, width=65, height=64)),
    )
    _expect_raises(
        ValueError,
        lambda: backend.query(replace(request, width=True)),
    )


def test_adapter_coalescing_and_stale_replies() -> None:
    backend = ManualBackend()
    adapter = AsyncViewAdapter(backend, "session-1", SOURCE_REVISION)

    initial = adapter.update_camera((0.0, 0.0, 1.0, 1.0), 1, 1)
    assert initial is not None
    backend.complete_success(initial.query_id, _stub_response(initial, 1, 10))
    assert adapter.displayed is not None
    assert adapter.displayed.counts == (10,)
    assert adapter.displayed_is_current

    rapid_requests: List[QueryRequest] = []
    for index in range(40):
        left = index / 100.0
        rapid_requests.append(
            adapter.update_camera((left, 0.0, left + 0.5, 1.0), 1, 1)  # type: ignore[arg-type]
        )
    assert all(request is not None for request in rapid_requests)
    first = rapid_requests[0]
    latest = rapid_requests[-1]
    assert first is not None and latest is not None
    assert adapter.camera_viewport == latest.viewport
    assert adapter.displayed.counts == (10,)
    assert not adapter.displayed_is_current
    assert adapter.active_request is first
    assert adapter.pending_request is latest
    assert adapter.queue_depth == 2
    assert backend.pending_count == 1
    assert adapter.max_queue_depth <= 2
    assert backend.max_pending <= 1

    # The first completion is delayed until after all camera updates. It is
    # delivered but rejected because the current generation is the latest one.
    backend.complete_success(first.query_id, _stub_response(first, 1, 11))
    assert adapter.displayed.counts == (10,)
    assert adapter.active_request is latest
    assert adapter.pending_request is None
    assert "stale-generation" in adapter.rejected_replies

    # A duplicate/out-of-order replay of the already completed request must not
    # disturb the now-active latest request.
    backend.replay_success(first.query_id, _stub_response(first, 1, 99))
    assert adapter.displayed.counts == (10,)
    assert adapter.active_request is latest
    assert "reply-not-active" in adapter.rejected_replies

    backend.complete_success(latest.query_id, _stub_response(latest, 1, 40))
    assert adapter.displayed.counts == (40,)
    assert adapter.displayed_is_current
    assert adapter.queue_depth == 0


def test_adapter_context_rejection() -> None:
    backend = ManualBackend()
    adapter = AsyncViewAdapter(backend, "session-1", SOURCE_REVISION)
    old_request = adapter.update_camera((0.0, 0.0, 1.0, 1.0), 1, 1)
    assert old_request is not None

    adapter.change_context("session-2", SOURCE_REVISION + 1)
    new_request = adapter.update_camera((0.1, 0.1, 0.9, 0.9), 1, 1)
    assert new_request is not None
    assert adapter.active_request is old_request
    assert adapter.pending_request is new_request

    # The old request is active at the transport boundary, but its session,
    # dataset revision, and generation no longer match the adapter context.
    backend.complete_success(old_request.query_id, _stub_response(old_request, 1, 1))
    assert adapter.displayed is None
    assert "wrong-session" in adapter.rejected_replies
    assert adapter.active_request is new_request
    assert backend.pending_count == 1

    backend.complete_success(new_request.query_id, _stub_response(new_request, 2, 2))
    assert adapter.displayed is not None
    assert adapter.displayed.counts == (2,)
    assert adapter.displayed_is_current
    assert "wrong-revision" not in adapter.rejected_replies

    revision_backend = ManualBackend()
    revision_adapter = AsyncViewAdapter(revision_backend, "session-1", SOURCE_REVISION)
    revision_old = revision_adapter.update_camera((0.0, 0.0, 1.0, 1.0), 1, 1)
    assert revision_old is not None
    revision_adapter.change_context("session-1", SOURCE_REVISION + 1)
    revision_new = revision_adapter.update_camera((0.1, 0.1, 0.9, 0.9), 1, 1)
    assert revision_new is not None
    revision_backend.complete_success(
        revision_old.query_id, _stub_response(revision_old, SOURCE_REVISION, 3)
    )
    assert "wrong-revision" in revision_adapter.rejected_replies
    revision_backend.complete_success(
        revision_new.query_id, _stub_response(revision_new, SOURCE_REVISION + 1, 4)
    )
    assert revision_adapter.displayed is not None
    assert revision_adapter.displayed.counts == (4,)


def test_adapter_error_retry_and_disposal() -> None:
    backend = ManualBackend()
    adapter = AsyncViewAdapter(backend, "session-1", SOURCE_REVISION)
    baseline = adapter.update_camera((0.0, 0.0, 1.0, 1.0), 1, 1)
    assert baseline is not None
    backend.complete_success(baseline.query_id, _stub_response(baseline, 1, 7))

    failed = adapter.update_camera((0.2, 0.2, 0.8, 0.8), 1, 1)
    assert failed is not None
    backend.complete_error(failed.query_id, RuntimeError("backend offline"))
    assert adapter.displayed.counts == (7,)
    assert adapter.error == "backend offline"
    assert adapter.active_request is None
    assert adapter.retry()
    retry_request = adapter.active_request
    assert retry_request is not None
    assert retry_request.query_id != failed.query_id
    assert adapter.displayed.counts == (7,)
    backend.complete_success(retry_request.query_id, _stub_response(retry_request, 1, 8))
    assert adapter.displayed.counts == (8,)
    assert adapter.error is None
    assert adapter.displayed_is_current

    disposal_backend = ManualBackend()
    disposal_adapter = AsyncViewAdapter(disposal_backend, "session-1", SOURCE_REVISION)
    active = disposal_adapter.update_camera((0.0, 0.0, 1.0, 1.0), 1, 1)
    pending = disposal_adapter.update_camera((0.1, 0.1, 0.9, 0.9), 1, 1)
    assert active is not None and pending is not None
    disposal_adapter.dispose()
    assert disposal_adapter.disposed
    assert disposal_adapter.queue_depth == 0
    disposal_backend.complete_success(active.query_id, _stub_response(active, 1, 123))
    assert disposal_adapter.displayed is None
    assert disposal_adapter.update_camera((0.0, 0.0, 1.0, 1.0), 1, 1) is None
    assert disposal_adapter.retry() is False
    assert disposal_backend.pending_count == 0


def test_numeric_limits_and_reducer_integration() -> None:
    reducer = DensityGridBackend(_fixture_points())
    # Invalid even with no source points; do not emit NaN/Infinity in JSON.
    empty = DensityGridBackend(generate_points(0))
    for viewport in [(-1e308, 0.0, 1e308, 1.0),
                     (1.0, 0.0, math.nextafter(1.0, 2.0), 1.0)]:
        _expect_raises(ValueError, lambda: empty.query(_fixture_request(viewport=viewport)))
    # Large but representable spans must work without intermediate overflow.
    huge = reducer.query(_fixture_request(viewport=(0.0, 0.0, 1e308, 1e308)))
    assert sum(huge.counts) == 6
    assert all(math.isfinite(value) for value in huge.x_edges)

    transport = ManualBackend()
    adapter = AsyncViewAdapter(transport, "real-reducer", SOURCE_REVISION)
    first = adapter.update_camera((0.0, 0.0, 1.0, 1.0), 2, 2)
    assert first is not None
    transport.complete_success(first.query_id, reducer.query(first))
    assert adapter.displayed is not None and adapter.displayed.counts == (1, 1, 1, 1)
    next_request = adapter.update_camera((0.5, 0.0, 1.0, 1.0), 1, 1)
    assert next_request is not None
    wrong = replace(reducer.query(next_request), source_revision=SOURCE_REVISION + 1)
    transport.complete_success(next_request.query_id, wrong)
    assert adapter.error == "invalid backend response"
    assert adapter.displayed.counts == (1, 1, 1, 1)
    assert adapter.retry()
    retry = adapter.active_request
    assert retry is not None
    transport.complete_success(retry.query_id, reducer.query(retry))
    assert adapter.displayed.counts == (2,) and adapter.displayed_is_current
    assert adapter.error is None


def run_large_query_probe() -> Dict[str, Any]:
    started = time.perf_counter()
    points = generate_points()
    generated_seconds = time.perf_counter() - started
    assert len(points) == SOURCE_POINT_COUNT
    assert points.source_ids[0] == 1
    assert points.source_ids[123_456] == 123_457
    assert points.source_ids[-1] == SOURCE_POINT_COUNT

    backend = DensityGridBackend(points)
    request = QueryRequest(
        query_id="large-full-range",
        session_id="probe-session",
        dataset_revision=SOURCE_REVISION,
        generation=1,
        viewport=(0.0, 0.0, 1.0, 1.0),
        width=64,
        height=64,
    )
    query_started = time.perf_counter()
    response = backend.query(request)
    query_seconds = time.perf_counter() - query_started
    serialized_bytes = len(response.serialized())

    assert sum(response.counts) == SOURCE_POINT_COUNT
    assert len(response.counts) == 64 * 64
    assert serialized_bytes <= MAX_SERIALIZED_RESPONSE_BYTES
    assert response.source_revision == SOURCE_REVISION
    assert response.query_id == request.query_id
    assert "source_ids" not in response.as_payload()

    return {
        "points": len(points),
        "seed": SOURCE_SEED,
        "source_array_bytes": points.representation_bytes,
        "serialized_response_bytes": serialized_bytes,
        "generated_seconds": generated_seconds,
        "query_seconds_diagnostic": query_seconds,
        "grid_cells": len(response.counts),
        "count_total": sum(response.counts),
    }


def main() -> None:
    test_deterministic_generation()
    test_small_fixture()
    test_validation()
    test_adapter_coalescing_and_stale_replies()
    test_adapter_context_rejection()
    test_adapter_error_retry_and_disposal()
    test_numeric_limits_and_reducer_integration()
    measurements = run_large_query_probe()

    print("PASS deterministic compact source generation")
    print("PASS small fixture exact counts and half-open boundaries")
    print("PASS invalid viewport and grid dimensions rejected")
    print("PASS one-active/one-pending coalescing and stale replies rejected")
    print("PASS wrong session/revision replies rejected")
    print("PASS backend error/retry retains prior view")
    print("PASS disposal prevents updates from delayed replies")
    print("PASS numeric limits and real reducer/adapter integration")
    print(
        "PASS full dataset count: "
        f"{measurements['count_total']:,} points in "
        f"{measurements['grid_cells']:,} cells"
    )
    print(
        "MEASURE source array buffers: "
        f"{measurements['source_array_bytes']:,} bytes; "
        "serialized response: "
        f"{measurements['serialized_response_bytes']:,} bytes; "
        f"limit: {MAX_SERIALIZED_RESPONSE_BYTES:,} bytes"
    )
    print(
        "DIAGNOSTIC generation/query time (not browser or network timing): "
        f"{measurements['generated_seconds']:.3f}s / "
        f"{measurements['query_seconds_diagnostic']:.3f}s"
    )


if __name__ == "__main__":
    main()
