// Separate from browser-check.mjs: no Chrome CDP, paint claims, or gallery writes.
import assert from 'node:assert/strict';
import {mkdir, readFile, writeFile} from 'node:fs/promises';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
import path from 'node:path';

const Engine = Object.freeze({firefox:'firefox', webkit:'webkit'});
const Outcome = Object.freeze({pass:'pass', unavailable:'unavailable', failed:'failed', blocked:'blocked'});
const Phase = Object.freeze({launch:'launch', normal:'normal', forced:'forced-unsupported'});
const engine = process.env.MOXI_BROWSER_ENGINE;
assert.ok(Object.values(Engine).includes(engine), 'Set MOXI_BROWSER_ENGINE=firefox or webkit');
const { [engine]: browserType } = await import(process.env.MOXI_PLAYWRIGHT_MODULE || 'playwright');
const here = path.dirname(fileURLToPath(import.meta.url));
const repo = path.resolve(here,'../..');
const output = path.resolve(process.env.MOXI_ENGINE_OUTPUT || path.join(here,'dist/engines',engine));
const origin = new URL(process.env.MOXI_DEMO_URL || 'http://127.0.0.1:8765/experiments/browser-moxi/');
assert.ok(['127.0.0.1','localhost','[::1]'].includes(origin.hostname), 'Use a local loopback service');
assert.equal(origin.search, '', 'Normal runtime must have no forced query');
await mkdir(output,{recursive:true});
const sha256 = data => createHash('sha256').update(data).digest('hex');
const nativeCheck = JSON.parse(await readFile(path.join(here,'dist/check.json'),'utf8'));
const exportedRevision = process.env.MOXI_SOURCE_REVISION;
if (exportedRevision) assert.match(exportedRevision,/^[0-9a-f]{40}$/,'Exported source revision must be a full commit SHA');
const sourceInputs = ['browser.mojo','runtime.mjs','demo.mjs','index.html','retarget.py','build.sh',
  'native.mojo','verify.mjs','check.mjs','runtime-check.mjs','test_retarget.py','target.mojo','serve.py',
  '../shared/memory64.mjs','../../native/hosts/moxi_web_host.mjs','engine-check.mjs'];
const sourceHashes = Object.fromEntries(await Promise.all(sourceInputs.map(async name =>
  [name,sha256(await readFile(path.join(here,name)))])));
const result = {engine, capturedAt:new Date().toISOString(), origin:origin.href,
  harness:{node:process.version,platform:process.platform,architecture:process.arch},
  expectedComparisons:nativeCheck.comparisons,
  sourceRevision:exportedRevision || execFileSync('git',['rev-parse','HEAD'],{cwd:repo,encoding:'utf8'}).trim(),
  sourceRevisionOrigin:exportedRevision ? 'explicit exported revision; independently compare sourceHashes with the host checkout' : 'git HEAD',
  sourceChanges:exportedRevision ? 'read-only exported tree; Git metadata not mounted' : execFileSync('git',['status','--porcelain','--',...sourceInputs.map(n=>path.relative(repo,path.join(here,n)))],{cwd:repo,encoding:'utf8'}).trim(),
  sourceHashes, wasmSha256:sha256(await readFile(path.join(here,'dist/browser.wasm'))),
  viewport:{width:1440,height:1100,deviceScaleFactor:1},
  launch:{headless:true,customFlags:false,customPreferences:false},
  scenarios:[],captures:[],pageErrors:[],failedRequests:[]};
