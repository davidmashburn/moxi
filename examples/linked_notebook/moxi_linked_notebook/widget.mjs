// Example-owned P05 transport. Similarity with P04 is evidence for a future seam,
// not a cross-frontend adapter contract or a dependency on the graph example.
export const Protocol = Object.freeze({version:1, bytes:4096, frameBytes:131072, timeoutMs:4000, heartbeatMs:750, intervalMs:50});
export const Kind = Object.freeze({hello:'hello', state:'state', ping:'ping', dispose:'dispose', ack:'ack', error:'error'});
export const Life = Object.freeze({starting:'starting', live:'live', failed:'failed', disposed:'disposed'});
const MAX_SAMPLES=120;
const sample=(a,v)=>{a.push(v);if(a.length>MAX_SAMPLES)a.shift();};
export class Channel {
  constructor(model,identity,{ack,fail,now=()=>performance.now()}) {
    Object.assign(this,{model,identity,ack,fail,now});
    this.sequence=0;this.flight=null;this.pending=null;this.lastSend=-Infinity;this.closed=false;
    this.metrics={sent:0,coalesced:0,maxQueued:0,roundtripMs:[],serializeMs:[],bytes:[]};
    this.receive=this.receive.bind(this);model.on('msg:custom',this.receive);
  }
  send(kind,state) {
    if(this.closed || this.flight)return;
    const start=this.now(), message={v:Protocol.version,...this.identity,seq:++this.sequence,kind};
    if(state)message.state={...state};
    const bytes=new TextEncoder().encode(JSON.stringify(message)).length;
    if(bytes>Protocol.bytes)throw Error('Message capacity exceeded');
    sample(this.metrics.serializeMs,this.now()-start);sample(this.metrics.bytes,bytes);
    this.flight={seq:message.seq,start,kind};this.lastSend=start;this.metrics.sent++;
    try{this.model.send(message);}catch{this.stop();this.fail('Kernel comm closed. Rerun after kernel restart.');}
  }
  queue(state) {
    if(this.closed)return;
    if(this.pending)this.metrics.coalesced++;
    this.pending={...state};this.metrics.maxQueued=Math.max(this.metrics.maxQueued,1+Number(!!this.flight));this.flush();
  }
  flush() {
    if(!this.closed && this.pending && !this.flight && this.now()-this.lastSend>=Protocol.intervalMs){const s=this.pending;this.pending=null;this.send(Kind.state,s);}
  }
  receive(m) {
    if(this.closed || !this.flight || !m || m.v!==Protocol.version || !Object.entries(this.identity).every(([k,v])=>m[k]===v) || m.seq!==this.flight.seq || ![Kind.ack,Kind.error].includes(m.kind))return;
    if(new TextEncoder().encode(JSON.stringify(m)).length>Protocol.frameBytes+4096){this.stop();this.fail('Frame capacity exceeded');return;}
    const f=this.flight;this.flight=null;sample(this.metrics.roundtripMs,this.now()-f.start);
    if(m.kind===Kind.error){this.stop();this.fail(m.detail);return;}
    this.ack(m,f.kind);this.flush();
  }
  tick(){
    if(this.closed)return;
    if(this.flight && this.now()-this.flight.start>Protocol.timeoutMs){this.stop();this.fail('Kernel timeout. Retry when idle, or rerun after restart.');return;}
    this.flush();if(!this.flight && this.now()-this.lastSend>=Protocol.heartbeatMs)this.send(Kind.ping);
  }
  stop(){this.flight=null;this.pending=null;}
  dispose(){if(this.closed)return;this.stop();this.send(Kind.dispose);this.closed=true;this.stop();this.model.off('msg:custom',this.receive);}
}

