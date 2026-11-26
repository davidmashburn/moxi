// Run from the repository root with Playwright and Chrome available locally.
const {chromium} = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {pathToFileURL} = require('node:url');
const {execFileSync} = require('node:child_process');

async function capture() {
  const demo = 'v14-room-temperature';
  const output = path.resolve('artifacts/demo-slideshows', demo);
  const source = ['model.js', 'replay.js', 'index.html'].map(name => path.join(__dirname, name));
  execFileSync('git', ['diff', '--exit-code', 'HEAD', '--', ...source]);
  const revision = execFileSync('git', ['log', '-1', '--format=%H', '--', ...source]).toString().trim();
  const browser = await chromium.launch({channel: 'chrome'});
  try {
    const page = await browser.newPage({viewport: {width: 960, height: 900}, offline: true});
    const errors = [];
    page.on('pageerror', e => errors.push(e.message));
    const slides = [];
    async function frame(phase, caption, action, expected) {
      await page.getByText(expected, {exact: true}).waitFor();
      const image = (slides.length + 1) + '-' + phase + '.png';
      await page.screenshot({path: path.join(output, image)});
      slides.push({phase, caption, action, expected, image, dimensions:[960,900], capture_kind:'browser'});
    }
    fs.mkdirSync(output, {recursive:true});
    await page.goto(pathToFileURL(source[2]).href);
    await frame('initial','First eligible forecast','Open the offline example.',
      'Selected 10–40 s · Route 2–8 m · Origin 21.18 °C');
    await page.locator('#cursor').press('ArrowRight');
    await frame('interaction','Advance the aligned interval','Press Right Arrow on the time slider.',
      'Selected 20–50 s · Route 4–10 m · Origin 21.23 °C');
    await page.getByText('Inspect reversal', {exact:true}).click();
    await frame('result','Rising trend misses the cooling transition','Select Inspect reversal.',
      'Synthetic outcome at 150 s: 21.80 °C · Outside the band');
    await page.getByText('Restart', {exact:true}).click();
    await frame('recovery','Return to the first forecast','Select Restart.',
      'Selected 10–40 s · Route 2–8 m · Origin 21.18 °C');
    await page.locator('#cursor').press('End');
    await page.getByText('Play', {exact:true}).click();
    await page.waitForFunction(() => document.querySelector('#cursor').value === '20');
    await page.getByText('Pause', {exact:true}).click();
    await page.locator('#cursor').press('End');
    await page.locator('#cursor').press('ArrowLeft');
    await page.getByText('Play', {exact:true}).click();
    await page.getByText('Play', {exact:true}).waitFor();
    assert.equal(await page.locator('#cursor').inputValue(), '210');
    await page.setViewportSize({width:390,height:844});
    await page.reload();
    assert.equal(await page.locator('#cursor').inputValue(), '10');
    assert.ok(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth));
    await page.getByText('Inspect reversal', {exact:true}).click();
    assert.match(await page.locator('#verdict').innerText(), /Outside/);
    const manifest = {version:1, demo_id:demo, title:'Synthetic room-temperature replay',
      scenario:'Held-out session B, aligned interval, cooling reversal and restart.',
      revision, host:[os.type(),os.release(),os.arch()].join(' '), backend:'Chrome ' + browser.version(),
      scale:1, fixture:'Deterministic ambient-temperature sessions A and B',
      reproduce:'From the repo root with Node, Playwright, Chrome and Python 3, run node examples/temperature-replay/capture.cjs.', slides};
    fs.writeFileSync(path.join(output,'manifest.json'), JSON.stringify(manifest,null,2)+'\n');
    // Validate and render this demo without touching the shared catalog.
    execFileSync('python3',['-B','-c', [
      'import sys',
      'from pathlib import Path',
      "sys.path.insert(0, 'scripts')",
      'from demo_slideshows import load_manifest, render',
      'out = Path(sys.argv[1])',
      "(out / 'index.html').write_text(render(load_manifest(out / 'manifest.json')))",
    ].join('\n'),output]);
    await page.goto(pathToFileURL(path.join(output,'index.html')).href);
    await page.keyboard.press('ArrowRight');
    assert.equal(await page.locator('#counter').innerText(),'2 / 4');
    await page.locator('[data-jump="3"]').click();
    await page.locator('#prev').click();
    assert.equal(await page.locator('#counter').innerText(),'3 / 4');
    assert.ok(await page.locator('img').evaluateAll(imgs => imgs.every(i => i.complete && i.naturalWidth === 960)));
    assert.deepEqual(errors,[]);
    console.log('Verified replay, mobile layout, drift and recovery; offline deck validated and navigated.');
  } finally {
    await browser.close();
  }
}
capture().catch(error => {console.error(error); process.exitCode = 1;});
