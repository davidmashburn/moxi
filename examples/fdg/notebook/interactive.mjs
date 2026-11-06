import {instantiateMoxi, EventKind, Control, AppField, NodeField} from "./runtime.mjs";

export const Protocol = Object.freeze({version:1, bytes:4096, timeoutMs:4000, heartbeatMs:750, intervalMs:50});
export const Kind = Object.freeze({hello:'hello', state:'state', ping:'ping', dispose:'dispose', ack:'ack', error:'error'});
export const Life = Object.freeze({starting:'starting', live:'live', failed:'failed', disposed:'disposed'});
const Phase = Object.freeze({sceneStart:0, serializeStart:1, serializeEnd:2, eventStart:3, eventEnd:4});
const MAX_SAMPLES = 120;
function sample(array, value) { array.push(value); if(array.length > MAX_SAMPLES) array.shift(); }

// One in-flight message and one latest-state slot. Release counts are cumulative
// and never coalesced away, even if the next gesture begins before an ACK.
export class Channel {
  constructor(model, identity, {ack, fail, now=()=>performance.now()}) {
    Object.assign(this,{model,identity,ack,fail,now});
    this.sequence=0; this.flight=null; this.pending=null; this.lastSend=-Infinity;
    this.metrics={sent:0,coalesced:0,maxQueued:0,roundtripMs:[],serializeMs:[],bytes:[]};
    this.receive=this.receive.bind(this); model.on('msg:custom',this.receive);
  }
  send(kind, state) {
    if(this.flight) return false;
    const start=this.now();
    const message={v:Protocol.version,...this.identity,seq:++this.sequence,kind};
    if(state)message.state=state;
    const size=new TextEncoder().encode(JSON.stringify(message)).length;
    if(size>Protocol.bytes)throw Error('Comm message exceeds capacity');
    sample(this.metrics.serializeMs,this.now()-start); sample(this.metrics.bytes,size);
    this.flight={seq:message.seq,start,kind};this.lastSend=start;this.metrics.sent++;
    try {this.model.send(message);return true;}
    catch(error){
      this.flight=null;this.pending=null;
      if(kind!==Kind.dispose)this.fail(`Kernel comm closed: ${String(error)}; rerun the cell after restart.`);
      return false;
    }
  }
  queue(state) {
    if(this.pending)this.metrics.coalesced++;
    this.pending=state;this.metrics.maxQueued=Math.max(this.metrics.maxQueued,1+(this.flight?1:0));
    this.flush();
  }
  flush() {
    if(this.pending && !this.flight && this.now()-this.lastSend>=Protocol.intervalMs) {
      const state=this.pending;this.pending=null;this.send(Kind.state,state);
    }
  }
  receive(message) {
    if(!message || message.v!==Protocol.version || !Object.entries(this.identity).every(([k,v])=>message[k]===v) || message.seq!==this.flight?.seq)return;
    if(message.kind!==Kind.ack && message.kind!==Kind.error)return;
    const flight=this.flight;this.flight=null;
    sample(this.metrics.roundtripMs,this.now()-flight.start);
    if(message.kind===Kind.error){this.pending=null;this.fail(message.detail);return;}
    this.ack(message,flight.kind);this.flush();
  }
  tick() {
    if(this.flight && this.now()-this.flight.start>Protocol.timeoutMs) {
      this.flight=null;this.pending=null;this.fail('Kernel connection timed out. Retry after reconnect, or rerun after kernel restart.');return;
    }
    this.flush();
    if(!this.flight && this.now()-this.lastSend>=Protocol.heartbeatMs)this.send(Kind.ping);
  }
  dispose() {
    this.model.off('msg:custom',this.receive);
    // A disposal notification is bounded; outstanding acknowledgements are ignored.
    this.flight=null;this.pending=null;this.send(Kind.dispose);this.flight=null;
  }
}

