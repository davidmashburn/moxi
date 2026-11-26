import {instantiateFractal} from './runtime.mjs';
import {MoxiRasterPresenter} from '../../native/hosts/moxi_web_host.mjs';
import {getDrawFractalIterator} from './dist/benchmark/original/drawFractal.js';
import {Generator} from './dist/benchmark/original/generator.js';
import {cases, provenance} from './dist/benchmark/cases.mjs';

const DisplayPath = Object.freeze({copy: 'cached-image-data-copy', direct: 'moxi-direct-view'});
const BufferMode = Object.freeze({mutated: 'same-buffer-mutated', alternating: 'alternating-buffers'});
const DEFAULTS = Object.freeze({warmups: 2, trials: 7, presentationWarmups: 5, presentationTrials: 31});
const WIDTH = 920;
const HEIGHT = 620;
const FULL_BUDGET = 1_000_000;

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function quantile(values, percentile) {
  if (!values.length) return null;
  const ordered = [...values].sort((a, b) => a - b);
  const index = (ordered.length - 1) * percentile;
  const low = Math.floor(index), high = Math.ceil(index);
  return ordered[low] + (ordered[high] - ordered[low]) * (index - low);
}

function summary(values) {
  return {count: values.length, medianMs: quantile(values, .5), p95Ms: quantile(values, .95),
    p99Ms: quantile(values, .99), minMs: Math.min(...values), maxMs: Math.max(...values)};
}

function surface() {
  const canvas = document.createElement('canvas');
  canvas.width = WIDTH;
  canvas.height = HEIGHT;
  const ctx = canvas.getContext('2d');
  assert(ctx, 'Canvas2D is unavailable');
  return {canvas, ctx};
}

function painted(pixels) {
  for (let i = 3; i < pixels.length; i += 4) if (pixels[i] !== 0) return true;
  return false;
}

function checkRaster(raster) {
  assert(raster.width === WIDTH && raster.height === HEIGHT, 'Unexpected Wasm raster dimensions');
  assert(raster.pixels instanceof Uint8ClampedArray, 'Wasm raster must expose a clamped memory view');
  assert(raster.pixels.length === WIDTH * HEIGHT * 4, 'Unexpected Wasm raster length');
  assert(painted(raster.pixels), 'Wasm raster is blank');
}

function checkLeaves(owner, expected) {
  const status = owner.status();
  assert(String(status.emitted) === String(expected), `Wasm leaf count: ${status.emitted} != ${expected}`);
  assert(!status.coordinateOverflow, 'Wasm reported coordinate overflow');
  return status;
}

// The native fixture benchmark also excludes reset/geometry setup from its timer.
function complete(owner, budget, recordChunks = false) {
  let count = 0;
  const chunkTimes = [];
  const start = performance.now();
  while (!owner.complete()) {
    if (recordChunks) {
      const chunkStart = performance.now();
      owner.advance(budget);
      chunkTimes.push(performance.now() - chunkStart);
    } else {
      owner.advance(budget);
    }
    count++;
    if ((count & 1023) === 0 && performance.now() - start > 60_000) {
      throw new Error(`Wasm rendering exceeded 60 seconds (budget ${budget})`);
    }
  }
  return {computeMs: performance.now() - start, chunkCount: count,
    ...(recordChunks ? {chunks: summary(chunkTimes)} : {})};
}

function originalTrial(fixture) {
  const {canvas, ctx} = surface();
  const generator = new Generator(fixture.lines);
  let leaves = 0;
  const started = performance.now();
  for (const _ of getDrawFractalIterator(ctx, generator, fixture.base, fixture.depth)) leaves++;
  const submitted = performance.now();
  const image = ctx.getImageData(0, 0, WIDTH, HEIGHT);
  const readable = performance.now();
  assert(leaves === fixture.expectedLeaves, `Original JS leaf count: ${leaves} != ${fixture.expectedLeaves}`);
  assert(painted(image.data), 'Original JS canvas is blank');
  canvas.width = 0;
  return {leaves, submitMs: submitted - started, syncReadbackMs: readable - submitted,
    throughReadbackMs: readable - started};
}

