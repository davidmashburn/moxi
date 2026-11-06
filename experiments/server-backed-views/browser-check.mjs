/** Real browser gestures, transport failures, captures and bounded diagnostic sweep. */
import assert from 'node:assert/strict';
import {mkdir,readFile,writeFile} from 'node:fs/promises';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
import path from 'node:path';
import {fingerprint} from './fingerprint.mjs';
const {chromium}=await import(process.env.MOXI_PLAYWRIGHT_MODULE||'playwright');
const here=path.dirname(fileURLToPath(import.meta.url)),output=path.resolve(here,'../../artifacts/demo-slideshows/server-backed-views');
await mkdir(output,{recursive:true});
const origin=process.env.MOXI_DENSITY_URL||'http://127.0.0.1:8766/';
const browser=await chromium.launch({headless:true,...(process.env.MOXI_CHROME?{executablePath:process.env.MOXI_CHROME}:{})});
const context=await browser.newContext({viewport:{width:1440,height:1100},deviceScaleFactor:1}),page=await context.newPage(),errors=[];
page.on('pageerror',e=>errors.push(String(e)));
const base=execFileSync('git',['rev-parse','HEAD'],{cwd:here,encoding:'utf8'}).trim(),source=await fingerprint();
const root=path.resolve(here,'../..'),tracked=new Set(execFileSync('git',['ls-tree','-r','--name-only','HEAD'],{cwd:root,encoding:'utf8'}).trim().split('\n'));
const dirty=source.inputs.some(p=>!tracked.has(p))||execFileSync('git',['diff','--name-only','HEAD','--',...source.inputs],{cwd:root,encoding:'utf8'}).trim().length>0;
const sourceStatus=dirty?'UNCOMMITTED source: revision is the integration base only; committed-source recapture is required':'Committed executable sources match revision';
const metadata={baseRevision:base,sourceStatus,sourceFingerprint:source,wasmSha256:createHash('sha256').update(await readFile(path.join(here,'dist/density.wasm'))).digest('hex'),browser:await browser.version(),captureHost:'Playwright Chromium; repository scripted browser workflow',capturedAt:new Date().toISOString(),viewport:{width:1440,height:1100,scale:1}};
const slides=[],raw=[];
async function capture(phase,name,action,expected){const file=`${String(slides.length+1).padStart(2,'0')}-${name}.png`;const png=await page.screenshot({path:path.join(output,file),fullPage:true});const dimensions=[png.readUInt32BE(16),png.readUInt32BE(20)];slides.push({phase,capture_kind:'browser',image:file,dimensions,caption:name.replaceAll('-',' '),action,expected});raw.push({file,sha256:createHash('sha256').update(png).digest('hex'),state:await state(),capturedAt:new Date().toISOString()});}
async function loaded(){await page.waitForFunction(()=>window.densityDemo?.failure||window.densityDemo?.panes.size===2);assert.equal(await page.evaluate(()=>window.densityDemo.failure),null);}
async function ready(id='a'){await page.waitForFunction(id=>{const a=window.densityDemo?.panes.get(id)?.adapter;return a?.state==='ready'&&!a.active&&!a.pending;},id,{timeout:15000});}
async function state(){return page.evaluate(()=>{const d=window.densityDemo;return [...d.panes].map(([id,p])=>({id,viewport:d.viewport(p.owner),state:p.adapter.state,generation:p.adapter.generation,active:!!p.adapter.active,pending:!!p.adapter.pending,total:p.adapter.displayed?.total,selection:p.owner.inspect(0,5),exact:p.owner.inspect(0,7),metrics:p.adapter.metrics,bytes:p.transport.bytes}));});}
async function point(id='a',fx=.5,fy=.5){return page.evaluate(({id,fx,fy})=>{const d=window.densityDemo,p=d.panes.get(id),[x,y,w,h]=d.rect(p.owner,2),r=document.getElementById(id).getBoundingClientRect();return{x:r.x+x+w*fx,y:r.y+y+h*fy};},{id,fx,fy});}
async function pan(dx=72,dy=30,steps=8){const p=await point();await page.mouse.move(p.x,p.y);await page.mouse.down();await page.mouse.move(p.x+dx,p.y+dy,{steps});await page.mouse.up();}
async function memory(){const cdp=await context.newCDPSession(page);const main=await cdp.send('Runtime.getHeapUsage'),dom=await cdp.send('Memory.getDOMCounters');await cdp.detach();
 const session=await browser.newBrowserCDPSession(),workers=[];
 try{const {targetInfos}=await session.send('Target.getTargets');for(const target of targetInfos.filter(t=>t.type==='worker'&&t.url.includes('/server-backed-views/local-worker.mjs'))){
  const {sessionId}=await session.send('Target.attachToTarget',{targetId:target.targetId,flatten:false});
  const usage=await new Promise((resolve,reject)=>{const timer=setTimeout(()=>reject(new Error('worker heap timeout')),5000);const listener=e=>{if(e.sessionId!==sessionId)return;const m=JSON.parse(e.message);if(m.id!==1)return;clearTimeout(timer);session.off('Target.receivedMessageFromTarget',listener);m.error?reject(new Error(JSON.stringify(m.error))):resolve(m.result);};session.on('Target.receivedMessageFromTarget',listener);session.send('Target.sendMessageToTarget',{sessionId,message:JSON.stringify({id:1,method:'Runtime.getHeapUsage'})}).catch(reject);});
  workers.push(usage);await session.send('Target.detachFromTarget',{sessionId});
 }}finally{await session.detach();}
 return {main,workers,dom,app:await page.evaluate(()=>({wasm:window.densityDemo.runtime.stats(),retainedWorkerSourceBytes:window.densityDemo.panes.get('a').transport.sourceBytes??0}))};}
