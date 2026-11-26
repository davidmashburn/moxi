#!/usr/bin/env node
// Optional automation dependency follows experiments/browser-moxi's convention.
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {execFileSync} from 'node:child_process';
import {createServer} from 'node:http';
import {mkdir, readFile, stat, writeFile} from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {parseArgs} from 'node:util';

const here = path.dirname(fileURLToPath(import.meta.url));
const {values} = parseArgs({options: {
  url: {type: 'string'}, output: {type: 'string'}, root: {type: 'string'},
  warmups: {type: 'string'}, trials: {type: 'string'},
  'presentation-warmups': {type: 'string'}, 'presentation-trials': {type: 'string'},
}});
const root = path.resolve(values.root || path.join(here, '../..'));
const output = path.resolve(values.output || path.join(here, 'dist/benchmark/browser-result.json'));
const mime = {'.html': 'text/html', '.mjs': 'text/javascript', '.js': 'text/javascript',
  '.wasm': 'application/wasm', '.json': 'application/json'};
let server;
let url = values.url;
if (!url) {
  server = createServer(async (req, res) => {
    try {
      const name = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
      const filename = path.resolve(root, `.${name}`);
      if (filename !== root && !filename.startsWith(root + path.sep)) {
        res.writeHead(403); res.end(); return;
      }
      if (!(await stat(filename)).isFile()) throw new Error('Not a file');
      res.setHeader('Content-Type', mime[path.extname(filename)] || 'application/octet-stream');
      res.setHeader('Cache-Control', 'no-store');
      res.end(await readFile(filename));
    } catch {
      res.writeHead(404); res.end('Not found');
    }
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  url = `http://127.0.0.1:${server.address().port}/experiments/fractal-web/benchmark.html`;
}
const target = new URL(url);
for (const [arg, param] of [['warmups', 'warmups'], ['trials', 'trials'],
  ['presentation-warmups', 'presentationWarmups'], ['presentation-trials', 'presentationTrials']]) {
  if (values[arg] !== undefined) target.searchParams.set(param, values[arg]);
}
let browser;
const errors = [];
function gitInfo(args) {
  try {return execFileSync('git', args, {cwd: root, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe']}).trim();}
  catch {return null;}
}
try {
  const {chromium} = await import(process.env.MOXI_PLAYWRIGHT_MODULE || 'playwright');
  browser = await chromium.launch({headless: true,
    ...(process.env.MOXI_CHROME ? {executablePath: process.env.MOXI_CHROME} : {})});
  const page = await browser.newPage({viewport: {width: 1200, height: 900}, deviceScaleFactor: 1});
  page.on('pageerror', error => errors.push(String(error)));
  page.on('requestfailed', request => errors.push(`${request.url()}: ${request.failure()?.errorText}`));
  await page.goto(target.href, {waitUntil: 'load'});
  await page.waitForFunction(() => window.moxiBenchmark?.done, null, {timeout: 300_000});
  const state = await page.evaluate(() => window.moxiBenchmark);
  assert.equal(state.error, null, state.error);
  assert.deepEqual(errors, []);
  const sources = ['benchmark.mjs', 'benchmark.html', 'benchmark-prepare.py', 'benchmark-run.mjs',
    'runtime.mjs', 'browser.mojo', '../../benchmarks/fractal_fixtures.mojo',
    'dist/fractal.wasm', 'dist/fractal.host-math.wasm', '../shared/memory64.mjs', '../browser-moxi/retarget.py', '../../native/hosts/moxi_web_host.mjs'];
  const hashes = {};
  for (const name of sources) {
    try {hashes[name] = createHash('sha256').update(await readFile(path.resolve(here, name))).digest('hex');}
    catch {hashes[name] = null;}
  }
  const reproduce = ['node', 'experiments/fractal-web/benchmark-run.mjs'];
  for (const name of ['warmups', 'trials', 'presentation-warmups', 'presentation-trials']) {
    if (values[name] !== undefined) reproduce.push(`--${name}`, values[name]);
  }
  const relevantSources = sources.map(name => path.relative(root, path.resolve(here, name)));
  const result = {...state.result, automation: {
    command: reproduce.join(' '), url: target.href, browserVersion: await browser.version(),
    headless: true, viewport: {width: 1200, height: 900, deviceScaleFactor: 1},
    os: {platform: os.platform(), release: os.release(), arch: os.arch(), cpus: os.cpus()[0]?.model},
    sourceRevision: gitInfo(['rev-parse', 'HEAD']),
    sourceStatus: gitInfo(['status', '--porcelain', '--untracked-files=all', '--', ...relevantSources])?.split('\n').filter(Boolean) ?? null,
    sourceSha256: hashes, errors,
  }};
  await mkdir(path.dirname(output), {recursive: true});
  await writeFile(output, JSON.stringify(result, null, 2) + '\n');
  // Compact stdout; retain every measured sample and all provenance in the file.
  console.log(JSON.stringify({output, curves: result.curves.map(c => ({name: c.name,
    nativeComputeMedianMs: c.summary.nativeCompute.medianMs,
    jsSubmitMedianMs: c.summary.jsSubmit.medianMs,
    wasmComputeMedianMs: c.summary.wasmCompute.medianMs,
    wasmComputeAndPresentationSubmitMedianMs: c.summary.wasmComputeAndPresentationSubmit.medianMs})),
    chunks: result.chunks.summary,
    presentation: result.presentation.map(p => ({bufferMode: p.bufferMode, summary: p.summary}))}));
} finally {
  await browser?.close();
  if (server) await new Promise((resolve, reject) => server.close(error => error ? reject(error) : resolve()));
}
