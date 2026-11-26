// Existing local Playwright + Chrome only. No dependency downloads or server.
// Usage: node editing-check.cjs BUILT.html OUTPUT_DIRECTORY
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const {createHash} = require('node:crypto');
const {execFileSync} = require('node:child_process');
const {pathToFileURL} = require('node:url');
const {chromium} = require('playwright');

async function check() {
  const [html, output] = process.argv.slice(2);
  assert.ok(html && output,'Provide the built editor and an evidence directory');
  fs.mkdirSync(output,{recursive:true});
  const root = path.resolve(__dirname,'../..');
  const sha256 = file => createHash('sha256').update(fs.readFileSync(file)).digest('hex');
  const sourceFiles = ['examples/foldable-motif/editor.html','examples/foldable-motif/project.cpp',
    'examples/foldable-motif/build.sh','examples/foldable-motif/check.cjs',
    'examples/foldable-motif/editing-check.cjs','native/spatial/core.cpp','native/spatial/core.hpp'];
  const originalDir = path.join(root,'artifacts/demo-slideshows/v11-foldable-motif');
  const browser = await chromium.launch({channel:'chrome',headless:true});
  const report = {captured_at:new Date().toISOString(),browser:browser.version(),
    host:{platform:os.platform(),release:os.release(),arch:os.arch()},
    source_revision:execFileSync('git',['rev-parse','HEAD'],{cwd:root,encoding:'utf8'}).trim(),
    source_sha256:Object.fromEntries(sourceFiles.map(file=>[file,sha256(path.join(root,file))])),
    built_html_sha256:sha256(html),
    original_evidence_sha256:Object.fromEntries(fs.readdirSync(originalDir)
      .filter(file=>/\.(png|html|json)$/.test(file)).map(file=>[file,sha256(path.join(originalDir,file))])),
    backend:'Offline Chrome, Moxi orthographic samples, SVG',scale:1,
    fixture:'Six rigid panels; 20 mm pitch, 40 mm depth, 30 degree tilt',
    scenarios:[],screenshots:[],errors:[]};
  try {
    const context = await browser.newContext({offline:true,deviceScaleFactor:1});
    const page = await context.newPage();
    page.on('pageerror',error => report.errors.push(error.message));
    const url = pathToFileURL(path.resolve(html)).href;
    const state = () => page.evaluate(() => ({
      faces:['flat','folded'].map(id=>[...document.querySelectorAll('#'+id+' polygon')].map(p=>p.getAttribute('points'))),
      selected:document.querySelector('#pick').value,
      inputs:[...document.querySelectorAll('input')].map(n=>n.value),
      comparison:document.querySelector('#comparison').innerText.replace(/Preview|Current/,'Patch'),
      sheet:document.querySelector('#sheet').textContent,
      adjacency:document.querySelector('#adjacency').textContent,
      note:document.querySelector('#flat .drawing').lastElementChild.textContent,
      trace:document.querySelector('#folded polyline')?.getAttribute('points') || null,
      handles:[...document.querySelectorAll('.handle')].map(n=>[n.id,n.getAttribute('cx'),n.getAttribute('cy'),n.getAttribute('aria-valuenow')])
    }));
    const apply = () => page.getByRole('button',{name:'Apply edit',exact:true}).click();
    const undo = () => page.getByRole('button',{name:'Undo',exact:true}).click();
    const numeric = async (pitch,tilt) => {
      await page.locator('#pitch').fill(String(pitch));
      await page.locator('#tilt').fill(String(tilt));
      await page.locator('#tilt').press('Enter');
    };
    const cleanHistory = async () => assert.ok(await page.locator('#undo').isDisabled(),'No hidden geometry commit');
    const capture = async (name,action,expected) => {
      const image = name+'.png';
      await page.screenshot({path:path.join(output,image),fullPage:true});
      report.screenshots.push({image,action,expected,viewport:page.viewportSize(),capture_kind:'offline headless browser'});
    };
    // Transform an independently computed model-space target to client pixels;
    // all actual edits go through mouse/keyboard/form entry points.
    const startDrag = async (id,pitch,tilt) => {
      const handle = page.locator('#'+id);
      await handle.scrollIntoViewIfNeeded();
      const positions = await handle.evaluate((node,{pitch,tilt}) => {
        const svg = node.ownerSVGElement, matrix = svg.getScreenCTM();
        const start = new DOMPoint(Number(node.getAttribute('cx')),Number(node.getAttribute('cy'))).matrixTransform(matrix);
        let x,y;
        if (node.id === 'flat-pitch') [x,y] = [250+7.5*pitch,150];
        else {
          const index = node.id === 'folded-pitch' ? 6 : 3;
          [x,y] = geometry.sections[tilt].offsets[index].map((offset,k)=>geometry.front[k]+offset*pitch/10);
        }
        const end = new DOMPoint(x,y).matrixTransform(matrix);
        return {start:{x:start.x,y:start.y},end:{x:end.x,y:end.y}};
      },{pitch,tilt});
      await page.mouse.move(positions.start.x,positions.start.y);
      await page.mouse.down();
      await page.mouse.move(positions.end.x,positions.end.y,{steps:8});
      return positions;
    };
    const dragTo = async (id,pitch,tilt) => { await startDrag(id,pitch,tilt); await page.mouse.up(); };
    for (const viewport of [{width:1180,height:900},{width:390,height:844}]) {
      await page.setViewportSize(viewport);
      const scenario = async (name,steps,expected,run) => {
        await page.goto(url);
        try {
          await run();
          assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth <= innerWidth),'No horizontal overflow');
        } catch (error) {
          report.scenarios.push({name,viewport,steps,expected,observed:error.message,result:'fail'});
          throw error;
        }
        report.scenarios.push({name,viewport,steps,expected,observed:expected,result:'pass'});
        console.log('PASS '+viewport.width+' '+name);
      };
      for (const id of ['flat-pitch','folded-pitch','folded-tilt']) {
        const pitch = id === 'folded-tilt' ? 20 : 24.5;
        const tilt = id === 'folded-tilt' ? 60 : 30;
        await scenario(id+' pointer / numeric parity',
          'Drag the visible circle to '+pitch+' mm / '+tilt+' degrees; apply; undo; enter the same numbers; undo.',
          'Preview updates both views and controls; applied geometry equals numeric geometry; each edit undoes once.',async () => {
            const initial = await state();
            await dragTo(id,pitch,tilt);
            assert.match(await page.locator('#comparison').innerText(),/Preview/);
            assert.deepEqual((await state()).inputs,[String(pitch),String(tilt),String(tilt)]);
            assert.equal(await page.locator(':focus').getAttribute('id'),id);
            await cleanHistory();
            if (viewport.width === 1180 || id === 'folded-tilt')
              await capture(viewport.width+'-'+id+'-preview','Drag '+id+' to '+pitch+' mm / '+tilt+' degrees.',
                'Both views preview the shared parameters; the focused circle remains usable.');
            if (id === 'folded-pitch') await page.locator('#'+id).press('Enter');
            else await apply();
            const direct = await state();
            await undo();
            assert.deepEqual(await state(),initial);
            await cleanHistory();
            await numeric(pitch,tilt);
            assert.deepEqual(await state(),direct);
            await undo();
            assert.deepEqual(await state(),initial);
            await cleanHistory();
          });
      }
      await scenario('flat / folded pitch at a steep fold',
        'Set 10 mm / 75 degrees. Drag flat pitch to 24.5 mm, apply and undo; repeat from the folded pitch circle.',
        'The same pitch edit produces exactly the same linked patch in both representations, even at the tightest fold and while narrow readouts wrap.',async () => {
          await numeric(10,75);
          const initial = await state();
          await dragTo('flat-pitch',24.5,75); await apply();
          const flatEdit = await state();
          await undo(); assert.deepEqual(await state(),initial);
          await dragTo('folded-pitch',24.5,75); await apply();
          assert.deepEqual(await state(),flatEdit);
          await undo(); assert.deepEqual(await state(),initial);
          await undo(); await cleanHistory();
        });
      await scenario('keyboard access, steps and limits',
        'Tab from the page through all three circles. Use arrows, Home/End and Enter; undo or Escape.',
        'All circles are reachable; pitch steps 0.1 mm and tilt steps 1 degree; endpoints match numeric entry; focus survives redraw.',async () => {
          const initial = await state();
          const reached = new Set();
          for (let i=0;i<16;i++) {
            await page.keyboard.press('Tab');
            const id = await page.evaluate(()=>document.activeElement.id);
            if (['flat-pitch','folded-pitch','folded-tilt'].includes(id)) reached.add(id);
          }
          assert.equal(reached.size,3);
          for (const [id,parameter,step] of [['flat-pitch','pitch',20.1],['folded-pitch','pitch',20.1],['folded-tilt','tilt',31]]) {
            const handle = page.locator('#'+id);
            await handle.focus();
            await handle.press('ArrowRight');
            assert.equal(await page.locator('#'+parameter).inputValue(),String(step));
            assert.equal(await page.locator(':focus').getAttribute('id'),id);
            await handle.press('ArrowLeft');
            assert.deepEqual(await state(),initial);
            for (const [key,value] of [['Home',parameter === 'pitch' ? 10 : 0],['End',parameter === 'pitch' ? 30 : 75]]) {
              await handle.press(key);
              await handle.press(key === 'Home' ? 'ArrowDown' : 'ArrowUp');
              assert.equal(await handle.getAttribute('aria-valuenow'),String(value));
              await handle.press('Enter');
              const direct = await state();
              await undo();
              await cleanHistory();
              await numeric(parameter === 'pitch' ? value : 20,parameter === 'tilt' ? value : 30);
              assert.deepEqual(await state(),direct);
              await undo();
              await handle.focus();
            }
            await handle.press('Escape');
            assert.deepEqual(await state(),initial);
          }
          // 16.1 has a non-integral binary product by ten: a valid tenth.
          await numeric(16.1,30);
          assert.equal(await page.locator('#pitch').inputValue(),'16.1');
          assert.match(await page.locator('#status').innerText(),/applied/);
          await undo();
          await cleanHistory();
        });
      await scenario('in-flight cancel and pointer bounds',
        'Drag each circle, press Escape before releasing, move again and release; repeat with Cancel edit. Drag far beyond both limits.',
        'Cancellation restores all linked values without history and later pointer movement cannot revive the draft; pointer bounds match Home/End.',async () => {
          const initial = await state();
          for (const id of ['flat-pitch','folded-pitch','folded-tilt']) {
            const {end} = await startDrag(id,id === 'folded-tilt' ? 20 : 26,id === 'folded-tilt' ? 65 : 30);
            await page.keyboard.press('Escape');
            await page.mouse.move(end.x+8,end.y+8);
            await page.mouse.up();
            assert.deepEqual(await state(),initial);
            await cleanHistory();
            await dragTo(id,id === 'folded-tilt' ? 20 : 26,id === 'folded-tilt' ? 65 : 30);
            await page.getByRole('button',{name:'Cancel edit',exact:true}).click();
            assert.deepEqual(await state(),initial);
            for (const [pitch,tilt,value] of [[-50,-100,id === 'folded-tilt' ? 0 : 10],[80,160,id === 'folded-tilt' ? 75 : 30]]) {
              const handle = page.locator('#'+id);
              await handle.scrollIntoViewIfNeeded();
              const box = await handle.boundingBox();
              const x = box.x+box.width/2, y = box.y+box.height/2;
              await page.mouse.move(x,y); await page.mouse.down();
              await page.mouse.move(x+(id === 'folded-tilt' ? 0 : pitch*5),y+(id === 'folded-tilt' ? -tilt : 0));
              await page.mouse.up();
              assert.equal(await handle.getAttribute('aria-valuenow'),String(value));
              await page.keyboard.press('Escape');
              assert.deepEqual(await state(),initial);
            }
          }
          await capture(viewport.width+'-cancelled','Cancel a geometry drag, then move the released pointer.',
            'Starting geometry and numeric values restored; no Undo entry.');
        });
      await scenario('invalid drafts and direct-entry rejection',
        'Submit blank, out-of-range and fractional values. Try a geometry drag and handle arrow with an invalid other parameter, then Escape.',
        'Rejections preserve the last valid geometry, draft inputs and undo history; Escape restores the committed inputs.',async () => {
          await numeric(24.5,60);
          const valid = await state();
          for (const [parameter,bad] of [['pitch',''],['pitch','9.9'],['pitch','30.1'],['pitch','12.34'],['tilt',''],['tilt','-1'],['tilt','76'],['tilt','2.5']]) {
            await page.locator('#'+parameter).fill(bad);
            await apply();
            assert.match(await page.locator('#status').innerText(),/rejected/);
            assert.deepEqual((await state()).faces,valid.faces);
            await page.keyboard.press('Escape');
            assert.deepEqual(await state(),valid);
          }
          for (const id of ['flat-pitch','folded-pitch','folded-tilt']) {
            const invalid = id === 'folded-tilt' ? 'pitch' : 'tilt';
            await page.locator('#'+invalid).fill('999');
            await dragTo(id,25,65);
            assert.match(await page.locator('#status').innerText(),/rejected/);
            await page.locator('#'+id).press('ArrowRight');
            assert.match(await page.locator('#status').innerText(),/rejected/);
            assert.equal(await page.locator('#'+invalid).inputValue(),'999');
            assert.deepEqual((await state()).faces,valid.faces);
            if (id === 'folded-tilt') await capture(viewport.width+'-invalid',
              'Try direct tilt with an invalid pitch draft.','Invalid input remains visible; last valid 24.5 mm / 60 degree geometry remains.');
            await page.keyboard.press('Escape');
          }
          await undo();
          await cleanHistory();
          assert.equal(await page.locator('#pitch').inputValue(),'20');
        });
      await scenario('per-view centroid picking at bounds',
        'For 10/30 mm and 0/75 degrees, click the actual centroid of every panel in each view; traverse the panel control with arrows.',
        'All 48 face clicks select the intended shared panel; handles and selected outlines do not steal a neighbor.',async () => {
          for (const pitch of [10,30]) for (const tilt of [0,75]) {
            await numeric(pitch,tilt);
            for (const view of ['flat','folded']) for (let index=1;index<=6;index++) {
              const face = page.locator('#'+view+' [data-panel="'+index+'"]');
              await face.scrollIntoViewIfNeeded();
              const point = await face.evaluate(node => {
                const points = [...node.points];
                const center = new DOMPoint(points.reduce((s,p)=>s+p.x,0)/4,points.reduce((s,p)=>s+p.y,0)/4).matrixTransform(node.getScreenCTM());
                return {x:center.x,y:center.y};
              });
              await page.mouse.click(point.x,point.y);
              for (const other of ['flat','folded'])
                assert.equal(await page.locator('#'+other+' .active').getAttribute('data-panel'),String(index));
            }
          }
          await page.locator('#pick').press('ArrowUp');
          assert.equal((await state()).selected,'5');
          await capture(viewport.width+'-picking','Click every face centroid at the pitch and tilt limits; select panel 5 with ArrowUp.',
            'Panel 5 is selected in both views at 30 mm / 75 degrees.');
        });
      await scenario('measurement drafts and interleaved undo',
        'Attach/undo the measurement during numeric and both direct previews; cancel. Interleave a measurement with two view edits and undo in order.',
        'Measurement attachment preserves drafts; geometry edits share one history and leave selection and measurement state intact.',async () => {
          const initial = await state();
          for (const id of [null,'flat-pitch','folded-tilt']) {
            if (id) await dragTo(id,id === 'flat-pitch' ? 24.5 : 20,id === 'folded-tilt' ? 60 : 30);
            else { await page.locator('#pitch').fill('24.5'); await page.locator('#tilt').fill('60'); }
            const draft = await state();
            await page.locator('#measure').click();
            const attached = await state();
            assert.deepEqual(attached.inputs,draft.inputs);
            assert.deepEqual(attached.faces,draft.faces);
            const shownHeight = id === 'folded-tilt' ? '17.3' : id === 'flat-pitch' ? '12.3' : '10.0';
            assert.ok(attached.note.includes(shownHeight+' mm high'));
            await undo();
            assert.deepEqual(await state(),draft);
            await cleanHistory();
            await page.keyboard.press('Escape');
            assert.deepEqual(await state(),initial);
          }
          await page.locator('#measure').click();
          const measured = await state();
          await dragTo('flat-pitch',24.5,30); await apply();
          const pitched = await state();
          await dragTo('folded-tilt',24.5,60); await page.locator('#folded-tilt').press('Enter');
          assert.match((await state()).note,/21.2 mm high/);
          await capture(viewport.width+'-linked-measurement','Measure crease 3, drag flat pitch to 24.5 mm, then folded tilt to 60 degrees; apply each.',
            'Both views, 147 mm sheet, 73.5 mm span, 21.2 mm rise and the trace follow the shared patch.');
          await undo(); assert.deepEqual(await state(),pitched);
          await undo(); assert.deepEqual(await state(),measured);
          await undo(); assert.deepEqual(await state(),initial);
          await cleanHistory();
        });
    }
    const deck = path.resolve(__dirname,'../../artifacts/demo-slideshows/v11-foldable-motif/index.html');
    for (const viewport of [{width:1180,height:900},{width:390,height:844}]) {
      await page.setViewportSize(viewport);
      await page.goto(pathToFileURL(deck).href);
      const imageResults = await page.locator('img').evaluateAll(async images => {
        await Promise.all(images.map(image=>image.decode()));
        return images.every(image=>image.naturalWidth>0);
      });
      assert.ok(imageResults);
      assert.equal(await page.locator('#counter').innerText(),'1 / 6');
      await page.locator('#next').click();
      assert.equal(await page.locator('#counter').innerText(),'2 / 6');
      await page.keyboard.press('ArrowRight');
      assert.equal(await page.locator('#counter').innerText(),'3 / 6');
      await page.locator('#prev').click();
      assert.equal(await page.locator('#counter').innerText(),'2 / 6');
      const contact = page.locator('.contact').locator('..');
      if (!(await contact.evaluate(node=>node.open))) await contact.locator('summary').click();
      await page.locator('[data-jump="5"]').click();
      assert.equal(await page.locator('#counter').innerText(),'6 / 6');
      report.scenarios.push({name:'original offline deck',viewport,steps:'Decode all embedded images; Next, ArrowRight, Previous and thumbnail jump.',
        expected:'Six original slides decode and navigation updates the visible slide.',observed:'Six original slides decode and navigation updates the visible slide.',result:'pass'});
    }
    assert.deepEqual(report.errors,[]);
    console.log('PASS original offline deck; '+report.scenarios.length+' scenarios, no page errors.');
  } finally {
    fs.writeFileSync(path.join(output,'results.json'),JSON.stringify(report,null,2)+'\n');
    await browser.close();
  }
}
check().catch(error => {console.error(error);process.exitCode=1;});
