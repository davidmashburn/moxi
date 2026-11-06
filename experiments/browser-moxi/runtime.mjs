/** Explicit single-threaded memory64 runtime for the experimental FDG subset. */
export const Limits = Object.freeze({memory: 64 * 1024 * 1024, instances: 8, nodes: 256, links: 1024, textBytes: 512, dimension: 4096});
export const Status = Object.freeze({ok: 0, invalidHandle: -1, invalidInput: -2, unsupported: -3});
export const EventKind = Object.freeze({down: 1, key: 2, text: 3, up: 5, move: 6, frame: 10, scroll: 11, cancel: 19, action: 20});
export const Control = Object.freeze({pause: 10, restart: 11, fit: 12, labels: 13, neighbors: 14, export: 15, search: 20, find: 21, canvas: 100});
export const NodeField = Object.freeze({x: 0, y: 1, vx: 2, vy: 3, pinned: 4, screenX: 5, screenY: 6});
export const AppField = Object.freeze({selected: 0, zoom: 1, panX: 2, panY: 3, paused: 4, alpha: 5, nodes: 6, links: 7});
export const RuntimeState = Object.freeze({ready: 'ready', failed: 'failed', disposed: 'disposed'});
export const DiagnosticImports = Object.freeze(['KGEN_CompilerRT_GetStackTrace', 'write', 'dup', 'fdopen', 'fflush', 'fclose', 'KGEN_CompilerRT_fprintf']);
const clock = () => performance.now();

export function supportsMemory64() {
  // A module containing a one-page i64-addressed memory, no compiler dependency.
  return typeof WebAssembly === 'object' && WebAssembly.validate(new Uint8Array([0,97,115,109,1,0,0,0,5,3,1,4,1]));
}

export function validateGraph(graph) {
  if (!graph || !Array.isArray(graph.groups) || !Array.isArray(graph.links) || graph.groups.length > Limits.nodes || graph.links.length > Limits.links) throw new RangeError('graph capacity: 256 nodes / 1024 links');
  const groups = Array.from(graph.groups, group => {
    if (!Number.isInteger(group) || group < 0 || group > 2147483647) throw new RangeError('invalid group');
    return group;
  });
  const links = Array.from(graph.links, edge => {
    if (!Array.isArray(edge) || edge.length !== 3) throw new TypeError('edge must be [source, target, weight]');
    const [a, b, weight] = edge;
    if (![a, b].every(i => Number.isInteger(i) && i >= 0 && i < groups.length) || !Number.isFinite(weight) || weight < 0 || weight > 1e6) throw new RangeError('invalid edge');
    return [a, b, weight];
  });
  return {groups, links};
}

