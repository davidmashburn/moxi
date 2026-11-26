// Run against the local file produced by build.sh. The optional directory
// receives the exact browser states referenced by the slideshow manifest.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {pathToFileURL} = require('node:url');
const {chromium} = require('playwright');

async function check() {
  const [html, output] = process.argv.slice(2);
  const browser = await chromium.launch({channel: 'chrome', headless: true});
  try {
    const context = await browser.newContext({viewport:{width:1180,height:790},
      deviceScaleFactor:1, offline:true});
    const page = await context.newPage();
    const errors = [];
    page.on('pageerror', e => errors.push(e.message));
    await page.goto(pathToFileURL(path.resolve(html)).href);
    const capture = async name => {
      if (!output) return;
      fs.mkdirSync(output, {recursive:true});
      await page.screenshot({path:path.join(output,name+'.png')});
    };
    const active = view => page.locator('#'+view+' .active').getAttribute('data-panel');
    const comparison = () => page.locator('#comparison tr').last().innerText();
    const points = view => page.locator('#'+view+' [data-panel="4"]').getAttribute('points');
    const apply = () => page.getByRole('button',{name:'Apply edit'}).click();
    assert.equal(await page.locator('#flat polygon').count(),6);
    const initial = await comparison();
    const initialFlat = await points('flat'), initialFold = await points('folded');
    assert.match(initial,/103.9 mm\s+10.0 mm/);
    await capture('01-start');
    await page.locator('#folded [data-panel="4"]').click();
    assert.equal(await active('flat'),'4');
    assert.match(await page.locator('#adjacency').innerText(), /3 and 5/);
    await page.locator('#flat [data-panel="2"]').click();
    assert.equal(await active('folded'),'2');
    await page.locator('#pick').press('ArrowDown');
    assert.equal(await active('folded'),'3');

    const sweep = page.locator('#sweep');
    await sweep.click();
    await sweep.press('End');
    assert.match(await comparison(),/Preview\s+20 mm\s+75°/);
    assert.notEqual(await points('folded'),initialFold);
    await capture('02-preview');
    await sweep.press('Escape');
    assert.equal(await comparison(),initial);
    assert.equal(await points('folded'),initialFold);
    assert.equal(await page.locator('#undo').isDisabled(),true);

    await page.locator('#pitch').fill('24.5');
    await page.locator('#tilt').fill('60');
    await page.locator('#tilt').press('Enter');
    const edited = await comparison();
    assert.match(edited,/73.5 mm\s+21.2 mm/);
    assert.notEqual(await points('flat'),initialFlat);
    assert.notEqual(await points('folded'),initialFold);
    assert.equal(await page.locator('#sheet').innerText(),'Sheet 147.0 × 40 mm · M mountain / V valley');
    await capture('03-edit');
    const editedShape = await points('folded');
    for (const bad of ['','-1','76','2.5','90']) {
      await page.locator('#tilt').fill(bad);
      await apply();
      assert.match(await page.locator('#status').innerText(),/rejected/);
      assert.equal(await comparison(),edited);
      assert.equal(await points('folded'),editedShape);
    }
    await capture('04-rejection');
    await page.locator('#undo').click();
    assert.equal(await points('flat'),initialFlat);
    assert.equal(await points('folded'),initialFold);
    assert.equal(await comparison(),initial);
    assert.equal(await active('flat'),'3');
    assert.equal(await page.locator('#undo').isDisabled(),true);
    await capture('05-undo');
    const note = page.locator('#flat text').last();
    const beforeNote = await note.evaluate(n => [n.textContent,n.getAttribute('x'),n.getAttribute('y')]);
    await page.locator('#measure').click();
    assert.match(await note.textContent(), /10.0 mm high/);
    assert.equal(await page.locator('#folded polyline').count(),1);
    await page.locator('#tilt').fill('60');
    await apply();
    assert.match(await note.textContent(), /17.3 mm high/);
    await capture('06-measure');
    await page.locator('#undo').click();
    assert.match(await note.textContent(), /10.0 mm high/);
    await page.locator('#undo').click();
    assert.deepEqual(await note.evaluate(n => [n.textContent,n.getAttribute('x'),n.getAttribute('y')]),beforeNote);
    assert.equal(await page.locator('#folded polyline').count(),0);
    assert.equal(await page.locator('#undo').isDisabled(),true);
    for (const pitch of ['','9.9','30.1','12.34']) {
      await page.locator('#pitch').fill(pitch);
      await apply();
      assert.match(await page.locator('#status').innerText(),/rejected/);
      assert.equal(await comparison(),initial);
    }
    for (const [pitch,tilt,measure] of [['10','0',/60.0 mm\s+0.0 mm/],['30','75',/46.6 mm\s+29.0 mm/]]) {
      await page.locator('#pitch').fill(pitch);
      await page.locator('#tilt').fill(tilt);
      await apply();
      assert.match(await comparison(),measure);
    }
    // Independently check every built sample, including its screen offsets
    // against an analytic orthographic basis for the declared camera.
    const data = await page.evaluate(() => geometry);
    assert.equal(data.sections.length,76);
    const scale = 100/(10.5*Math.tan(Math.PI/8));
    const near = (a,b) => assert.ok(Math.abs(a-b)<1e-7);
    data.sections.forEach(({run,rise,offsets},angle) => {
      near(run,Math.cos(angle*Math.PI/180));
      near(rise,Math.sin(angle*Math.PI/180));
      near(Math.hypot(run,rise),1);
      assert.equal(offsets.length,7);
      offsets.forEach(([dx,dy],i) => {
        const x = (i-3)*run, y = (i%2)*rise;
        near(dx,scale*Math.cos(-.19)*x);
        near(dy,-scale*(Math.cos(.87)*y-Math.sin(.87)*Math.sin(-.19)*x));
      });
    });
    await page.setViewportSize({width:390,height:844});
    assert.ok(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth));
    await page.locator('#pick').selectOption('6');
    assert.match(await page.locator('#adjacency').innerText(),/adjacent to 5 ·/);

    // Attachment and its undo must not resolve a draft or commit a preview.
    const draftState = async () => ({
      inputs: await page.locator('input:not([type=file])').evaluateAll(inputs => inputs.map(input => input.value)),
      comparison: await comparison(), flat: await points('flat'), folded: await points('folded')
    });
    const measurementDraft = async previewing => {
      if (previewing) {
        await sweep.focus();
        await sweep.press('End');
        assert.match(await comparison(),/Preview\s+20 mm\s+75°/);
      } else {
        await page.locator('#pitch').fill('24.5');
        await page.locator('#tilt').fill('60');
        assert.equal(await comparison(),initial);
      }
      const draft = await draftState();
      await page.locator('#measure').click();
      assert.deepEqual(await draftState(),draft,'Attaching a measurement must preserve the draft');
      assert.match(await note.textContent(),previewing ? /19.3 mm high/ : /10.0 mm high/);
      assert.equal(await page.locator('#folded polyline').count(),1);
      await capture(previewing ? '08-preview-measure' : '07-draft-measure');
      await page.locator('#undo').click();
      assert.deepEqual(await draftState(),draft,'Undoing attachment must preserve the draft');
      assert.equal(await page.locator('#folded polyline').count(),0);
      assert.match(await note.textContent(),/how high\?/);
      assert.equal(await page.locator('#undo').isDisabled(),true);
      await page.locator('#measure').click();
      await page.keyboard.press('Escape');
      assert.equal(await comparison(),initial,'Attachment must not implicitly commit the draft');
      assert.equal(await points('folded'),initialFold);
      assert.deepEqual(await page.locator('input:not([type=file])').evaluateAll(inputs => inputs.map(input => input.value)),['20','30','30']);
      assert.match(await note.textContent(),/10.0 mm high/);
      await page.locator('#undo').click();
      assert.equal(await page.locator('#undo').isDisabled(),true);
    };
    const neighborPicking = async () => {
      await page.locator('#pitch').fill('10');
      await page.locator('#tilt').fill('75');
      await apply();
      assert.equal(await active('folded'),'1');
      // Use the actual projected centroid, not Playwright's clickable-point
      // fallback, which can miss an outline stealing part of a face's fill.
      const center = await page.locator('#folded [data-panel="2"]').evaluate(face => {
        const vertices = Array.from(face.points);
        const point = new DOMPoint(
          vertices.reduce((sum,p) => sum+p.x,0)/vertices.length,
          vertices.reduce((sum,p) => sum+p.y,0)/vertices.length
        ).matrixTransform(face.getScreenCTM());
        return {x:point.x,y:point.y};
      });
      await capture('09-before-neighbor-pick');
      await page.mouse.click(center.x,center.y);
      assert.equal(await active('folded'),'2','The selected outline must not intercept its neighbor');
      assert.equal(await active('flat'),'2');
      assert.equal(await page.locator('#pick').inputValue(),'2');
      await capture('10-after-neighbor-pick');
    };
    await page.setViewportSize({width:1180,height:790});
    const failures = [];
    for (const [name,scenario] of [
      ['numeric draft measurement',() => measurementDraft(false)],
      ['slider preview measurement',() => measurementDraft(true)],
      ['neighbor picking at 10 mm / 75 degrees',neighborPicking]
    ]) {
      await page.reload();
      try {
        await scenario();
        console.log('Passed '+name+'.');
      } catch (error) {
        failures.push(new Error(name,{cause:error}));
      }
    }
    assert.deepEqual(errors,[]);
    if (failures.length) throw new AggregateError(failures,'Browser regressions failed');
    console.log('Passed offline Chrome '+browser.version()+' geometry, linked picking, edit, preview, rejection, undo and narrow layout.');
  } finally {
    await browser.close();
  }
}
check().catch(error => { console.error(error); process.exitCode = 1; });
