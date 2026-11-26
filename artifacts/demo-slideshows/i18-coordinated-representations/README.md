# I18 verification

Captured 2026-11-26 at approximately 02:15 UTC on macOS. An isolated
collaborative-preview tab opened the loopback server at localhost:62631,
running the committed application at b5fe1f4. The viewport was 1280 × 800
CSS pixels at 2×. This is a local, single-user, synthetic fixture.

The manifest pairs actions and expected results with the original PNGs.
Build the offline slideshow with
`python3 artifacts/demo-slideshows/i18-coordinated-representations/build.py`.
The published gallery loads the 15 adjacent PNGs offline. The original offline check loaded all 15 images,
advanced with ArrowRight and jumped to slide 15 from the contact sheet.

| Scenario | Observed result | Evidence |
| --- | --- | --- |
| Tab to a specimen, then Enter | Focus ring on S-14; row, plot and slide highlight S-14 | Frames 1–3 |
| Filter and restore | S-14 reads filtered with three remaining marks. Removing the filter restores its highlight. | Frames 4–5 |
| Group and select a mean | One mean selects S-14 and S-38. Deleting this selection shows the single-visible-source requirement. | Frames 6–8 |
| Select a card, delete, reload | The S-38 tombstone survives reload. The first mean links only to S-14. | Frames 9–11 |
| Switch domain, select a mark and route mean | T-19 links to its station. The Coastal mean selects T-02 and T-19. | Frames 12–15 |

All five scenarios passed. The Playwright replay independently checked
highlights, mark counts and the error message, selected T-68 on a 390 × 844
viewport without horizontal overflow, and received HTTP 400 for a foreign
source ID. Core tests checked all 128 projection combinations across both
domains, including empty results. The repository Python suite passed 246
tests. See the example README for isolated setup and commands.

Open gates include coincident plot anchors, real-domain data, wider platform
coverage, screen-reader use and participant evaluation. The two fixture
adapters share an example-local projection contract. Framework extraction
remains a separate decision. Mojo/native suites were skipped.
