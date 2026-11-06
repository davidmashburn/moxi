import {State,WorkerMessage as Message} from './adapter.mjs';
export class LocalTransport {
  static async create(meta,signal){
    const self=new LocalTransport();self.worker=new Worker(new URL('./local-worker.mjs',import.meta.url),{type:'module'});
    self.pending=null;self.state=State.pending;self.bytes=0;self.requestBytes=0;self.samples=[];
    let readyResolve,readyReject;
    const ready=new Promise((resolve,reject)=>{readyResolve=resolve;readyReject=reject;});
    const abort=()=>{self.worker.terminate();readyReject(new Error('worker initialization cancelled'));};
    signal?.addEventListener('abort',abort,{once:true});
    ready.catch(()=>{}); // failure can arrive before the source fetch finishes
    self.worker.onmessage=({data})=>{
      if(data.type===Message.ready){self.sourceBytes=data.sourceBytes;self.state=State.ready;readyResolve();return;}
      if(data.type===Message.error){readyReject(new Error(data.error));self.pending?.reject(new Error(data.error));self.pending=null;return;}
      if(data.type===Message.result && self.pending){const p=self.pending;self.pending=null;p.resolve(data.result);}
    };
    self.worker.onerror=e=>{readyReject(new Error(e.message));self.pending?.reject(new Error(e.message));self.pending=null;};
    try{
      const start=performance.now(),response=await fetch('/api/source',{signal:signal?AbortSignal.any([signal,AbortSignal.timeout(15000)]):AbortSignal.timeout(15000)});
      if(!response.ok)throw new Error(`source HTTP ${response.status}`);
      const buffer=await response.arrayBuffer();self.bytes=buffer.byteLength;self.sourceLoadMs=performance.now()-start;
      self.worker.postMessage({type:Message.init,buffer,count:meta.count,revision:meta.revision},[buffer]);await ready;return self;
    }catch(e){self.worker.terminate();throw e;}finally{signal?.removeEventListener('abort',abort);}
  }
  async query(request){
    if(this.state===State.disposed)throw new Error('worker disposed');
    if(this.pending)throw new Error('one worker query only');
    const start=performance.now();
    const result=await new Promise((resolve,reject)=>{this.pending={resolve,reject};this.worker.postMessage({type:Message.query,request});});
    this.samples.push({query:request.query,kind:request.kind,delay:0,totalMs:performance.now()-start,reducerMs:result.reducer_ms??null,cancelled:!!result.cancelled});if(this.samples.length>120)this.samples.shift();return result;
  }
  cancel(request){this.worker.postMessage({type:Message.cancel,query:request.query});}
  dispose(){this.state=State.disposed;this.worker.terminate();this.pending?.reject(new Error('worker disposed'));this.pending=null;}
}
