// Real Chrome regression/replay. Set PORT and optionally pass an evidence directory.
const {chromium} = require('playwright-core');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const {execFileSync} = require('node:child_process');

const Operation = Object.freeze({ACCENT:'accent', LENGTH:'length'});
const StepAction = Object.freeze({ADVANCE:'advance', KEEP:'keep'});
const MappingVersion = Object.freeze({LEGACY:1, CURRENT:2, UNSUPPORTED:99});
const CalculationVersion = Object.freeze({PIECEWISE:1, UNSUPPORTED:99});
const mappingKey = 'moxi.phrase.v1.mapping', scoreKey = 'moxi.phrase.v1.score';
const clone = value => JSON.parse(JSON.stringify(value));
// Independent integer-rational oracle: ties round to even, including 0/100 endpoints.
function expectedOutput(midpoint,input) {
  const numerator = input <= 50 ? midpoint*input : midpoint*50+(100-midpoint)*(input-50);
  const floor = Math.floor(numerator/50), remainder = numerator%50;
  return floor+(remainder > 25 || (remainder === 25 && floor%2) ? 1 : 0);
}

async function check() {
  const directory = process.argv[2];
  if (directory) fs.mkdirSync(directory,{recursive:true});
  const url = 'http://127.0.0.1:'+(process.env.PORT || 8182)+'/';
  const record = {startedAt:new Date().toISOString(),url,fixture:'Repository CSV pitches; isolated synthetic score and panel',
    revision:execFileSync('git',['rev-parse','HEAD'],{encoding:'utf8'}).trim(),
    viewport:{width:1120,height:960},sourceSha256:{},scenarios:[],pageErrors:[]};
  for (const name of ['app.py','index.html','graph-check.cjs','check.cjs'])
    record.sourceSha256[name] = crypto.createHash('sha256').update(fs.readFileSync(path.join(__dirname,name))).digest('hex');
  const browser = await chromium.launch({channel:'chrome',args:['--mute-audio']});
  record.browser = 'Chrome '+browser.version();
  let page;
  try {
    page = await browser.newPage({viewport:record.viewport,deviceScaleFactor:1});
    page.on('pageerror',error => record.pageErrors.push(error.message));
    const el = id => page.locator('#'+id);
    const notes = page.locator('.note');
    const status = text => page.waitForFunction(text => document.getElementById('status').textContent.includes(text),text);
    const ready = () => page.waitForFunction(() => !document.getElementById('stamp').disabled);
    const saved = () => page.evaluate(([m,s]) => ({mapping:localStorage.getItem(m),score:localStorage.getItem(s)}),[mappingKey,scoreKey]);
    const restoreFixture = async value => {
      await page.evaluate(([m,s,v]) => {
        for (const [key,raw] of [[m,v.mapping],[s,v.score]]) raw === null ? localStorage.removeItem(key) : localStorage.setItem(key,raw);
      },[mappingKey,scoreKey,value]);
      await page.reload(); await ready();
    };
    const capture = async name => {
      if (directory) await page.screenshot({path:path.join(directory,name+'.png'),fullPage:true});
    };
    async function scenario(name,expected,run) {
      const item = {name,expected,startedAt:new Date().toISOString()}; record.scenarios.push(item);
      try { item.observed = await run(); item.outcome = 'PASS'; }
      catch (error) { item.outcome = 'FAIL'; item.error = error.message; throw error; }
    }
    const initial = await page.goto(url); await ready();
    const servedTemplate = (await initial.text()).replace(/const fixture = .*;\n/,'const fixture = __INSTRUMENT__;\n');
    assert.equal(crypto.createHash('sha256').update(servedTemplate).digest('hex'),record.sourceSha256['index.html'],
      'Running server must serve this checkout’s HTML');
    // Fail immediately on 5768f2b, rather than timing out on a selector.
    assert.equal(await el('graph').count(),1,'V12 needs an editable mode graph in the normal desk');
    let graphFixture;
    await scenario('Extract and author the graph','Direct source edit persists; extraction and graph/curve drafts do not affect installed mapping or score; both curves build.',async () => {
      assert.equal(await notes.count(),8);
      await page.getByText('Phrase controls · extract into your panel',{exact:true}).click();
      await notes.nth(1).click();
      await el('source-length').press('Home');
      await el('source-length').press('ArrowRight');
      assert.match(await notes.nth(1).getAttribute('aria-label'),/accent 70%, length 1%$/);
      const before = await saved();
      await el('extract-length').click();
      assert.equal(await el('mode-length').isHidden(),true);
      await el('midpoint').fill('37');
      await el('mode-next').selectOption(Operation.ACCENT);
      await el('step-action').selectOption(StepAction.ADVANCE);
      await el('operation').selectOption(Operation.ACCENT);
      await el('midpoint').fill('75');
      await el('mode-next').selectOption(Operation.LENGTH);
      await el('step-action').selectOption(StepAction.KEEP);
      assert.match(await el('active-transition').innerText(),/Accent · advance/);
      assert.deepEqual(await saved(),before);
      await el('build').click(); await status('Draft response built.');
      assert.deepEqual(await saved(),before);
      assert.match(await el('preview').innerText(),/Accent 75%/);
      await capture('authored-draft');
      await el('save').click(); await status('Mapping saved.');
      graphFixture = await saved();
      const config = JSON.parse(graphFixture.mapping);
      assert.equal(config.version,2); // Independent wire literal checks compatibility.
      assert.equal(config.modes[0].next.mode,'length');
      assert.equal(config.modes[0].next.step,'keep');
      assert.equal(config.modes[1].calculation.version,1);
      assert.equal(graphFixture.score,before.score);
      await page.reload(); await ready();
      assert.equal(await el('mode-length').isVisible(),true);
      assert.match(await el('active-transition').innerText(),/Length · keep/);
      assert.equal(await page.locator('#plot svg').count(),1,'A reopened custom graph must restore its response plot');
      await capture('reopened-graph');
      return {config,score:JSON.parse(graphFixture.score),captures:['authored-draft.png','reopened-graph.png']};
    });
    await scenario('Perform changed transitions by pointer and keyboard','Accent → Length on same step; Length → Accent advances; equal full score after Next/Apply and real Right/Space, with stable pad focus.',async () => {
      const before = JSON.parse(graphFixture.score);
      await notes.nth(2).click();
      // Physical pointer input to the real slider; read its actual thumb value.
      const box = await el('input').boundingBox();
      await el('input').click({position:{x:Math.round(box.width*.67),y:box.height/2}});
      const amount = Number(await el('input').inputValue());
      await el('next').click();
      assert.match(await el('target').innerText(),/Step 3 → Length/);
      await el('stamp').click();
      await el('next').click();
      assert.match(await el('target').innerText(),/Step 4 → Accent/);
      await el('stamp').click();
      const pointer = await saved();
      const expected = clone(before);
      expected[2].length = expectedOutput(37,amount);
      expected[3].accent = expectedOutput(75,amount);
      assert.deepEqual(JSON.parse(pointer.score),expected);
      await capture('pointer-performance');
      await restoreFixture(graphFixture);
      await notes.nth(2).click(); await el('pad').focus();
      for (let i=50;i<amount;i++) await page.keyboard.press('ArrowUp');
      for (let i=50;i>amount;i--) await page.keyboard.press('ArrowDown');
      for (const key of ['ArrowRight','Space','ArrowRight','Space']) await page.keyboard.press(key);
      assert.deepEqual(await saved(),pointer);
      assert.equal(await page.evaluate(() => document.activeElement.id),'pad');
      assert.match(await el('target').innerText(),/Step 4 → Accent/);
      await page.keyboard.press('Shift+ArrowRight');
      assert.match(await el('target').innerText(),/Step 4 → Accent/);
      await el('midpoint').focus(); await page.keyboard.press('ArrowRight');
      assert.match(await el('target').innerText(),/Step 4 → Accent/);
      await notes.last().click(); await el('pad').focus();
      await page.keyboard.press('ArrowRight');
      assert.match(await el('target').innerText(),/Step 8 → Length/);
      await page.keyboard.press('ArrowRight');
      assert.match(await el('target').innerText(),/Step 1 → Accent/);
      await capture('keyboard-performance');
      await page.reload(); await ready(); assert.deepEqual(await saved(),pointer);
      graphFixture = pointer;
      return {actualPointerInput:amount,pointerAndKeyboardScore:expected,focus:'pad',wrap:'8 Accent → 8 Length → 1 Accent',
        captures:['pointer-performance.png','keyboard-performance.png']};
    });
    await scenario('Replace and fail a calculation build','Custom midpoint 41 builds, retains the same focused input/pad nodes and score; invalid calculation receives HTTP 400 and leaves active/stored state unchanged.',async () => {
      await el('operation').selectOption(Operation.LENGTH);
      await el('midpoint').fill('41');
      await el('midpoint').evaluate(el => { window.retainedInput = el; window.retainedPad = document.getElementById('pad'); });
      await el('midpoint').press('Control+Enter'); await status('Mapping saved.');
      assert.equal(await page.evaluate(() => document.activeElement === window.retainedInput && document.getElementById('pad') === window.retainedPad),true);
      assert.equal((await saved()).score,graphFixture.score);
      graphFixture = await saved();
      await el('mode-length').click();
      assert.match(await el('target').innerText(),/Length 41%/);
      await el('midpoint').fill('not-a-number');
      const failure = page.waitForResponse(r => r.url().endsWith('/build') && r.status() === 400);
      await el('midpoint').press('Control+Enter'); await failure; await status('Build failed:');
      assert.deepEqual(await saved(),graphFixture);
      assert.match(await el('target').innerText(),/Length 41%/);
      assert.equal(await page.evaluate(() => document.activeElement === window.retainedInput),true);
      await capture('failed-build');
      await page.reload(); await ready();
      await el('mode-length').click(); assert.match(await el('target').innerText(),/Length 41%/);
      return {replacementMidpoint:41,failedBuildStatus:400,retained:['mapping','score','focused input node','pad node'],capture:'failed-build.png'};
    });
    await scenario('Reject invalid and unsupported configuration imports','Ten malformed/unsupported configurations reject without changing installed or stored graph/score or the current mode.',async () => {
      await page.getByText('Versioned configuration',{exact:true}).click();
      const good = JSON.parse(graphFixture.mapping);
      const cases = [null,{...good,version:MappingVersion.UNSUPPORTED},{...good,startMode:'missing'},
        {...good,modes:[]},{...good,modes:[good.modes[0],good.modes[0]]},
        {...good,modes:[{...good.modes[0],id:'unknown'}]},
        {...good,modes:good.modes.map(n => ({...n,next:{...n.next,mode:'missing'}}))},
        {...good,modes:good.modes.map(n => ({...n,next:{...n.next,step:'skip'}}))},
        {...good,modes:good.modes.map(n => ({...n,calculation:{version:CalculationVersion.UNSUPPORTED,midpoint:50}}))},
        {...good,modes:good.modes.map(n => ({...n,calculation:{version:CalculationVersion.PIECEWISE,midpoint:101}}))}];
      for (const value of cases) {
        await el('configuration').fill(JSON.stringify(value)); await el('import').click(); await status('Configuration rejected:');
        assert.deepEqual(await saved(),graphFixture);
        assert.match(await el('target').innerText(),/Length 41%/);
      }
      await capture('invalid-configuration');
      await el('export').click(); await el('import').click(); await status('Configuration loaded to draft.');
      assert.deepEqual(await saved(),graphFixture);
      return {rejected:cases.length,retainedMode:Operation.LENGTH,capture:'invalid-configuration.png'};
    });
    await scenario('Retain last good state on storage/transport/stale build failures','Failed save/restore/apply, failed local build and stale build leave both records intact.',async () => {
      await el('midpoint').fill('42');
      await page.evaluate(() => { Storage.prototype.setItem = () => { throw new Error('quota fixture'); }; });
      await el('save').click(); await status('could not be saved'); assert.deepEqual(await saved(),graphFixture);
      await el('restore').click(); await status('could not be saved'); assert.deepEqual(await saved(),graphFixture);
      await el('stamp').click(); assert.deepEqual(await saved(),graphFixture);
      await page.reload(); await ready();
      await page.route('**/build',route => route.fulfill({status:500,contentType:'application/json',body:JSON.stringify({error:'Synthetic renderer failure.'})}));
      await el('save').click(); await status('Build failed:'); assert.deepEqual(await saved(),graphFixture);
      await page.unroute('**/build');
      let entered,release;
      const started = new Promise(resolve => { entered = resolve; }), gate = new Promise(resolve => { release = resolve; });
      await page.route('**/build',async route => { entered(); await gate; await route.continue(); });
      await el('save').click(); await started;
      await el('midpoint').fill('43'); release(); await status('Draft changed during build');
      assert.deepEqual(await saved(),graphFixture); await page.unroute('**/build');
      return {failures:['save quota','restore quota','apply quota','renderer 500','stale draft'],retained:['mapping','score']};
    });
    await scenario('Recover corrupt storage and failed rebuild','Unsupported/dangling saved graph defaults without overwriting it; valid score survives; explicit repair only changes mapping; saved custom graph survives unavailable rebuild.',async () => {
      const good = JSON.parse(graphFixture.mapping);
      const badRecords = ['{',JSON.stringify({...good,version:MappingVersion.UNSUPPORTED}),
        JSON.stringify({...good,modes:good.modes.map(n => ({...n,next:{mode:'missing',step:StepAction.KEEP}}))})];
      for (const raw of badRecords) {
        await restoreFixture({...graphFixture,mapping:raw});
        await status('Saved mapping unreadable');
        assert.match(await el('target').innerText(),/Accent 50%/);
        assert.deepEqual(await saved(),{...graphFixture,mapping:raw});
      }
      await capture('stored-recovery');
      await el('restore').click(); await status('Default mapping restored.');
      assert.equal((await saved()).score,graphFixture.score);
      await page.reload(); await ready(); assert.equal(await el('status').innerText(),'');
      await restoreFixture(graphFixture);
      await page.route('**/build',route => route.fulfill({status:500,contentType:'application/json',body:'{"error":"Synthetic rebuild failure."}'}));
      await page.reload(); await ready(); await status('Saved response could not be built');
      assert.deepEqual(await saved(),graphFixture);
      await page.unroute('**/build'); await page.reload(); await ready();
      assert.equal(await el('mode-length').isVisible(),true);
      // A read-denial hook is restricted to this temporary page and flag.
      await page.addInitScript(() => {
        if (sessionStorage.getItem('deny-reads')) Storage.prototype.getItem = () => { throw new Error('read fixture'); };
      });
      await page.evaluate(() => sessionStorage.setItem('deny-reads','1'));
      await page.reload(); await ready(); await status('Saved score unreadable');
      await page.evaluate(() => sessionStorage.removeItem('deny-reads'));
      await page.reload(); await ready(); assert.deepEqual(await saved(),graphFixture);
      return {invalidRecords:badRecords.length,readDenial:true,failedRebuild:true,capture:'stored-recovery.png'};
    });
    await scenario('Keep version 1 configurations compatible','All 6 legacy operation/preset combinations retain wire data until Save; self transitions advance and wrap; explicit Save emits v2 with identical response/score.',async () => {
      for (const operation of Object.values(Operation)) for (const midpoint of [25,50,75]) {
        const raw = JSON.stringify({version:MappingVersion.LEGACY,operation,midpoint});
        await restoreFixture({...graphFixture,mapping:raw});
        assert.equal(await el('status').innerText(),'');
        assert.match(await el('target').innerText(),new RegExp('Step 1 → '+(operation === Operation.ACCENT ? 'Accent' : 'Length')+' '+midpoint+'%'));
        assert.deepEqual(await saved(),{...graphFixture,mapping:raw});
        await notes.last().click(); await el('pad').focus(); await page.keyboard.press('ArrowRight');
        assert.equal(await notes.first().getAttribute('aria-pressed'),'true');
      }
      await el('save').click(); await status('Mapping saved.');
      const converted = JSON.parse((await saved()).mapping);
      assert.equal(converted.version,2);
      assert.deepEqual(converted.modes,[{id:'length',calculation:{version:1,midpoint:75},next:{mode:'length',step:'advance'}}]);
      assert.equal((await saved()).score,graphFixture.score);
      await restoreFixture(graphFixture);
      return {legacyCases:6,converted};
    });
    await scenario('Validate bounded build contract with an independent oracle','Every returned value for 7 curves matches integer rounding; unsupported versions/types/ranges/counts reject.',async () => {
      for (const midpoint of [0,25,37,41,50,75,100]) {
        const response = await page.request.post(url+'build',{data:[{version:1,midpoint}]});
        assert.equal(response.status(),200);
        const result = await response.json();
        assert.deepEqual(result.curves[0].values,Array.from({length:101},(_,i) => expectedOutput(midpoint,i)));
        assert.match(result.curves[0].svg,/<svg/);
      }
      for (const body of [[],[{}, {}, {}],[{version:99,midpoint:50}],[{version:true,midpoint:50}],
        [{version:1,midpoint:'50'}],[{version:1,midpoint:50.5}],[{version:1,midpoint:-1}],[{version:1,midpoint:101}]]) {
        assert.equal((await page.request.post(url+'build',{data:body})).status(),400);
      }
      return {curveValues:707,rejectedBuilds:8};
    });
    await scenario('Keep authoring independent of startup rebuild','Extracting a new mode during a delayed custom-curve rebuild preserves the draft, keeps installed controls separate, and does not use mismatched plot data.',async () => {
      const length = clone(JSON.parse(graphFixture.mapping).modes[1]);
      length.next = {mode:Operation.LENGTH,step:StepAction.ADVANCE};
      const single = {version:MappingVersion.CURRENT,startMode:Operation.LENGTH,modes:[length]};
      await page.evaluate(([key,value]) => localStorage.setItem(key,value),[mappingKey,JSON.stringify(single)]);
      let entered,release;
      const started = new Promise(resolve => { entered = resolve; }), gate = new Promise(resolve => { release = resolve; });
      await page.route('**/build',async route => { entered(); await gate; await route.continue(); });
      await page.reload(); await started;
      assert.equal(await el('stamp').isDisabled(),true);
      await page.getByText('Phrase controls · extract into your panel',{exact:true}).click();
      await el('extract-accent').click();
      release(); await ready(); await page.unroute('**/build');
      assert.equal(await page.locator('#graph li').count(),2);
      assert.equal(await el('operation').inputValue(),Operation.ACCENT);
      assert.equal(await el('mode-accent').isHidden(),true);
      await el('build').click(); await status('Draft response built.');
      assert.equal(await page.locator('#plot svg').count(),1);
      assert.deepEqual(JSON.parse((await saved()).mapping),single);
      await restoreFixture(graphFixture);
      return {draftModes:2,installedModes:1,scoreRetained:(await saved()).score === graphFixture.score};
    });
    await scenario('Inspect narrow layout and retained accessibility state','390×844 has no horizontal overflow; eight named notes, one selected, mode labels and native controls remain; no uncaught page errors.',async () => {
      await page.setViewportSize({width:390,height:844});
      await page.getByText('Phrase controls · extract into your panel',{exact:true}).click();
      assert.ok(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth));
      assert.equal(await page.locator('.note[aria-pressed=true]').count(),1);
      for (let i=0;i<8;i++) assert.match(await notes.nth(i).getAttribute('aria-label'),new RegExp('^Step '+(i+1)+', MIDI'));
      await capture('narrow-graph');
      assert.deepEqual(record.pageErrors,[]);
      return {viewport:{width:390,height:844},namedNotes:8,selectedNotes:1,capture:'narrow-graph.png'};
    });
    console.log('PASS — '+record.scenarios.length+' graph scenarios. '+record.browser);
  } finally {
    record.completedAt = new Date().toISOString();
    if (directory) fs.writeFileSync(path.join(directory,'results.json'),JSON.stringify(record,null,2)+'\n');
    await browser.close();
  }
}
check().catch(error => { console.error(error); process.exitCode = 1; });