function wasmTrial(owner, fixture, fixtureIndex) {
  owner.fixture(fixtureIndex);
  const {canvas, ctx} = surface();
  const presenter = new MoxiRasterPresenter(ctx);
  const measured = complete(owner, FULL_BUDGET);
  const rasterStarted = performance.now();
  const raster = owner.raster();
  const rasterAccessMs = performance.now() - rasterStarted;
  // Validation is outside all measured stages.
  checkRaster(raster);
  const status = checkLeaves(owner, fixture.expectedLeaves);
  const submitted = performance.now();
  presenter.present(raster.pixels, raster.width, raster.height);
  const readableStart = performance.now();
  const image = ctx.getImageData(0, 0, WIDTH, HEIGHT);
  const readable = performance.now();
  assert(painted(image.data), 'Wasm presentation is blank');
  canvas.width = 0;
  const presentationSubmitMs = readableStart - submitted;
  const syncReadbackMs = readable - readableStart;
  return {...measured, leaves: String(status.emitted), rasterAccessMs, presentationSubmitMs,
    syncReadbackMs,
    computeAndPresentationSubmitMs: measured.computeMs + rasterAccessMs + presentationSubmitMs,
    computeThroughReadbackMs: measured.computeMs + rasterAccessMs + presentationSubmitMs + syncReadbackMs};
}

function mutateSentinels(pixels, serial) {
  // Opaque sentinels permit exact readback regardless of premultiplication rules.
  const first = [serial % 251, (serial * 17) % 251, (serial * 37) % 251, 255];
  const last = [(serial * 11) % 251, (serial * 43) % 251, (serial * 5) % 251, 255];
  pixels.set(first, 0);
  pixels.set(last, pixels.length - 4);
  return {first, last};
}

function checkSentinel(actual, expected, label) {
  assert(actual.length === 4 && actual.every((byte, i) => byte === expected[i]), `${label}: stale or corrupt pixels`);
}

function checkSamePixels(copyContext, directContext, label) {
  // Compare canvas outputs: premultiplication can round nonopaque source RGB.
  const copied = copyContext.getImageData(0, 0, WIDTH, HEIGHT).data;
  const direct = directContext.getImageData(0, 0, WIDTH, HEIGHT).data;
  for (let i = 0; i < copied.length; i++) {
    assert(copied[i] === direct[i], `${label}: byte ${i} differs (${copied[i]} != ${direct[i]})`);
  }
}

