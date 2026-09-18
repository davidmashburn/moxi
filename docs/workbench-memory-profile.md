# Workbench memory profile

Captured 2026-09-18 from the same native process (PID 7690), whose start time
was 18:24:44. The baseline was the default 48-row workbench state. The second
capture followed the confirmed import of 100,000 rows, three numeric fields,
100,000 visible rows, and zero selected rows. The executable and bundle identity
are recorded with the raw captures. Evidence is in
[`workbench-memory-profile-2026-09-18`](benchmarks/workbench-memory-profile-2026-09-18/),
with a SHA-256 manifest at
[`SHA256SUMS.txt`](benchmarks/workbench-memory-profile-2026-09-18/SHA256SUMS.txt).

## Observed memory

The two tools report different accounting views and were run at slightly
different times. Values below are kept in their native units where that avoids
false precision.

| Measurement | Baseline | 100k state | Change or note |
| --- | ---: | ---: | --- |
| `ps` RSS at first probe | 98,496 KiB | 435,568 KiB | +337,072 KiB (+329.2 MiB) |
| `ps` RSS after 100k tools | — | 377,792 KiB | Lower after diagnostic attachment; not a stable comparison point |
| `footprint` total | 166,347,904 B (158.6 MiB) | 594,822,584 B (567.3 MiB) | +428,474,680 B (+408.6 MiB) |
| `footprint` peak since launch | 462,177,384 B (440.8 MiB) | 747,980,240 B (713.3 MiB) | +285,802,856 B (+272.5 MiB) |
| `vmmap` physical footprint | 169.7 MiB | 567.3 MiB | Snapshot-specific; see raw summaries |

The footprint increase is concentrated in dirty `untagged (VM_ALLOCATE)` pages,
which grew by 338,444,288 B, and `MALLOC_SMALL`, which grew by 82,444,288 B.
The dirty `IOSurface` category stayed at 31,653,888 B; its swapped amount grew
under memory pressure. The largest `vmmap` regions are anonymous `VM_ALLOCATE`
regions (two approximately 112 MiB regions in the 100k capture), but `vmmap`
cannot identify their Mojo owner. `ps` virtual size stayed near 416 GiB
(435,982,144 to 436,408,832 KiB); this is address space, not physical use.

The heap snapshots show a strong per-mark Core Graphics signal:

* `CGPath`: 433 objects / 68 KiB at baseline, 100,253 / 15.3 MiB at 100k.
* `CG::DisplayListEntryPath`: 286 / 45 KiB at baseline, 100,098 / 15.3 MiB at
  100k.
* The corresponding 100,176 shared display-list entry pointers are also present
  in the 100k top allocations.

The workbench builds a rounded-rectangle scene command for each scatter mark
when the dense scatter path is rendered (`plotting.mojo`), and the native
rounded-rectangle path uses `CGPathCreateWithRoundedRect`. The counts are
consistent with retained per-mark display-list entries in this capture. They do
not by themselves prove which object holds the final lifetime.

The heap also reports framework objects that scale with the larger capture:
`_NSCallStackArray._frames` 24,894 / 48.6 MiB to 40,070 / 78.3 MiB,
`NSInvocation._retdata` 12,455 / 7.6 MiB to 20,047 / 12.2 MiB, and `NSException`
12,447 to 20,035 objects. These are object-type counts without allocation
stacks. They could reflect repeated Accessibility/VoiceOver or other framework
inspection activity during this session, but that is only a hypothesis. A targeted
source search found no app `NSException`, `@throw`, or `@catch` path. The native
accessibility implementation caps its element arrays at 128 elements and
rebuilds them per frame, so the heap counts cannot be attributed to that code
from this evidence alone.

The `leaks` scans were nearly unchanged: 1,238 objects / 40,736 B at baseline
and 1,353 / 43,888 B at 100k. This does not indicate a large unreachable-object
leak, though a reachability scan is not a lifetime or ownership proof.

## Limits and next profile

RSS is resident memory at one instant. `footprint` is macOS dirty/system
accounting, and `vmmap` also reports reserved virtual regions. The initial 100k
RSS probe was 435,568 KiB and the post-tool probe was 377,792 KiB; diagnostic
attachment and paging changed residency. The historical approximately 619 MB
RSS observation was not reproduced by this capture, so these measurements should
not be treated as an exact rerun of that result.

This process was not launched with `MallocStackLogging`; `malloc_history` could
not produce stacks, and the binary has no matching dSYM/source line information.
The available `xctrace` path was not run because the installed Xcode required
license acceptance and latency work had priority. Consequently, the report
attributes categories and heap types, not Mojo source allocation sites.

If attribution is needed after the latency work, use one fresh process with
`MallocStackLoggingNoCompact=1`, load the same CSV, and capture one bounded
`malloc_history` call tree (or an Allocations trace when `xctrace` is available).
Run it without a concurrent latency sample. The result that would change the
current interpretation is an allocation stack tying the anonymous growth or
the Core Graphics display-list objects to a specific workbench/rendering path;
an identical run without Accessibility inspection would also test the current
framework-overhead hypothesis.