let browser, context, page, phase = Phase.launch;
const check = (name,steps,expected,observed) => result.scenarios.push({name,steps,expected,observed,outcome:Outcome.pass});
async function capture(name) {
  const file = `${name}.png`, png = await page.screenshot({path:path.join(output,file),fullPage:true});
  result.captures.push({file,sha256:sha256(png),capturedAt:new Date().toISOString()});
}
async function settle() {
  await page.waitForFunction(()=>window.moxiDemo?.panes.size===2 || document.querySelector('#status')?.textContent==='Runtime unavailable');
}
async function inspect(id,index,field) {
  return page.evaluate(({id,index,field})=>window.moxiDemo.panes.get(id).owner.inspect(index,field),{id,index,field});
}
async function nodePoint(index) {
  return page.evaluate(index=>{const d=window.moxiDemo,r=document.querySelector('#a').getBoundingClientRect(),p=d.panes.get('a');
    return {x:r.x+p.owner.inspect(index,d.NodeField.screenX),y:r.y+p.owner.inspect(index,d.NodeField.screenY)};},index);
}
async function control(name) {
  const p=await page.evaluate(name=>{const d=window.moxiDemo,r=document.querySelector('#a').getBoundingClientRect(),b=d.panes.get('a').lastFrame.semantics.find(n=>n.id===d.Control[name]).bounds;
    return {x:r.x+b.x+b.width/2,y:r.y+b.y+b.height/2};},name);
  await page.mouse.click(p.x,p.y);
}
async function unavailable(forced) {
  assert.equal(await page.locator('#status').textContent(),'Runtime unavailable');
  const diagnostic=await page.locator('#failure').textContent();
  assert.match(diagnostic,/Unsupported runtime: WebAssembly memory64 is required; no JavaScript graph fallback/);
  assert.equal(diagnostic.includes('forced feature-gate scenario'),forced);
  assert.equal(await page.evaluate(()=>typeof window.moxiDemo),'undefined');
  assert.equal(await page.locator('#a svg, #b svg, [data-moxi-accessibility]').count(),0);
  check(forced?'forced-unavailable':'natural-unavailable',forced?'Load ?unsupported':'Load normal URL with default engine settings',
    'Explicit memory64 diagnostic, Runtime unavailable, no graph/semantics/fallback',diagnostic);
  await capture(forced?'forced-unavailable':'natural-unavailable');
}
async function interactive() {
  const fields=await page.evaluate(()=>({app:window.moxiDemo.AppField,node:window.moxiDemo.NodeField}));
  assert.equal(await inspect('a',-1,fields.app.nodes),36);
  assert.equal(await inspect('b',-1,fields.app.nodes),36);
  assert.equal(await inspect('a',-1,fields.app.paused),1);
  assert.equal(await inspect('b',-1,fields.app.paused),1);
  assert.equal(await page.locator('#a svg, #b svg').count(),2);
  const bBefore=await page.evaluate(()=>{const d=window.moxiDemo,p=d.panes.get('b');return Array.from({length:36},(_,i)=>[p.owner.inspect(i,d.NodeField.x),p.owner.inspect(i,d.NodeField.y)]);});
  check('initial','Load normal URL','Two paused 36-node Wasm FDG apps with SVG','Two apps rendered');
  await capture('initial');
  let point=await nodePoint(0);
  await page.mouse.click(point.x,point.y);
  assert.equal(await inspect('a',-1,fields.app.selected),0);
  await page.locator('#a').focus();await page.keyboard.press('ArrowRight');
  assert.equal(await inspect('a',-1,fields.app.selected),1);
  check('selection','Click node-0, focus A, ArrowRight','Selection changes from 0 to 1','Mojo selected=1');
  point=await nodePoint(0);
  const oldX=await inspect('a',0,fields.node.x);
  await page.mouse.move(point.x,point.y);await page.mouse.down();
  await page.mouse.move(point.x+80,point.y+45,{steps:6});
  assert.equal(await inspect('a',0,fields.node.pinned),1);
  assert.notEqual(await inspect('a',0,fields.node.x),oldX);
  await capture('dragging');await page.mouse.up();
  assert.equal(await inspect('a',0,fields.node.pinned),0);
  check('drag-release','Drag node-0 by 80x45 CSS pixels, then release','Position changes; pinned while held, unpinned after release','Mojo position changed, pin 1 then 0');
  const pan=await inspect('a',-1,fields.app.panX),zoom=await inspect('a',-1,fields.app.zoom);
  const bounds=await page.evaluate(()=>{const d=window.moxiDemo,r=document.querySelector('#a').getBoundingClientRect(),b=d.panes.get('a').lastFrame.semantics.find(n=>n.id===d.Control.canvas).bounds;
    return {x:r.x+b.x,y:r.y+b.y,width:b.width,height:b.height};});
  await page.mouse.move(bounds.x+bounds.width-50,bounds.y+bounds.height-50);await page.mouse.down();
  await page.mouse.move(bounds.x+bounds.width-140,bounds.y+bounds.height-90,{steps:5});await page.mouse.up();
  assert.notEqual(await inspect('a',-1,fields.app.panX),pan);
  await page.mouse.wheel(0,-160);
  await page.waitForFunction(old=>window.moxiDemo.panes.get('a').owner.inspect(-1,window.moxiDemo.AppField.zoom)!==old,zoom);
  await page.locator('#resize-a').click();
  await page.waitForFunction(()=>document.querySelector('#a svg')?.getAttribute('height')==='720');
  check('pan-zoom-resize','Drag empty canvas -90/-40; wheel -160; Resize A','Pan/zoom change and SVG height=720','Mojo pan/zoom changed and SVG resized');
  await capture('pan-zoom-resize');
  await control('pause');
  await page.evaluate(()=>{window.moxiDemo.frames.length=0;});
  await page.waitForFunction(()=>window.moxiDemo.frames.length>=3);
  await control('pause');assert.equal(await inspect('a',-1,fields.app.paused),1);
  await control('restart');
  await page.evaluate(()=>{window.moxiDemo.frames.length=0;});
  await page.waitForFunction(()=>window.moxiDemo.frames.length>=3);
  await control('pause');assert.equal(await inspect('a',-1,fields.app.paused),1);
  check('resume-pause-reheat','Resume, wait 3 frames, Pause; Reheat, wait 3 frames, Pause',
    'Default animation loop advances app for both Resume and Reheat, then pauses','At least 3 draws for each, Mojo paused=1');
  await control('search');await page.keyboard.type('node-12');await page.keyboard.press('Enter');
  assert.equal(await inspect('a',-1,fields.app.selected),12);
  assert.equal(await page.evaluate(()=>{const d=window.moxiDemo;return d.panes.get('a').lastFrame.semantics.find(n=>n.id===d.Control.search).value;}),'node-12');
  assert.equal(await inspect('b',-1,fields.app.selected),-1);
  assert.deepEqual(await page.evaluate(()=>{const d=window.moxiDemo,p=d.panes.get('b');return Array.from({length:36},(_,i)=>[p.owner.inspect(i,d.NodeField.x),p.owner.inspect(i,d.NodeField.y)]);}),bBefore);
  check('text-search-isolation','Click Moxi search; type node-12, Enter','Select node-12 with semantic query; all B positions/selection unchanged','Mojo selected=12; query=node-12; B unchanged');
  await capture('search-isolation');
  const handle=await page.evaluate(()=>String(window.moxiDemo.panes.get('a').owner.handle));
  await page.locator('#dispose-a').click();
  assert.equal(await page.evaluate(()=>window.moxiDemo.panes.size),1);
  assert.equal(await page.locator('#a [data-moxi-accessibility], #a svg').count(),0);
  assert.equal(await page.locator('#b svg').count(),1);
  await capture('disposed');
  await page.locator('#recreate-a').click();await settle();
  assert.notEqual(await page.evaluate(()=>String(window.moxiDemo.panes.get('a').owner.handle)),handle);
  assert.equal(await page.evaluate(h=>window.moxiDemo.runtime.invoke('moxi_destroy',BigInt(h)),handle),-1);
  assert.equal(await inspect('a',-1,fields.app.selected),-1);
  check('dispose-recreate','Dispose A, Recreate A; invoke destroy on old handle','Overlay/graph removed; B live; new handle/state; stale destroy=-1','All lifecycle assertions passed');
  await capture('recreated');
  await page.locator('#verify').click();
  await page.waitForFunction(()=>window.moxiDemo.verification || window.moxiDemo.failure,null,{timeout:120000});
  assert.equal(await page.evaluate(()=>window.moxiDemo.failure),null);
  result.verification=await page.evaluate(()=>window.moxiDemo.verification.verification);
  assert.equal(result.verification.comparisons,nativeCheck.comparisons);
  assert.equal(result.verification.liveAllocations,0);
  check('native-parity-lifecycle','Click Verify in normal app',`${nativeCheck.comparisons} comparisons matching the fresh native/Node check, exact SVG structure/text, 100 disposal cycles, no live allocations`,
    {comparisons:result.verification.comparisons,liveAllocations:result.verification.liveAllocations,maxAbsoluteError:result.verification.maxAbsoluteError});
  await page.reload();await settle();
  assert.equal(await inspect('a',-1,fields.app.selected),-1);
  assert.equal(await inspect('b',-1,fields.app.selected),-1);
  assert.equal(await page.evaluate(()=>window.moxiDemo.failure),null);
  check('reload','Reload after interactions/verification','Two fresh paused apps; no persisted selection or failure','Two apps selected=-1, failure=null');
}
try {
  browser=await browserType.launch({headless:true,...(process.env.MOXI_BROWSER_EXECUTABLE?{executablePath:process.env.MOXI_BROWSER_EXECUTABLE}:{}),timeout:20000});
  result.browserVersion=browser.version();
  context=await browser.newContext({viewport:{width:1440,height:1100},deviceScaleFactor:1});
  page=await context.newPage();page.setDefaultTimeout(20000);
  page.on('pageerror',error=>result.pageErrors.push({phase,message:String(error)}));
  page.on('requestfailed',request=>result.failedRequests.push({phase,url:request.url(),error:request.failure()}));
  phase=Phase.normal;await page.goto(origin.href);await settle();
  result.initialStatus=await page.locator('#status').textContent();
  result.runtimeDiagnostic=await page.locator('#failure').textContent();
  result.userAgent=await page.evaluate(()=>navigator.userAgent);
  result.memory64=await page.evaluate(async()=> (await import('./runtime.mjs')).supportsMemory64());
  // Match the served artifact/modules to this checkout, including the shared host.
  for (const name of ['dist/browser.wasm','runtime.mjs','demo.mjs','verify.mjs','../shared/memory64.mjs','../../native/hosts/moxi_web_host.mjs']) {
    const response=await context.request.get(new URL(name,origin).href);assert.equal(response.status(),200);
    assert.equal(sha256(await response.body()),sha256(await readFile(path.join(here,name))),`served ${name} differs`);
  }
  check('source-identity','Hash loopback Wasm and runtime/host modules','Served bytes match this checkout','All six hashes match');
  if (result.memory64) {
    assert.equal(result.initialStatus,'Two live Mojo/Moxi instances',result.runtimeDiagnostic);
    await interactive();result.normalOutcome=Outcome.pass;
  }
  else {await unavailable(false);result.normalOutcome=Outcome.unavailable;}
} catch(error) {
  result.normalOutcome=phase===Phase.launch?Outcome.blocked:Outcome.failed;
  result.error={phase,message:String(error),stack:error.stack};
  if(page)await capture('failure').catch(()=>{});
}
// Exercise the documented forced path even after a normal-runtime assertion fails.
if(page) {
  try {
    phase=Phase.forced;let wasmRequests=0;
    page.on('request',request=>{if(phase===Phase.forced && new URL(request.url()).pathname.endsWith('/browser.wasm'))wasmRequests++;});
    const forced=new URL(origin);forced.search='unsupported';
    await page.goto(forced.href);await settle();await unavailable(true);
    assert.equal(wasmRequests,0,'forced path must reject before fetching app Wasm');
    result.forcedOutcome=Outcome.pass;
  } catch(error) {result.forcedOutcome=Outcome.failed;result.forcedError=String(error);}
}
await context?.close();await browser?.close();
result.completedAt=new Date().toISOString();
result.outcome= result.normalOutcome===Outcome.blocked ? Outcome.blocked :
  result.normalOutcome===Outcome.failed || result.forcedOutcome!==Outcome.pass || result.pageErrors.length || result.failedRequests.length ? Outcome.failed : result.normalOutcome;
await writeFile(path.join(output,'result.json'),JSON.stringify(result,null,2)+'\n');
console.log(JSON.stringify({engine,version:result.browserVersion,memory64:result.memory64,outcome:result.outcome,
  normal:result.normalOutcome,forced:result.forcedOutcome,scenarios:result.scenarios.length,output}));
process.exitCode=[Outcome.failed,Outcome.blocked].includes(result.outcome)?1:0;