function presentationBenchmark(raster, config) {
  checkRaster(raster);
  const memory = new WebAssembly.Memory({initial: Math.ceil(raster.pixels.byteLength / 65536)});
  const alternate = new Uint8ClampedArray(memory.buffer, 0, raster.pixels.byteLength);
  alternate.set(raster.pixels);
  const sources = [raster.pixels, alternate];
  const results = [];
  for (const bufferMode of Object.values(BufferMode)) {
    const copySurface = surface(), directSurface = surface();
    const cachedImage = new ImageData(WIDTH, HEIGHT);
    const presenter = new MoxiRasterPresenter(directSurface.ctx);
    const paths = new Map([
      [DisplayPath.copy, {ctx: copySurface.ctx, present: pixels => {
        cachedImage.data.set(pixels);
        copySurface.ctx.putImageData(cachedImage, 0, 0);
      }}],
      [DisplayPath.direct, {ctx: directSurface.ctx, present: pixels => presenter.present(pixels, WIDTH, HEIGHT)}],
    ]);
    const trials = [];
    for (let trial = 0; trial < config.presentationWarmups + config.presentationTrials; trial++) {
      const source = sources[bufferMode === BufferMode.alternating ? trial % 2 : 0];
      const expected = mutateSentinels(source, trial + 1);
      // The runtime can return a fresh typed-array wrapper for the same memory.
      const view = new Uint8ClampedArray(source.buffer, source.byteOffset, source.byteLength);
      const order = trial % 2 ? [DisplayPath.direct, DisplayPath.copy] : [DisplayPath.copy, DisplayPath.direct];
      const pair = {trial: trial - config.presentationWarmups, order, samples: {}};
      for (const name of order) {
        const path = paths.get(name);
        const started = performance.now();
        path.present(view);
        const submitted = performance.now();
        const first = path.ctx.getImageData(0, 0, 1, 1).data;
        const synchronized = performance.now();
        checkSentinel(first, expected.first, `${bufferMode}/${name}/first`);
        // Check both ends; only the first readback participates in timing.
        checkSentinel(path.ctx.getImageData(WIDTH - 1, HEIGHT - 1, 1, 1).data,
          expected.last, `${bufferMode}/${name}/last`);
        pair.samples[name] = {submitMs: submitted - started,
          syncReadbackMs: synchronized - submitted, throughSyncMs: synchronized - started};
      }
      if (trial >= config.presentationWarmups) trials.push(pair);
    }
    checkSamePixels(copySurface.ctx, directSurface.ctx, bufferMode);
    results.push({bufferMode, width: WIDTH, height: HEIGHT, warmups: config.presentationWarmups,
      trials, summary: Object.fromEntries([...paths.keys()].map(name => [name, {
        submit: summary(trials.map(t => t.samples[name].submitMs)),
        syncReadback: summary(trials.map(t => t.samples[name].syncReadbackMs)),
        throughSync: summary(trials.map(t => t.samples[name].throughSyncMs)),
      }]))});
    copySurface.canvas.width = directSurface.canvas.width = 0;
  }
  return results;
}

function chunkBenchmark(owner, config) {
  const fixtureIndex = 2;
  const fixture = cases[fixtureIndex];
  const budgets = [64, 2048];
  const trials = [];
  for (let trial = 0; trial < config.warmups + config.trials; trial++) {
    const order = trial % 2 ? [...budgets].reverse() : budgets;
    for (const budget of order) {
      owner.fixture(fixtureIndex);
      const result = complete(owner, budget);
      checkLeaves(owner, fixture.expectedLeaves);
      if (trial >= config.warmups) trials.push({trial: trial - config.warmups, budget, ...result});
    }
  }
  return {curve: fixture.name, expectedLeaves: fixture.expectedLeaves, warmups: config.warmups,
    budgets, trials, summary: Object.fromEntries(budgets.map(budget => {
      const samples = trials.filter(t => t.budget === budget);
      // Profile call duration separately so clock reads do not bias throughput
      // against the smaller chunk size.
      owner.fixture(fixtureIndex);
      const profile = complete(owner, budget, true);
      return [budget, {compute: summary(samples.map(t => t.computeMs)),
        maximumChunkMs: profile.chunks.maxMs, chunkProfile: profile.chunks,
        note: 'Per-call advance timing includes JS/Wasm boundary and two clock reads; excludes event scheduling and input dispatch.'}];
    }))};
}

async function compareScalarMath(owner, config) {
  const response = await fetch('./dist/fractal.host-math.wasm');
  assert(response.ok, 'Build the comparison module with build.sh --host-math');
  const baselineRuntime = await instantiateFractal(await response.arrayBuffer());
  const baseline = baselineRuntime.create();
  const hostMathMs = [], wasmMathMs = [];
  try {
    for (let i = 0; i < config.warmups + config.trials; i++) {
      const order = i % 2 ? [owner, baseline] : [baseline, owner];
      for (const app of order) {
        app.fixture(2);
        const {computeMs} = complete(app, FULL_BUDGET);
        checkLeaves(app, cases[2].expectedLeaves);
        if (i >= config.warmups) (app === owner ? wasmMathMs : hostMathMs).push(computeMs);
      }
      const a = baseline.raster().pixels, b = owner.raster().pixels;
      assert(a.length === b.length && a.every((byte, index) => byte === b[index]),
             'Changing min/max lowering altered the Peano raster');
    }
    return {hostMathMs, wasmMathMs, host: summary(hostMathMs), wasm: summary(wasmMathMs)};
  } finally {
    baselineRuntime.dispose();
  }
}

