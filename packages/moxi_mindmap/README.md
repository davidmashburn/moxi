# Moxi mind map

Public consumer package at `src/moxi_mindmap`. Requires `moxi` and `moxi_canvas`; no Freeplane runtime, Python runtime, network service, plugin or scripting engine. The model, layout, codec and history are headless. The optional macOS storage adapter links `native/mindmap/storage.m` with Cocoa.

Run `pixi run d04-mindmap-consumer` for a consumer compiled from three `.mojoc` packages in a temporary directory without a source include path. Run `pixi run d04-mindmap-app` for the native example. See `docs/mindmap.md` for scope, controls, limitations and validation evidence.
