// Offline browser exercise. Requires locally installed puppeteer-core and Chrome.
const assert = require('node:assert/strict');
const {spawn} = require('node:child_process');
const fs = require('node:fs/promises');
const path = require('node:path');
const {once} = require('node:events');
const puppeteer = require('puppeteer-core');

async function main() {
  const out = process.argv[2];
  if (out) await fs.mkdir(out,{recursive:true});
  const server = spawn(process.env.PYTHON || 'python3',['app.py','--port','0'], {
    cwd:__dirname, env:{...process.env,PYTHONPATH:path.resolve(__dirname,'../../python')},
    stdio:['ignore','pipe','inherit']
  });
  let browser;
  try {
    const [banner] = await once(server.stdout,'data');
    const url = banner.toString().match(/http:\/\/127\.0\.0\.1:\d+/)[0];
    browser = await puppeteer.launch({executablePath:process.env.CHROME, channel:process.env.CHROME?undefined:'chrome',
      args:['--disable-background-networking','--disable-component-update']});
    const page = await browser.newPage();
    const errors=[];
    page.on('pageerror', e=>errors.push(e.message));
    await page.setViewport({width:1160,height:890});
    await page.goto(url,{waitUntil:'networkidle0'});
    const text = selector=>page.$eval(selector,e=>e.textContent);
    const snapshot = async name=>{if(out) await page.screenshot({path:path.join(out,name+'.png')})};
    async function command(trigger,expected,ok=true){
      const done = page.waitForResponse(r=>r.url()===url+'/view');
      await trigger();
      await done;
      await page.waitForFunction(()=>!busy);
      assert.ok((await text('#status')).includes(expected),await text('#status')+'; expected '+expected);
      assert.equal(await page.$eval('#status',e=>e.classList.contains('error')),!ok);
    }
    const click=(action,msg,ok)=>command(()=>page.click('[data-action='+action+']'),msg,ok);
    const key=(k,msg)=>command(()=>page.keyboard.press(k),msg);
    const read=async(route)=> (await fetch(url+route)).json();
    const script=async(action)=>fetch(url+'/script',{method:'POST',headers:{'Content-Type':'application/json'},
      body:JSON.stringify({action,alpha:.25,rate:44100})});
    await snapshot('01-empty');
    // Construct all edges using standard focus traversal, native selects and Enter.
    await page.keyboard.press('Tab');
    for(const [from,to] of [['WAV source','Low-pass'],['Low-pass','Block RMS'],
        ['Block RMS','Trace'],['Block RMS','Recorder']]){
      for(const name of [from,to]){
        await page.keyboard.press(name[0].toLowerCase());
        await page.keyboard.press('Tab');
      }
      await key('Enter','Connected '+from+' to '+to);
      await page.keyboard.down('Shift');
      for(let i=0;i<2;i++) await page.keyboard.press('Tab');
      await page.keyboard.up('Shift');
    }
    const wires=(await read('/view')).wires;
    await click('record','Recorded 32 blocks');
    const saved=await read('/recording.json');
    assert.equal(saved.rows.length,32);
    assert.deepEqual(saved.wires,wires);
    assert.ok(Math.abs(saved.rows[1].filter_memory+0.00499935608684285)<1e-12);
    await page.select('#probe','Low-pass');
    await page.focus('#tick');
    await page.keyboard.press('End');
    assert.match(await text('#probeText'),/block 31.*23.220 ms.*filter_memory/);
    await snapshot('02-recorded');
    await click('preview','Preview complete');
    const clicked=(await read('/view')).rows;
    await key('p','Preview complete');
    assert.deepEqual((await read('/view')).rows,clicked);
    assert.equal((await script('preview')).status,200);
    assert.deepEqual((await read('/view')).rows,clicked);
    assert.equal((await script('record')).status,400);
    await page.$eval('#alpha',e=>e.value=.04);
    await key('p','Preview complete');
    assert.equal(await page.$$eval('#trace polyline',p=>p.length),2);
    assert.notDeepEqual((await read('/view')).rows,saved.rows);
    await snapshot('03-preview');
    await key('Escape','Preview cancelled');
    assert.equal(await page.$eval('#alpha',e=>e.value),'0.25');
    assert.deepEqual((await read('/view')).rows,saved.rows);
    await page.select('#rate','22050');
    await click('record','Rate mismatch',false);
    await snapshot('04-rate');
    await page.select('#rate','44100');
    await page.select('#src','WAV source');
    await page.select('#dst','Recorder');
    await click('wire','Invalid wire',false);
    assert.deepEqual((await read('/view')).wires,wires);
    await snapshot('05-invalid');
    await page.click('#fault');
    await click('record','failed at block 7',false);
    assert.deepEqual(await read('/recording.json'),saved);
    await snapshot('06-failed');
    await page.click('#fault');
    await page.$eval('#alpha',e=>e.value=.04);
    await click('record','Recorded 32 blocks');
    assert.notDeepEqual((await read('/recording.json')).rows,saved.rows);
    await snapshot('07-recovered');
    await click('undo','Restored previous recording');
    await page.reload({waitUntil:'networkidle0'});
    assert.deepEqual(await read('/recording.json'),saved);
    assert.equal(await page.$$eval('#trace polyline',p=>p.length),1);
    await page.setViewport({width:390,height:844});
    assert.ok(await page.evaluate(()=>document.body.scrollWidth<=innerWidth));
    await page.select('#src','WAV source');
    await page.select('#dst','Block RMS');
    await click('wire','Connected WAV source to Block RMS');
    await click('preview','Preview complete');
    assert.notDeepEqual((await read('/view')).rows,saved.rows);
    await click('patch','Connected the five-node pipeline');
    assert.deepEqual((await read('/view')).wires,wires);
    assert.deepEqual(errors,[]);
    console.log('PASS: keyboard patch, probe, caller equivalence and policy, preview/cancel, atomic failures, retry, undo/reload, alternate wire, mobile width.',await browser.version());
  } finally {if(browser)await browser.close();server.kill();}
}
main().catch(e=>{console.error(e);process.exitCode=1});
