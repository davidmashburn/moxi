import {MoxiWebHost, MOXI_MOD_COMMAND} from '../../native/hosts/moxi_web_host.mjs';
import {instantiateMoxi, EventKind, Control, AppField, NodeField, RuntimeState} from './runtime.mjs';
import {verify} from './verify.mjs';
const $ = id => document.getElementById(id);
const keyMap = new Map([[37,1000],[39,1001],[38,1002],[40,1003],[36,1004],[35,1005],[46,127],[65,97]]);
const frames = [], inputSamples = [];
let runtime, bytes, animate = true, failure = null;
const panes = new Map();
function fail(error) {
  failure = String(error); $('failure').textContent = failure; $('status').textContent = 'Runtime unavailable';
  for (const pane of panes.values()) pane.host.stop();
}
function draw(pane) {
  const frame = pane.owner.render(), start = performance.now();
  pane.host.presentSVG(frame.svg); pane.host.updateAccessibility(frame.semantics);
  pane.lastFrame = frame;
  frames.push({sceneMs:frame.sceneMs,transferMs:frame.transferMs,domSubmitMs:performance.now()-start});
  if (frames.length>240) frames.shift();
}
function guarded(fn) { return (...args) => { try { return fn(...args); } catch (e) { fail(e); } }; }
function mount(id) {
  if (panes.has(id)) return;
  const surface=$(id), rect=surface.getBoundingClientRect();
  const owner=runtime.create({width:Math.max(320,rect.width),height:Math.max(320,rect.height)});
  // Settle the real solver and fit once for a useful initial view. Start paused
  // so the first frame remains inspectable; Resume/Reheat are Moxi actions.
  for(let i=0;i<100;i++)owner.event(EventKind.frame);
  owner.event(EventKind.action,{key:Control.fit,value:1});
  owner.event(EventKind.action,{key:Control.pause,value:1});
  const pane={owner,host:null,lastFrame:null};
  function input(fn) {
    const start=performance.now();fn();draw(pane);
    const submit=performance.now()-start;
    requestAnimationFrame(()=>{
      inputSamples.push({inputToDomMs:submit,inputToNextAnimationFrameMs:performance.now()-start});
      if(inputSamples.length>240)inputSamples.shift();
    });
  }
  pane.host=new MoxiWebHost(surface,{
    event:guarded((kind,pointer,x,y,buttons,modifiers)=>input(()=>owner.event(kind,{x,y,modifiers}))),
    key:guarded((key,modifiers)=>input(()=>owner.event(EventKind.key,{key:keyMap.get(key)??key,modifiers}))),
    scroll:guarded((dx,dy,x,y,modifiers)=>input(()=>owner.event(EventKind.scroll,{x,y,value:Math.max(-16,Math.min(16,-dy/40)),modifiers}))),
    resize:guarded((width,height)=>{owner.resize(Math.max(320,width),Math.max(320,height));draw(pane);}),
    frame:guarded(()=>{
      if(!animate || owner.inspect(-1,AppField.paused) || owner.inspect(-1,AppField.alpha)<.001)return;
      owner.event(EventKind.frame);draw(pane);
    }),
    accessibilityAction:guarded((key,value)=>input(()=>owner.event(EventKind.action,{key,value}))),
  },{svgTarget:surface.querySelector('.svg'),accessibilityTarget:surface});
  const typed=guarded(event=>{
    if(event.isComposing || event.ctrlKey || event.metaKey || event.altKey || event.key.length!==1)return;
    event.preventDefault();input(()=>owner.text(event.key));
  });
  surface.addEventListener('keydown',typed);
  pane.cleanup=()=>surface.removeEventListener('keydown',typed);
  panes.set(id,pane);pane.host.start();draw(pane);
}
function dispose(id) {
  const pane=panes.get(id);if(!pane)return;
  pane.host.stop();pane.cleanup();
  if(runtime.stats().state===RuntimeState.ready)pane.owner.dispose();
  panes.delete(id);$(id).querySelector('.svg').textContent='Disposed — recreate to start a new Moxi instance.';
}
function search(id,text) {
  const pane=panes.get(id), bounds=pane.lastFrame.semantics.find(n=>n.id===Control.search).bounds;
  pane.owner.event(EventKind.down,{x:bounds.x+5,y:bounds.y+5});
  pane.owner.event(EventKind.up,{x:bounds.x+5,y:bounds.y+5});
  pane.owner.event(EventKind.key,{key:97,modifiers:MOXI_MOD_COMMAND});
  pane.owner.text(text);pane.owner.event(EventKind.action,{key:Control.find,value:1});draw(pane);
}
async function runVerification() {
  $('status').textContent='Comparing actual Wasm app with native fixtures…';
  const [fixture,initial,final]=await Promise.all(['native.txt','native-initial.svg','native-final.svg'].map(name=>fetch(`./dist/${name}`).then(r=>{if(!r.ok)throw Error(`Missing ${name}`);return r.text();})));
  const result=await verify(bytes,fixture,initial,final);
  const evidence={userAgent:navigator.userAgent,verification:result,frames,inputSamples,runtime:runtime.stats()};
  $('evidence').textContent=JSON.stringify(evidence,null,2);$('status').textContent=`Passed: ${result.comparisons} native comparisons; 100 disposal cycles`;
  window.moxiDemo.verification=evidence;return evidence;
}
try {
  if(new URLSearchParams(location.search).has('unsupported'))throw Error('Unsupported runtime: WebAssembly memory64 is required; no JavaScript graph fallback (forced feature-gate scenario)');
  const response=await fetch('./dist/browser.wasm');if(!response.ok)throw Error('Build browser.wasm before opening this demo');bytes=new Uint8Array(await response.arrayBuffer());
  runtime=await instantiateMoxi(bytes);mount('a');mount('b');$('status').textContent='Two live Mojo/Moxi instances';
  $('dispose-a').onclick=guarded(()=>dispose('a'));
  $('recreate-a').onclick=guarded(()=>mount('a'));
  $('resize-a').onclick=guarded(()=>{ $('a').style.height=$('a').style.height==='720px'?'640px':'720px'; });
  $('find-a').onclick=guarded(()=>search('a',$('search-a').value));
  $('animate').onclick=()=>{animate=!animate;$('animate').textContent=animate?'Stop animation':'Start animation';};
  $('verify').onclick=()=>runVerification().catch(fail);
  window.moxiDemo={panes,runtime,frames,inputSamples,runVerification,search,dispose,mount,draw,EventKind,Control,AppField,NodeField,setAnimate:value=>{animate=value;},get failure(){return failure;}};
  addEventListener('pagehide',()=>{for(const id of [...panes.keys()])dispose(id);runtime.dispose();},{once:true});
} catch(error) { fail(error); }
