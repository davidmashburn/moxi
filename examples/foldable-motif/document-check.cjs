// Existing local Playwright + Chrome; no server, installs or network.
// Usage: node document-check.cjs BUILT.html OUTPUT_DIRECTORY
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
  assert.ok(html && output,'Provide built HTML and a new evidence directory');
  fs.mkdirSync(output,{recursive:true});
  const root = path.resolve(__dirname,'../..');
  const url = pathToFileURL(path.resolve(html)).href;
  const sha256 = file => createHash('sha256').update(fs.readFileSync(file)).digest('hex');
  const git = (...args) => execFileSync('git',args,{cwd:root,encoding:'utf8'}).trim();
  const sources = ['editor.html','build.sh','project.cpp','document-check.cjs','check.cjs','editing-check.cjs']
    .map(file=>'examples/foldable-motif/'+file).concat(['native/spatial/core.cpp','native/spatial/core.hpp']);
  const historical = git('ls-files','artifacts/demo-slideshows/v11-foldable-motif').split('\n')
    .filter(file=>!file.includes('/saved-document/'));
  const report = {captured_at:new Date().toISOString(),base_revision:'ae1663fe323b6955a6a5d96aae8cad00420b68d2',
    source_revision:git('rev-parse','HEAD'),source_status:git('status','--short','--','examples/foldable-motif'),
    source_sha256:Object.fromEntries(sources.map(file=>[file,sha256(path.join(root,file))])),
    built_html_sha256:sha256(html),
    historical_evidence_files:historical.length,
    historical_evidence_tree_sha256:createHash('sha256').update(historical.map(file=>file+' '+sha256(path.join(root,file))).join('\n')).digest('hex'),
    host:{platform:os.platform(),release:os.release(),arch:os.arch()},backend:'Offline file URL, headless Google Chrome, SVG',
    fixture:'Six rigid panels, fixed 40 mm depth; synthetic data only',device_scale_factor:1,
    fresh_browser_method:'Close the exporting Chrome process before launching importing Chrome; no shared context or storage',
    read_failure_method:'Test-only Blob.text fault for unreadable.json; all imports use the visible button and file chooser',
    scenarios:[],screenshots:[],documents:[],errors:[],network_requests:[]};
  let browser;
  const launch = async viewport => {
    browser = await chromium.launch({channel:'chrome',headless:true});
    report.browser = browser.version();
    const context = await browser.newContext({viewport,deviceScaleFactor:1,offline:true,acceptDownloads:true});
    await context.addInitScript(() => {
      const original = Blob.prototype.text;
      Blob.prototype.text = function() {
        if (this instanceof File && this.name === 'unreadable.json')
          return Promise.reject(new DOMException('Synthetic file read failure.','NotReadableError'));
        return original.call(this);
      };
    });
    const page = await context.newPage();
    page.on('pageerror',error=>report.errors.push(error.message));
    page.on('console',message=>{if (message.type() === 'error') report.errors.push(message.text());});
    page.on('request',request=>{if (/^https?:/.test(request.url())) report.network_requests.push(request.url());});
    await page.goto(url);
    return page;
  };
  const state = page => page.evaluate(() => ({
    faces:['flat','folded'].map(id=>[...document.querySelectorAll('#'+id+' polygon')].map(p=>({panel:Number(p.dataset.panel),points:p.getAttribute('points'),active:p.classList.contains('active')}))),
    selected:document.querySelector('#pick').value,
    inputs:['pitch','tilt','sweep'].map(id=>document.getElementById(id).value),
    comparison:document.querySelector('#comparison').innerText,
    sheet:document.querySelector('#sheet').textContent,
    adjacency:document.querySelector('#adjacency').textContent,
    note:document.querySelector('#flat .drawing text:last-child').textContent,
    trace:document.querySelector('#folded polyline')?.getAttribute('points') || null,
    measureDisabled:document.querySelector('#measure').disabled,
    undoDisabled:document.querySelector('#undo').disabled
  }));
  const visual = snapshot => {const {undoDisabled,...rest} = snapshot; return rest;};
  const apply = page => page.getByRole('button',{name:'Apply edit',exact:true}).click();
  const undo = page => page.getByRole('button',{name:'Undo',exact:true}).click();
  const edit = async (page,pitch,tilt) => {
    await page.locator('#pitch').fill(String(pitch));
    await page.locator('#tilt').fill(String(tilt));
    await apply(page);
  };
  const imported = async (page,file) => {
    const chooserPromise = page.waitForEvent('filechooser');
    await page.getByRole('button',{name:'Import document',exact:true}).click();
    const chooser = await chooserPromise;
    await chooser.setFiles(file ? [file] : []);
    await page.waitForFunction(()=>!document.querySelector('#import-document').disabled);
    return page.locator('#document-status').innerText();
  };
  const exported = async (page,file) => {
    const downloadPromise = page.waitForEvent('download');
    // Keyboard activation verifies the normal button route as well as pointer import.
    await page.getByRole('button',{name:'Export document',exact:true}).focus();
    await page.keyboard.press('Enter');
    const download = await downloadPromise;
    assert.equal(download.suggestedFilename(),'accordion-v1.json');
    await download.saveAs(file);
    assert.equal(await download.failure(),null);
    return JSON.parse(fs.readFileSync(file,'utf8'));
  };
  const patch = async (page,doc) => {
    const actual = await state(page);
    assert.deepEqual(actual.inputs,[String(doc.pitch),String(doc.tilt),String(doc.tilt)]);
    assert.equal(actual.selected,String(doc.selectedPanel));
    for (const faces of actual.faces) assert.deepEqual(faces.filter(face=>face.active).map(face=>face.panel),[doc.selectedPanel]);
    assert.equal(actual.measureDisabled,doc.measuring);
    assert.equal(Boolean(actual.trace),doc.measuring);
    const row = await page.locator('#comparison tr').last().innerText();
    const angle = doc.tilt*Math.PI/180;
    const values = ['Current',doc.pitch+' mm',doc.tilt+'°',(6*doc.pitch*Math.cos(angle)).toFixed(1)+' mm',
      (doc.pitch*Math.sin(angle)).toFixed(1)+' mm'];
    assert.deepEqual(row.split(/\s*\t\s*/),values);
    if (doc.measuring) assert.match(actual.note,new RegExp((doc.pitch*Math.sin(angle)).toFixed(1).replace('.','\\.')+' mm high'));
  };
  const capture = async (page,name,steps,expected) => {
    const file = name+'.png';
    await page.screenshot({path:path.join(output,file),fullPage:true});
    report.screenshots.push({file,viewport:page.viewportSize(),steps,expected,observed:await state(page)});
  };
  const scenario = async (page,name,steps,expected,run) => {
    const entry = {name,viewport:page.viewportSize(),steps,expected,result:'fail'};
    report.scenarios.push(entry);
    try {
      await run();
      assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth <= innerWidth),'No horizontal overflow');
      entry.observed = expected;
      entry.result = 'pass';
      console.log('PASS '+page.viewportSize().width+' '+name);
    } catch (error) {entry.observed = error.message; throw error;}
  };
  const fixture = (name,data) => {
    const file = path.join(output,name);
    fs.writeFileSync(file,typeof data === 'string' ? data : JSON.stringify(data));
    return file;
  };
  const baseline = {format:'moxi-accordion',version:1,pitch:20,tilt:30,selectedPanel:1,measuring:false};
  const saved = {...baseline,pitch:24.5,tilt:60,selectedPanel:5,measuring:true};
  try {
    for (const viewport of [{width:1180,height:900},{width:390,height:844}]) {
      let page = await launch(viewport);
      const prefix = String(viewport.width);
      const savedFile = path.join(output,prefix+'-document.json');
      let savedVisual;
      await scenario(page,'committed-only export with pending preview',
        'Apply 24.5 mm / 60 degrees, select panel 5, measure crease 3; draft 27.1 / 22 and preview one tilt step; export via Enter.',
        'Downloaded v1 JSON contains committed 24.5 / 60, panel 5 and measurement; pending preview and undo history are untouched.',async () => {
          await edit(page,saved.pitch,saved.tilt);
          await page.locator('#pick').selectOption(String(saved.selectedPanel));
          await page.locator('#measure').click();
          await patch(page,saved);
          savedVisual = visual(await state(page));
          await page.locator('#pitch').fill('27.1');
          await page.locator('#tilt').fill('22');
          await page.locator('#folded-tilt').press('ArrowUp');
          const before = await state(page);
          assert.match(before.comparison,/Preview/);
          assert.deepEqual(await exported(page,savedFile),saved);
          assert.deepEqual(await state(page),before);
          report.documents.push({file:path.basename(savedFile),sha256:sha256(savedFile),contents:saved});
          await capture(page,prefix+'-export-preview','Export while a 27.1 mm / 23 degree preview is pending.','Preview remains; downloaded file holds the committed 24.5 mm / 60 degree configuration.');
          await undo(page);
          assert.equal((await state(page)).measureDisabled,false);
          assert.deepEqual((await state(page)).inputs,before.inputs);
          assert.match((await state(page)).comparison,/Preview/);
          await undo(page);
          await patch(page,{...baseline,selectedPanel:5});
          assert.equal((await state(page)).undoDisabled,true);
          // Export from an invalid numeric draft must also preserve it and the empty history.
          await page.locator('#pitch').fill('9');
          const invalid = await state(page);
          const invalidExport = path.join(output,prefix+'-invalid-draft-export.json');
          assert.deepEqual(await exported(page,invalidExport),{...baseline,selectedPanel:5});
          assert.deepEqual(await state(page),invalid);
        });
      // A genuinely fresh browser process, not a reload, page or context.
      await browser.close();
      browser = null;
      page = await launch(viewport);
      await scenario(page,'fresh browser import and reload/reimport',
        'Close exporting Chrome; launch new offline Chrome. Import the actual download through the button/file chooser; edit pitch from flat and tilt from folded using handle keys, then undo; undo import; reload/reimport.',
        'Both views, selection, exact values, comparison, measurement and trace match export. Imported work remains editable with shared undo; import is one undo step and works after reload.',async () => {
          await patch(page,baseline);
          assert.equal((await state(page)).undoDisabled,true);
          assert.match(await imported(page,savedFile),/^Document imported/);
          await patch(page,saved);
          assert.deepEqual(visual(await state(page)),savedVisual);
          await capture(page,prefix+'-fresh-import','Import the downloaded file in a new offline Chrome process.','Panel 5, 24.5 mm / 60 degrees, 73.5 mm span, 21.2 mm rise and crease trace restored in both views.');
          await page.locator('#flat-pitch').press('ArrowUp');
          await page.locator('#flat-pitch').press('Enter');
          await patch(page,{...saved,pitch:24.6});
          await page.locator('#folded-tilt').press('ArrowDown');
          await page.locator('#folded-tilt').press('Enter');
          await patch(page,{...saved,pitch:24.6,tilt:59});
          await undo(page);
          await patch(page,{...saved,pitch:24.6});
          await undo(page);
          await patch(page,saved);
          await undo(page);
          await patch(page,baseline);
          assert.equal((await state(page)).undoDisabled,true);
          await imported(page,savedFile);
          await page.reload();
          await patch(page,baseline);
          assert.equal((await state(page)).undoDisabled,true);
          assert.match(await imported(page,savedFile),/^Document imported/);
          await patch(page,saved);
        });
      await scenario(page,'atomic import, draft clearing and linked undo',
        'Reload; commit 18.2 / 12, select panel 2; preview 21.3 / 10; import saved document; undo import, then undo earlier edit.',
        'Import clears the preview. Undo restores previous committed geometry, panel 2 and detached measurement; next undo reaches baseline, with no phantom draft step.',async () => {
          await page.reload();
          await edit(page,18.2,12);
          await page.locator('#pick').selectOption('2');
          const prior = await state(page);
          await page.locator('#pitch').fill('21.3');
          await page.locator('#tilt').fill('9');
          await page.locator('#folded-tilt').press('ArrowUp');
          assert.match((await state(page)).comparison,/Preview/);
          await imported(page,savedFile);
          await patch(page,saved);
          await undo(page);
          assert.deepEqual(await state(page),prior);
          await capture(page,prefix+'-undo-import','Undo an import that replaced a pending preview.','The prior committed 18.2 mm / 12 degree patch, panel 2 and detached measurement return; discarded draft is not resurrected.');
          await undo(page);
          await patch(page,{...baseline,selectedPanel:2});
          assert.equal((await state(page)).undoDisabled,true);
          // Equal-geometry and identical imports still each have a whole-document undo.
          const sameGeometry = fixture('same-geometry.json',{...baseline,selectedPanel:6,measuring:true});
          await page.locator('#tilt').fill('90');
          await imported(page,sameGeometry);
          await patch(page,{...baseline,selectedPanel:6,measuring:true});
          await imported(page,sameGeometry);
          await undo(page);
          await patch(page,{...baseline,selectedPanel:6,measuring:true});
          await undo(page);
          await patch(page,{...baseline,selectedPanel:2});
          assert.equal((await state(page)).undoDisabled,true);
        });
      await scenario(page,'invalid documents, picker cancellation, read failure and recovery',
        'Commit 18.2 / 12, select panel 2, measure; retain an invalid numeric draft while trying malformed, foreign, incomplete, oversized and out-of-range documents plus a synthetic read failure. Repeat under a preview, correct the same file and import it.',
        'All rejected imports preserve both views, controls, measurement, selection, pending edits and history. Cancellation is inert; same-file retry succeeds; undo order remains intact.',async () => {
          await page.reload();
          await edit(page,18.2,12);
          await page.locator('#pick').selectOption('2');
          await page.locator('#measure').click();
          await page.locator('#pitch').fill('9');
          const rejectedDraft = await state(page);
          await imported(page,null);
          assert.deepEqual(await state(page),rejectedDraft);
          const invalids = [
            ['malformed','{'],['empty',''],['null','null'],['array','[]'],['primitive','42'],
            ['missing field',((({measuring,...rest})=>rest)(saved))],
            ['extra field',{...saved,unknown:true}],['foreign format',{...saved,format:'another-document'}],
            ['future version',{...saved,version:2}],['string version',{...saved,version:'1'}],
            ['low pitch',{...saved,pitch:9.9}],['high pitch',{...saved,pitch:30.1}],
            ['pitch precision',{...saved,pitch:20.01}],['string pitch',{...saved,pitch:'20'}],
            ['null pitch',{...saved,pitch:null}],['boolean pitch',{...saved,pitch:true}],
            ['infinite pitch',JSON.stringify(saved).replace('24.5','1e400')],
            ['low tilt',{...saved,tilt:-1}],['high tilt',{...saved,tilt:76}],['fraction tilt',{...saved,tilt:30.5}],
            ['string tilt',{...saved,tilt:'30'}],['null tilt',{...saved,tilt:null}],
            ['low panel',{...saved,selectedPanel:0}],['high panel',{...saved,selectedPanel:7}],
            ['fraction panel',{...saved,selectedPanel:1.5}],['string panel',{...saved,selectedPanel:'1'}],
            ['string measurement',{...saved,measuring:'false'}],['numeric measurement',{...saved,measuring:1}],
            ['null measurement',{...saved,measuring:null}],['oversized',JSON.stringify(saved)+' '.repeat(16384)]
          ];
          const results = [];
          for (const [name,data] of invalids) {
            const file = fixture('retry.json',data);
            const status = await imported(page,file);
            assert.match(status,/^Import rejected\./,name);
            assert.deepEqual(await state(page),rejectedDraft,name);
            results.push({name,status,result:'pass'});
          }
          await capture(page,prefix+'-rejected-import','Reject an oversized document with a 9 mm numeric draft pending, after the malformed/schema/type/range cases.','Last valid measured geometry, panel 2, invalid draft and history remain intact; the size-limit error is reported.');
          const failure = await imported(page,fixture('unreadable.json',saved));
          assert.match(failure,/Import rejected.*Synthetic file read failure/);
          assert.deepEqual(await state(page),rejectedDraft);
          report.scenarios.at(-1).invalid_cases = results;
          await page.locator('#pitch').fill('21.3');
          await page.locator('#folded-tilt').press('ArrowUp');
          const preview = await state(page);
          assert.match(preview.comparison,/Preview/);
          assert.match(await imported(page,fixture('retry.json','{')),/^Import rejected/);
          assert.deepEqual(await state(page),preview);
          assert.match(await imported(page,fixture('retry.json',saved)),/^Document imported/);
          await patch(page,saved);
          await undo(page);
          await patch(page,{...baseline,pitch:18.2,tilt:12,selectedPanel:2,measuring:true});
          await undo(page);
          await patch(page,{...baseline,pitch:18.2,tilt:12,selectedPanel:2});
          await undo(page);
          await patch(page,{...baseline,selectedPanel:2});
          assert.equal((await state(page)).undoDisabled,true);
        });
      await scenario(page,'boundary documents and measurement false',
        'Import and re-export pitch/tilt endpoints, both measurement states and panels 1/6 using version 1 JSON.',
        'Supported bounds and tenths round-trip without coercion; measured and unmeasured documents update linked views and undo cleanly.',async () => {
          await page.reload();
          const priorStates = [];
          for (const doc of [{...baseline,pitch:10,tilt:0,selectedPanel:6,measuring:true},
            {...baseline,pitch:30,tilt:75},{...baseline,pitch:16.1,tilt:1,selectedPanel:6}]) {
            priorStates.push(await state(page));
            await imported(page,fixture('boundary.json',doc));
            await patch(page,doc);
            const outputFile = path.join(output,'boundary-export.json');
            assert.deepEqual(await exported(page,outputFile),doc);
            if (!doc.measuring) {
              const beforeMeasurement = await state(page);
              await page.locator('#measure').click();
              await patch(page,{...doc,measuring:true});
              await undo(page);
              assert.deepEqual(await state(page),beforeMeasurement);
            }
          }
          for (const prior of priorStates.reverse()) {
            await undo(page);
            assert.deepEqual(await state(page),prior);
          }
        });
      await browser.close();
      browser = null;
    }
    assert.deepEqual(report.errors,[]);
    assert.deepEqual(report.network_requests,[]);
    console.log('PASS '+report.scenarios.length+' scenarios; 60 invalid-document cases; no page/console errors or HTTP(S) requests.');
  } finally {
    if (browser) await browser.close();
    report.finished_at = new Date().toISOString();
    fs.writeFileSync(path.join(output,'results.json'),JSON.stringify(report,null,2)+'\n');
    // Inputs used for rejection/recovery are synthetic and regenerated on every run.
    for (const file of ['retry.json','unreadable.json','same-geometry.json','boundary.json','boundary-export.json'])
      fs.rmSync(path.join(output,file),{force:true});
  }
}
check().catch(error=>{console.error(error);process.exitCode=1;});
