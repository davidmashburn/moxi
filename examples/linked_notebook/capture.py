#!/usr/bin/env python3
"""Actual local Lab/Chrome capture; run with the clean wheel environment."""
import hashlib
import importlib.metadata
import json
import os
from pathlib import Path
import platform
import secrets
import signal
import shutil
import subprocess
import sys
import time
from urllib.request import urlopen

from playwright.sync_api import sync_playwright

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
DEST = ROOT / 'artifacts/demo-slideshows/linked-notebook'
CONSUMER = Path(os.environ.get('MOXI_P05_CONSUMER', '/tmp/moxi-p05-consumer'))
VIEWS = "document.querySelectorAll('[data-linked-life]')"


def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    import moxi_linked_notebook
    installed=Path(moxi_linked_notebook.__file__).parent
    assert ROOT not in installed.parents, 'Run from clean installed wheel environment'
    assert sha(installed/'widget.mjs')==sha(HERE/'moxi_linked_notebook/widget.mjs'), 'Rebuild and install wheel after edits'
    runtime=json.loads((CONSUMER/'runtime.json').read_text())
    assert runtime['runtimeLoadedFromConsumer'] and runtime['binarySha256']==sha(CONSUMER/'moxi-linked')
    for name,digest in runtime['runtimeLibraries'].items():assert sha(CONSUMER/'lib'/name)==digest
    DEST.mkdir(parents=True,exist_ok=True)
    nb=json.loads((HERE/'linked.ipynb').read_text())
    # Optional actual P04 co-display regression. Copy prepared example assets;
    # the clean consumer never imports the repository or invokes Mojo compiler.
    fdg=ROOT/'examples/fdg'
    if not (fdg/'dist/interactive/browser.wasm').exists():raise RuntimeError('Prepare P04 assets for isolation check')
    (CONSUMER/'fdg/notebook').mkdir(parents=True,exist_ok=True)
    (CONSUMER/'fdg/dist/interactive').mkdir(parents=True,exist_ok=True)
    for name in ('interactive.py','static_interactive.mjs'):
        shutil.copyfile(fdg/'notebook'/name,CONSUMER/'fdg/notebook'/name)
    for name in ('browser.wasm','widget.mjs','runtime.mjs'):
        shutil.copyfile(fdg/'dist/interactive'/name,CONSUMER/'fdg/dist/interactive'/name)
    nb['cells'].insert(3,dict(id='fdg-isolation',cell_type='code',metadata={},outputs=[],execution_count=None,source=['import sys\n','sys.path.insert(0, "fdg/notebook")\n','from interactive import InlineFDG\n','g = InlineFDG(slot="fdg-isolation", title="P04 · Independent real Mojo FDG")\n','g.show()']))
    target=CONSUMER/'capture.ipynb';target.write_text(json.dumps(nb))
    token=secrets.token_hex(24);port=int(os.environ.get('MOXI_NOTEBOOK_PORT','8918'));base=f'http://127.0.0.1:{port}'
    env=dict(os.environ,MOXI_LINKED_BINARY=str(CONSUMER/'moxi-linked'))
    checks={};shots=[]
    with open('/tmp/moxi-p05-capture-server.log','w') as log:
        server=subprocess.Popen([sys.executable,'-m','jupyterlab','--no-browser','--ip=127.0.0.1',f'--port={port}','--ServerApp.port_retries=0',f'--ServerApp.root_dir={CONSUMER}',f'--IdentityProvider.token={token}','--LabApp.expose_app_in_browser=True'],cwd=CONSUMER,env=env,stdout=log,stderr=subprocess.STDOUT)
        try:
            deadline=time.monotonic()+30
            while True:
                if server.poll() is not None:raise RuntimeError('Jupyter exited')
                try:
                    with urlopen(f'{base}/api?token={token}',timeout=1):break
                except OSError:pass
                if time.monotonic()>deadline:raise TimeoutError('Jupyter startup')
                time.sleep(.2)
            with sync_playwright() as pw:
                browser=pw.chromium.launch(channel='chrome',headless=True)
                context=browser.new_context(viewport={'width':1500,'height':1100},device_scale_factor=1)
                page=context.new_page();page.set_default_timeout(15000)
                errors=[];page.on('pageerror',lambda e:errors.append(str(e)))
                page.goto(f'{base}/lab/workspaces/p05-{token[:8]}/tree/capture.ipynb?token={token}')
                page.wait_for_function("window.jupyterapp?.shell.currentWidget?.context?.path==='capture.ipynb'")
                page.evaluate("async()=>{const a=window.jupyterapp;await a.shell.currentWidget.sessionContext.ready;a.shell.currentWidget.content.notebookConfig={...a.shell.currentWidget.content.notebookConfig,windowingMode:'none'};await a.commands.execute('notebook:run-all-cells');}")
                page.wait_for_function(f"{VIEWS}.length===2 && [...{VIEWS}].every(e=>e.linked.life==='live') && document.querySelector('[data-moxi-life]')?.moxi?.life==='live'")
                for label in ('No','Ignore all updates'):
                    button=page.get_by_role('button',name=label,exact=True)
                    if button.is_visible():button.click()
                page.evaluate("window.jupyterapp.commands.execute('application:toggle-left-area')")
                def code(source):
                    return page.evaluate("""async code=>{const k=window.jupyterapp.shell.currentWidget.sessionContext.session.kernel;const f=k.requestExecute({code,store_history:false});let out='';f.onIOPub=m=>{if(m.header.msg_type==='stream')out+=m.content.text;};const r=await f.done;if(r.content.status!=='ok')throw Error(JSON.stringify(r.content));return out.trim();}""",source)
                def frame(i=0):return page.evaluate(f'i=>{VIEWS}[i].linked.frame',i)
                def settled():page.wait_for_function(f"{VIEWS}[0]?.linked.life==='live' && !{VIEWS}[0].linked.channel.flight && !{VIEWS}[0].linked.channel.pending")
                def selected(key):page.wait_for_function(f"{VIEWS}[0].linked.frame.selected==={key} && !{VIEWS}[0].linked.channel.pending")
                def capture(name,caption):
                    page.locator('.moxi-linked').first.scroll_into_view_if_needed()
                    page.screenshot(path=str(DEST/name));shots.append({'file':name,'caption':caption,'capture':'installed Google Chrome, headless Playwright, actual local JupyterLab'})
                def point(key):return page.evaluate(f"""key=>{{const e={VIEWS}[0],s=e.querySelector('.surface'),r=s.getBoundingClientRect(),p=e.linked.frame.points.find(p=>p.key===key);return {{x:r.left+p.x*r.width/720,y:r.top+p.y*r.height/360}};}}""",key)
                def click_point(key):
                    page.locator('.moxi-linked .surface').first.scroll_into_view_if_needed();page.mouse.click(**point(key));selected(key);settled()
                def rerun(index):page.evaluate("async index=>{const a=window.jupyterapp;a.shell.currentWidget.content.activeCellIndex=index;await a.commands.execute('notebook:run-cell');}",index)
                settled();capture('01-initial.png','Initial real Mojo scatter plot and linked record table')
                before_b=frame(1);fdg_before=page.evaluate("document.querySelector('[data-moxi-life]').moxi.snapshot()")
                click_point(3);assert frame()['detail']['label']=='Sample 04';assert frame()['selectionSemantic']==1
                assert frame(1)==before_b
                assert page.evaluate("document.querySelector('[data-moxi-life]').moxi.snapshot()")==fdg_before
                checks['linked_selection_and_fdg_isolation']=True
                capture('02-selection.png','Pointer selection links actual Moxi mark, details and table; B and P04 FDG unchanged')
                buttons=page.locator('.moxi-linked').first.locator('tbody button')
                buttons.first.focus();page.keyboard.press('ArrowDown');page.keyboard.press('Enter');selected(1);settled()
                assert page.evaluate('document.activeElement.dataset.key')=='1'
                assert buttons.nth(1).get_attribute('aria-pressed')=='true'
                page.keyboard.press('Home');page.keyboard.press('Space');selected(0);settled()
                page.locator('.moxi-linked .surface').first.focus();page.keyboard.press('Tab')
                assert page.evaluate('document.activeElement.dataset.key')=='0'
                page.keyboard.press('ArrowDown');page.keyboard.press('Enter');selected(1);settled()
                checks['keyboard_focus_selection_semantics']={'tab':True,'arrows':True,'home':True,'enter':True,'space':True}
                capture('03-keyboard.png','Arrow-key focus and Enter selection survive the acknowledged frame')
                page.locator('.moxi-linked select').first.select_option('70');selected(-1);settled()
                assert [r['key'] for r in frame()['rows']]==[5,7,8,9,10,11]
                capture('04-filter.png','Filter retains stable record keys and clears details for a removed selection')
                code('a.update(sample_rows()[:6])');page.wait_for_function(f'{VIEWS}[0].linked.frame.dataVersion===2');settled()
                assert len(frame()['rows'])==6 and len(frame(1)['rows'])==12
                capture('05-update.png','Atomic data replacement resets selection; independent output keeps 12 records')
                page.locator('.moxi-linked select').first.select_option('100');settled();page.wait_for_function(f'{VIEWS}[0].linked.frame.points.length===0')
                page.locator('.moxi-linked select').first.select_option('0');page.wait_for_function(f'{VIEWS}[0].linked.frame.points.length===6');settled()
                checks['filter_update_empty']=True
                code('a.set_backend_available(False)');page.wait_for_function(f"{VIEWS}[0].linked.life==='failed'")
                assert page.evaluate(f'{VIEWS}[0].linked.timer')==0
                capture('06-failure.png','Real Python backend rejection preserves the last frame and exposes recovery')
                code('a.set_backend_available(True)');page.locator('.moxi-linked .retry').first.click();settled()
                click_point(4);capture('07-recovery.png','Explicit Retry reconnects and selection works again')
                checks['backend_failure_recovery']=True
                code('saved_binary=a.binary; a.binary=__import__("pathlib").Path("/missing-p05-executable")')
                page.locator('.moxi-linked').first.locator('tbody button').first.click()
                page.wait_for_function(f"{VIEWS}[0].linked.life==='failed'")
                assert 'Mojo process failed' in page.locator('.moxi-linked .status').first.inner_text()
                code('a.binary=saved_binary');page.locator('.moxi-linked .retry').first.click();settled()
                checks['actual_process_failure_recovery']=True
                # Busy kernel: real kernel request, immediate focus/gesture feedback,
                # repeated semantic selections coalesce and final value wins.
                page.evaluate("()=>{const k=window.jupyterapp.shell.currentWidget.sessionContext.session.kernel;window.busy=k.requestExecute({code:'import time; time.sleep(1.3)',store_history:false}).done;}")
                page.evaluate(f"()=>{{const e={VIEWS}[0],buttons=e.querySelectorAll('tbody button');for(let i=0;i<2000;i++)buttons[i%6].click();buttons[5].click();}}")
                assert page.evaluate(f'{VIEWS}[0].linked.channel.metrics.maxQueued')<=2
                page.evaluate('window.busy');selected(5);settled()
                assert int(code('print(a.finals)'))>=2001
                checks['busy_kernel_final_action']={'updates':2001,'maxQueued':2,'selected':5}
                # This IPykernel can service comms concurrently with sleep. For
                # a genuinely unresponsive local kernel, suspend only this test
                # server's kernel process and always resume it before teardown.
                kernel_pid=int(code('import os; print(os.getpid())'));settled()
                os.kill(kernel_pid,signal.SIGSTOP)
                try:
                    page.evaluate(f"{VIEWS}[0].querySelectorAll('tbody button')[1].click()")
                    page.wait_for_function(f"{VIEWS}[0].linked.channel.flight?.kind==='state'")
                    page.evaluate(f"{VIEWS}[0].querySelectorAll('tbody button')[4].click()")
                    page.wait_for_function(f"{VIEWS}[0].linked.life==='failed'")
                    assert page.evaluate(f'{VIEWS}[0].linked.timer')==0 and frame()['selected']==5
                finally:
                    os.kill(kernel_pid,signal.SIGCONT)
                code('pass')
                page.locator('.moxi-linked .retry').first.click();selected(1);settled()
                click_point(5)
                checks['unresponsive_kernel_lease_recovery']={'method':'SIGSTOP/SIGCONT of owned local test kernel','preservedFrame':5,'inFlightApplied':1,'unsentDropped':4,'timerStopped':True}
                # Pointer capture loss and explicit browser cancellation clear the
                # presentation preview; neither changes acknowledged selection.
                page.locator('.moxi-linked .surface').first.scroll_into_view_if_needed()
                p=point(2);page.mouse.move(**p);page.mouse.down();page.mouse.move(p['x']+1,p['y']+1)
                page.wait_for_function(f'{VIEWS}[0].linked.active!==null')
                page.evaluate(f'()=>{{const e={VIEWS}[0];e.querySelector(".surface").releasePointerCapture(e.linked.active);}}')
                page.mouse.move(p['x']+2,p['y']+2);page.wait_for_function(f'{VIEWS}[0].linked.active===null');page.mouse.up();settled();assert frame()['selected']==5
                page.mouse.move(**point(2));page.mouse.down();page.mouse.move(p['x']+1,p['y']+1)
                page.evaluate(f'()=>{{const e={VIEWS}[0];e.querySelector(".surface").dispatchEvent(new PointerEvent("pointercancel",{{pointerId:e.linked.active,bubbles:true}}));}}')
                page.wait_for_function(f'{VIEWS}[0].linked.active===null');page.mouse.up();settled();assert frame()['selected']==5
                checks['capture_loss_and_synthetic_cancel']=True
                cdp=context.new_cdp_session(page)
                page.set_viewport_size({'width':620,'height':1100})
                cdp.send('Emulation.setDeviceMetricsOverride',{'width':620,'height':1100,'deviceScaleFactor':2,'mobile':False})
                click_point(3)
                assert page.evaluate('devicePixelRatio')==2
                assert page.evaluate('innerWidth')==620
                assert page.locator('.moxi-linked .body').first.evaluate('e=>getComputedStyle(e).gridTemplateColumns.split(" ").length')==1
                assert page.locator('.moxi-linked').first.evaluate('e=>e.scrollWidth<=e.clientWidth+1')
                capture('08-narrow-dpr2.png','620 CSS-pixel viewport at DPR 2; actual pointer hit after resize')
                checks['resize_dpr2']={'cssWidth':620,'dpr':2,'singleColumn':True}
                cdp.send('Emulation.clearDeviceMetricsOverride');page.set_viewport_size({'width':1500,'height':1100})
                # Browser trace measures main-thread Paint, not scan-out/GPU time.
                cdp.send('Tracing.start',{'categories':'devtools.timeline','transferMode':'ReturnAsStream'})
                for key in (0,1,2,3,4,5):click_point(key)
                trace=[];cdp.on('Tracing.tracingComplete',lambda params:trace.append(params));cdp.send('Tracing.end')
                deadline=time.monotonic()+10
                while not trace:
                    if time.monotonic()>deadline:raise TimeoutError('trace completion')
                    page.wait_for_timeout(50)
                stream=trace[0]['stream'];chunks=[]
                while True:
                    chunk=cdp.send('IO.read',{'handle':stream});chunks.append(chunk['data'])
                    if chunk.get('eof'):break
                cdp.send('IO.close',{'handle':stream})
                trace_json=json.loads(''.join(chunks));(CONSUMER/'paint-trace.json').write_text(json.dumps(trace_json))
                paints=[e['dur']/1000 for e in trace_json['traceEvents'] if e.get('name')=='Paint' and 'dur' in e]
                metrics=page.evaluate(f'({{pipeline:{VIEWS}[0].linked.metrics,channel:{VIEWS}[0].linked.channel.metrics}})');metrics['chromePaintMs']=paints
                # Save actual independent MIME output, then reopen offline without
                # JS. It is the initial snapshot emitted by .show(), not artwork.
                page.evaluate('window.jupyterapp.shell.currentWidget.context.save()')
                saved=json.loads(target.read_text())
                html=next(''.join(o['data']['text/html']) if isinstance(o['data']['text/html'],list) else o['data']['text/html'] for o in saved['cells'][1]['outputs'] if 'text/html' in o.get('data',{}))
                assert '<script' not in html and '<svg' in html and '<table' in html
                (CONSUMER/'saved-fallback.html').write_text('<!doctype html><meta charset="utf-8"><title>Saved notebook output</title>'+html.replace('<details ', '<details open '))
                checks['saved_notebook_mime']=True
                # Maximum supported rows through actual frontend and kernel.
                code('b.update([dict(label=f"Capacity {i}", x=i, y=(i*7)%100) for i in range(64)])')
                page.wait_for_function(f'{VIEWS}[1].linked.frame.points.length===64')
                capacity_frame=frame(1)
                assert capacity_frame['dataVersion']==2
                checks['actual_notebook_capacity']={'rows':64,'frameBytes':len(json.dumps(capacity_frame).encode()),'processMs':capacity_frame['processMs']}
                # Distinct document-global IDs, even with saved outputs expanded.
                assert page.evaluate('()=>{const ids=[...document.querySelectorAll("[id^=linked-]")].map(e=>e.id);return ids.length===new Set(ids).size;}')
                checks['svg_fragment_isolation']=True
                # Stale schema/session/generation/data are rejected by the actual kernel.
                out=code("import uuid\nbase=dict(v=1,session=a.session,generation=a.generation,view=a.view,seq=a.sequence+1,kind='ping')\nold=a.rejected\nfor patch in [dict(v=2),dict(session='old'),dict(generation=0),dict(seq=0)]:\n a._receive(a,dict(base,**patch),[])\nprint(a.rejected-old)")
                assert out=='4';checks['real_kernel_stale_rejection']=True
                page.evaluate(f'window.oldA={VIEWS}[0];window.oldB={VIEWS}[1]')
                rerun(1);page.wait_for_function(f"window.oldA.linked.life==='disposed' && {VIEWS}[0].linked.life==='live' && {VIEWS}[0]!==window.oldA")
                assert page.evaluate('window.oldA.linked.timer')==0
                assert page.evaluate(f'{VIEWS}[0].linked.identity.session!==window.oldA.linked.identity.session')
                checks['rerun_disposes_predecessor']=True
                page.evaluate("window.jupyterapp.shell.currentWidget.content.widgets[2].model.outputs.clear()")
                page.wait_for_function("window.oldB.linked.life==='disposed'");assert page.evaluate('window.oldB.linked.timer')==0
                checks['clear_disposal']=True
                rerun(2);page.wait_for_function(f"{VIEWS}.length===2 && {VIEWS}[1].linked.life==='live'")
                page.evaluate(f'window.disposedB={VIEWS}[1]');page.locator('.moxi-linked .dispose').nth(1).click()
                page.wait_for_function("window.disposedB.linked.life==='disposed'");assert page.evaluate('window.disposedB.linked.timer')==0
                checks['explicit_dispose']=True
                page.evaluate(f'window.restartA={VIEWS}[0]')
                page.evaluate('window.jupyterapp.shell.currentWidget.sessionContext.session.kernel.restart()')
                page.wait_for_function("['failed','disposed'].includes(window.restartA.linked.life)")
                assert page.evaluate('window.restartA.linked.timer')==0
                checks['actual_kernel_restart']=True
                rerun(1);page.wait_for_function(f"{VIEWS}[0]?.linked.life==='live'")
                checks['rerun_after_restart']=True
                capture('09-restart.png','After actual kernel restart and rerun: new session, live linked consumer')
                offline=browser.new_context(java_script_enabled=False,offline=True,viewport={'width':1100,'height':1100})
                fallback=offline.new_page();fallback.goto((CONSUMER/'saved-fallback.html').as_uri());assert fallback.locator('svg').count()==1 and fallback.locator('tbody tr').count()==12
                fallback.screenshot(path=str(DEST/'10-saved-fallback.png'));shots.append({'file':'10-saved-fallback.png','caption':'Actual saved notebook HTML MIME reopened offline with JavaScript disabled; initial SVG and all 12 records','capture':'Chrome headless, persisted MIME output, offline/no JavaScript'})
                checks['offline_fallback']=True
                # Record exact artifacts and versions before orderly shutdown.
                source_paths=[p for p in HERE.rglob('*') if p.is_file() and not any(part in ('dist','build','__pycache__') or part.endswith('.egg-info') for part in p.relative_to(HERE).parts) and p.suffix in ('.py','.mjs','.mojo','.sh','.ipynb','.toml','.txt')]
                source_paths += list((ROOT/'src').rglob('*.mojo'))
                report=dict(checks=checks,metrics=metrics,screenshots=shots,sourceRevision=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),scopedStatus=subprocess.check_output(['git','status','--short','--','examples/linked_notebook'],cwd=ROOT,text=True).strip(),sourceHashes={str(p.relative_to(ROOT)):sha(p) for p in sorted(source_paths)},binarySha256=sha(CONSUMER/'moxi-linked'),wheelSha256=sha(next(CONSUMER.glob('*.whl'))),fdgWasmSha256=sha(CONSUMER/'fdg/dist/interactive/browser.wasm'),versions={p:importlib.metadata.version(p) for p in ('anywidget','ipywidgets','jupyterlab','jupyterlab_widgets','playwright','ipykernel')},python=sys.version,platform=platform.platform(),chrome=browser.version,pageErrors=errors,limits={'rows':64,'coordinateRange':[0,100],'clientMessageBytes':4096,'frameBytes':131072,'queueSlots':2,'leaseMs':4000,'processDeadlineSeconds':2,'metricsSamples':120},gaps=['real remote host','physical input','human usability','screen reader / VoiceOver','other frontends/browsers','Linux/Windows compiler/runtime','GPU completion and display scan-out'])
                report['runtimeBundle']=runtime
                preview=DEST/'t3-evidence.json'
                if preview.exists():report['collaborativePreview']=json.loads(preview.read_text())
                report['screenshotHashes']={p.name:sha(p) for p in DEST.glob('*.png')}
                (DEST/'evidence.json').write_text(json.dumps(report,indent=2)+'\n')
                browser.close()
                print(json.dumps({'checks':checks,'screenshots':len(shots),'pageErrors':errors,'report':str(DEST/'evidence.json')}))
        finally:
            server.terminate()
            try:server.wait(timeout=15)
            except subprocess.TimeoutExpired:server.kill();server.wait()
            log.flush()
            log_path = Path(log.name)
            log_path.write_text(log_path.read_text().replace(token, "[redacted]"))


if __name__=='__main__':main()
