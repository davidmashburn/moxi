import {instantiateMoxi,EventKind} from '../browser-moxi/runtime.mjs';
import {MoxiWebHost} from '../../native/hosts/moxi_web_host.mjs';
import {Adapter,HttpTransport,Kind,State,Route,GRID} from './adapter.mjs';
import {LocalTransport} from './local.mjs';
const Status=Object.freeze({ready:0,pending:1,error:2});
const $=id=>document.getElementById(id),panes=new Map(),mounts=new Map(),epochs=new Map();
let runtime,meta, failure=null;
const delay=()=>Number($('delay').value);
const rect=(owner,index)=>Array.from({length:4},(_,field)=>owner.inspect(index,field));
const viewport=(owner,index=0)=>{const[x,y,w,h]=rect(owner,index);return[x,y,x+w,y+h];};
function fail(e){failure=String(e);$('failure').textContent=failure;}
function invoke(p,name,...args){const status=runtime.invoke(name,p.owner.handle,...args);if(status!==0)throw new Error(`${name}: ${status}`);}
function draw(p){if(p.disposed)return;const frame=p.owner.render();p.host.presentSVG(frame.svg);p.host.updateAccessibility(frame.semantics);p.frame=frame;}
function notify(p){
  if(p.disposed)return;
  const status=p.adapter.state===State.pending?Status.pending:p.adapter.state===State.error?Status.error:Status.ready;
  if(status!==p.drawnStatus || p.needsDraw){invoke(p,'moxi_status',status);draw(p);p.drawnStatus=status;p.needsDraw=false;}
  const gesture=p.gestureStart;
  if(gesture && p.adapter.displayed?.query===gesture.query && gesture.sample.freshDomMs===null){
    gesture.sample.freshDomMs=performance.now()-gesture.start;
    requestAnimationFrame(()=>{gesture.sample.freshNextAnimationFrameMs=performance.now()-gesture.start;});
  }
  const a=p.adapter,t=p.transport;
  $(`status-${p.id}`).textContent=`${a.state} · generation ${a.generation} · queue ${a.active?1:0}+${a.pending?1:0} · received ${t.bytes.toLocaleString()} B${a.error?' · '+a.error:''}`;
  $(`status-${p.id}`).classList.toggle('error',a.state===State.error);
}
function apply(p,result){
  p.needsDraw=true;
  if(result.kind===Kind.grid){
    const[x,y,xmax,ymax]=result.viewport;invoke(p,'moxi_grid',x,y,xmax-x,ymax-y);
    for(const count of result.counts)invoke(p,'moxi_count',count);
    p.lastFresh={query:result.query,at:performance.now(),viewport:result.viewport};
  }else{
    invoke(p,'moxi_exact',0);for(const record of result.records)invoke(p,'moxi_exact',record.id);
    $(`records-${p.id}`).textContent=`Exact source records: ${result.records.length} of ${result.total}${result.truncated?' (capped; not the full aggregate)':''}\n`+result.records.map(r=>`ID ${r.id}  x=${r.x.toFixed(6)}  y=${r.y.toFixed(6)}`).join('\n');
  }
}
async function mount(id){
  if(panes.has(id)||mounts.has(id))return;
  const controller=new AbortController();mounts.set(id,controller);
  let transport;
  try {
  const surface=$(id),bounds=surface.getBoundingClientRect(),route=id==='a'&&new URLSearchParams(location.search).get('route')===Route.full?Route.full:Route.reduced;
  transport=route===Route.full?await LocalTransport.create(meta,controller.signal):new HttpTransport();
  if(controller.signal.aborted || mounts.get(id)!==controller){transport.dispose?.();return;}
  const owner=runtime.create({width:bounds.width,height:bounds.height});
  const p={id,route,transport,owner,host:null,disposed:false,feedback:[],freshSamples:[]};
  p.adapter=new Adapter({transport,revision:meta.revision,apply:result=>apply(p,result),notify:()=>notify(p)});
  const query=()=>p.adapter.request(Kind.grid,viewport(owner),route===Route.full?0:delay());
  function input(kind,options){
    if(p.disposed)return;
    try{
      const start=performance.now(),before=owner.inspect(0,4),selection=owner.inspect(0,8);
      owner.event(kind,options);
      // Synchronous Moxi render/DOM submission precedes asynchronous transport work.
      draw(p);const domMs=performance.now()-start;
      if(before!==owner.inspect(0,4)){
        const q=query();const sample={query:q.query,domMs,nextAnimationFrameMs:null,freshMs:null,freshDomMs:null,freshNextAnimationFrameMs:null};p.feedback.push(sample);if(p.feedback.length>120)p.feedback.shift();
        requestAnimationFrame(()=>{sample.nextAnimationFrameMs=performance.now()-start;});
        p.gestureStart={query:q.query,start,sample};
      }
      if(selection!==owner.inspect(0,8)){
        // A new aggregate supersedes an outstanding exact request as well.
        const cell=owner.inspect(0,9),r=Math.floor(cell/GRID),c=cell%GRID,grid=p.adapter.displayed;
        p.selectionBounds=[grid.x_edges[c],grid.y_edges[r],grid.x_edges[c+1],grid.y_edges[r+1]];
        p.adapter.invalidateDetails();$(`records-${id}`).textContent='New aggregate; exact records not requested.';
        if(p.adapter.last?.kind===Kind.details)query();
      }
    }catch(e){fail(e);}
  }
  const originalApply=p.adapter.apply;p.adapter.apply=result=>{originalApply(result);if(p.gestureStart?.query===result.query){p.gestureStart.sample.freshMs=performance.now()-p.gestureStart.start;p.freshSamples.push(p.gestureStart.sample);if(p.freshSamples.length>120)p.freshSamples.shift();}};
  p.host=new MoxiWebHost(surface,{
    event:(kind,pointer,x,y,buttons,modifiers)=>input(kind,{x,y,modifiers}),
    scroll:(dx,dy,x,y,modifiers)=>input(EventKind.scroll,{x,y,value:Math.max(-16,Math.min(16,-dy/40)),modifiers}),
    resize:(width,height)=>{if(p.disposed)return;try{owner.resize(Math.max(320,width),Math.max(320,height));draw(p);}catch(e){fail(e);}},
    frame:()=>{},key:()=>{},accessibilityAction:()=>{},
  },{svgTarget:surface.querySelector('.svg'),accessibilityTarget:surface});
  panes.set(id,p);p.host.start();draw(p);query();
  if(id==='a')$('route-a').textContent=route===Route.full?'Local full data / identical Moxi view':'Server reduction';
  } catch(error) {transport?.dispose?.();if(!controller.signal.aborted)throw error;}
  finally {if(mounts.get(id)===controller)mounts.delete(id);}
}
function dispose(id){epochs.set(id,(epochs.get(id)??0)+1);mounts.get(id)?.abort();mounts.delete(id);const p=panes.get(id);if(!p)return;p.disposed=true;p.adapter.dispose();p.host.stop();p.owner.dispose();panes.delete(id);$(id).querySelector('.svg').textContent='Disposed — no live Moxi owner. Restart creates a new session.';$(`status-${id}`).textContent='disposed';$(`records-${id}`).textContent='Selection cleared.';}
async function restart(id){dispose(id);const epoch=epochs.get(id);const response=await fetch('/api/meta');if(!response.ok)throw new Error(`metadata HTTP ${response.status}`);const current=await response.json();if(epochs.get(id)!==epoch)return;meta=current;await mount(id);}
function details(id){const p=panes.get(id);if(!p)return;if(p.owner.inspect(0,5)<0){$(`records-${id}`).textContent='Click an aggregate cell first.';return;}p.adapter.request(Kind.details,p.selectionBounds,p.route===Route.full?0:delay());}
for(const id of ['a','b']){
  $(`details-${id}`).onclick=()=>details(id);
  $(`retry-${id}`).onclick=()=>{const p=panes.get(id);if(p){p.transport.online=true;p.adapter.retry();}};
  $(`dispose-${id}`).onclick=()=>dispose(id);
  $(`restart-${id}`).onclick=()=>restart(id).catch(fail);
}
$('disconnect-a').onclick=()=>{const p=panes.get('a');if(p&&p.route===Route.reduced){p.transport.online=false;p.adapter.request(Kind.grid,viewport(p.owner),delay());}};
try{
  const response=await fetch('/api/meta');if(!response.ok)throw new Error(`metadata HTTP ${response.status}`);meta=await response.json();
  const wasmResponse=await fetch('./dist/density.wasm');if(!wasmResponse.ok)throw new Error(`Wasm HTTP ${wasmResponse.status}; run build.sh`);
  runtime=await instantiateMoxi(await wasmResponse.arrayBuffer());
  $('meta').textContent=`${meta.count.toLocaleString()} points · ${meta.source_bytes.toLocaleString()} source bytes · revision SHA-256 ${meta.revision}`;
  await mount('a');await mount('b');
}catch(e){fail(e);}
window.densityDemo={panes,viewport,rect,runtime,meta,dispose,restart,details,Kind,State,get failure(){return failure;}};
window.addEventListener('pagehide',()=>{for(const id of [...panes.keys()])dispose(id);runtime?.dispose();},{once:true});
