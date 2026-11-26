// Run against a fresh local server. An optional argument captures the four slides.
const { chromium } = require('playwright-core');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

async function check() {
  const browser = await chromium.launch({channel:'chrome'});
  try {
    const page = await browser.newPage({viewport:{width:1120,height:840}, deviceScaleFactor:1});
    const errors = [];
    page.on('pageerror', e => errors.push(e.message));
    const captures = process.argv[2];
    const capture = async name => {
      if (!captures) return;
      fs.mkdirSync(captures,{recursive:true});
      await page.screenshot({path:path.join(captures,name+'.png')});
    };
    const url = 'http://127.0.0.1:'+(process.env.PORT || 8182)+'/';
    const el = id => page.locator('#'+id);
    const notes = page.locator('.note');
    const assertNote = async (i,accent,length) =>
      assert.match(await notes.nth(i).getAttribute('aria-label'),new RegExp('accent '+accent+'%, length '+length+'%$'));
    await page.goto(url);
    assert.equal(await notes.count(),8);
    await assertNote(0,70,80);
    assert.equal(await page.locator('#plot svg').count(),1);
    await capture('initial');

    await el('stamp').click();
    await assertNote(0,50,80);
    await el('pad').focus();
    await page.keyboard.press('ArrowRight');
    await page.keyboard.press('Space');
    await assertNote(1,50,80);
    await page.keyboard.press('ArrowUp');
    assert.equal(await el('input').inputValue(),'51');
    await page.keyboard.press('ArrowDown');
    await el('operation').selectOption('length');
    await el('midpoint').selectOption('25');
    assert.match(await el('preview').innerText(),/Length 25%/);
    assert.match(await el('target').innerText(),/Accent 50%/);
    await capture('interaction');
    await el('save').click();
    await page.reload();
    assert.match(await el('target').innerText(),/Step 1 → Length 25%/);
    await assertNote(1,50,80);
    await el('pad').focus();
    await page.keyboard.press('Space');
    await assertNote(0,50,25);
    assert.equal(await page.evaluate(() => document.activeElement.id),'pad');
    await capture('result');

    // A future schema is unreadable even when its operation looks familiar.
    await page.evaluate(() => localStorage.setItem('moxi.phrase.v1.mapping',
      JSON.stringify({version:2,midpoint:25,operation:'length'})));
    await page.reload();
    assert.match(await el('status').innerText(),/Saved mapping unreadable/);
    assert.match(await el('target').innerText(),/Accent 50%/);
    await assertNote(0,50,25);
    await capture('recovery');
    await el('restore').click();
    await page.reload();
    assert.equal(await el('status').innerText(),'');
    await assertNote(0,50,25);
    await notes.last().click();
    await el('next').click();
    assert.equal(await notes.first().getAttribute('aria-pressed'),'true');

    await el('midpoint').selectOption('75');
    await page.evaluate(() => { Storage.prototype.setItem = () => { throw new Error('quota'); }; });
    await el('save').click();
    assert.match(await el('status').innerText(),/could not be saved/);
    assert.match(await el('target').innerText(),/Accent 50%/);
    await el('next').click();
    await el('next').click();
    await el('stamp').click();
    await assertNote(2,70,80);
    await page.setViewportSize({width:390,height:844});
    assert.ok(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth));
    await el('listen').click();
    await page.waitForFunction(() => !document.getElementById('listen').disabled);
    assert.doesNotMatch(await el('status').innerText(),/Audio playback unavailable/);
    assert.deepEqual(errors,[]);
    console.log('PASS — pointer, keyboard, preview, reopen, recovery, write failure, wrap, narrow layout and playback scheduling. Chrome '+browser.version());
  } finally { await browser.close(); }
}
check().catch(error => { console.error(error); process.exitCode = 1; });
