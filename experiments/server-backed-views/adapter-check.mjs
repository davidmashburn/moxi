import assert from 'node:assert/strict';
import {Adapter,Kind,State,GRID,validResult} from './adapter.mjs';
function result(q,n=1){const[x,y,xx,yy]=q.viewport;return {...q,total:n,reducer_ms:1,counts:[n,...Array(GRID*GRID-1).fill(0)],x_edges:Array.from({length:GRID+1},(_,i)=>x+(xx-x)*i/GRID),y_edges:Array.from({length:GRID+1},(_,i)=>y+(yy-y)*i/GRID)};}
function fixture(){const callbacks=[],cancellations=[];let applied=0;const transport={query:q=>new Promise((resolve,reject)=>callbacks.push({q,resolve,reject})),cancel:q=>cancellations.push(q)};const a=new Adapter({transport,revision:'r1',apply:()=>applied++});return {a,callbacks,cancellations,get applied(){return applied;}};}
const flush=()=>new Promise(r=>setImmediate(r));
const f=fixture(),a=f.a;
let q=a.request(Kind.grid,[0,0,1,1]);f.callbacks[0].resolve(result(q));await flush();assert.equal(f.applied,1);
const retained=a.displayed;
a.request(Kind.grid,[.1,0,1.1,1]);
for(let i=0;i<40;i++)a.request(Kind.grid,[i/100,0,1+i/100,1]);
assert.equal(f.callbacks.length,2);assert.equal(f.cancellations.length,1);assert.equal(a.displayed,retained);assert.equal(a.metrics.maxPending,1);
f.callbacks[1].resolve(result(f.callbacks[1].q,9));await flush();assert.equal(a.displayed,retained);assert.equal(f.callbacks.length,3);
f.callbacks[2].resolve(result(f.callbacks[2].q,4));await flush();assert.equal(a.displayed.total,4);assert.equal(a.state,State.ready);
for(const change of [{session:'wrong'},{revision:'old'},{generation:0},{query:'duplicate'},{counts:[]},{total:999}]){
 q=a.request(Kind.grid,[0,0,1,1]);f.callbacks.at(-1).resolve({...result(q),...change});await flush();assert.equal(a.state,State.error);assert.equal(a.displayed.total,4);
 a.retry();f.callbacks.at(-1).resolve(result(a.last,4));await flush();assert.equal(a.state,State.ready);
}
q=a.request(Kind.details,[0,0,1,1]);const details={...q,total:1,records:[{id:7,x:.2,y:.3}],truncated:false,reducer_ms:1};assert.ok(validResult(details,q));assert.ok(!validResult({...details,records:[{id:0,x:.2,y:.3}]},q));f.callbacks.at(-1).resolve(details);await flush();assert.equal(a.details.records[0].id,7);assert.equal(a.displayed.total,4);
a.request(Kind.grid,[0,0,1,1]);f.callbacks.at(-1).reject(new Error('network down'));await flush();assert.equal(a.state,State.error);assert.equal(a.details.records[0].id,7);
a.retry();const late=f.callbacks.at(-1);a.request(Kind.grid,[.1,0,1,1]);a.dispose();late.resolve(result(late.q));await flush();assert.equal(a.state,State.disposed);assert.equal(a.pending,null);assert.equal(a.active,null);assert.equal(a.displayed,null);assert.equal(a.retry(),undefined);
const other=fixture();other.a.request(Kind.grid,[0,0,1,1]);assert.notEqual(other.a.session,a.session);assert.equal(other.a.generation,1);
console.log('PASS queue/coalescing, identity and malformed payload rejection, retained data, details, retry, disposal, independent sessions');