let comparison=[];
try{
 await page.goto(origin);await loaded();await ready();await ready('b');
 assert.equal((await state())[0].total,1000000);
 await capture('initial','initial-grid','Open the built P02 application; wait for both million-point reductions.','Two actual Moxi views each show a 32×32 grid totaling one million points.');
 const bBefore=(await state())[1];
 await page.locator('#delay').selectOption('3000');await pan();
 assert.equal((await state())[0].state,'pending');assert.equal((await state())[0].total,1000000);
 await capture('interaction','pan-pending-retained','Set 3000ms delay; drag A by 72×30 pixels in eight moves. Capture before the final reply.','The old grid moves synchronously with the Moxi camera; pending status is visible and B stays fixed.');
 await ready();assert.deepEqual((await state())[1].viewport,bBefore.viewport);
 await capture('result','fresh-reduction','Release the pointer and wait for the current-generation response.','Fresh viewport reduction replaces the transformed retained grid; one active and one replaceable pending were the maximum.');
 await page.locator('#delay').selectOption('150');const select=await point();await page.mouse.click(select.x,select.y);
 assert.ok((await state())[0].selection>32);assert.equal((await state())[0].exact,0);
 await capture('interaction','aggregate-selection','Click a visible density cell in A.','Orange aggregate bounds are selected; aggregate counts are not record IDs; exact selection is empty.');
 await page.locator('#delay').selectOption('1800');await page.locator('#details-a').click();
 await page.mouse.click(select.x,select.y); // same cell is a new selection epoch
 assert.equal((await state())[0].exact,0);assert.equal(await page.evaluate(()=>window.densityDemo.panes.get('a').adapter.details),null);
 await ready();await page.locator('#delay').selectOption('150');
 await page.locator('#details-a').click();await ready();assert.equal((await state())[0].exact,32);
 assert.equal(await page.evaluate(()=>window.densityDemo.panes.get('a').adapter.details.total),(await state())[0].selection);
 const ids=await page.evaluate(()=>window.densityDemo.panes.get('a').adapter.details.records.map(r=>r.id));
 await capture('result','capped-exact-records','Click Exact records (≤32) and wait for the separate capped request.','32 stable source IDs and coordinates are shown, with the larger aggregate total and truncation disclosed.');
 await pan(-20,10,4);await ready();assert.deepEqual(await page.evaluate(()=>window.densityDemo.panes.get('a').adapter.details.records.map(r=>r.id)),ids);assert.equal((await state())[0].exact,32);
 // Actual browser network disconnection, not just a local control flag.
 await context.setOffline(true);await pan(20,0,2);await page.waitForFunction(()=>window.densityDemo.panes.get('a').adapter.state==='error');
 await capture('recovery','network-disconnected','Use Chromium network-offline emulation and drag A.','The fetch fails visibly; the prior reduction and exact selection remain; B is isolated.');
 await context.setOffline(false);await page.locator('#retry-a').click();await ready();
 await capture('recovery','retry-recovered','Restore the loopback network and click Reconnect / retry.','The current viewport receives fresh data; exact IDs for the unchanged revision remain selected.');
 // Identity forgery through real HTTP response interception must be rejected.
 await page.route('**/api/query',async route=>{const response=await route.fetch();const body=await response.json();await route.fulfill({response,json:{...body,session:'wrong-session'}});},{times:1});
 await page.locator('#retry-a').click();await page.waitForFunction(()=>window.densityDemo.panes.get('a').adapter.state==='error');
 assert.match(await page.locator('#status-a').innerText(),/invalid or stale/);await page.locator('#retry-a').click();await ready();
 await page.locator('#delay').selectOption('3000');await pan(10,0,3);
 const oldHandle=await page.evaluate(()=>String(window.densityDemo.panes.get('a').owner.handle));
 await page.locator('#dispose-a').click();assert.equal(await page.evaluate(()=>window.densityDemo.panes.size),1);
 await capture('recovery','disposed-while-pending','Pan A with 3000ms delay, then Dispose before the reply.','A has no live Moxi owner; B continues displaying its independent view.');
 await page.locator('#delay').selectOption('150');await page.locator('#restart-a').click();await ready();
 assert.notEqual(await page.evaluate(()=>String(window.densityDemo.panes.get('a').owner.handle)),oldHandle);assert.equal((await state())[1].total,1000000);assert.equal((await state())[0].exact,0);
 await capture('recovery','restarted-two-views','Restart A; wait for its new session and reduction.','A starts at the full viewport with empty selection and a new handle; B remains unchanged.');
 assert.deepEqual(errors,[]);
 // Independent fresh pages per delay/route; identical world-space source and screen gestures.
 for(const delay of [0,150,600,1800])for(const route of ['reduced','full']){
  await page.goto(origin+(route==='full'?'?route=full':''));await loaded();await ready();await ready('b');
  await page.locator('#dispose-b').click();await page.locator('#delay').selectOption(String(delay));
  const initial=await page.evaluate(()=>{const p=window.densityDemo.panes.get('a');return{sourceRevision:window.densityDemo.meta.revision,bytes:p.transport.bytes,sourceLoadMs:p.transport.sourceLoadMs??null,total:p.adapter.displayed.total};});
  const memInitial=await memory();
  await pan(72,30,8);await ready();
  const p=await point();await page.mouse.move(p.x,p.y);await page.mouse.wheel(0,-160);await page.waitForFunction(()=>window.densityDemo.panes.get('a').owner.inspect(0,2)<1);await ready();
  const measurements=await page.evaluate(()=>{const p=window.densityDemo.panes.get('a');return{viewport:window.densityDemo.viewport(p.owner),counts:p.adapter.displayed.counts,total:p.adapter.displayed.total,bytes:p.transport.bytes,requestBytes:p.transport.requestBytes,feedback:p.feedback,requests:p.transport.samples,adapter:p.adapter.metrics};});
  const memFinal=await memory();comparison.push({route,serverDelayMs:delay,localQueryDelayMs:0,initial,memoryInitial:memInitial,memoryFinal:memFinal,...measurements});
 }
 for(const delay of [0,150,600,1800]){const pair=comparison.filter(r=>r.serverDelayMs===delay);assert.deepEqual(pair[0].viewport,pair[1].viewport);assert.deepEqual(pair[0].counts,pair[1].counts);}
 await page.evaluate(()=>Promise.all([window.densityDemo.restart('a'),window.densityDemo.restart('a')]));await ready();
 assert.equal(await page.evaluate(()=>window.densityDemo.runtime.stats().instances),1);
 assert.deepEqual(errors,[]);
 const manifest={version:1,demo_id:'server-backed-views',title:`P02 · Moxi million-point density explorer${dirty?' · UNCOMMITTED (revision = base only)':''}`,scenario:`${sourceStatus}. Executable-source SHA-256 ${source.sha256}. Real delayed loopback transport, immediate Moxi camera, retained reductions, capped exact selection and isolated lifecycle recovery`,revision:base,source_status:sourceStatus,source_fingerprint:source.sha256,host:`${process.platform} ${process.arch}; Chromium ${metadata.browser}`,backend:'Mojo App[Density] → experimental Wasm64 → Moxi SVG / MoxiWebHost; loopback Python transport',scale:1,fixture:'probe.generate_points(1_000_000, seed=0x5EED2026), immutable binary source SHA-256 cbc893afb24c38048ff9e30813c114c47ee1052bd18aa8963008ff93a04c991f',reproduce:'See experiments/server-backed-views/README.md. MOXI_PIXI_MANIFEST=/path/to/installed/moxi/pixi.toml bash experiments/server-backed-views/build.sh; python3 experiments/server-backed-views/server.py --port 8766; MOXI_PLAYWRIGHT_MODULE=/tmp/moxi-p01-tools/node_modules/playwright/index.mjs node experiments/server-backed-views/browser-check.mjs; python3 scripts/demo_slideshows.py',slides};
 await writeFile(path.join(output,'manifest.json'),JSON.stringify(manifest,null,2)+'\n');
 await writeFile(path.join(output,'capture-provenance.json'),JSON.stringify({metadata,captures:raw},null,2)+'\n');
 await writeFile(path.join(here,'comparison.json'),JSON.stringify({metadata,scope:'one nonstatistical run per route/delay; DOM submission and next RAF are not presentation latency; reducer algorithms/languages differ; CDP snapshots are not process RSS',comparison},null,2)+'\n');
 console.log(JSON.stringify({passed:true,captures:slides.length,comparisonRuns:comparison.length,source:source.sha256,errors},null,2));
}catch(error){await page.screenshot({path:'/tmp/moxi-p02-browser-failure.png',fullPage:true});console.error(JSON.stringify({state:await state().catch(()=>null),errors},null,2));throw error;}
finally{await browser.close();}