export default {render({model,el}) {
  const identity={session:model.get('session'),generation:model.get('generation'),view:crypto.randomUUID()};
  let life=Life.starting, frame=model.get('initial'), desired, finals=0, timer=0, active=null, focused=-1, inputAt=0;
  const listeners=new AbortController(), metrics={domMs:[],inputToDomMs:[],frameBytes:[],layoutMs:[],sceneMs:[],svgMs:[],processMs:[]};
  el.innerHTML=`<section class="moxi-linked"><style>
.moxi-linked{padding:16px;border:1px solid #97aebe;border-radius:8px;background:#f7fafc;color:#18334a;font:14px system-ui;max-width:1100px}
.moxi-linked *{box-sizing:border-box}.moxi-linked h3{margin:0 0 8px}.moxi-linked button,.moxi-linked select{font:inherit;padding:6px 10px;margin:2px;border:1px solid #859aaa;border-radius:4px;background:white;color:#18334a}
.moxi-linked button:focus-visible,.moxi-linked select:focus-visible,.moxi-linked [tabindex]:focus-visible{outline:3px solid #a235ad;outline-offset:2px}
.moxi-linked .tools{display:flex;gap:8px;flex-wrap:wrap;align-items:center;margin:10px 0}.moxi-linked .body{display:grid;grid-template-columns:minmax(0,2fr) minmax(180px,1fr);gap:16px}
.moxi-linked .surface{position:relative;touch-action:none;min-width:0}.moxi-linked .surface svg{width:100%;height:auto;display:block}.moxi-linked .preview{position:absolute;width:20px;height:20px;border:3px solid #a235ad;border-radius:50%;transform:translate(-50%,-50%);pointer-events:none;display:none}
.moxi-linked .records{max-height:235px;overflow:auto}.moxi-linked table{border-collapse:collapse;width:100%;font-variant-numeric:tabular-nums}.moxi-linked th,.moxi-linked td{padding:4px 8px;text-align:left;border-bottom:1px solid #d6e0e7}.moxi-linked tr.selected{background:#d4edf0}.moxi-linked .details{padding:12px;background:#e9f1f6;border-radius:6px}.moxi-linked .status{min-height:20px}.moxi-linked [hidden]{display:none!important}
@container (max-width:600px){.moxi-linked .body{grid-template-columns:1fr}}.moxi-linked{container-type:inline-size}
</style><h3></h3><p>Dose (x) and response (y), 0–100. Choose a mark or a record. Arrow keys move table focus; Enter or Space selects; Escape clears.</p>
<div class="status" role="status" aria-live="polite"></div>
<div class="tools"><label>Minimum response <select aria-label="Minimum response"><option value="0">0 — all</option><option value="40">40</option><option value="70">70</option><option value="100">100 — empty</option></select></label><button class="clear">Clear selection</button><button class="retry">Retry backend</button><button class="dispose">Dispose output</button></div>
<div class="body"><div class="surface" tabindex="0" role="group" aria-label="Assay scatter plot; choose records in the table for keyboard access"><div class="svg"></div><div class="preview"></div></div><div class="details" role="region" aria-label="Selected record" aria-live="polite"></div></div>
<div class="records"><table><caption>Linked records — Dose and response</caption><thead><tr><th scope="col">Sample</th><th scope="col">Dose</th><th scope="col">Response</th></tr></thead><tbody></tbody></table></div></section>`;
  const $=s=>el.querySelector(s), surface=$('.surface'), status=$('.status'), tbody=$('tbody'), preview=$('.preview'), filter=$('select');
  $('h3').textContent=model.get('title');
  const on=(target,event,handler)=>target.addEventListener(event,handler,{signal:listeners.signal});
  function setLife(value,text){life=value;el.dataset.linkedLife=value;status.textContent=text;filter.disabled=value!==Life.live;$('.clear').disabled=value!==Life.live;$('.retry').disabled=value!==Life.failed;}
  function resetDesired(){desired={selected:frame.selected,minimum:frame.minimum,finals,dataVersion:frame.dataVersion};filter.value=String(frame.minimum);}
  function showPreview(key){const p=frame.points.find(p=>p.key===key);preview.style.display=p?'block':'none';if(p){preview.style.left=`${100*p.x/720}%`;preview.style.top=`${100*p.y/360}%`;}}
  function cancel(){if(active!==null){const id=active;active=null;if(surface.hasPointerCapture(id))surface.releasePointerCapture(id);if(life===Life.live){finals++;desired.finals=finals;channel.queue(desired);}}showPreview(-1);}
  function draw(next){
    if(next.schema!==Protocol.version || next.dataVersion!==model.get('initial').dataVersion)throw Error('Unsupported or stale frame');
    const start=performance.now(), priorFocus=document.activeElement, focusedKey=priorFocus?.dataset?.key;
    frame=next;$('.svg').innerHTML=frame.svg;
    const svg=$('.svg svg');svg.setAttribute('viewBox','0 0 720 360');svg.setAttribute('role','img');svg.setAttribute('aria-label',`${frame.points.length} assay records; ${frame.selected<0?'no selection':`selected record ${frame.selected+1}`}`);
    tbody.replaceChildren();
    for(const row of frame.rows){const tr=document.createElement('tr');tr.classList.toggle('selected',row.key===frame.selected);const td=document.createElement('td'),button=document.createElement('button');button.textContent=row.label;button.dataset.key=String(row.key);button.setAttribute('aria-pressed',String(row.key===frame.selected));button.tabIndex=row.key===(focused>=0?focused:frame.rows[0]?.key)?0:-1;td.append(button);tr.append(td);for(const k of ['x','y']){const cell=document.createElement('td');cell.textContent=String(row[k]);tr.append(cell);}tbody.append(tr);}
    const d=frame.detail;$('.details').textContent=d?`${d.label} · Record ${d.key+1}\nDose: ${d.x}\nResponse: ${d.y}\nSelected in Moxi (${frame.selectionSemantic===1?'semantic state confirmed':'no semantic selection'}).`:'No record selected. Choose a plot mark or table record.';$('.details').style.whiteSpace='pre-line';
    if(!frame.rows.length){const tr=document.createElement('tr'),td=document.createElement('td');td.colSpan=3;td.textContent='No records match this filter.';tr.append(td);tbody.append(tr);}
    if(focusedKey!==undefined){const button=[...tbody.querySelectorAll('button')].find(b=>b.dataset.key===focusedKey)||tbody.querySelector('button');if(button){focused=Number(button.dataset.key);button.tabIndex=0;button.focus({preventScroll:true});}else surface.focus({preventScroll:true});}
    if(!tbody.querySelector('button[tabindex="0"]')){const first=tbody.querySelector('button');if(first){first.tabIndex=0;focused=Number(first.dataset.key);}}
    sample(metrics.domMs,performance.now()-start);sample(metrics.frameBytes,new TextEncoder().encode(JSON.stringify(frame)).length);
    for(const [key,value] of Object.entries({layoutMs:frame.layoutNs/1e6,sceneMs:frame.sceneNs/1e6,svgMs:frame.svgNs/1e6,processMs:frame.processMs}))sample(metrics[key],value);
    if(inputAt){sample(metrics.inputToDomMs,performance.now()-inputAt);inputAt=0;}
  }
  function fail(text){setLife(Life.failed,text);cancel();clearInterval(timer);timer=0;channel.stop();}
  const channel=new Channel(model,identity,{fail,ack(m,kind){
    if(m.dataVersion!==model.get('initial').dataVersion)return;
    finals=Math.max(finals,m.finals);
    if(m.frame && !channel.pending){try{draw(m.frame);resetDesired();}catch(error){fail(String(error));return;}}
    if(kind===Kind.hello)setLife(Life.live,'Ready. Moxi plot and details linked.');
    else if(!channel.pending)status.textContent=`Ready · ${frame.points.length} records · ${finals} final actions acknowledged`;
  }});
  function commit(selected=desired.selected){if(life!==Life.live)return;inputAt=performance.now();finals++;desired={...desired,selected,finals};status.textContent='Selection/filter pending in kernel…';channel.queue(desired);}
  function start(){if(life===Life.disposed)return;channel.stop();setLife(Life.starting,'Connecting to kernel…');channel.send(Kind.hello);clearInterval(timer);timer=setInterval(()=>channel.tick(),50);}
  function pick(event){const r=surface.getBoundingClientRect(),x=(event.clientX-r.left)*720/r.width,y=(event.clientY-r.top)*360/r.height;let best=-1,distance=12**2;for(const p of frame.points){const d=(p.x-x)**2+(p.y-y)**2;if(d<=distance){distance=d;best=p.key;}}return best;}
  on(surface,'pointerdown',event=>{if(life!==Life.live||event.button!==0||active!==null)return;active=event.pointerId;surface.setPointerCapture(active);surface.focus();showPreview(pick(event));});
  on(surface,'pointermove',event=>{if(event.pointerId===active)showPreview(pick(event));});
  on(surface,'pointerup',event=>{if(event.pointerId!==active)return;active=null;surface.releasePointerCapture(event.pointerId);showPreview(-1);commit(pick(event));});
  on(surface,'pointercancel',cancel);on(surface,'lostpointercapture',cancel);on(window,'blur',cancel);
  on(surface,'keydown',event=>{if(event.key==='Escape'){cancel();commit(-1);event.preventDefault();}});
  on(tbody,'focusin',event=>{if(!event.target.matches('button'))return;focused=Number(event.target.dataset.key);for(const b of tbody.querySelectorAll('button'))b.tabIndex=b===event.target?0:-1;showPreview(focused);});
  on(tbody,'focusout',()=>showPreview(-1));
  on(tbody,'click',event=>{const button=event.target.closest('button');if(button)commit(Number(button.dataset.key));});
  on(tbody,'keydown',event=>{const buttons=[...tbody.querySelectorAll('button')],i=buttons.indexOf(event.target);if(i<0)return;let next=i;if(['ArrowDown','ArrowRight'].includes(event.key))next=Math.min(i+1,buttons.length-1);else if(['ArrowUp','ArrowLeft'].includes(event.key))next=Math.max(i-1,0);else if(event.key==='Home')next=0;else if(event.key==='End')next=buttons.length-1;else if(event.key==='Escape'){commit(-1);event.preventDefault();return;}else return;event.preventDefault();buttons[next].focus();});
  on(filter,'change',()=>{desired.minimum=Number(filter.value);commit();});
  on($('.clear'),'click',()=>commit(-1));on($('.retry'),'click',start);
  function dispose(){if(life===Life.disposed)return;cancel();clearInterval(timer);timer=0;channel.dispose();listeners.abort();model.off('change:initial',update);setLife(Life.disposed,'Output disposed. Saved plot and table remain available.');}
  on($('.dispose'),'click',dispose);
  function update(){if(life===Life.disposed)return;cancel();channel.stop();frame=model.get('initial');draw(frame);resetDesired();start();}
  model.on('change:initial',update);
  // Read-only diagnostics support real integration checks; no alternate renderer.
  el.linked={channel,metrics,get frame(){return frame;},get life(){return life;},get active(){return active;},get timer(){return timer;},identity};
  draw(frame);resetDesired();start();return dispose;
}};
