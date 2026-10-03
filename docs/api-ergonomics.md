# API ergonomics baseline

The article review identified compile-time and diagnostic burden as risks for
Moxi's Mojo-facing API. `pixi run api-ergonomics-quick` records a small public
consumer and request/effect example; `pixi run api-ergonomics-full` adds the
composed and demo consumers.

Each report under `dist/api-ergonomics/` records:

- same-process compile-and-run wall time for the selected consumer fixtures;
- the byte and line size of a deliberately invalid `RequestHandle` consumer
  diagnostic; and
- the current export count, trait-method count, generic declaration count,
  `Component` method count, `ComponentSlot` generic count, and request-generic
  count.

The output is a local baseline, not a cross-machine performance claim. Keep
the compiler version, host, and git revision from the report with any review.
The invalid fixture is intentionally excluded from `scripts/test.sh`; it is
only compiled by the ergonomics harness and must continue to fail.
