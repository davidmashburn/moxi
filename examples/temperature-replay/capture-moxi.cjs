// Fresh offline Chrome context; writes only this example's new evidence deck.
const {chromium} = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {pathToFileURL} = require('node:url');
const {createHash} = require('node:crypto');
const {execFileSync} = require('node:child_process');
const root = path.resolve(__dirname, '../..');
const built = path.join(root, 'dist/temperature-replay');
const output = path.join(root, 'artifacts/demo-slideshows/v14-moxi-sensor');
const hash = file => createHash('sha256').update(fs.readFileSync(file)).digest('hex');

async function capture() {
  const build = JSON.parse(fs.readFileSync(path.join(built, 'build-manifest.json')));
  for (const [file, digest] of Object.entries(build.sourceHashes)) assert.equal(hash(path.join(root, file)), digest, 'stale build: ' + file);
  const sourceFiles = [...Object.keys(build.sourceHashes), 'examples/temperature-replay/browser-check.js',
    'examples/temperature-replay/native-check.cjs', 'examples/temperature-replay/sensor-check.cjs',
    'examples/temperature-replay/capture-moxi.cjs'];
  execFileSync('git', ['diff', '--exit-code', 'HEAD', '--', ...sourceFiles], {cwd: root});
  for (const file of sourceFiles) execFileSync('git', ['ls-files', '--error-unmatch', file], {cwd: root});
  const revision = execFileSync('git', ['rev-parse', 'HEAD'], {cwd: root, encoding: 'utf8'}).trim();
  assert.equal(build.revision, revision, 'rebuild after the source commit before capturing');
  const browser = await chromium.launch({channel: 'chrome'});
  try {
    const context = await browser.newContext({viewport: {width: 1100, height: 1360}, deviceScaleFactor: 1, offline: true});
    const page = await context.newPage();
    const errors = [], remote = [], failed = [];
    page.on('pageerror', e => errors.push(e.message));
    page.on('request', request => { if (/^https?:/.test(request.url())) remote.push(request.url()); });
    page.on('requestfailed', request => failed.push({url: new URL(request.url()).pathname.split('/').at(-1), error: request.failure()?.errorText}));
    await page.goto(pathToFileURL(path.join(built, 'index.html')).href);
    await page.addScriptTag({path: path.join(__dirname, 'browser-check.js')});
    const verification = await page.evaluate(() => checkMoxiReplay());
    const slides = [];
    fs.mkdirSync(output, {recursive: true});
    async function frame(phase, caption, action, expected, fullPage = true) {
      await page.getByText(expected, {exact: true}).waitFor();
      const image = `${slides.length + 1}-${phase}.png`;
      const buffer = await page.screenshot({path: path.join(output, image), fullPage});
      const dimensions = [buffer.readUInt32BE(16), buffer.readUInt32BE(20)];
      slides.push({phase, caption, action, expected, image, dimensions, capture_kind: 'browser'});
    }
    await frame('initial', 'Original forecast through real Moxi plotting', 'Open the offline built consumer.',
      'Selected 10–40 s · Route 2–8 m · Origin 21.18 °C');
    await page.locator('#cursor').focus(); await page.keyboard.press('ArrowRight');
    assert.equal(await page.locator('#cursor').inputValue(), '20');
    assert.equal(await page.locator('#plot').getAttribute('data-frame'), 'temperature:20');
    await page.getByText('Inspect reversal', {exact: true}).click();
    assert.match(await page.locator('#verdict').innerText(), /Outside the band/);
    await frame('interaction', 'Original cooling miss retained', 'Use slider ArrowRight, then Inspect reversal.',
      'Synthetic outcome at 150 s: 21.80 °C · Outside the band');
    await page.locator('#scenario').selectOption('B');
    await page.getByText('Inspect 120 s', {exact: true}).click();
    await frame('result', 'One candidate predictor in a paired comparison', 'Select proxy session B, then Inspect 120 s.',
      'Held-out B: without proxy MAE 0.047 °C · with proxy MAE 0.013 °C · Δ -0.034 °C (lower error with proxy). Persistence MAE 0.216 °C.');
    await page.locator('#scenario').selectOption('D');
    await page.getByText('Inspect 120 s', {exact: true}).click();
    await frame('result', 'Constructed relationship shift exposes harm', 'Select proxy session D, then Inspect 120 s.',
      'Held-out D: without proxy MAE 0.045 °C · with proxy MAE 0.086 °C · Δ 0.041 °C (higher error with proxy). Persistence MAE 0.202 °C.');
    await page.evaluate(() => { window.savedMoxiFrame = MoxiFrames.frames.D[120]; delete MoxiFrames.frames.D[120]; document.getElementById('cursor').dispatchEvent(new Event('input')); });
    await frame('result', 'Missing export is an explicit failure', 'Temporarily remove the selected in-memory Moxi frame and redraw.',
      'Moxi frame unavailable. Rebuild with node examples/temperature-replay/build.cjs.');
    await page.evaluate(() => { MoxiFrames.frames.D[120] = window.savedMoxiFrame; delete window.savedMoxiFrame; document.getElementById('cursor').dispatchEvent(new Event('input')); });
    assert.equal(await page.locator('#plot-error').isVisible(), false);
    await page.getByText('Restart', {exact: true}).click();
    assert.equal(await page.locator('#plot').getAttribute('data-frame'), 'D:10');
    await frame('recovery', 'Restore the export and restart', 'Restore the selected export, redraw, then Restart.', 'Held-out proxy session D');
    await page.setViewportSize({width: 390, height: 844});
    await page.reload();
    assert.equal(await page.locator('#scenario').inputValue(), 'temperature');
    assert.equal(await page.locator('#cursor').inputValue(), '10');
    assert.ok(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth));
    await page.locator('#scenario').selectOption('D');
    await page.getByText('Inspect 120 s', {exact: true}).click();
    assert.match(await page.locator('#scores').innerText(), /higher error with proxy/);
    assert.ok(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth));
    await frame('recovery', 'Narrow viewport after a fresh reload', 'Resize to 390 × 844, reload, select D and Inspect 120 s.',
      'Held-out proxy session D', true);
    verification.checks.push({scenario: 'keyboard and narrow reload', steps: 'ArrowRight on slider; resize, reload, select D',
      expected: 'Frame follows keyboard; default restored on reload; no horizontal overflow; D harm still visible',
      observed: 'temperature:20; temperature:10 after reload; D:120 at 390 × 844; no overflow', outcome: 'pass'});
    verification.transport = 'Offline fresh Chrome context; local file URL; no remote requests';
    verification.browser = 'Chrome ' + browser.version();
    verification.errors = errors; verification.remoteRequests = remote; verification.failedRequests = failed;
    verification.sourceHashes = Object.fromEntries(sourceFiles.map(file => [file, hash(path.join(root, file))]));
    verification.framesSha256 = hash(path.join(built, 'moxi-frames.js'));
    assert.deepEqual(errors, []); assert.deepEqual(remote, []); assert.deepEqual(failed, []);
    const manifest = {version: 1, demo_id: 'v14-moxi-sensor', title: 'Moxi synthetic environmental replay',
      scenario: 'Original temperature playback plus one artificial CO2 proxy; held-out ablation and shifted failure.', revision,
      host: [os.type(), os.release(), os.arch()].join(' '), backend: verification.browser, scale: 1,
      fixture: 'Deterministic artificial sessions T1-T3, A1-A2, B-D; original temperature A/B unchanged',
      reproduce: 'Build, run native-check.cjs, then node examples/temperature-replay/capture-moxi.cjs with Playwright and local Chrome available.',
      captured_at: new Date().toISOString(), slides};
    fs.writeFileSync(path.join(output, 'manifest.json'), JSON.stringify(manifest, null, 2) + '\n');
    fs.writeFileSync(path.join(output, 'verification.json'), JSON.stringify(verification, null, 2) + '\n');
    fs.copyFileSync(path.join(built, 'evaluation.json'), path.join(output, 'evaluation.json'));
    execFileSync('python3', ['-B', '-c', [
      'import sys', 'from pathlib import Path', "sys.path.insert(0, 'scripts')",
      'from demo_slideshows import load_manifest, render', 'out = Path(sys.argv[1])',
      "(out / 'index.html').write_text(render(load_manifest(out / 'manifest.json')))",
    ].join('\n'), output], {cwd: root});
    await page.goto(pathToFileURL(path.join(output, 'index.html')).href);
    await page.keyboard.press('ArrowRight');
    assert.equal(await page.locator('#counter').innerText(), '2 / 7');
    await page.locator('[data-jump="6"]').click();
    assert.equal(await page.locator('#counter').innerText(), '7 / 7');
    assert.ok(await page.locator('img').evaluateAll(images => images.every(i => i.complete && i.naturalWidth > 0)));
    assert.deepEqual(errors, []); assert.deepEqual(remote, []); assert.deepEqual(failed, []);
    verification.checks.push({scenario: 'evidence deck', steps: 'Open generated deck offline; ArrowRight; jump to final slide',
      expected: 'Seven captures load; keyboard and direct navigation work',
      observed: '2 / 7 then 7 / 7; every image loaded; no browser errors or remote requests', outcome: 'pass'});
    fs.writeFileSync(path.join(output, 'verification.json'), JSON.stringify(verification, null, 2) + '\n');
    console.log('Offline Chrome: replay, original reversal, all ablations, failure/recovery, keyboard, narrow reload, zero remote requests; 7 captures and deck verified.');
  } finally { await browser.close(); }
}
capture().catch(error => { console.error(error); process.exitCode = 1; });
