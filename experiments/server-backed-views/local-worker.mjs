import {GRID,Kind,WorkerMessage as Message} from './adapter.mjs';
let x,y,ids,sourceBytes=0,revision;
let active=null, cancelled=false;
self.onmessage=async({data})=>{
  try {
    if(data.type===Message.init){
      const n=data.count,buffer=data.buffer;sourceBytes=buffer.byteLength;
      if(sourceBytes!==n*20)throw new Error('source layout mismatch');
      revision=Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',buffer)),x=>x.toString(16).padStart(2,'0')).join('');
      if(revision!==data.revision)throw new Error('source fingerprint mismatch');
      x=new Float64Array(buffer,0,n);y=new Float64Array(buffer,n*8,n);ids=new Uint32Array(buffer,n*16,n);
      self.postMessage({type:Message.ready,sourceBytes,revision});return;
    }
    if(data.type===Message.cancel){if(active===data.query)cancelled=true;return;}
    if(data.type!==Message.query)throw new Error('unknown worker operation');
    active=data.request.query;cancelled=false;
    const q=data.request,start=performance.now(),[xmin,ymin,xmax,ymax]=q.viewport,counts=Array(GRID*GRID).fill(0),records=[];
    if(!x||q.revision!==revision)throw new Error('worker source not ready');
    let total=0,computeMs=0;
    for(let begin=0;begin<x.length;begin+=16384){
      if(cancelled){active=null;self.postMessage({type:Message.result,result:{...q,cancelled:true}});return;}
      const chunkStart=performance.now();
      for(let i=begin;i<Math.min(x.length,begin+16384);i++)if(x[i]>=xmin&&x[i]<xmax&&y[i]>=ymin&&y[i]<ymax){
        total++;
        if(q.kind===Kind.grid){const c=Math.min(GRID-1,Math.floor((x[i]-xmin)/(xmax-xmin)*GRID)),r=Math.min(GRID-1,Math.floor((y[i]-ymin)/(ymax-ymin)*GRID));counts[r*GRID+c]++;}
        else if(records.length<q.cap)records.push({id:ids[i],x:x[i],y:y[i]});
      }
      computeMs+=performance.now()-chunkStart;
      // Yield to cancellation messages; yield wait is excluded from active-chunk reducer samples.
      await new Promise(resolve=>setTimeout(resolve,0));
    }
    const result={...q,total,reducer_ms:computeMs,worker_wall_ms:performance.now()-start};
    if(q.kind===Kind.grid)Object.assign(result,{counts,x_edges:Array.from({length:GRID+1},(_,i)=>xmin+(xmax-xmin)*i/GRID),y_edges:Array.from({length:GRID+1},(_,i)=>ymin+(ymax-ymin)*i/GRID)});
    else Object.assign(result,{records,truncated:total>records.length});
    active=null;self.postMessage({type:Message.result,result});
  }catch(error){self.postMessage({type:Message.error,error:String(error),query:data.request?.query});}
};