export async function instantiateMoxi(bytes, {heapLimit = Limits.memory, memory64 = supportsMemory64()} = {}) {
  if (!memory64) throw new Error('Unsupported runtime: WebAssembly memory64 is required; no JavaScript graph fallback');
  if (!Number.isSafeInteger(heapLimit) || heapLimit < 65536 || heapLimit > Limits.memory) throw new RangeError('invalid heap limit');
  const started = clock();
  let instance, top, peak = 0, allocations = 0, liveBytes = 0, state = RuntimeState.ready, failure = null;
  let nextHandle = 1n, graphInput = null, textInput = new Uint8Array(), transferMs = 0;
  const handles = new Map(), live = new Map(), freeBlocks = [], frames = new Map();
  const decoder = new TextDecoder('utf-8', {fatal: true});
  function memoryRange(pointer, size) {
    const p = Number(pointer), n = Number(size);
    if (!Number.isSafeInteger(p) || !Number.isSafeInteger(n) || p < 0 || n < 0 || p + n > instance.exports.memory.buffer.byteLength) throw new RangeError('invalid memory range');
    return new Uint8Array(instance.exports.memory.buffer, p, n);
  }
  function readText(pointer, size) { return decoder.decode(memoryRange(pointer, size)); }
  function alloc(alignment, size) {
    const a = Number(alignment), n = Math.max(1, Number(size));
    if (!Number.isSafeInteger(n) || !Number.isSafeInteger(a) || a < 1 || a > 65536 || (a & (a - 1))) throw new RangeError('invalid allocation');
    let ptr;
    const index = freeBlocks.findIndex(b => Math.ceil(b.ptr / a) * a + n <= b.ptr + b.size);
    if (index >= 0) {
      const block = freeBlocks.splice(index, 1)[0];
      ptr = Math.ceil(block.ptr / a) * a;
      if (ptr > block.ptr) freeBlocks.push({ptr: block.ptr, size: ptr - block.ptr});
      if (ptr + n < block.ptr + block.size) freeBlocks.push({ptr: ptr + n, size: block.ptr + block.size - ptr - n});
    } else {
      ptr = Math.ceil(top / a) * a;
      if (ptr + n > heapLimit) throw new RangeError('Moxi heap capacity exceeded');
      if (ptr > top) freeBlocks.push({ptr: top, size: ptr - top});
      top = ptr + n;
      const memory = instance.exports.memory;
      if (top > memory.buffer.byteLength) memory.grow(BigInt(Math.ceil((top - memory.buffer.byteLength) / 65536)));
      peak = Math.max(peak, top);
    }
    live.set(ptr, n); liveBytes += n; allocations++;
    return BigInt(ptr);
  }
  function free(pointer) {
    const ptr = Number(pointer);
    if (ptr === 0) return;
    if (!live.has(ptr)) throw new Error('invalid or double free');
    const size = live.get(ptr); live.delete(ptr); liveBytes -= size;
    freeBlocks.push({ptr, size}); freeBlocks.sort((a, b) => a.ptr - b.ptr);
    for (let i = freeBlocks.length - 2; i >= 0; i--) {
      const a = freeBlocks[i], b = freeBlocks[i + 1];
      if (a.ptr + a.size === b.ptr) { a.size += b.size; freeBlocks.splice(i + 1, 1); }
    }
    const last = freeBlocks.at(-1);
    if (last && last.ptr + last.size === top) { top = last.ptr; freeBlocks.pop(); }
  }
  const fmax = (a,b) => Number.isNaN(a) ? b : Number.isNaN(b) ? a : Math.max(a,b);
  const fmin = (a,b) => Number.isNaN(a) ? b : Number.isNaN(b) ? a : Math.min(a,b);
  const env = {
    KGEN_CompilerRT_AlignedAlloc: alloc, KGEN_CompilerRT_AlignedFree: free,
    sin: Math.sin, cos: Math.cos, fmax, fmin, fmaxf: fmax, fminf: fmin,
    // wasm64 C ABI lowers i128 return to a result pointer, then low/high limbs.
    __multi3: (out, al, ah, bl, bh) => {
      const a = (BigInt.asUintN(64, ah) << 64n) | BigInt.asUintN(64, al);
      const b = (BigInt.asUintN(64, bh) << 64n) | BigInt.asUintN(64, bl);
      const result = BigInt.asUintN(128, a * b);
      const range = memoryRange(out, 16);
      const view = new DataView(range.buffer, range.byteOffset, range.byteLength);
      view.setBigUint64(0, BigInt.asUintN(64, result), true); view.setBigUint64(8, result >> 64n, true);
    },
    moxi_can_create: () => handles.size < Limits.instances && nextHandle < 2n ** 63n ? 1 : 0,
    moxi_register: address => {
      if (handles.size >= Limits.instances || nextHandle >= 2n ** 63n) throw new Error('handle capacity');
      const handle = nextHandle++; handles.set(handle, address); return handle;
    },
    moxi_resolve: handle => handles.get(handle) ?? 0n,
    moxi_forget: handle => { handles.delete(handle); frames.delete(handle); },
    moxi_graph_size: field => field === 0 ? graphInput.groups.length : graphInput.links.length,
    moxi_graph_group: i => graphInput.groups[i],
    moxi_graph_edge: (i, field) => graphInput.links[i][field],
    moxi_text_size: () => textInput.length,
    moxi_text_byte: i => textInput[i],
    moxi_svg: (handle, ptr, length) => {
      const start = clock(); frames.set(handle, {svg: readText(ptr, length), semantics: []}); transferMs += clock() - start;
    },
    moxi_semantic: (handle, id, parent_id, role, lp, ln, vp, vn, x, y, width, height, enabled, focused, selected, actions) => {
      const start = clock();
      frames.get(handle).semantics.push({id, parent_id, role, label: readText(lp, ln), value: readText(vp, vn), bounds: {x,y,width,height}, enabled: !!enabled, focused: !!focused, selected: !!selected, actions});
      transferMs += clock() - start;
    },
  };
  for (const name of DiagnosticImports) env[name] = () => { throw new Error(`Unsupported Mojo diagnostic path: ${name}; module must be discarded`); };
  const module = await WebAssembly.compile(bytes);
  const imports = WebAssembly.Module.imports(module);
  for (const item of imports) if (item.module !== 'env' || item.kind !== 'function' || !Object.hasOwn(env, item.name)) throw new Error(`Unapproved runtime import: ${item.module}.${item.name}`);
  instance = await WebAssembly.instantiate(module, {env});
  top = Number(instance.exports.__heap_base.value);
  if (top > heapLimit || instance.exports.memory.buffer.byteLength > heapLimit) throw new RangeError('initial memory exceeds heap capacity');
  const startupMs = clock() - started;
  function invoke(name, ...args) {
    if (state !== RuntimeState.ready) throw new Error(`Moxi runtime ${state}: ${failure ?? ''}`);
    if (!Object.hasOwn(instance.exports, name) || !name.startsWith('moxi_')) throw new TypeError('unknown ABI operation');
    try { return instance.exports[name](...args); }
    catch (error) {
      // Unwinding a foreign JS exception cannot run Mojo destructors. Never reuse
      // any object after a trap; discard the whole memory instance on dispose.
      state = RuntimeState.failed; failure = String(error); handles.clear(); frames.clear(); throw error;
    }
  }
  function check(status) { if (status !== Status.ok) throw new RangeError(`Moxi operation rejected: ${status}`); }
  function create({width = 1000, height = 760, graph = null} = {}) {
    graphInput = graph === null ? null : validateGraph(graph);
    let handle;
    try { handle = invoke('moxi_create', width, height, graphInput === null ? 1 : 0); }
    finally { graphInput = null; }
    if (handle === 0n) throw new RangeError('Moxi creation rejected: dimensions, graph, or instance capacity');
    let disposed = false;
    function owned() { if (disposed) throw new Error('Moxi owner disposed'); }
    return Object.freeze({
      handle,
      event(kind, {x = 0, y = 0, value = 0, key = 0, modifiers = 0} = {}) { owned(); check(invoke('moxi_event', handle, kind, x, y, value, key, modifiers)); },
      text(text) {
        owned(); textInput = new TextEncoder().encode(text);
        try { this.event(EventKind.text); } finally { textInput = new Uint8Array(); }
      },
      resize(width, height) { owned(); check(invoke('moxi_resize', handle, width, height)); },
      inspect(index, field) { owned(); return invoke('moxi_inspect', handle, index, field); },
      render() {
        owned(); const start = clock(), transferBefore = transferMs;
        check(invoke('moxi_render', handle));
        return {...frames.get(handle), sceneMs: clock() - start - (transferMs - transferBefore), transferMs: transferMs - transferBefore};
      },
      dispose() { if (disposed) return false; check(invoke('moxi_destroy', handle)); disposed = true; return true; },
    });
  }
  return Object.freeze({create, invoke,
    stats: () => ({state, failure, allocations, liveAllocations: live.size, liveBytes, heapHighWater: peak, memoryBytes: instance?.exports.memory.buffer.byteLength ?? 0, instances: handles.size, wasmBytes: bytes.byteLength, startupMs, imports: imports.map(i => i.name)}),
    dispose() {
      if (state === RuntimeState.ready) for (const handle of [...handles.keys()]) check(invoke('moxi_destroy', handle));
      instance = null; handles.clear(); frames.clear(); live.clear(); freeBlocks.length = 0; liveBytes = 0; state = RuntimeState.disposed;
    },
  });
}
