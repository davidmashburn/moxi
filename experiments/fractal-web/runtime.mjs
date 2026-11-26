import { createMemory64Allocator, supportsMemory64 } from "../shared/memory64.mjs";
export { supportsMemory64 };
/** Experimental memory64 host for Mojo's actual FractalState + RGBA raster. */
export const Limits = Object.freeze({ memory: 64 * 1024 * 1024, instances: 8 });
export const Status = Object.freeze({ ok: 0, invalidHandle: -1, invalidInput: -2 });
export const EventKind = Object.freeze({ down: 1, up: 5, move: 6, frame: 10, cancel: 19 });
export const RuntimeState = Object.freeze({ ready: "ready", failed: "failed", disposed: "disposed" });
export const DiagnosticImports = Object.freeze([
  "KGEN_CompilerRT_GetStackTrace",
  "write",
  "dup",
  "fdopen",
  "fflush",
  "fclose",
  "KGEN_CompilerRT_fprintf",
]);

// moxi_inspect field numbers are the wire contract with browser.mojo.
const Field = Object.freeze({
  preset: 0,
  complete: 1,
  overflow: 2,
  branches: 3,
  guides: 4,
  colors: 5,
  pointCount: 6,
  previewCount: 7,
  width: 8,
  height: 9,
  dragging: 10,
  startDocked: 11,
  endDocked: 12,
  startRevealed: 13,
  endRevealed: 14,
  pointX: 20,
  pointY: 21,
  baselineX: 22,
  baselineY: 23,
  previewX0: 24,
  previewY0: 25,
  previewX1: 26,
  previewY1: 27,
});

