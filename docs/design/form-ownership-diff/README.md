# Three form ownership designs in Bygone

Open the three panels, from left to right: current-state projection, shared
observed property, and controlled value plus callback.

```sh
bygone --read-only --diff docs/design/form-ownership-diff/01-projection.mojo docs/design/form-ownership-diff/02-observed.mojo docs/design/form-ownership-diff/03-controlled.mojo
```

Each file includes the same complete `Details` definition above its candidate
and the same native launch below it. Unchanged code inside the candidates is
also retained. These are **uncompiled source specifications**, not working Moxi
applications; the `proposed` imports still identify missing runtime APIs.

Source: [the comparison](../form-ownership-comparison.md) at planning commit
`1a1d180fa07b841aadbdf3aff197168e53224ef4`. The first five Mojo blocks supply the shared domain
code, three variants, and shared launch. For this flattened view, module-heading
comments, `from common import Details`, and the launch's candidate-module import
are removed. Every remaining source line is unchanged. The in-file `Details`
and `Model` definitions take their place. No behavior is intentionally changed.

Verification: exact extraction of each candidate body; byte-identical common
prefix and suffix across all three files. No full application compilation or
runtime tests were performed. This is a file comparison, not a revision history
or an authored tour.
