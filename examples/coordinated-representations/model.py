"""Source references and projections for two small, synthetic collections."""
from dataclasses import dataclass, replace
from enum import Enum
from statistics import mean


class Domain(str, Enum):
    SPECIMEN = "specimen"
    TRANSIT = "transit"


class Visibility(str, Enum):
    VISIBLE = "visible"
    FILTERED = "filtered"
    DELETED = "deleted"


@dataclass(frozen=True)
class Source:
    key: str
    group: str
    x: int
    y: int
    left: int
    top: int


@dataclass(frozen=True)
class Collection:
    title: str
    axes: str
    canvas: str
    measure: str
    threshold: int
    sources: tuple[Source, ...]


@dataclass(frozen=True)
class Stop:
    station: str
    km: int
    hourly_boardings: tuple[int, ...]
    position: tuple[int, int]


# Transit stores ordered stops per route and counts per hour. The plot uses
# total boardings while the schematic uses the station position.
ROUTES = {
    "Coastal": (Stop("T-02", 1, (7, 11), (16, 66)),
                Stop("T-19", 5, (14, 32), (39, 46))),
    "Upland": (Stop("T-31", 3, (20, 15), (59, 29)),
               Stop("T-68", 8, (40, 32), (81, 52))),
}


COLLECTIONS = {
    Domain.SPECIMEN: Collection("Specimen readings", "Depth (mm) × intensity (AU)",
        "Slide positions", "Intensity", 50, (
            Source("S-14", "Slide A", 2, 32, 20, 30),
            Source("S-38", "Slide A", 7, 76, 37, 60),
            Source("S-52", "Slide B", 4, 57, 64, 38),
            Source("S-87", "Slide B", 9, 85, 79, 70))),
    Domain.TRANSIT: Collection("Transit stops", "Distance (km) × boardings",
        "Station schematic", "Boardings", 30, tuple(
            Source(stop.station, route, stop.km, sum(stop.hourly_boardings), *stop.position)
            for route, stops in ROUTES.items() for stop in stops)),
}


@dataclass(frozen=True)
class Mark:
    members: tuple[str, ...]
    x: float
    y: float


@dataclass(frozen=True)
class View:
    domain: Domain = Domain.SPECIMEN
    selected: tuple[str, ...] = ()
    deleted: tuple[str, ...] = ()
    filtered: bool = False
    grouped: bool = False

    def __post_init__(self):
        keys = {row.key for row in self.collection.sources}
        for refs in (self.selected, self.deleted):
            if set(refs) - keys or len(refs) != len(set(refs)):
                raise ValueError("Invalid source references for this collection.")

    @property
    def collection(self):
        return COLLECTIONS[self.domain]

    def visibility(self, row):
        if row.key in self.deleted:
            return Visibility.DELETED
        if self.filtered and row.y < self.collection.threshold:
            return Visibility.FILTERED
        return Visibility.VISIBLE

    def visible(self):
        return [r for r in self.collection.sources if self.visibility(r) is Visibility.VISIBLE]

    def marks(self):
        groups = {}
        for row in self.visible():
            groups.setdefault(row.group if self.grouped else row.key, []).append(row)
        return [Mark(tuple(r.key for r in rows), mean(r.x for r in rows),
                     mean(r.y for r in rows)) for rows in groups.values()]

    def delete(self):
        if len(self.selected) != 1 or self.selected[0] not in {r.key for r in self.visible()}:
            raise ValueError("Choose one visible source to delete.")
        return replace(self, deleted=self.deleted + self.selected)
