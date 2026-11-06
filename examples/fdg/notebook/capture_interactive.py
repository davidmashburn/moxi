#!/usr/bin/env python3
"""Real local JupyterLab/Chrome acceptance, traces and captures (P03 workflow)."""
import hashlib
import importlib.metadata
import json
import os
from pathlib import Path
import platform
import secrets
import shutil
import subprocess
import sys
import time
from urllib.request import urlopen

from playwright.sync_api import sync_playwright

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
DIST = HERE.parent / 'dist/interactive'
DEST = ROOT / 'artifacts/demo-slideshows/fdg-inline-notebook'
WIDGETS = "document.querySelectorAll('[data-moxi-life]')"


def dependency_hashes():
    import anywidget
    package=Path(anywidget.__file__).parent
    paths=[package/'widget.py',package/'nbextension/index.js',*sorted((package/'labextension/static').glob('*.js'))]
    return {str(p.relative_to(package)):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}


def main():
    DIST.mkdir(parents=True, exist_ok=True); DEST.mkdir(parents=True, exist_ok=True)
    target=DIST/'capture.ipynb';shutil.copyfile(HERE/'interactive.ipynb',target)
    token=secrets.token_hex(24);port=int(os.environ.get('MOXI_NOTEBOOK_PORT','8916'));base=f'http://127.0.0.1:{port}'
    with open('/tmp/moxi-p04-capture-server.log','w') as log:
        server=subprocess.Popen([sys.executable,'-m','jupyterlab','--no-browser','--ip=127.0.0.1',f'--port={port}','--ServerApp.port_retries=0',f'--ServerApp.root_dir={ROOT}',f'--IdentityProvider.token={token}','--LabApp.expose_app_in_browser=True'],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT)
        try:
            deadline=time.monotonic()+30
            while True:
                if server.poll() is not None:raise RuntimeError('Jupyter exited; see /tmp/moxi-p04-capture-server.log')
                try:
                    with urlopen(f'{base}/api?token={token}',timeout=1):break
                except OSError:pass
                if time.monotonic()>deadline:raise TimeoutError('Jupyter startup')
                time.sleep(.2)
            with sync_playwright() as pw:
                browser=pw.chromium.launch(channel='chrome',headless=True)
                context=browser.new_context(viewport={'width':1600,'height':1200},device_scale_factor=1,accept_downloads=True)
                page=context.new_page();page.set_default_timeout(15000)
                errors=[];page.on('pageerror',lambda error:errors.append(str(error)))
                page.goto(f'{base}/lab/workspaces/p04-{token[:8]}/tree/examples/fdg/dist/interactive/capture.ipynb?token={token}')
                page.wait_for_function("window.jupyterapp?.shell.currentWidget?.context?.path==='examples/fdg/dist/interactive/capture.ipynb'")
                page.evaluate("async()=>{const a=window.jupyterapp;await a.shell.currentWidget.sessionContext.ready;a.shell.currentWidget.content.notebookConfig={...a.shell.currentWidget.content.notebookConfig,windowingMode:'none'};await a.commands.execute('notebook:run-all-cells');}")
                page.wait_for_function(f"{WIDGETS}.length===2 && [...{WIDGETS}].every(e=>e.moxi?.life==='live')")
                for label in ('No','Ignore all updates'):
                    button=page.get_by_role('button',name=label,exact=True)
                    if button.is_visible():button.click()
                page.evaluate("window.jupyterapp.commands.execute('application:toggle-left-area')")

                def code(source):
                    return page.evaluate("""async code=>{const k=window.jupyterapp.shell.currentWidget.sessionContext.session.kernel;const f=k.requestExecute({code,store_history:false});let output='';f.onIOPub=m=>{if(m.header.msg_type==='stream')output+=m.content.text;};const reply=await f.done;if(reply.content.status!=='ok')throw Error(JSON.stringify(reply.content));return output.trim();}""",source)
                def inspect(i=0):return page.evaluate(f"i=>{WIDGETS}[i].moxi.snapshot()",i)
                def scroll(i=2):
                    page.evaluate("async i=>{const n=window.jupyterapp.shell.currentWidget.content;n.activeCellIndex=i;await n.scrollToItem(i,'start');}",i)
                    page.locator('.moxi-inline').nth(i-2).scroll_into_view_if_needed()
                def capture(name):page.screenshot(path=str(DEST/name))
                def point(i,node):
                    return page.evaluate(f"""([i,node])=>{{const e={WIDGETS}[i],s=e.querySelector('.moxi-surface'),r=s.getBoundingClientRect(),d=e.moxi.dimensions();return {{x:r.left+e.moxi.owner.inspect(node,5)*r.width/d.width,y:r.top+e.moxi.owner.inspect(node,6)*r.height/d.height}};}}""",[i,node])
                def pinned(i,node):return page.evaluate(f"([i,n])=>{WIDGETS}[i].moxi.owner.inspect(n,4)",[i,node])
                def wait_ack():page.wait_for_function(f"!{WIDGETS}[0].moxi.channel.pending && !{WIDGETS}[0].moxi.channel.flight")
                def nodes(i):return page.evaluate(f"i=>[{WIDGETS}[i].moxi.owner.inspect(-1,6),{WIDGETS}[i].moxi.owner.inspect(-1,7)]",i)
                assert nodes(0)==[77,254] and nodes(1)==[256,1024]
                scroll();capture('01-initial.png');before_b=inspect(1)
                p=point(0,0);page.mouse.move(**p);page.mouse.down();page.mouse.move(p['x']+90,p['y']+40,steps=12)
                assert inspect()['selected']==0 and pinned(0,0)==1
                capture('02-drag.png');page.mouse.up();assert pinned(0,0)==0
                wait_ack();assert json.loads(code('import json; print(json.dumps(a.snapshot))'))['releases']==inspect()['releases']
                # Blank-canvas pan, wheel zoom and pause operate on actual Mojo state.
                bounds=page.locator('.moxi-surface').first.bounding_box()
                x,y=bounds['x']+25,bounds['y']+bounds['height']-90
                pan=inspect()['panX'];page.mouse.move(x,y);page.mouse.down();page.mouse.move(x+50,y-25,steps=8);page.mouse.up();assert inspect()['panX']!=pan
                zoom=inspect()['zoom'];page.mouse.wheel(0,-160);assert inspect()['zoom']!=zoom
                page.locator('.moxi-surface').first.press(' ');assert not inspect()['paused']
                page.wait_for_timeout(180);page.locator('.moxi-surface').first.press(' ');assert inspect()['paused']
                assert inspect(1)==before_b
                capture('03-pan-pause.png')
                # Real capture loss, then Escape cancel; no injected solver state.
                for cancel in ('capture','escape'):
                    p=point(0,1);page.mouse.move(**p);page.mouse.down()
                    # The preceding drag can put this center beneath another
                    # node. Cancel the actual picked node, respecting z-order.
                    dragged=inspect()['selected'];assert dragged>=0 and pinned(0,dragged)==1
                    if cancel=='capture':
                        # Establish the pending capture, then flush its release with
                        # another pointer event (Pointer Events pending-capture rules).
                        page.mouse.move(p['x']+1,p['y']+1)
                        page.locator('.moxi-surface').first.evaluate("s=>{for(let id=0;id<10;id++)if(s.hasPointerCapture(id))s.releasePointerCapture(id);}")
                        page.mouse.move(p['x']+2,p['y']+2)
                    else:page.keyboard.press('Escape')
                    page.wait_for_function(f"{WIDGETS}[0].moxi.owner.inspect({dragged},4)===0");page.mouse.up()
                # A real busy kernel delays ACKs while pointer feedback remains local.
                page.evaluate("()=>{window.p04busy=window.jupyterapp.shell.currentWidget.sessionContext.session.kernel.requestExecute({code:'import time; time.sleep(1.5)',store_history:false}).done;}")
                p=point(0,2);page.mouse.move(**p);page.mouse.down()
                for j in range(60):page.mouse.move(p['x']+j,p['y']+j/2)
                page.mouse.up();assert pinned(0,2)==0
                page.evaluate('window.p04busy');wait_ack()
                assert json.loads(code('print(json.dumps(a.snapshot))'))['dragging'] is False
                assert page.evaluate(f'{WIDGETS}[0].moxi.channel.metrics.maxQueued')<=2
                print('Gestures, isolation, capture loss, cancel and busy-kernel traffic passed',flush=True)

                # Both actual outputs fit in a taller viewport; resize is real CSS.
                page.set_viewport_size({'width':1600,'height':1900});scroll();capture('04-two-outputs.png')
                page.set_viewport_size({'width':860,'height':1100});scroll()
                page.wait_for_timeout(150)
                p=point(0,3);page.mouse.click(**p);assert inspect()['selected']==3
                capture('05-resize.png')
                cdp=context.new_cdp_session(page)
                cdp.send('Emulation.setDeviceMetricsOverride',{'width':860,'height':1100,'deviceScaleFactor':2,'mobile':False})
                p=point(0,4);page.mouse.click(**p);assert inspect()['selected']==4
                assert page.evaluate('devicePixelRatio')==2
                capture('06-scale2.png')
                cdp.send('Emulation.clearDeviceMetricsOverride');page.set_viewport_size({'width':1600,'height':1200})

                code('a.set_backend_available(False)')
                page.wait_for_function(f"{WIDGETS}[0].moxi.life==='failed'")
                assert page.evaluate(f"Object.values({WIDGETS}[0].moxi.resources).every(v=>!v)")
                assert inspect(1)==before_b;capture('07-failure.png')
                code('a.set_backend_available(True)');page.locator('.moxi-retry').first.click()
                page.wait_for_function(f"{WIDGETS}[0].moxi.life==='live'");capture('08-recovery.png')
                with page.expect_download() as downloaded:page.locator('.moxi-export').first.click()
                downloaded.value.save_as(DIST/'export.svg');assert '<svg' in (DIST/'export.svg').read_text()

                measurements=[]
                for index in range(2):
                    scroll(index+2)
                    # Reset bounded metrics; 30 warmup, 60 measured real frames.
                    page.evaluate(f"i=>{{const m={WIDGETS}[i].moxi; m.owner.event(20,{{key:11,value:1}}); if(m.owner.inspect(-1,4))m.owner.event(20,{{key:10,value:1}});}}",index)
                    page.wait_for_timeout(1100)
                    page.evaluate(f"i=>{{for(const a of Object.values({WIDGETS}[i].moxi.measures))a.length=0;}}",index)
                    chunks=[]
                    def collect(data):chunks.extend(data['value'])
                    cdp.on('Tracing.dataCollected',collect)
                    cdp.send('Tracing.start',{'categories':'devtools.timeline','transferMode':'ReportEvents'})
                    page.wait_for_timeout(2100)
                    with page.expect_event('console',predicate=lambda m:m.text=='p04-trace-complete'):
                        cdp.once('Tracing.tracingComplete',lambda _:page.evaluate("console.log('p04-trace-complete')"))
                        cdp.send('Tracing.end')
                    cdp.remove_listener('Tracing.dataCollected',collect)
                    result=page.evaluate(f"i=>{{const m={WIDGETS}[i].moxi; m.owner.event(20,{{key:10,value:1}});return {{nodes:m.owner.inspect(-1,6),links:m.owner.inspect(-1,7),measures:m.measures,comm:m.channel.metrics,runtime:m.runtime.stats()}};}}",index)
                    result['paintMs']=[e['dur']/1000 for e in chunks if e.get('name')=='Paint' and e.get('ph')=='X' and 'dur' in e]
                    (DIST/f'paint-{index}.json').write_text(json.dumps(chunks))
                    # Measure input feedback on each workload, after pausing simulation.
                    bounds=page.locator('.moxi-surface').nth(index).bounding_box()
                    x,y=bounds['x']+25,bounds['y']+bounds['height']-90
                    page.mouse.move(x,y);page.mouse.down()
                    for j in range(12):page.mouse.move(x+3*j,y-j)
                    page.mouse.up();page.mouse.wheel(0,80)
                    page.wait_for_timeout(200)
                    result['input']=page.evaluate(f"i=>{{const m={WIDGETS}[i].moxi;return {{inputToDomMs:m.measures.inputToDomMs,inputToNextRafMs:m.measures.inputToNextRafMs}};}}",index)
                    assert result['measures']['layoutMs'] and result['measures']['sceneMs'] and result['paintMs'] and result['input']['inputToDomMs']
                    measurements.append(result)
                print('Both workloads measured with actual Chromium paint traces',flush=True)

                # Retain only a test reference to prove callbacks really stopped.
                scroll();page.evaluate(f'window.p04old={WIDGETS}[0]')
                page.evaluate("async()=>{const a=window.jupyterapp;a.shell.currentWidget.content.activeCellIndex=2;await a.commands.execute('notebook:run-cell');}")
                page.wait_for_function(f"{WIDGETS}[0]!==window.p04old && {WIDGETS}[0].moxi.life==='live'")
                page.wait_for_function("window.p04old.moxi.life==='disposed' && Object.values(window.p04old.moxi.resources).every(v=>!v)")
                old_session=page.evaluate('window.p04old.moxi.channel.identity.session')
                new_session=page.evaluate(f'{WIDGETS}[0].moxi.channel.identity.session');assert old_session!=new_session
                rejected=code("before=a.rejected; a._receive(a,dict(v=1,session='stale',generation=a.generation-1,view='00000000-0000-0000-0000-000000000001',seq=999,kind='ping'),[]); print(a.rejected-before)");assert rejected=='1'
                page.evaluate(f'window.p04old={WIDGETS}[0]')
                page.evaluate("async()=>{const a=window.jupyterapp;a.shell.currentWidget.content.activeCellIndex=2;await a.commands.execute('notebook:clear-cell-output');}")
                page.wait_for_function("window.p04old.moxi.life==='disposed' && Object.values(window.p04old.moxi.resources).every(v=>!v)")
                page.evaluate("window.jupyterapp.commands.execute('notebook:run-cell')")
                page.wait_for_function(f"{WIDGETS}.length===2 && [...{WIDGETS}].every(e=>e.moxi.life==='live')")
                # Restart the actual kernel; existing outputs must stop without a rerun.
                pid=code('import os;print(os.getpid())')
                page.evaluate(f'window.p04retired=[...{WIDGETS}]')
                page.evaluate("async()=>{await window.jupyterapp.shell.currentWidget.sessionContext.session.kernel.restart();}")
                page.wait_for_function("window.p04retired.every(e=>['failed','disposed'].includes(e.moxi.life) && Object.values(e.moxi.resources).every(v=>!v))")
                capture('09-restart-stopped.png')
                assert pid!=code('import os;print(os.getpid())')
                page.evaluate("window.jupyterapp.commands.execute('notebook:run-all-cells')")
                page.wait_for_function(f"{WIDGETS}.length===2 && [...{WIDGETS}].every(e=>e.moxi.life==='live')")
                scroll();capture('10-restart-recovered.png')
                # Save the real executed notebook, export it normally, block all
                # external adapter scripts, and inspect its independent SVG.
                page.evaluate("window.jupyterapp.shell.currentWidget.context.save()")
                code('a.close();b.close()')
                page.wait_for_function(f"[...{WIDGETS}].every(e=>['disposed','failed'].includes(e.moxi.life))")
                from nbconvert import HTMLExporter
                import nbformat
                saved=nbformat.read(target,as_version=4)
                saved.metadata.pop('widgets',None) # Adapter state is deliberately not required.
                html,_=HTMLExporter().from_notebook_node(saved)
                (DIST/'saved.html').write_text(html)
                offline=browser.new_context(viewport={'width':1600,'height':1200},offline=True)
                saved_page=offline.new_page();saved_page.goto((DIST/'saved.html').as_uri())
                saved_page.locator('details.moxi-static').first.evaluate('e=>e.open=true')
                saved_page.locator('details.moxi-static').first.scroll_into_view_if_needed()
                assert saved_page.locator('details.moxi-static svg').count()==2
                assert saved_page.locator('[data-moxi-life]').count()==0
                saved_page.screenshot(path=str(DEST/'11-saved-fallback.png'))
                offline.close()
                assert not errors, errors
                evidence=dict(base_revision=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),uncommitted=bool(subprocess.check_output(['git','status','--porcelain','--',str(HERE.relative_to(ROOT)), 'src', 'examples/fdg/src', 'experiments/browser-moxi'],cwd=ROOT,text=True).strip()),
                    browser=browser.version,platform=platform.platform(),python=platform.python_version(),
                    versions={name:importlib.metadata.version(name) for name in ('anywidget','ipywidgets','jupyterlab','jupyterlab_widgets','ipykernel','nbconvert','playwright')},
                    checks=['fresh kernel and real widget comm roundtrip','77/254 and 256/1024 actual state counts','selection and active drag/release','pan/zoom/pause','two outputs isolated','lost capture and Escape cancel','busy kernel immediate feedback and bounded queue/final release','resize and DPR 2 hit testing','real backend failure/recovery stops resources','current SVG download','rerun disposes old view','stale replaced identity rejected','clear output stops resources','actual kernel PID changed and old animations stopped','restart rerun recovers','offline saved fallback without adapter'],
                    measurements=measurements,frontend_errors=errors,
                    skipped=['actual remote kernel: no target available','VoiceOver: paused','other browsers/frontends/platforms','physical input and independent human usability'],
                    source_hashes={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in [*sorted(HERE.glob('*interactive*')),HERE/'requirements.txt',HERE/'requirements-capture.txt',HERE/'check_channel.mjs'] if p.is_file()},
                    dependency_source_hashes=dependency_hashes(),
                    build=json.loads((DIST/'build.json').read_text()))
                (DIST/'evidence.json').write_text(json.dumps(evidence,indent=2)+'\n')
                browser.close()
                print('PASS: actual notebook lifecycle, captures and measurements; remote not tested',flush=True)
        finally:
            server.terminate()
            try:server.wait(timeout=15)
            except subprocess.TimeoutExpired:server.kill();server.wait()


if __name__=='__main__':main()