export default {render({model,el}) {
  const identity={session:model.get('session'),generation:model.get('generation'),view:crypto.randomUUID()};
  let life=Life.starting, runtime=null, owner=null, raf=0, timer=0, observer=null, controller=null;
  let active=null, pendingMove=null, releaseCount=0, epoch=0, width=1000, height=620, lastFrame=0, inputRaf=0;
  let semantics=[];
  const measures={layoutMs:[],sceneMs:[],svgSerializeMs:[],wasmTransferMs:[],domSubmitMs:[],inputToDomMs:[],inputToNextRafMs:[]};
  const marks=new Map();
  el.innerHTML=`<section class="moxi-inline" style="border:1px solid #9aabba;border-radius:8px;padding:12px;background:#f4f7fa;color:#182e43"><h3 style="margin:0 0 8px"></h3><div role="status" class="moxi-status"></div><div style="display:flex;gap:8px;margin:8px 0"><button class="moxi-retry">Retry backend</button><button class="moxi-export">Export current SVG</button><button class="moxi-close">Dispose output</button></div><div class="moxi-surface" tabindex="0" role="application" aria-label="Moxi force-directed graph" style="position:relative;width:100%;height:620px;touch-action:none;outline-offset:2px"><div class="moxi-svg" style="width:100%;height:100%"></div></div></section>`;
  const status=el.querySelector('.moxi-status'), surface=el.querySelector('.moxi-surface'), svg=el.querySelector('.moxi-svg');
  el.querySelector('h3').textContent=model.get('title');
  svg.innerHTML=model.get('fallback');
  function normalizeSVG() { const s=svg.querySelector('svg');if(s){s.setAttribute('viewBox',`0 0 ${width} ${height}`);s.setAttribute('width','100%');s.setAttribute('height','100%');s.setAttribute('preserveAspectRatio','none');} }
  normalizeSVG();
  function setLife(value,text){life=value;el.dataset.moxiLife=value;status.textContent=text;}
  function snapshot(){return {selected:owner.inspect(-1,AppField.selected),paused:!!owner.inspect(-1,AppField.paused),panX:owner.inspect(-1,AppField.panX),panY:owner.inspect(-1,AppField.panY),zoom:owner.inspect(-1,AppField.zoom),releases:releaseCount,dragging:active!==null};}
  function draw(){
    const frame=owner.render();semantics=frame.semantics;sample(measures.wasmTransferMs,frame.transferMs);
    const start=performance.now();svg.innerHTML=frame.svg;normalizeSVG();sample(measures.domSubmitMs,performance.now()-start);
  }
  function releaseCapture(){if(active!==null){const pointer=active;active=null;try{surface.releasePointerCapture(pointer);}catch{}}}
  function stopRuntime(){
    epoch++;cancelAnimationFrame(raf);cancelAnimationFrame(inputRaf);raf=0;inputRaf=0;clearInterval(timer);timer=0;
    observer?.disconnect();observer=null;controller?.abort();controller=null;pendingMove=null;
    if(owner){try{owner.event(EventKind.cancel);}catch{} releaseCapture();}
    runtime?.dispose();runtime=null;owner=null;
  }
  function fail(error){if(life===Life.disposed)return;stopRuntime();setLife(Life.failed,`Backend stopped: ${String(error)}`);}
  const channel=new Channel(model,identity,{
    fail,
    ack:(_,kind)=>{if(kind===Kind.hello && life===Life.starting)startRuntime();},
  });
  function guarded(fn){return (...args)=>{if(life!==Life.live)return;try{fn(...args);}catch(error){fail(error);}};}
  function gesture(fn, start=performance.now()){
    fn();draw();channel.queue(snapshot());sample(measures.inputToDomMs,performance.now()-start);
    const current=epoch;
    cancelAnimationFrame(inputRaf);
    inputRaf=requestAnimationFrame(()=>{inputRaf=0;if(epoch===current)sample(measures.inputToNextRafMs,performance.now()-start);});
  }
  function point(event){const rect=surface.getBoundingClientRect();return {x:(event.clientX-rect.left)*width/rect.width,y:(event.clientY-rect.top)*height/rect.height};}
  function finish(event,kind){
    if(active!==event.pointerId)return;
    // Consume the last coalesced position before the terminal event.
    const move=pendingMove;pendingMove=null;
    gesture(()=>{if(move)owner.event(EventKind.move,move);owner.event(kind,point(event));releaseCount++;releaseCapture();});
  }
  function frame(now){
    if(life!==Life.live)return;
    try {
      if(pendingMove){const move=pendingMove;pendingMove=null;gesture(()=>owner.event(EventKind.move,move),move.started);}
      if(now-lastFrame>=33 && !owner.inspect(-1,AppField.paused) && owner.inspect(-1,AppField.alpha)>.001){owner.event(EventKind.frame);draw();lastFrame=now;}
      raf=requestAnimationFrame(frame);
    }catch(error){fail(error);}
  }
  async function startRuntime(){
    const current=++epoch;
    try {
      const bytes=Uint8Array.from(atob(model.get('wasm')),c=>c.charCodeAt(0));
      const next=await instantiateMoxi(bytes,{observe:phase=>{
        const now=performance.now();
        if(phase===Phase.serializeStart)sample(measures.sceneMs,now-marks.get(Phase.sceneStart));
        if(phase===Phase.serializeEnd)sample(measures.svgSerializeMs,now-marks.get(Phase.serializeStart));
        if(phase===Phase.eventEnd)sample(measures.layoutMs,now-marks.get(Phase.eventStart));
        marks.set(phase,now);
      }});
      if(current!==epoch || life===Life.disposed){next.dispose();return;}
      runtime=next;
      const rect=surface.getBoundingClientRect();width=Math.max(640,Math.min(4096,rect.width));height=Math.max(320,Math.min(4096,rect.height));
      owner=runtime.create({width,height,graph:model.get('graph')});
      for(let i=0;i<100;i++)owner.event(EventKind.frame);
      owner.event(EventKind.action,{key:Control.fit,value:1});owner.event(EventKind.action,{key:Control.pause,value:1});
      setLife(Life.live,'Live Mojo/Moxi · kernel roundtrip confirmed · browser-owned graph');
      controller=new AbortController();const options={signal:controller.signal};
      surface.addEventListener('pointerdown',guarded(event=>{
        if(active!==null || event.button!==0)return;event.preventDefault();surface.focus();
        const p=point(event), bounds=semantics.find(n=>n.id===Control.export)?.bounds;
        if(bounds && p.x>=bounds.x && p.x<=bounds.x+bounds.width && p.y>=bounds.y && p.y<=bounds.y+bounds.height){exportSVG();return;}
        active=event.pointerId;surface.setPointerCapture(active);
        gesture(()=>owner.event(EventKind.down,point(event)));
      }),options);
      surface.addEventListener('pointermove',guarded(event=>{if(event.pointerId===active)pendingMove={...point(event),started:performance.now()};}),options);
      surface.addEventListener('pointerup',guarded(event=>finish(event,EventKind.up)),options);
      surface.addEventListener('pointercancel',guarded(event=>finish(event,EventKind.cancel)),options);
      surface.addEventListener('lostpointercapture',guarded(event=>finish(event,EventKind.cancel)),options);
      surface.addEventListener('wheel',guarded(event=>{event.preventDefault();gesture(()=>owner.event(EventKind.scroll,{...point(event),value:Math.max(-16,Math.min(16,-event.deltaY/40))}));}),{...options,passive:false});
      surface.addEventListener('keydown',guarded(event=>{
        if(event.key==='Escape' && active!==null){finish({pointerId:active,clientX:0,clientY:0},EventKind.cancel);event.preventDefault();return;}
        const keys={ArrowLeft:1000,ArrowRight:1001,ArrowUp:1002,ArrowDown:1003};
        if(Object.hasOwn(keys,event.key)){event.preventDefault();gesture(()=>owner.event(EventKind.key,{key:keys[event.key]}));}
        else if(event.key===' '){event.preventDefault();gesture(()=>owner.event(EventKind.action,{key:Control.pause,value:1}));}
      }),options);
      window.addEventListener('blur',guarded(()=>{if(active!==null)finish({pointerId:active,clientX:0,clientY:0},EventKind.cancel);}),options);
      observer=new ResizeObserver(guarded(()=>{
        const r=surface.getBoundingClientRect();width=Math.max(640,Math.min(4096,r.width));height=Math.max(320,Math.min(4096,r.height));
        owner.resize(width,height);draw();
      }));observer.observe(surface);
      draw();channel.queue(snapshot());raf=requestAnimationFrame(frame);
    }catch(error){fail(error);}
  }
  function connect(){
    if(life===Life.disposed)return;
    stopRuntime();channel.flight=null;channel.pending=null;
    setLife(Life.starting,'Connecting to the kernel…');
    if(channel.send(Kind.hello))timer=setInterval(()=>channel.tick(),50);
  }
  const toolbar=new AbortController();
  el.querySelector('.moxi-retry').addEventListener('click',connect,{signal:toolbar.signal});
  el.querySelector('.moxi-close').addEventListener('click',()=>dispose(),{signal:toolbar.signal});
  function exportSVG(){
    const content=owner?owner.render().svg:model.get('fallback');
    const url=URL.createObjectURL(new Blob([content],{type:'image/svg+xml'}));
    const a=document.createElement('a');a.href=url;a.download='moxi-graph.svg';a.click();setTimeout(()=>URL.revokeObjectURL(url),0);
  }
  el.querySelector('.moxi-export').addEventListener('click',exportSVG,{signal:toolbar.signal});
  function dispose(){if(life===Life.disposed)return;stopRuntime();channel.dispose();toolbar.abort();setLife(Life.disposed,'Disposed · animation, pointers, observers and comm listener released');}
  // Read-only app inspection and bounded metrics for the real-browser checks.
  el.moxi={get life(){return life;},get owner(){return owner;},get runtime(){return runtime;},get channel(){return channel;},get measures(){return measures;},get resources(){return {raf:!!raf,inputRaf:!!inputRaf,timer:!!timer,observer:!!observer,listeners:!!controller};},snapshot,dimensions:()=>({width,height}),dispose};
  connect();
  return dispose;
}};
