/** Bounded allocator shared by experimental single-threaded memory64 hosts. */
export function supportsMemory64() {
  return (
    typeof WebAssembly === "object" &&
    WebAssembly.validate(new Uint8Array([0, 97, 115, 109, 1, 0, 0, 0, 5, 3, 1, 4, 1]))
  );
}

export function createMemory64Allocator({ memory, heapLimit }) {
  let top,
    peak = 0,
    allocations = 0,
    liveBytes = 0;
  const live = new Map(),
    freeBlocks = [];
  function initialize(heapBase) {
    top = Number(heapBase);
    if (!Number.isSafeInteger(top) || top < 0 || top > heapLimit || memory().buffer.byteLength > heapLimit)
      throw new RangeError("initial memory exceeds heap capacity");
  }
  function range(pointer, size) {
    const p = Number(pointer),
      n = Number(size);
    if (
      !Number.isSafeInteger(p) ||
      !Number.isSafeInteger(n) ||
      p < 0 ||
      n < 0 ||
      p + n > memory().buffer.byteLength
    )
      throw new RangeError("invalid memory range");
    return new Uint8Array(memory().buffer, p, n);
  }
  function alloc(alignment, size) {
    const a = Number(alignment),
      n = Math.max(1, Number(size));
    if (!Number.isSafeInteger(n) || !Number.isSafeInteger(a) || a < 1 || a > 65536 || a & (a - 1))
      throw new RangeError("invalid allocation");
    let ptr;
    const index = freeBlocks.findIndex((b) => Math.ceil(b.ptr / a) * a + n <= b.ptr + b.size);
    if (index >= 0) {
      const block = freeBlocks.splice(index, 1)[0];
      ptr = Math.ceil(block.ptr / a) * a;
      if (ptr > block.ptr) freeBlocks.push({ ptr: block.ptr, size: ptr - block.ptr });
      if (ptr + n < block.ptr + block.size)
        freeBlocks.push({ ptr: ptr + n, size: block.ptr + block.size - ptr - n });
    } else {
      ptr = Math.ceil(top / a) * a;
      if (ptr + n > heapLimit) throw new RangeError("Moxi heap capacity exceeded");
      if (ptr > top) freeBlocks.push({ ptr: top, size: ptr - top });
      top = ptr + n;
      const wasmMemory = memory();
      if (top > wasmMemory.buffer.byteLength)
        wasmMemory.grow(BigInt(Math.ceil((top - wasmMemory.buffer.byteLength) / 65536)));
      peak = Math.max(peak, top);
    }
    live.set(ptr, n);
    liveBytes += n;
    allocations++;
    return BigInt(ptr);
  }
  function free(pointer) {
    const ptr = Number(pointer);
    if (ptr === 0) return;
    if (!live.has(ptr)) throw new Error("invalid or double free");
    const size = live.get(ptr);
    live.delete(ptr);
    liveBytes -= size;
    freeBlocks.push({ ptr, size });
    freeBlocks.sort((a, b) => a.ptr - b.ptr);
    for (let i = freeBlocks.length - 2; i >= 0; i--) {
      const a = freeBlocks[i],
        b = freeBlocks[i + 1];
      if (a.ptr + a.size === b.ptr) {
        a.size += b.size;
        freeBlocks.splice(i + 1, 1);
      }
    }
    const last = freeBlocks.at(-1);
    if (last && last.ptr + last.size === top) {
      top = last.ptr;
      freeBlocks.pop();
    }
  }
  return Object.freeze({
    initialize,
    range,
    alloc,
    free,
    stats: () => ({
      allocations,
      liveAllocations: live.size,
      liveBytes,
      heapTop: top,
      heapHighWater: peak,
      memoryBytes: memory()?.buffer.byteLength ?? 0,
    }),
    reset() {
      live.clear();
      freeBlocks.length = 0;
      liveBytes = 0;
    },
  });
}
