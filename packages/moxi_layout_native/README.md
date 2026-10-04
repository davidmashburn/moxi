# Optional native layout services

This provisional `osx-arm64` conda package provides
`lib/libmoxi_layout_native.a`, containing the pinned Kiwi constraint bridge and
the CoreText/AppKit services used by the Mojo-owned layout candidate. It contains
no flow/grid engine. The Moxi Mojo package remains a separate dependency.

Build locally with Xcode command-line tools and a macOS SDK installed:

```sh
pixi publish --path packages/moxi_layout_native/recipe.yaml --target-dir dist/layout-native-package
```

The recipe pins Kiwi's commit and archive checksum, includes the Moxi and Kiwi
licenses, and compiles the native archive with a macOS 14 deployment target. It
uses the host Apple compiler/SDK; this is not a hermetic compiler distribution or
an Intel/cross-platform package. The pinned stable Mojo 1.1.0 consumer requires
macOS 15+ and Xcode or Command Line Tools 16+; the archive target does not lower
those [compiler requirements](https://mojolang.org/docs/requirements/).

After installing `moxi` and `moxi_layout_native` from the same candidate channel,
declare `macos = "15.0"` under `[system-requirements]` in the consumer's Pixi
manifest, then compile inside that environment:

```sh
mojo build -Xlinker "$CONDA_PREFIX/lib/libmoxi_layout_native.a" -Xlinker -lc++ \
  -Xlinker -framework -Xlinker Cocoa -Xlinker -framework -Xlinker CoreText \
  main.mojo -o app
```

`pixi run layout-package-consumer` builds a temporary local channel, installs
Moxi and this archive into a fresh environment, and compiles/runs the independent
layout consumer without repository source includes or native object paths.
This check does not upload a package or promote the candidate to the public API.
