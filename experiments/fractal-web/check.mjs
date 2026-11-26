import assert from 'node:assert/strict';
import {readFile, writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {instantiateFractal, EventKind, RuntimeState} from './runtime.mjs';

const read = name => readFile(new URL(`./dist/${name}`, import.meta.url));
const bytes = await read('fractal.wasm');
const runtime = await instantiateFractal(bytes);
const app = runtime.create();
const cases = [];
for (let index = 0; index < 3; index++) {
  app.fixture(index);
  let batches = 0;
  const start = performance.now();
  while (!app.complete()) { app.advance(1000000); assert.ok(++batches < 100); }
  const elapsedMs = performance.now() - start;
  const {pixels, width, height} = app.raster();
  assert.equal(app.status().emitted, ['4096', '65536', '1000000'][index]);
  const native = Uint8Array.from(JSON.parse(await read(`native-${index}.pixels.json`)));
  assert.equal(native.length, width * height * 4);
  const output = new Uint8Array(pixels.buffer, pixels.byteOffset, pixels.byteLength);
  let differences = 0, maxDifference = 0;
  for (let i = 0; i < output.length; i++) if (output[i] !== native[i]) { differences++; maxDifference = Math.max(maxDifference, Math.abs(output[i] - native[i])); }
  cases.push({index, ...app.status(), width, height, batches, elapsedMs, differences, maxDifference,
    wasmHash: createHash('sha256').update(output).digest('hex'), nativeHash: createHash('sha256').update(native).digest('hex')});
  assert.equal(differences, 0, `fixture ${index} differs from native`);
}
app.preset(0);
let p = app.inspect().points[2];
assert.equal(app.event(EventKind.move, p), false);
assert.equal(app.event(EventKind.down, p), true);
assert.equal(app.inspect().dragging, true);
const moved = {x: p.x + 20, y: p.y + 25};
assert.equal(app.event(EventKind.move, moved), true);
assert.deepEqual(app.inspect().points[2], moved);
assert.equal(app.event(EventKind.move, moved), false);
assert.equal(app.event(EventKind.up, moved), true);
assert.equal(app.inspect().dragging, false);
const hugeDepth = '1000000000000000000000000000000000000000000000';
app.setDepth(hugeDepth);
assert.equal(app.inspect().depth, hugeDepth);
let hugeBatches = 0;
while (!app.complete()) { app.advance(1000000); assert.ok(++hugeBatches < 100); }
const largeDepth = app.status();
for (const preset of runtime.presets) {
  app.preset(preset.id); app.setDepth('2');
  let count = 0;
  while (!app.complete()) { app.advance(100000); assert.ok(++count < 100); }
  assert.equal(app.inspect().preset, preset.id);
  assert.equal(app.status().coordinateOverflow, false);
}
assert.throws(() => app.setDepth('-1'), /depth/);
assert.throws(() => app.setDepth('1.5'), /depth/);
assert.throws(() => app.setDepth(Number.MAX_SAFE_INTEGER + 1), /depth/);
assert.throws(() => app.setDepth(''), /depth/);
assert.throws(() => app.preset(27), /preset/);
assert.throws(() => app.fixture(3), /fixture/);
assert.throws(() => app.advance(0), /budget/);
assert.throws(() => app.event(99), /event/);
app.dispose();
assert.throws(() => app.advance(), /disposed/);
assert.equal(runtime.stats().liveBytes, 0);
assert.equal(runtime.stats().instances, 0);
const lifecycle = runtime.stats();
for (let cycle = 0; cycle < 100; cycle++) {
  const current = runtime.create({preset: cycle % runtime.presets.length, depth: '3'});
  current.advance(384);
  current.dispose();
  assert.equal(runtime.stats().liveAllocations, 0, `leak after cycle ${cycle}`);
}
const owners = Array.from({length: 8}, () => runtime.create());
assert.throws(() => runtime.create(), /capacity/);
owners.forEach(owner => owner.dispose());
assert.equal(runtime.stats().liveAllocations, 0);
runtime.dispose();
assert.equal(runtime.stats().state, RuntimeState.disposed);
assert.equal(runtime.stats().memoryBytes, 0);
await assert.rejects(instantiateFractal(bytes, {memory64: false}), /memory64/);
const limited = await instantiateFractal(bytes, {heapLimit: 131072});
assert.throws(() => limited.create(), /capacity/);
assert.equal(limited.stats().state, RuntimeState.failed);
assert.throws(() => limited.create(), /runtime failed/);
limited.dispose();
const unknown = Buffer.from(bytes), before = Buffer.from('KGEN_CompilerRT_GetStackTrace'), after = Buffer.from('x'.repeat(before.length));
for (let offset = unknown.indexOf(before); offset >= 0; offset = unknown.indexOf(before, offset + after.length)) after.copy(unknown, offset);
await assert.rejects(instantiateFractal(unknown), /Unapproved runtime import/);
const result = {node: process.version, floatingPointPolicy: 'native --fp-mode contract=off; scalar WebAssembly has no FMA', cases, presets: runtime.presets.length, pointerDrag: true, duplicateMove: true, arbitraryDepth: {depth: hugeDepth, ...largeDepth}, invalidInput: true, lifecycleCycles: 100, capacity: true, oomPoisoning: true, lifecycle};
await writeFile(new URL('./dist/check.json', import.meta.url), JSON.stringify(result, null, 2) + '\n');
console.log(JSON.stringify(result, null, 2));
