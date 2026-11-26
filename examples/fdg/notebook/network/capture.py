#!/usr/bin/env python3
"""Real Lab/P04 checks over the fixture's separate kernel network namespace."""
import argparse
from datetime import datetime, timezone
from enum import IntEnum, StrEnum
import hashlib
import json
import math
from pathlib import Path
from statistics import median
import subprocess
import time

from playwright.sync_api import sync_playwright

from fixture import DEFAULT, DIST, NOTEBOOK, ROOT, partition, read_state, topology

WIDGETS = "document.querySelectorAll('[data-moxi-life]')"


class Life(StrEnum):
    STARTING = 'starting'
    LIVE = 'live'
    FAILED = 'failed'
    DISPOSED = 'disposed'


class KernelStatus(StrEnum):
    BUSY = 'busy'
    IDLE = 'idle'


class Outcome(StrEnum):
    PASS = 'pass'
    FAILED = 'failed'


class Control(IntEnum):
    PAUSE = 10
    REHEAT = 11
    FIT = 12
    LABELS = 13
    NEIGHBORS = 14
    EXPORT = 15
    SEARCH = 20
    FIND = 21
    LESS = 22
    MORE = 23


class AppField(IntEnum):
    ALPHA = 5


class NodeField(IntEnum):
    PINNED = 4
    SCREEN_X = 5