export async function runBenchmark(options = {}, report = () => {}) {
  const config = {...DEFAULTS, ...options};
  for (const [key, value] of Object.entries(config)) {
    assert(Number.isSafeInteger(value) && value >= (key.toLowerCase().includes('warmup') ? 0 : 1), `Invalid ${key}`);
  }
  assert(cases.length === 3, 'Expected all canonical native benchmark fixtures');
  const response = await fetch('./dist/fractal.wasm');
  assert(response.ok, `Wasm fetch failed: HTTP ${response.status}`);
  const bytes = await response.arrayBuffer();
  const initStarted = performance.now();
  const runtime = await instantiateFractal(bytes);
  const instantiateMs = performance.now() - initStarted;
  const owner = runtime.create();
  const result = {schemaVersion: 1, capturedAt: new Date().toISOString(), config,
    browser: {userAgent: navigator.userAgent, hardwareConcurrency: navigator.hardwareConcurrency,
      devicePixelRatio: devicePixelRatio, crossOriginIsolated: crossOriginIsolated},
    endpoints: {
      native: 'CPU fractal traversal plus colored raster; setup/reset excluded; native timings captured during preparation.',
      original: 'Pinned JS traversal plus Canvas2D strokes; submit and full RGBA readback endpoints.',
      wasm: 'advance(1_000_000) loop through complete(); setup/reset excluded; raster view access and Canvas2D presentation measured separately.',
      presentation: 'Cached ImageData.data.set+putImageData vs MoxiRasterPresenter; same source bytes, fresh typed views, alternating path order, 1px synchronization on both paths.',
      visibility: 'Canvas submission and synchronous readback only; screen display, compositing and input latency are not measured.',
    }, provenance, instantiateMs, curves: [], chunks: null, presentation: null};
  try {
    for (let index = 0; index < cases.length; index++) {
      const fixture = cases[index];
      report(`Rendering ${fixture.name}`);
      const js = [], wasm = [];
      for (let trial = 0; trial < config.warmups + config.trials; trial++) {
        let a, b;
        if (trial % 2) {
          b = wasmTrial(owner, fixture, index);
          a = originalTrial(fixture);
        } else {
          a = originalTrial(fixture);
          b = wasmTrial(owner, fixture, index);
        }
        if (trial >= config.warmups) {
          js.push(a);
          wasm.push(b);
        }
      }
      result.curves.push({name: fixture.name, expectedLeaves: fixture.expectedLeaves, depth: fixture.depth,
        native: {warmups: 2, trials: fixture.nativeTrials.slice(2)}, js, wasm,
        summary: {nativeCompute: summary(fixture.nativeTrials.slice(2).map(t => t.ms)),
          jsSubmit: summary(js.map(t => t.submitMs)), jsThroughReadback: summary(js.map(t => t.throughReadbackMs)),
          wasmCompute: summary(wasm.map(t => t.computeMs)),
          wasmPresentationSubmit: summary(wasm.map(t => t.presentationSubmitMs)),
          wasmComputeAndPresentationSubmit: summary(wasm.map(t => t.computeAndPresentationSubmitMs)),
          wasmComputeThroughReadback: summary(wasm.map(t => t.computeThroughReadbackMs))}});
    }
    report('Comparing host and Wasm scalar min/max');
    result.scalarMath = await compareScalarMath(owner, config);
    report('Profiling 64 and 2048 transform chunks');
    result.chunks = chunkBenchmark(owner, config);
    report('Comparing cached copy and direct memory presentation');
    result.presentation = presentationBenchmark(owner.raster(), config);
    report('Complete');
    return result;
  } finally {
    owner.dispose?.();
    runtime.dispose?.();
  }
}
