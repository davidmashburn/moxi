/** Example-local, one active / one replaceable pending operation across both kinds. */
export const Kind = Object.freeze({grid:'grid', details:'details'});
export const State = Object.freeze({ready:'ready', pending:'pending', error:'error', disposed:'disposed'});
export const Route = Object.freeze({reduced:'reduced', full:'full'});
export const WorkerMessage = Object.freeze({init:'init',query:'query',cancel:'cancel',ready:'ready',result:'result',error:'error'});
export const GRID = 32, DETAILS_CAP = 32, RESPONSE_CAP = 65536;
const identity = ['session','revision','query','generation','kind'];
export function validResult(result, request) {
  if (!result || identity.some(k=>result[k] !== request[k])) return false;
  if (result.cancelled === true) return true;
  if (!Array.isArray(result.viewport) || result.viewport.some((x,i)=>x !== request.viewport[i]) || result.viewport.length!==4 || !Number.isInteger(result.total) || result.total<0 || result.total>1e6 || !Number.isFinite(result.reducer_ms) || result.reducer_ms<0) return false;
  if (request.kind===Kind.grid) {
    if(result.width!==GRID || result.height!==GRID || result.counts?.length!==GRID*GRID || !result.counts.every(x=>Number.isInteger(x)&&x>=0&&x<=1e6) || result.counts.reduce((a,b)=>a+b,0)!==result.total || 'records' in result) return false;
    return ['x_edges','y_edges'].every((key,axis)=>result[key]?.length===GRID+1 && result[key].every((x,i)=>Number.isFinite(x)&&Math.abs(x-(request.viewport[axis]+(request.viewport[axis+2]-request.viewport[axis])*i/GRID))<1e-12));
  }
  return Array.isArray(result.records) && result.records.length<=request.cap && result.records.length===Math.min(result.total,request.cap) && result.truncated===(result.total>result.records.length) && new Set(result.records.map(r=>r.id)).size===result.records.length && result.records.every(r=>Number.isInteger(r.id)&&r.id>=1&&r.id<=1e6&&Number.isFinite(r.x)&&Number.isFinite(r.y)&&r.x>=request.viewport[0]&&r.x<request.viewport[2]&&r.y>=request.viewport[1]&&r.y<request.viewport[3]);
}
export class Adapter {
  constructor({transport,revision,apply,notify=()=>{},session=crypto.randomUUID()}) {
    Object.assign(this,{transport,revision,apply,notify,session});
    this.generation=0; this.active=null; this.pending=null; this.displayed=null; this.details=null;
    this.state=State.ready; this.error=null; this.last=null;
    this.metrics={maxActive:0,maxPending:0,replaced:0,cancelled:0,rejected:0,accepted:0};
  }
  request(kind,viewport,delay=0) {
    if(this.state===State.disposed)return;
    if(!Object.values(Kind).includes(kind)||viewport.length!==4||!viewport.every(Number.isFinite)||viewport[0]>=viewport[2]||viewport[1]>=viewport[3]||!Number.isInteger(delay)||delay<0||delay>3000)throw new RangeError('invalid request');
    const request={session:this.session,revision:this.revision,query:crypto.randomUUID(),generation:++this.generation,kind,viewport:[...viewport],delay,width:GRID,height:GRID,cap:DETAILS_CAP};
    this.last=request; this.error=null; this.state=State.pending;
    if(this.active) {
      if(this.pending)this.metrics.replaced++;
      this.pending=request; this.metrics.maxPending=1; this.cancelActive();
    } else this.start(request);
    this.notify(); return request;
  }
  cancelActive() {
    if(!this.active || this.active.cancelRequested)return;
    this.active.cancelRequested=true; this.metrics.cancelled++;
    // Keep the active slot until the real transport acknowledges completion.
    Promise.resolve(this.transport.cancel(this.active.request)).catch(e=>{if(this.state!==State.disposed){this.error=`Cancellation failed: ${e}`;this.notify();}});
  }
  async start(request) {
    const active={request,cancelRequested:false};this.active=active;this.metrics.maxActive=1;
    try {
      const result=await this.transport.query(request);
      if(this.state===State.disposed || this.active!==active || request.generation!==this.generation) {this.metrics.rejected++;return;}
      if(!validResult(result,request)) {this.metrics.rejected++;throw new Error('invalid or stale response identity/payload');}
      if(result.cancelled) {this.metrics.rejected++;throw new Error('query cancelled; retry');}
      if(request.kind===Kind.grid)this.displayed=result;else this.details=result;
      this.metrics.accepted++;this.state=State.ready;this.error=null;this.apply(result);
    } catch(error) {
      if(this.state!==State.disposed && request.generation===this.generation){this.state=State.error;this.error=String(error);}
    } finally {
      if(this.active===active)this.active=null;
      if(this.state!==State.disposed && this.pending){const next=this.pending;this.pending=null;this.start(next);}
      this.notify();
    }
  }
  retry(){if(this.state!==State.disposed&&this.last)return this.request(this.last.kind,this.last.viewport,this.last.delay);}
  invalidateDetails(){this.details=null;}
  dispose(){if(this.state===State.disposed)return;this.state=State.disposed;this.generation++;this.pending=null;this.cancelActive();this.transport.dispose?.();this.displayed=null;this.details=null;this.notify();}
}
export class HttpTransport {
  constructor(){this.bytes=0;this.requestBytes=0;this.samples=[];this.online=true;}
  async post(path,request){
    if(!this.online)throw new Error('Disconnected by local transport control');
    const body=JSON.stringify(request);this.requestBytes+=new TextEncoder().encode(body).length;
    const response=await fetch(path,{method:'POST',headers:{'Content-Type':'application/json'},body,signal:AbortSignal.timeout(15000)});
    const reader=response.body.getReader();let chunks=[],size=0;
    for(;;){const {done,value}=await reader.read();if(done)break;size+=value.length;if(size>RESPONSE_CAP){await reader.cancel();throw new Error('response exceeds 64KiB');}chunks.push(value);}
    this.bytes+=size;
    const joined=new Uint8Array(size);let at=0;for(const chunk of chunks){joined.set(chunk,at);at+=chunk.length;}
    const result=JSON.parse(new TextDecoder().decode(joined));
    if(!response.ok)throw new Error(result.error??`HTTP ${response.status}`);
    return result;
  }
  async query(request){const start=performance.now();const result=await this.post('/api/query',request);this.samples.push({query:request.query,kind:request.kind,delay:request.delay,totalMs:performance.now()-start,reducerMs:result.reducer_ms??null,cancelled:!!result.cancelled});if(this.samples.length>120)this.samples.shift();return result;}
  cancel(request){return this.post('/api/cancel',{session:request.session,query:request.query});}
}