def summary(values):
    if not values:
        return dict(n=0)
    values = sorted(values)
    return dict(n=len(values), median=median(values), p95=values[math.ceil(len(values)*.95)-1], maximum=max(values))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--directory', type=Path, default=DEFAULT)
    args = parser.parse_args()
    directory = args.directory.resolve()
    state = read_state(directory)
    captures = directory / 'captures'
    captures.mkdir(exist_ok=True)
    record = dict(captured_at=datetime.now(timezone.utc).isoformat(),
                  checkout=str(ROOT), url=f'http://127.0.0.1:{state["port"]}', device_scale_factor=1,
                  revision=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
                  scoped_status=subprocess.check_output(['git', 'status', '--porcelain', '--', str(NOTEBOOK)], cwd=ROOT, text=True).splitlines(),
                  browser='Google Chrome via Playwright; isolated headless profile', viewport=dict(width=1600,height=1200),
                  fixture='synthetic P04 77/254 and 256/1024; no external accounts', scenarios=[],
                  local_emulation=True, physical_remote_host_acceptance=False)
    record['source_hashes'] = {str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest()
                              for p in [NOTEBOOK/'interactive.py', NOTEBOOK/'interactive.mjs', NOTEBOOK/'prepare_interactive.py', *sorted(Path(__file__).parent.glob('*.py')),Path(__file__).parent/'Dockerfile']}
    started = time.monotonic()

    def scenario(name, steps, expected, observed, screenshot=None):
        entry = dict(name=name, steps=steps, expected=expected, observed=observed, outcome=Outcome.PASS,
                     elapsed_seconds=round(time.monotonic()-started, 3))
        if screenshot:
            entry['screenshot'] = f'captures/{screenshot}'
        record['scenarios'].append(entry)
        (directory / 'evidence.json').write_text(json.dumps(record, indent=2) + '\n')
        print(f'PASS: {name}', flush=True)

    with sync_playwright() as pw:
        browser = pw.chromium.launch(channel='chrome', headless=True)
        record['browser_version'] = browser.version
        context = browser.new_context(viewport=record['viewport'], device_scale_factor=1, accept_downloads=True)
        page = context.new_page()
        page.set_default_timeout(30000)
        errors = []
        page.on('pageerror', lambda e: errors.append(str(e)))
        path = 'examples/fdg/dist/interactive/network.ipynb'
        page.goto(f'http://127.0.0.1:{state["port"]}/lab/tree/{path}?token={state["token"]}')
        page.wait_for_function(f"window.jupyterapp?.shell.currentWidget?.context?.path==={json.dumps(path)}")
        page.evaluate("async()=>{const a=window.jupyterapp;await a.shell.currentWidget.sessionContext.ready;a.shell.currentWidget.content.notebookConfig={...a.shell.currentWidget.content.notebookConfig,windowingMode:'none'};await a.commands.execute('notebook:run-all-cells');}")

        def live():
            page.wait_for_function(f"{WIDGETS}.length===2 && [...{WIDGETS}].every(e=>e.moxi?.life==={json.dumps(Life.LIVE)})")

        def code(source):
            page.evaluate("""code=>{const k=window.jupyterapp.shell.currentWidget.sessionContext.session.kernel;
            window.p04execute={done:false};const f=k.requestExecute({code,store_history:false});let output='';
            f.onIOPub=m=>{if(m.header.msg_type==='stream')output+=m.content.text;};
            f.done.then(reply=>{window.p04execute={done:true,ok:reply.content.status==='ok',output:output.trim(),reply:reply.content};},
                error=>{window.p04execute={done:true,ok:false,error:String(error)};});}""", source)
            page.wait_for_function('window.p04execute.done')
            result = page.evaluate('window.p04execute')
            assert result['ok'], result
            return result['output']

        def inspect(i=0):
            return page.evaluate(f"i=>{WIDGETS}[i].moxi.snapshot()", i)

        def wait_ack():
            page.wait_for_function(f"[...{WIDGETS}].every(e=>!e.moxi.channel.pending && !e.moxi.channel.flight)")

        def scroll(i=0):
            page.evaluate("async i=>{const n=window.jupyterapp.shell.currentWidget.content;n.activeCellIndex=i+2;await n.scrollToItem(i+2,'start');}", i)
            page.locator('.moxi-inline').nth(i).scroll_into_view_if_needed()

        def capture(name):
            page.screenshot(path=str(captures / name))

        def point(node=0):
            return page.evaluate(f"""n=>{{const e={WIDGETS}[0],r=e.querySelector('.moxi-surface').getBoundingClientRect(),d=e.moxi.dimensions();
            return {{x:r.left+e.moxi.owner.inspect(n,5)*r.width/d.width,y:r.top+e.moxi.owner.inspect(n,6)*r.height/d.height}};}}""", node)

        def resources_stopped():
            return page.evaluate(f"[...{WIDGETS}].every(e=>Object.values(e.moxi.resources).every(v=>!v))")

        try:
            live()
            for label in ('No', 'Ignore all updates'):
                button = page.get_by_role('button', name=label, exact=True)
                if button.is_visible():
                    button.click()
            page.evaluate("window.jupyterapp.commands.execute('application:toggle-left-area')")
            scroll()
            location = json.loads(code("import os,socket,json,hashlib; from pathlib import Path; import interactive; print(json.dumps(dict(hostname=socket.gethostname(),pid=os.getpid(),network_namespace=os.readlink('/proc/self/ns/net'),source_sha256=hashlib.sha256(Path(interactive.__file__).read_bytes()).hexdigest())))"))
            proof = topology(directory)
            assert location['hostname'] == 'p04-kernel'
            assert location['network_namespace'] == proof['hosts']['kernel']['network_namespace']
            assert not proof['hosts']['lab']['ipykernel_processes']
            assert proof['hosts']['kernel']['ipykernel_processes']
            assert location['source_sha256'] == hashlib.sha256((NOTEBOOK / 'interactive.py').read_bytes()).hexdigest()
            record['kernel_location'] = location
            counts = page.evaluate(f"[...{WIDGETS}].map(e=>[e.moxi.owner.inspect(-1,6),e.moxi.owner.inspect(-1,7)])")
            assert counts == [[77,254],[256,1024]], counts
            capture('01-separate-kernel.png')
            scenario('separate kernel namespace', 'Run the unchanged P04 notebook through Lab GatewayClient.',
                     'Both actual Mojo widgets live; ipykernel runs only on the other host.',
                     dict(counts=counts, kernel=location, lab_namespace=proof['hosts']['lab']['network_namespace']), '01-separate-kernel.png')

            before_b = inspect(1)
            p = point()
            page.mouse.move(**p); page.mouse.down(); page.mouse.move(p['x']+60,p['y']+35,steps=12)
            selected = inspect()['selected']
            assert selected >= 0
            assert page.evaluate(f'{WIDGETS}[0].moxi.owner.inspect({selected},4)') == 1
            capture('02-active-drag.png')
            page.mouse.up()
            assert page.evaluate(f'{WIDGETS}[0].moxi.owner.inspect({selected},4)') == 0
            bounds = page.locator('.moxi-surface').first.bounding_box()
            x,y = bounds['x']+25,bounds['y']+bounds['height']-90
            pan = inspect()['panX']
            page.mouse.move(x,y); page.mouse.down(); page.mouse.move(x+50,y-25,steps=8); page.mouse.up()
            assert inspect()['panX'] != pan
            zoom = inspect()['zoom']; page.mouse.wheel(0,-160)
            page.wait_for_function(f'{WIDGETS}[0].moxi.snapshot().zoom!=={zoom}')
            page.locator('.moxi-surface').first.press(' ')
            assert not inspect()['paused']
            page.wait_for_timeout(200)
            page.locator('.moxi-surface').first.press(' ')
            assert inspect()['paused'] and inspect(1) == before_b
            wait_ack()
            assert not json.loads(code('print(json.dumps(a.snapshot))'))['dragging']
            scenario('gestures and output isolation', 'Drag/release, pan, zoom and toggle pause in A.',
                     'Real Mojo pin released; state ACK reaches the other host; B unchanged.',
                     dict(a=inspect(), b_unchanged=inspect(1)==before_b), '02-active-drag.png')

            before_coalesced = page.evaluate(f'{WIDGETS}[0].moxi.channel.metrics.coalesced')
            page.evaluate("""()=>{window.p04busyDone=false;window.p04busyStarted=false;window.p04busyStatus=null;
            const f=window.jupyterapp.shell.currentWidget.sessionContext.session.kernel.requestExecute({code:'import time;print("p04-busy-start",flush=True);time.sleep(3)',store_history:false});
            f.onIOPub=m=>{
                if(m.header.msg_type==='status')window.p04busyStatus=m.content.execution_state;
                if(m.header.msg_type==='stream' && m.content.text.includes('p04-busy-start'))window.p04busyStarted=true;
            };
            window.p04busy=f.done.then(reply=>{
                window.p04busyDone=true;if(reply.content.status!=='ok')throw Error(JSON.stringify(reply.content));
            });}""")
            page.wait_for_function(f"window.p04busyStarted && window.p04busyStatus==={json.dumps(KernelStatus.BUSY)} && !window.p04busyDone")
            p = point(2); page.mouse.move(**p); page.mouse.down()
            selected = inspect()['selected']
            assert selected >= 0
            before_x = page.evaluate(f'{WIDGETS}[0].moxi.owner.inspect({selected},{NodeField.SCREEN_X})')
            page.evaluate(f"window.p04busySVG={WIDGETS}[0].querySelector('.moxi-svg').innerHTML")
            # One browser input sequence avoids spending the busy interval on
            # Python/browser round trips; all 65 moves still enter as real input.
            page.mouse.move(p['x']+32,p['y']+21,steps=65)
            page.wait_for_function(f"{WIDGETS}[0].moxi.owner.inspect({selected},{NodeField.SCREEN_X})!=={before_x}")
            during = page.evaluate(f"""()=>({{kernel_status:window.jupyterapp.shell.currentWidget.sessionContext.session.kernel.status,
            execute_status:window.p04busyStatus,execute_started:window.p04busyStarted,
            execution_done:window.p04busyDone,x:{WIDGETS}[0].moxi.owner.inspect({selected},{NodeField.SCREEN_X}),
            pinned:{WIDGETS}[0].moxi.owner.inspect({selected},{NodeField.PINNED}),dragging:{WIDGETS}[0].moxi.snapshot().dragging,
            queued:Number(!!{WIDGETS}[0].moxi.channel.flight)+Number(!!{WIDGETS}[0].moxi.channel.pending),coalesced:{WIDGETS}[0].moxi.channel.metrics.coalesced,
            svg_changed:{WIDGETS}[0].querySelector('.moxi-svg').innerHTML!==window.p04busySVG}})""")
            assert KernelStatus(during['execute_status']) is KernelStatus.BUSY and during['execute_started'] and not during['execution_done'], during
            assert during['x'] != before_x and during['pinned'] == 1 and during['dragging'] and during['svg_changed'], during
            assert during['queued'] <= 2 and during['coalesced'] > before_coalesced, during
            capture('02-busy-local-feedback.png')
            page.mouse.up()
            released = page.evaluate(f"""()=>({{execution_done:window.p04busyDone,
            execute_status:window.p04busyStatus,
            kernel_status:window.jupyterapp.shell.currentWidget.sessionContext.session.kernel.status,
            pinned:{WIDGETS}[0].moxi.owner.inspect({selected},{NodeField.PINNED}),dragging:{WIDGETS}[0].moxi.snapshot().dragging}})""")
            assert not released['execution_done'] and KernelStatus(released['execute_status']) is KernelStatus.BUSY, released
            assert released['pinned'] == 0 and not released['dragging'], released
            page.evaluate('window.p04busy'); wait_ack()
            backend = json.loads(code('print(json.dumps(a.snapshot))'))
            channel = page.evaluate(f'{WIDGETS}[0].moxi.channel.metrics')
            assert channel['maxQueued'] <= 2 and channel['coalesced'] > 0
            assert backend['releases'] == inspect()['releases'] and not backend['dragging']
            scenario('busy kernel bounded delivery', 'Wait for actual busy status, then drag and release during a 3 s kernel execution.',
                     'Immediate local feedback; at most two queued states; final release acknowledged.',
                     dict(before_x=before_x,before_coalesced=before_coalesced,during=during,released=released,max_queued=channel['maxQueued'],coalesced=channel['coalesced'],backend=backend),
                     '02-busy-local-feedback.png')

            # Trace actual browser Paint separately from DOM and next-rAF timings.
            cdp = context.new_cdp_session(page)
            trace_events=[]
            cdp.on('Tracing.dataCollected', lambda data: trace_events.extend(data['value']))
            cdp.send('Tracing.start', {'categories':'devtools.timeline','transferMode':'ReportEvents'})
            page.locator('.moxi-surface').first.press(' ')
            page.wait_for_timeout(900)
            page.locator('.moxi-surface').first.press(' ')
            with page.expect_event('console', predicate=lambda m:m.text=='p04-network-trace-complete'):
                cdp.once('Tracing.tracingComplete', lambda _:page.evaluate("console.log('p04-network-trace-complete')"))
                cdp.send('Tracing.end')
            (directory / 'paint.json').write_text(json.dumps(trace_events))
            paint = [e['dur']/1000 for e in trace_events if e.get('name')=='Paint' and e.get('ph')=='X' and 'dur' in e]
            assert paint
            record['measurements'] = page.evaluate(f"[...{WIDGETS}].map(e=>({{phases:e.moxi.measures,comm:e.moxi.channel.metrics}}))")
            record['phase_ms'] = [{k:summary(v) for k,v in m['phases'].items()} for m in record['measurements']]
            record['paint_ms'] = summary(paint)
            record['roundtrip_ms'] = summary(record['measurements'][0]['comm']['roundtripMs'])
            scenario('phase and transport metrics', 'Record Chrome trace while the actual solver is resumed.',
                     'Separate solver, scene, SVG, DOM, input, Paint and end-to-end comm measurements.',
                     dict(paint_ms=record['paint_ms'],roundtrip_ms=record['roundtrip_ms']))

            page.set_viewport_size(dict(width=480,height=1100)); scroll()
            toolbar = page.locator('.moxi-inline').first
            clipping = toolbar.evaluate("""e=>{const box=e.getBoundingClientRect();return {width:box.width,
            toolbarInside:[...e.querySelectorAll('button')].every(b=>{const r=b.getBoundingClientRect();return r.left>=box.left && r.right<=box.right && r.width>=b.scrollWidth;}),
            viewportWidth:e.querySelector('.moxi-viewport').clientWidth,surfaceWidth:e.querySelector('.moxi-surface').clientWidth,
            pageOverflow:document.documentElement.scrollWidth>innerWidth};}""")
            assert clipping['toolbarInside'] and not clipping['pageOverflow'], clipping
            assert clipping['surfaceWidth'] >= 800 and clipping['viewportWidth'] < clipping['surfaceWidth']
            capture('03-narrow-wrapped.png')
            viewport = page.locator('.moxi-viewport').first
            # Use trusted Tab/Arrow events, without injecting a widget handler or
            # assigning scrollLeft. Jupyter must not navigate to another cell.
            page.locator('.moxi-close').first.focus(); page.keyboard.press('Tab')
            assert viewport.evaluate('e=>document.activeElement===e')
            before_keys = inspect()
            page.keyboard.press('ArrowRight')
            page.wait_for_function("document.querySelector('.moxi-viewport').scrollLeft>0")
            keyboard_right = viewport.evaluate('e=>({focused:document.activeElement===e,scrollLeft:e.scrollLeft})')
            assert keyboard_right['focused'] and inspect() == before_keys, keyboard_right
            capture('03-narrow-keyboard.png')
            page.keyboard.press('ArrowLeft')
            page.wait_for_function("document.querySelector('.moxi-viewport').scrollLeft===0")
            assert viewport.evaluate('e=>document.activeElement===e')
            page.keyboard.press('Tab')
            assert page.locator('.moxi-surface').first.evaluate('e=>document.activeElement===e')
            page.keyboard.press('ArrowRight')
            assert inspect()['selected'] != before_keys['selected']
            assert page.locator('.moxi-surface').first.evaluate('e=>document.activeElement===e')
            assert viewport.evaluate('e=>e.scrollLeft') == 0
            scenario('narrow keyboard scrolling', 'At 480 px, Tab from Dispose to the viewport, ArrowRight, ArrowLeft, Tab into the graph, ArrowRight.',
                     'Native scrolling retains viewport focus without selecting a node; Tab exits and graph arrows still select.',
                     dict(viewport=dict(width=480,height=1100),right=keyboard_right,left_scroll=0,surface_selects=True), '03-narrow-keyboard.png')

            targets = []

            def control_point(control):
                viewport.hover()
                delta = page.evaluate(f"""id=>{{const e={WIDGETS}[0],v=e.querySelector('.moxi-viewport'),
                b=e.moxi.owner.render().semantics.find(n=>n.id===id).bounds;return b.x+b.width/2-v.clientWidth/2-v.scrollLeft;}}""", control)
                zoom = inspect()['zoom']
                page.mouse.wheel(delta,0)
                # Inspect SVG semantics, not the unrelated outer DOM buttons.
                geometry = f"""id=>{{const e={WIDGETS}[0],v=e.querySelector('.moxi-viewport').getBoundingClientRect(),
                s=e.querySelector('.moxi-surface').getBoundingClientRect(),d=e.moxi.dimensions(),n=e.moxi.owner.render().semantics.find(n=>n.id===id),b=n.bounds,
                left=s.left+b.x*s.width/d.width,right=s.left+(b.x+b.width)*s.width/d.width,top=s.top+b.y*s.height/d.height,bottom=s.top+(b.y+b.height)*s.height/d.height;
                return {{id,label:n.label,enabled:n.enabled,width:right-left,height:bottom-top,x:(left+right)/2,y:(top+bottom)/2,
                visible:left>=v.left && right<=v.right && top>=v.top && bottom<=v.bottom && top>=0 && bottom<=innerHeight}};}}"""
                page.wait_for_function(f'id=>({geometry})(id).visible', arg=control)
                target = page.evaluate(geometry, control)
                assert target['visible'] and target['enabled'] and target['height'] >= 32, target
                assert inspect()['zoom'] == zoom
                targets.append(target)
                return dict(x=target['x'],y=target['y'])

            def click(control):
                page.mouse.click(**control_point(control))

            def label(control):
                return page.evaluate(f'id=>{WIDGETS}[0].moxi.owner.render().semantics.find(n=>n.id===id).label', control)

            assert inspect()['paused']
            click(Control.PAUSE); assert not inspect()['paused']
            click(Control.PAUSE); assert inspect()['paused']
            click(Control.REHEAT); assert not inspect()['paused']
            click(Control.PAUSE); assert inspect()['paused']
            # Deliberately change zoom so a no-op Fit cannot pass.
            zoom = inspect()['zoom']
            viewport.hover(); page.mouse.wheel(0,-160)
            page.wait_for_function(f'{WIDGETS}[0].moxi.snapshot().zoom!=={zoom}')
            zoom = inspect()['zoom']
            click(Control.FIT); assert inspect()['zoom'] != zoom
            click(Control.LABELS); assert label(Control.LABELS) == 'Show labels'
            click(Control.LABELS); assert label(Control.LABELS) == 'Hide labels'
            click(Control.NEIGHBORS); assert label(Control.NEIGHBORS) == 'All nodes'
            click(Control.NEIGHBORS); assert label(Control.NEIGHBORS) == 'Neighbors'
            export = control_point(Control.EXPORT)
            with page.expect_download() as download:
                page.mouse.click(**export)
            download.value.save_as(directory / 'narrow-export.svg')
            assert '<svg' in (directory / 'narrow-export.svg').read_text()
            capture('04-narrow-right-controls.png')
            # Cover the second row too. Text/IME entry is outside this adapter's
            # contract; test the search hit target and Find's empty-query action.
            click(Control.SEARCH)
            assert page.evaluate(f'{WIDGETS}[0].moxi.owner.render().semantics.find(n=>n.id==={Control.SEARCH}).focused')
            assert inspect()['selected'] >= 0
            click(Control.FIND); assert inspect()['selected'] == -1
            repulsion = []
            for control in (Control.LESS, Control.MORE):
                click(Control.PAUSE)
                page.wait_for_function(f'{WIDGETS}[0].moxi.owner.inspect(-1,{AppField.ALPHA})<0.95')
                click(Control.PAUSE)
                alpha = page.evaluate(f'{WIDGETS}[0].moxi.owner.inspect(-1,{AppField.ALPHA})')
                click(control)
                reheated = page.evaluate(f'{WIDGETS}[0].moxi.owner.inspect(-1,{AppField.ALPHA})')
                assert reheated == 1 and reheated > alpha and inspect()['paused']
                repulsion.append(dict(control=control.name,before_alpha=alpha,after_alpha=reheated))

            # Native Shift+wheel axis conversion is not synthesized reliably by
            # Chrome automation. Assert the adapter lets it through without zoom
            # and record actual scrolling separately, without claiming physical input.
            viewport.hover(); page.mouse.wheel(-1000,0)
            page.wait_for_function("document.querySelector('.moxi-viewport').scrollLeft===0")
            viewport.evaluate("""e=>e.addEventListener('wheel',event=>{queueMicrotask(()=>{window.p04shiftWheel={shift:event.shiftKey,trusted:event.isTrusted,prevented:event.defaultPrevented};});},{once:true})""")
            zoom = inspect()['zoom']
            page.keyboard.down('Shift'); page.mouse.wheel(0,600); page.keyboard.up('Shift')
            page.wait_for_function('window.p04shiftWheel')
            shifted = page.evaluate("({...window.p04shiftWheel,scrollLeft:document.querySelector('.moxi-viewport').scrollLeft})")
            assert shifted['shift'] and shifted['trusted'] and not shifted['prevented'] and inspect()['zoom'] == zoom, shifted
            scenario('narrow controls and scrolled hit testing', 'At 480 px, horizontal-wheel and click all six first-row actions, search, Find and both repulsion controls; send Shift+wheel.',
                     'Full-size SVG targets are visible when clicked and produce state changes; Shift+wheel is not consumed as zoom.',
                     dict(clipping=clipping,targets=targets,repulsion=repulsion,shift_wheel=shifted,physical_shift_wheel_verified=False), '04-narrow-right-controls.png')
            page.set_viewport_size(record['viewport']); scroll()

            # Record ordered lifecycle mutations, including the detached old view.
            # Mutation order catches even same-task overlap that final-state polls miss.
            page.evaluate(f"""()=>{{window.p04old={WIDGETS}[0];window.p04rerun=[];
            window.p04rerunObserver=new MutationObserver(records=>{{
                const changes=records.filter(r=>r.type==='attributes');
                changes.forEach((r,i)=>{{const next=changes.slice(i+1).find(n=>n.target===r.target);
                    window.p04rerun.push({{old_view:r.target===window.p04old,from:r.oldValue,
                    to:next?next.oldValue:r.target.dataset.moxiLife,at:performance.now(),
                    old_life:window.p04old.moxi.life,old_resources:window.p04old.moxi.resources}});
                }});
            }});
            const options={{attributes:true,attributeOldValue:true,attributeFilter:['data-moxi-life'],subtree:true}};
            window.p04rerunObserver.observe(window.p04old.closest('.jp-CodeCell'),options);
            window.p04rerunObserver.observe(window.p04old,options);}}""")
            page.evaluate("async()=>{const a=window.jupyterapp;a.shell.currentWidget.content.activeCellIndex=2;await a.commands.execute('notebook:run-cell');}")
            page.wait_for_function(f"{WIDGETS}[0]!==window.p04old && {WIDGETS}[0].moxi.life==={json.dumps(Life.LIVE)}")
            ordering = page.evaluate('()=>{window.p04rerunObserver.disconnect();return window.p04rerun;}')
            record['rerun_events'] = ordering
            disposed_at = next(i for i,e in enumerate(ordering) if e['old_view'] and Life(e['to']) is Life.DISPOSED)
            live_at = next(i for i,e in enumerate(ordering) if not e['old_view'] and Life(e['to']) is Life.LIVE)
            assert disposed_at < live_at, ordering
            assert all(not v for v in ordering[disposed_at]['old_resources'].values()), ordering
            assert ordering[live_at]['old_life'] == Life.DISPOSED and all(not v for v in ordering[live_at]['old_resources'].values()), ordering
            scenario('rerun disposal', 'Rerun graph A on the separate kernel host.',
                     'The old view and its resources are disposed before the replacement is live.', dict(events=ordering,disposed_event=disposed_at,live_event=live_at))

            network_identity = page.evaluate(f'[...{WIDGETS}].map(e=>e.moxi.channel.identity)')
            partition(directory)
            cut_at = time.monotonic()
            page.wait_for_function(f"[...{WIDGETS}].every(e=>e.moxi.life==={json.dumps(Life.FAILED)})")
            assert resources_stopped()
            record['disconnect_detection_seconds'] = time.monotonic()-cut_at
            capture('05-network-cut.png')
            partition(directory, restore=True)
            restored_at = time.monotonic()
            # Retry is the first kernel-bound action after interface restoration:
            # no execute request may warm up the upstream connection first.
            page.locator('.moxi-retry').first.click()
            page.locator('.moxi-retry').nth(1).click()
            live(); wait_ack()
            assert page.evaluate(f'[...{WIDGETS}].map(e=>e.moxi.channel.identity)') == network_identity
            scroll(); capture('06-network-retry.png')
            scenario('network partition and explicit retry', 'Remove the kernel network interface, await lease expiry, restore the same IP, click Retry.',
                     'Both runtimes stop resources; same widget comm recovers without replaying pointer history.',
                     dict(detection_seconds=record['disconnect_detection_seconds'],recovery_seconds=time.monotonic()-restored_at,
                          warmup_execute=False,same_channel_identities=True,kernel_response=code('print(socket.gethostname())')),
                     '06-network-retry.png')

            code('a.set_backend_available(False)')
            page.wait_for_function(f"{WIDGETS}[0].moxi.life==={json.dumps(Life.FAILED)}")
            assert page.evaluate(f'Object.values({WIDGETS}[0].moxi.resources).every(v=>!v)')
            assert page.evaluate(f'{WIDGETS}[1].moxi.life') == Life.LIVE
            code('a.set_backend_available(True)'); page.locator('.moxi-retry').first.click(); live(); wait_ack()
            scenario('backend rejection and retry', 'Reject real Python messages in A, restore backend and Retry.',
                     'Only A stops and recovers.', dict(b_life=page.evaluate(f'{WIDGETS}[1].moxi.life')))

            pid = code('print(os.getpid())')
            page.evaluate(f'window.p04retired=[...{WIDGETS}]')
            page.evaluate('''()=>{window.p04restart=null;
            window.jupyterapp.shell.currentWidget.sessionContext.session.kernel.restart()
                .then(()=>{window.p04restart={ok:true};},error=>{window.p04restart={ok:false,error:String(error)};});}''')
            page.wait_for_function('window.p04restart!==null')
            assert page.evaluate('window.p04restart.ok'), page.evaluate('window.p04restart')
            page.wait_for_function("window.p04retired.every(e=>Object.values(e.moxi.resources).every(v=>!v))")
            capture('07-kernel-restart.png')
            new_pid = code('import os;print(os.getpid())')
            assert pid != new_pid
            page.evaluate("window.jupyterapp.commands.execute('notebook:run-all-cells')")
            live(); scroll(); capture('08-restarted-live.png')
            scenario('actual remote-namespace kernel restart', 'Restart through JupyterLab and rerun the original notebook.',
                     'Kernel PID changes on p04-kernel; old resources stop; fresh widgets work.',
                     dict(before_pid=pid,after_pid=new_pid), '08-restarted-live.png')

            page.evaluate('window.jupyterapp.shell.currentWidget.context.save()')
            code('a.close();b.close()')
            from nbconvert import HTMLExporter
            import nbformat
            saved = nbformat.read(directory / 'lab' / path, as_version=4)
            saved.metadata.pop('widgets', None)
            html,_ = HTMLExporter().from_notebook_node(saved)
            saved_html = directory / 'saved.html'
            saved_html.write_text(html)
            offline = browser.new_context(viewport=record['viewport'], offline=True)
            saved_page = offline.new_page(); saved_page.goto(saved_html.as_uri())
            saved_page.locator('details.moxi-static').first.evaluate('e=>e.open=true')
            saved_page.locator('details.moxi-static').first.scroll_into_view_if_needed()
            assert saved_page.locator('details.moxi-static svg').count() == 2
            assert saved_page.locator('[data-moxi-life]').count() == 0
            saved_page.screenshot(path=str(captures / '09-offline-fallback.png'))
            offline.close()
            scenario('saved static fallback', 'Save and export the executed notebook; reopen offline without widget state.',
                     'Both independent real Moxi SVG snapshots remain available.', dict(svg_count=2), '09-offline-fallback.png')
            assert not errors, errors
            record['frontend_errors'] = errors
            record['topology'] = topology(directory)
            record['build'] = json.loads((DIST / 'build.json').read_text())
            record['skipped'] = ['physical remote-host/WAN acceptance','other browser/frontend platforms','VoiceOver per task','physical input and independent human usability','sustained performance and network-only latency isolation']
            record['result'] = Outcome.PASS
        except BaseException as exc:
            record['result'] = Outcome.FAILED
            record['failure'] = dict(type=type(exc).__name__,detail=str(exc))
            record['frontend_errors'] = errors
            capture('failure.png')
            raise
        finally:
            (directory / 'evidence.json').write_text(json.dumps(record, indent=2) + '\n')
            browser.close()


if __name__ == '__main__':
    main()
