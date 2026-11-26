// Normal Chrome input replay. NODE_PATH may point to an external Playwright
// installation; neither the browser dependency nor captures need enter source.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {pathToFileURL} = require('node:url');
const {execFileSync} = require('node:child_process');
const {createHash} = require('node:crypto');
const {chromium} = require('playwright');

async function check() {
  const [html, destination] = process.argv.slice(2);
  if (!html || !destination) throw new Error('usage: check.cjs BUILT.html CAPTURE_DIRECTORY');
  const root = path.resolve(__dirname, '../..'), output = path.resolve(destination);
  fs.mkdirSync(output, {recursive:true});
  const git = args => execFileSync('git', args, {cwd:root, encoding:'utf8'}).trim();
  const hash = file => createHash('sha256').update(fs.readFileSync(file)).digest('hex');
  const manifest = {
    capturedAt:new Date().toISOString(), revision:git(['rev-parse','HEAD']),
    base:'033596ddb576b09b48234733b45a283b4c3fecae',
    sourceState:git(['status','--short','--','examples/equation-linkage']),
    sourceHashes:Object.fromEntries(['model.mjs','app.mjs','editor.html','build.py','check.cjs','model.test.mjs'].map(file => [file,hash(path.join(__dirname,file))])),
    htmlHash:hash(html), url:pathToFileURL(path.resolve(html)).href,
    browser:null, viewport:{width:1280,height:900}, role:'synthetic local fixture; no account',
    offline:true, scenarios:[], limits:['VoiceOver paused; no screen-reader trial', 'No native host, physical device, material or independent usability trial', 'No persistence; reload intentionally restores the starter'],
  };
  const browser = await chromium.launch({channel:'chrome', headless:true});
  manifest.browser = browser.version();
  const context = await browser.newContext({viewport:manifest.viewport, deviceScaleFactor:1, offline:true});
  const page = await context.newPage();
  const errors = [], failed = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('requestfailed', request => failed.push({url:request.url(),error:request.failure()}));
  const value = id => page.locator('#'+id).inputValue();
  const source = () => value('equation-text');
  const geometry = () => page.locator('#bar').evaluate(line => [line.getAttribute('x2'),line.getAttribute('y2')]);
  const capture = async file => {
    await page.screenshot({path:path.join(output,file),fullPage:true});
    const scenario=manifest.scenarios.at(-1);
    (scenario.screenshots ||= []).push(file);
    return file;
  };
  async function scenario(name, steps, expected, run, image) {
    const item = {name,steps,expected,viewport:page.viewportSize()};
    manifest.scenarios.push(item);
    try {
      item.observed = await run();
      item.outcome = 'pass';
      if (image) item.screenshot = await capture(image);
      console.log('PASS ' + name);
    } catch (error) {
      item.outcome = 'fail'; item.observed = error.message;
      item.screenshot = await capture('failure.png');
      throw error;
    }
  }
  const initial = 'L = 100.00 mm\nθ = 30.0 deg\nx = L * cos(θ)\ny = L * sin(θ)\n';
  const precise = '\tL  =  00100.5000 mm # length\nθ = +030.000 deg\nx = L · cos(θ)\ny = L * sin(θ)\n';
  const edited = precise.replace('00100.5000','00120.2500').replace('+030.000','+045.000');
  try {
    await page.goto(manifest.url);
    await scenario('equation surface exists', 'Open the generated consumer.', 'Text and structured numeric leaves are present; initial pose is 30°.', async () => {
      assert.equal(await page.locator('#equation-text').count(),1,'Missing editable equation source on baseline');
      assert.equal(await source(),initial);
      assert.equal(await value('layout-length'),'100.00');
      assert.equal(await value('layout-angle'),'30.0');
      return 'Four equations, two editable leaves and linked arm loaded.';
    },'01-start.png');

    await scenario('lossless text to layout to text', 'Choose Equation text; enter exact whitespace, comments and padded decimals; apply; switch layout/text twice.', 'Source bytes and numeric spelling are unchanged; geometry uses L=100.5, θ=30.', async () => {
      await page.getByRole('button',{name:'Equation text',exact:true}).click();
      await page.locator('#equation-text').fill(precise);
      await page.getByRole('button',{name:'Apply change'}).click();
      await page.getByRole('button',{name:'Structured layout'}).click();
      assert.equal(await value('layout-length'),'00100.5000');
      assert.equal(await value('layout-angle'),'+030.000');
      await page.getByRole('button',{name:'Equation text',exact:true}).click();
      assert.equal(await source(),precise);
      return {exactSource:await source(),coordinates:await page.locator('#coordinates').textContent()};
    },'02-exact-text.png');

    await scenario('two structured edits and cancel', 'Switch to layout; edit length, then angle without applying between them; press Escape.', 'Both leaf edits coexist; cancel restores the exact source and endpoint.', async () => {
      const before = await geometry();
      await page.getByRole('button',{name:'Structured layout'}).click();
      await page.locator('#layout-length').fill('00120.2500');
      await page.locator('#layout-angle').fill('+045.000');
      assert.equal(await source(),edited);
      assert.notDeepEqual(await geometry(),before);
      await page.keyboard.press('Escape');
      assert.equal(await source(),precise);
      assert.deepEqual(await geometry(),before);
      return 'Sibling length edit retained while editing angle; Escape restored source and geometry.';
    });

    await scenario('structured commit and shared history', 'Edit both layout leaves; apply once; Undo then Redo.', 'One undo restores both precise numbers and geometry; redo restores the joint change.', async () => {
      const before = await geometry();
      await page.locator('#layout-length').fill('00120.2500');
      await page.locator('#layout-angle').fill('+045.000');
      await page.getByRole('button',{name:'Apply change'}).click();
      const after = await geometry();
      await page.getByRole('button',{name:'Undo',exact:true}).click();
      assert.equal(await source(),precise); assert.deepEqual(await geometry(),before);
      await page.getByRole('button',{name:'Redo',exact:true}).click();
      assert.equal(await source(),edited); assert.deepEqual(await geometry(),after);
      return {exactSource:await source(),coordinates:await page.locator('#coordinates').textContent()};
    },'03-structured-edit.png');

    await scenario('incomplete structured leaf recovery', 'Clear length; type an incomplete value; repair it in the same leaf; edit its sibling; cancel.', 'Incomplete text remains editable, cannot apply, and leaves committed geometry intact. Repair retains both edits.', async () => {
      const before = await geometry();
      await page.locator('#layout-length').fill('');
      assert.equal(await page.locator('#apply').isDisabled(),true);
      assert.equal(await value('layout-length'),'');
      assert.deepEqual(await geometry(),before);
      await page.locator('#layout-length').pressSequentially('1..');
      assert.equal(await value('layout-length'),'1..');
      await page.locator('#layout-length').fill('00125.7500');
      await page.locator('#layout-angle').fill('+040.000');
      assert.equal(await source(),edited.replace('00120.2500','00125.7500').replace('+045.000','+040.000'));
      await page.getByRole('button',{name:'Cancel preview'}).click();
      assert.equal(await source(),edited); assert.deepEqual(await geometry(),before);
      return 'Hole and malformed number retained; repair and sibling edit succeeded; cancel restored the applied state.';
    });

    await scenario('malformed source and layout fallback', 'Enter an unsupported relation with literal HTML; switch layout/text; try to apply; cancel.', 'Exact unsupported text survives; it is inert, apply is disabled and the endpoint stays at the applied state.', async () => {
      const before = await geometry();
      const bad = edited.replace('sin(θ)','sin(θ) + <img src=x onerror=alert(1)>');
      await page.getByRole('button',{name:'Equation text',exact:true}).click();
      await page.locator('#equation-text').fill(bad);
      await page.getByRole('button',{name:'Structured layout'}).click();
      assert.equal(await page.locator('#layout pre').textContent(),bad);
      assert.equal(await page.locator('#layout img').count(),0);
      assert.equal(await page.locator('#apply').isDisabled(),true);
      assert.deepEqual(await geometry(),before);
      await capture('04-invalid-layout.png');
      await page.getByRole('button',{name:'Equation text',exact:true}).click();
      assert.equal(await source(),bad);
      await page.getByRole('button',{name:'Cancel preview'}).click();
      assert.equal(await source(),edited);
      return 'Unsupported draft retained as inert text in both representations; cancel restored exact equations.';
    });

    await scenario('domain rejection', 'Enter 39.999 mm, 140.001 mm and 91° in text; cancel each draft.', 'Each violates a named bound; cannot apply or move the arm.', async () => {
      const before = await geometry();
      for (const invalid of [edited.replace('00120.2500','39.999'),edited.replace('00120.2500','140.001'),edited.replace('+045.000','91')]) {
        await page.locator('#equation-text').fill(invalid);
        assert.equal(await source(),invalid);
        assert.equal(await page.locator('#apply').isDisabled(),true);
        assert.equal(await page.locator('#pose').isDisabled(),true);
        assert.deepEqual(await geometry(),before);
        await page.getByRole('button',{name:'Cancel preview'}).click();
      }
      return 'All three bounds rejected; source retained until explicit cancel.';
    });

    await scenario('keyboard geometry preview and cancellation', 'Focus the arm; press Up three times; inspect text/layout; press Escape.', 'Only theta becomes +048.000; Escape restores +045.000 and all other text exactly.', async () => {
      const before = await geometry();
      await page.locator('#mechanism').focus();
      await page.keyboard.press('ArrowUp'); await page.keyboard.press('ArrowUp'); await page.keyboard.press('ArrowUp');
      assert.equal(await source(),edited.replace('+045.000','+048.000'));
      await page.getByRole('button',{name:'Structured layout'}).click();
      assert.equal(await value('layout-angle'),'+048.000');
      await page.keyboard.press('Escape');
      assert.equal(await source(),edited); assert.deepEqual(await geometry(),before);
      return 'Three keys created one cancellable angle preview; exact non-angle source retained.';
    });

    await scenario('slider keyboard commit and undo', 'Focus range; End to 90°; apply; Undo.', 'Whole-degree endpoint at 90°; exact padded angle updates; undo restores both equations and geometry.', async () => {
      const before = await geometry();
      await page.locator('#pose').focus(); await page.keyboard.press('End');
      assert.equal(await source(),edited.replace('+045.000','+090.000'));
      await capture('05-angle-preview.png');
      await page.getByRole('button',{name:'Apply change'}).click();
      await page.getByRole('button',{name:'Undo',exact:true}).click();
      assert.equal(await source(),edited); assert.deepEqual(await geometry(),before);
      return '90° preview applied as one history entry; undo restored the exact prior document.';
    });

    const pointAt = angle => page.locator('#mechanism').evaluate((svg,angle) => {
      const tip = svg.querySelector('#tip'), bar = svg.querySelector('#bar');
      const origin = {x:Number(bar.getAttribute('x1')),y:Number(bar.getAttribute('y1'))};
      const samples = svg.querySelector('#trace').points;
      const r = angle*Math.PI/180;
      const local = angle === null ? new DOMPoint(Number(tip.getAttribute('cx')),Number(tip.getAttribute('cy'))) :
        new DOMPoint(origin.x+(samples.getItem(0).x-origin.x)*Math.cos(r),origin.y+(samples.getItem(samples.numberOfItems-1).y-origin.y)*Math.sin(r));
      const p=local.matrixTransform(svg.getScreenCTM()); return {x:p.x,y:p.y};
    },angle);
    await scenario('pointer drag, commit and shared undo', 'Drag the endpoint normally to 60°; release; apply; inspect source; undo.', 'Preview updates only theta; a single undo restores exact text and endpoint.', async () => {
      const before = await geometry();
      const start=await pointAt(null), end=await pointAt(60);
      await page.mouse.move(start.x,start.y); await page.mouse.down(); await page.mouse.move(end.x,end.y,{steps:12}); await page.mouse.up();
      assert.equal(await source(),edited.replace('+045.000','+060.000'));
      assert.equal(await value('layout-angle'),'+060.000');
      await capture('06-pointer-preview.png');
      await page.getByRole('button',{name:'Apply change'}).click();
      await page.getByRole('button',{name:'Equation text',exact:true}).click();
      assert.equal(await source(),edited.replace('+045.000','+060.000'));
      await page.getByRole('button',{name:'Undo',exact:true}).click();
      assert.equal(await source(),edited); assert.deepEqual(await geometry(),before);
      return 'Normal mouse drag previewed 60°, applied once, and undid to exact text/geometry.';
    });

    await scenario('pointer interruption, focus loss and no-op', 'Preview a pose; deliver pointercancel and window blur separately; click the unchanged endpoint.', 'Both interruption routes restore exact equations; a no-op cannot add a history entry.', async () => {
      await page.locator('#mechanism').focus(); await page.keyboard.press('ArrowUp');
      await page.locator('#mechanism').dispatchEvent('pointercancel');
      assert.equal(await source(),edited);
      await page.locator('#mechanism').focus(); await page.keyboard.press('ArrowUp');
      await page.evaluate(()=>window.dispatchEvent(new Event('blur')));
      assert.equal(await source(),edited);
      const unchanged=await pointAt(null); await page.mouse.click(unchanged.x,unchanged.y);
      assert.equal(await source(),edited); assert.equal(await page.locator('#apply').isDisabled(),true);
      return 'Synthetic interruption events cancelled; normal no-op click retained source spelling.';
    });

    await scenario('Moxi trace projection agreement', 'Compare all 91 displayed Moxi samples with analytic quarter-circle projection.', 'Each point agrees within 0.02 SVG pixels.', async () => {
      const scaleDifference = await page.locator('#trace').evaluate(trace => {
        const points=Array.from(trace.points), bar=document.querySelector('#bar');
        return Math.abs((points[0].x-Number(bar.getAttribute('x1'))) + (points.at(-1).y-Number(bar.getAttribute('y1'))));
      });
      assert.ok(scaleDifference<.02,`Geometry must use equal x/y scales; difference ${scaleDifference}`);
      const error = await page.locator('#trace').evaluate(trace => {
        const points=Array.from(trace.points), bar=document.querySelector('#bar');
        const ox=Number(bar.getAttribute('x1')),oy=Number(bar.getAttribute('y1'));
        return Math.max(...points.map((p,i)=>Math.hypot(p.x-(ox+(points[0].x-ox)*Math.cos(i*Math.PI/180)),p.y-(oy+(points.at(-1).y-oy)*Math.sin(i*Math.PI/180)))));
      });
      assert.ok(error<.02,`projection error ${error}`); return {samples:91,maxPixelError:error};
    });

    await scenario('fractional endpoint no-op', 'Apply a precise fractional angle; click its unchanged endpoint; Undo.', 'A no-op click preserves the fractional token exactly; Undo restores the preceding document.', async () => {
      const fractional=edited.replace('+045.000','+045.1250');
      await page.locator('#equation-text').fill(fractional);
      await page.getByRole('button',{name:'Apply change'}).click();
      const unchanged=await pointAt(null); await page.mouse.click(unchanged.x,unchanged.y);
      assert.equal(await source(),fractional);
      assert.equal(await page.locator('#apply').isDisabled(),true);
      await page.getByRole('button',{name:'Undo',exact:true}).click();
      assert.equal(await source(),edited);
      return 'Precise fractional angle unchanged by an endpoint click; undo restored the preceding text.';
    });

    await scenario('narrow layout and edit/undo', 'Resize to 390×844; enter and apply a text length edit; undo; inspect layout.', 'No document overflow; both representations remain operable, with exact undo.', async () => {
      await page.setViewportSize({width:390,height:844});
      await page.locator('#equation-text').fill(edited.replace('00120.2500','00110.1250'));
      await page.getByRole('button',{name:'Apply change'}).click();
      await page.getByRole('button',{name:'Undo',exact:true}).click();
      assert.equal(await source(),edited);
      await page.getByRole('button',{name:'Structured layout'}).click();
      assert.equal(await value('layout-length'),'00120.2500');
      assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
      return '390px layout fits and text edit/undo restores the precise layout leaf.';
    },'07-narrow.png');

    await scenario('session-only reload and browser errors', 'Reload the offline consumer.', 'Starter returns; no uncaught browser errors or failed requests.', async () => {
      await page.reload();
      assert.equal(await source(),initial);
      assert.deepEqual(errors,[]); assert.deepEqual(failed,[]);
      return {errors,failedRequests:failed,reloadedSource:await source()};
    });
  } finally {
    manifest.finishedAt=new Date().toISOString(); manifest.errors=errors; manifest.failedRequests=failed;
    fs.writeFileSync(path.join(output,'manifest.json'),JSON.stringify(manifest,null,2)+'\n');
    await context.close(); await browser.close();
  }
}
check().catch(error=>{console.error(error);process.exitCode=1;});