export async function instantiateFractal(
  bytes,
  { heapLimit = Limits.memory, memory64 = supportsMemory64() } = {},
) {
  if (!memory64) throw new Error("Unsupported runtime: WebAssembly memory64 is required");
  if (!Number.isSafeInteger(heapLimit) || heapLimit < 65536 || heapLimit > Limits.memory)
    throw new RangeError("invalid heap limit");
  const started = performance.now();
  let instance;
  let state = RuntimeState.ready,
    failure = null,
    nextHandle = 1n;
  let textInput = new Uint8Array(),
    textOutput = "";
  const handles = new Map();
  const decoder = new TextDecoder("utf-8", { fatal: true });
  const allocator = createMemory64Allocator({ memory: () => instance?.exports.memory, heapLimit });
  const { range: memoryRange, alloc, free } = allocator;
  const fmax = (a, b) => (Number.isNaN(a) ? b : Number.isNaN(b) ? a : Math.max(a, b));
  const fmin = (a, b) => (Number.isNaN(a) ? b : Number.isNaN(b) ? a : Math.min(a, b));
  const env = {
    KGEN_CompilerRT_AlignedAlloc: alloc,
    KGEN_CompilerRT_AlignedFree: free,
    sin: Math.sin,
    cos: Math.cos,
    sinf: Math.sin,
    cosf: Math.cos,
    fmax,
    fmin,
    fmaxf: fmax,
    fminf: fmin,
    __multi3: (out, al, ah, bl, bh) => {
      const a = (BigInt.asUintN(64, ah) << 64n) | BigInt.asUintN(64, al);
      const b = (BigInt.asUintN(64, bh) << 64n) | BigInt.asUintN(64, bl);
      const result = BigInt.asUintN(128, a * b);
      const range = memoryRange(out, 16);
      const view = new DataView(range.buffer, range.byteOffset, range.byteLength);
      view.setBigUint64(0, BigInt.asUintN(64, result), true);
      view.setBigUint64(8, result >> 64n, true);
    },
    moxi_can_create: () => (handles.size < Limits.instances && nextHandle < 2n ** 63n ? 1 : 0),
    moxi_register: (address) => {
      if (handles.size >= Limits.instances || nextHandle >= 2n ** 63n) throw new Error("handle capacity");
      const handle = nextHandle++;
      handles.set(handle, address);
      return handle;
    },
    moxi_resolve: (handle) => handles.get(handle) ?? 0n,
    moxi_forget: (handle) => {
      handles.delete(handle);
    },
    moxi_text_size: () => textInput.length,
    moxi_text_byte: (i) => textInput[i],
    moxi_text_out: (ptr, length) => {
      textOutput = decoder.decode(memoryRange(ptr, length));
    },
  };
  for (const name of DiagnosticImports)
    env[name] = () => {
      throw new Error(`Unsupported Mojo diagnostic path: ${name}; module must be discarded`);
    };
  const module = await WebAssembly.compile(bytes);
  const imports = WebAssembly.Module.imports(module);
  for (const item of imports)
    if (item.module !== "env" || item.kind !== "function" || !Object.hasOwn(env, item.name))
      throw new Error(`Unapproved runtime import: ${item.module}.${item.name}`);
  instance = await WebAssembly.instantiate(module, { env });
  allocator.initialize(instance.exports.__heap_base.value);
  const startupMs = performance.now() - started;
  function invoke(name, ...args) {
    if (state !== RuntimeState.ready) throw new Error(`Fractal runtime ${state}: ${failure ?? ""}`);
    if (!Object.hasOwn(instance.exports, name) || !name.startsWith("moxi_"))
      throw new TypeError("unknown ABI operation");
    try {
      return instance.exports[name](...args);
    } catch (error) {
      state = RuntimeState.failed;
      failure = String(error);
      handles.clear();
      throw error;
    }
  }
  function check(status) {
    if (status !== Status.ok) throw new RangeError(`Fractal operation rejected: ${status}`);
  }
  const presets = Object.freeze(
    Array.from({ length: invoke("moxi_preset_count") }, (_, id) => {
      check(invoke("moxi_preset_name", id));
      return Object.freeze({ id, name: textOutput });
    }),
  );
  function create({ preset = 0, depth = "5" } = {}) {
    const handle = invoke("moxi_create");
    if (handle === 0n) throw new RangeError("Fractal instance capacity exceeded");
    let disposed = false;
    const owned = () => {
      if (disposed) throw new Error("Fractal owner disposed");
    };
    const scalar = (field, index = 0) => {
      owned();
      return invoke("moxi_inspect", handle, field, index);
    };
    const text = (field) => {
      owned();
      check(invoke("moxi_text", handle, field));
      return textOutput;
    };
    const owner = Object.freeze({
      handle,
      preset(id) {
        owned();
        if (!Number.isInteger(id) || id < 0 || id >= presets.length) throw new RangeError("invalid preset");
        check(invoke("moxi_preset", handle, id));
      },
      fixture(id) {
        owned();
        if (!Number.isInteger(id) || id < 0 || id > 2) throw new RangeError("invalid fixture");
        check(invoke("moxi_fixture", handle, id));
      },
      setDepth(value) {
        owned();
        if (typeof value === "number" && (!Number.isSafeInteger(value) || value < 0))
          throw new RangeError("depth must be nonnegative safe integer or decimal string");
        if (typeof value !== "string" && typeof value !== "number" && typeof value !== "bigint")
          throw new TypeError("invalid depth type");
        const spelling = String(value);
        if (!/^\d+$/.test(spelling)) throw new RangeError("depth must be a nonnegative decimal integer");
        textInput = new TextEncoder().encode(spelling);
        try {
          check(invoke("moxi_depth", handle));
        } finally {
          textInput = new Uint8Array();
        }
      },
      setFlags({ guides = !!scalar(Field.guides), randomColors = !!scalar(Field.colors) } = {}) {
        owned();
        check(invoke("moxi_flags", handle, Number(!!guides), Number(!!randomColors)));
      },
      reset() {
        owned();
        check(invoke("moxi_reset", handle));
      },
      advance(budget = 384) {
        owned();
        if (!Number.isInteger(budget) || budget < 1 || budget > 2147483647)
          throw new RangeError("invalid work budget");
        const value = invoke("moxi_advance", handle, budget);
        if (value < 0) check(value);
        return !!value;
      },
      complete() {
        return !!scalar(Field.complete);
      },
      event(kind, { x = 0, y = 0, deltaSeconds = 0 } = {}) {
        owned();
        if (
          !Object.values(EventKind).includes(kind) ||
          ![x, y, deltaSeconds].every(Number.isFinite) ||
          deltaSeconds < 0 ||
          !Number.isFinite(Math.fround(x)) ||
          !Number.isFinite(Math.fround(y))
        )
          throw new RangeError("invalid pointer event");
        const value = invoke("moxi_event", handle, kind, x, y, deltaSeconds);
        if (value < 0) check(value);
        return !!value;
      },
      status() {
        return {
          complete: !!scalar(Field.complete),
          emitted: text(1),
          coordinateOverflow: !!scalar(Field.overflow),
        };
      },
      inspect() {
        return {
          preset: scalar(Field.preset),
          depth: text(0),
          ...this.status(),
          branchFactor: scalar(Field.branches),
          guides: !!scalar(Field.guides),
          randomColors: !!scalar(Field.colors),
          dragging: !!scalar(Field.dragging),
          endpointDocked: [!!scalar(Field.startDocked), !!scalar(Field.endDocked)],
          endpointRevealed: [!!scalar(Field.startRevealed), !!scalar(Field.endRevealed)],
          points: Array.from({ length: scalar(Field.pointCount) }, (_, i) => ({
            x: scalar(Field.pointX, i),
            y: scalar(Field.pointY, i),
          })),
          baseline: Array.from({ length: 2 }, (_, i) => ({
            x: scalar(Field.baselineX, i),
            y: scalar(Field.baselineY, i),
          })),
          preview: Array.from({ length: scalar(Field.previewCount) }, (_, i) => ({
            x0: scalar(Field.previewX0, i),
            y0: scalar(Field.previewY0, i),
            x1: scalar(Field.previewX1, i),
            y1: scalar(Field.previewY1, i),
          })),
        };
      },
      raster() {
        owned();
        const width = scalar(Field.width),
          height = scalar(Field.height),
          pointer = Number(invoke("moxi_pixels", handle));
        memoryRange(pointer, width * height * 4);
        return {
          width,
          height,
          pointer,
          pixels: new Uint8ClampedArray(instance.exports.memory.buffer, pointer, width * height * 4),
        };
      },
      dispose() {
        if (disposed) return false;
        if (state === RuntimeState.ready) check(invoke("moxi_destroy", handle));
        disposed = true;
        return true;
      },
    });
    try {
      owner.preset(preset);
      owner.setDepth(depth);
    } catch (error) {
      owner.dispose();
      throw error;
    }
    return owner;
  }
  return Object.freeze({
    create,
    presets,
    stats() {
      return { state, failure, startupMs, ...allocator.stats(), instances: handles.size };
    },
    dispose() {
      if (state === RuntimeState.disposed) return false;
      if (state === RuntimeState.ready)
        for (const handle of handles.keys()) check(invoke("moxi_destroy", handle));
      handles.clear();
      instance = null;
      allocator.reset();
      state = RuntimeState.disposed;
      return true;
    },
  });
}
