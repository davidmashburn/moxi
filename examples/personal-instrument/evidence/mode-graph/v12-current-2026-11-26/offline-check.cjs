// Verify one existing generated deck as a local file, with networking disabled.
// NODE_PATH=<playwright-core directory> node offline-check.cjs <evidence directory>
const {chromium} = require('playwright-core');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {pathToFileURL} = require('node:url');
const {createHash} = require('node:crypto');

async function check() {
  const directory = path.resolve(process.argv[2]);
  const manifest = JSON.parse(fs.readFileSync(path.join(directory,'manifest.json')));
  const sha = bytes => createHash('sha256').update(bytes).digest('hex');
  const record = {startedAt:new Date().toISOString(),protocol:'file:',networkOffline:true,
    viewport:{width:1120,height:900},deviceScaleFactor:1,
    htmlSha256:sha(fs.readFileSync(path.join(directory,'index.html'))),
    checks:[],pageErrors:[],failedRequests:[],httpRequests:[]};
  const browser = await chromium.launch({channel:'chrome',args:['--mute-audio']});
  record.browser = 'Chrome '+browser.version();
  const context = await browser.newContext({viewport:record.viewport,deviceScaleFactor:1,offline:true});
  const page = await context.newPage();
  page.on('pageerror',error => record.pageErrors.push(error.message));
  page.on('request',request => {if (/^https?:/.test(request.url())) record.httpRequests.push(request.url());});
  page.on('requestfailed',request => record.failedRequests.push({protocol:new URL(request.url()).protocol,error:request.failure()?.errorText}));
  try {
    await page.goto(pathToFileURL(path.join(directory,'index.html')).href);
    const images = await page.locator('img.shot').evaluateAll(async images => {
      await Promise.all(images.map(image => image.decode()));
      return images.map(image => ({width:image.naturalWidth,height:image.naturalHeight,src:image.src}));
    });
    assert.equal(images.length,manifest.slides.length);
    images.forEach((image,i) => {
      assert.deepEqual([image.width,image.height],manifest.slides[i].dimensions);
      assert.ok(image.src.startsWith('data:image/png;base64,'));
      assert.equal(sha(Buffer.from(image.src.split(',')[1],'base64')),manifest.slides[i].sha256);
    });
    record.checks.push({action:'Open index.html offline and decode every embedded slide',
      expected:'All PNG hashes/dimensions match the manifest without HTTP resources',
      observed:{decoded:images.length,hashesAndDimensionsMatched:images.length},outcome:'PASS'});
    const at = async index => {
      assert.equal(await page.locator('[data-slide]:visible').count(),1);
      assert.equal(await page.locator('[data-slide]:visible').getAttribute('data-slide'),String(index));
      assert.equal(await page.locator('#counter').innerText(),`${index+1} / ${images.length}`);
    };
    await at(0);
    for (let i=1;i<=images.length;i++) {await page.locator('#next').click();await at(i%images.length);}
    await page.locator('#prev').click(); await at(images.length-1);
    await page.locator('#prev').focus();
    await page.keyboard.press('ArrowRight'); await at(0);
    await page.keyboard.press('ArrowLeft'); await at(images.length-1);
    for (let i=0;i<images.length;i++) {await page.locator(`[data-jump="${i}"]`).click();await at(i);}
    await page.evaluate(() => scrollTo(0,0));
    await page.screenshot({path:path.join(directory,'offline-navigation.png')});
    record.checks.push({action:'Visit every slide with Next and thumbnails; exercise Previous and both arrow keys with wrapping',
      expected:'Exactly one visible slide and correct counter after every action',
      observed:{nextVisits:images.length,thumbnailVisits:images.length,previous:true,arrowKeys:true,wrap:true},outcome:'PASS'});
    assert.deepEqual(record.pageErrors,[]);
    assert.deepEqual(record.failedRequests,[]);
    assert.deepEqual(record.httpRequests,[]);
    record.outcome = 'PASS';
    console.log(`PASS ${manifest.demo_id}: ${images.length} embedded PNGs, file: offline, all navigation`);
  } finally {
    record.completedAt = new Date().toISOString();
    fs.writeFileSync(path.join(directory,'offline.json'),JSON.stringify(record,null,2)+'\n');
    await browser.close();
  }
}
check().catch(error => {console.error(error);process.exitCode=1;});
