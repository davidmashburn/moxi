async function instantiateProbe(bytes) {
  let instance, top, peak=0, allocations=0;
  const live=new Map(), available=[];
  function alloc(alignment, size) {
    const a=Number(alignment), n=Math.max(1,Number(size));
    if (!Number.isSafeInteger(n)||!Number.isSafeInteger(a)||a<1||(a&(a-1))) throw Error('invalid allocation');
    let index=available.findIndex(b=>b.size>=n&&b.ptr%a===0),ptr;
    if(index>=0){const b=available.splice(index,1)[0];ptr=b.ptr;live.set(ptr,b.size);}
    else {
      ptr=Math.ceil(top/a)*a; top=ptr+n;
      if(top>64*1024*1024) throw Error('probe heap limit');
      const memory=instance.exports.memory;
      if(top>memory.buffer.byteLength) memory.grow(BigInt(Math.ceil((top-memory.buffer.byteLength)/65536)));
      live.set(ptr,n); peak=Math.max(peak,top);
    }
    allocations++; return BigInt(ptr);
  }
  function free(pointer) {
    const ptr=Number(pointer);if(!ptr)return;
    if(!live.has(ptr))throw Error('invalid/double free '+ptr);
    available.push({ptr,size:live.get(ptr)});live.delete(ptr);
  }
  const env={KGEN_CompilerRT_AlignedAlloc:alloc,KGEN_CompilerRT_AlignedFree:free,
    sin:Math.sin,cos:Math.cos,
    fmax:(a,b)=>Number.isNaN(a)?b:Number.isNaN(b)?a:Math.max(a,b),
    fmin:(a,b)=>Number.isNaN(a)?b:Number.isNaN(b)?a:Math.min(a,b)};
  const errorImports=['KGEN_CompilerRT_GetStackTrace','write','dup','fdopen','fflush','fclose','KGEN_CompilerRT_fprintf'];
  for(const name of errorImports)env[name]=()=>{throw Error('unimplemented error-path import: '+name)};
  const result=await WebAssembly.instantiate(bytes,{env}); instance=result.instance;
  top=Number(instance.exports.__heap_base.value);
  return {instance, stats:()=>({allocations,liveAllocations:live.size,heapHighWater:peak,
    bytes:bytes.length,imports:WebAssembly.Module.imports(result.module).map(x=>x.name)})};
}
async function runProbe(bytes) {
  const {instance,stats}=await instantiateProbe(bytes);
  const expected=[-490.73085389089306,-579.0101732943626,-25242.94863141275];
  const results=[0,1,100].map((steps,i)=>{
    const value=instance.exports.fdg_probe(steps),error=Math.abs(value-expected[i]);
    if(error>1e-8||!Number.isFinite(value))throw Error('native parity failed: '+steps+' '+value);
    if(stats().liveAllocations)throw Error('live allocations after probe');
    return {steps,value,absoluteError:error};
  });
  for(let i=0;i<20;i++){instance.exports.fdg_probe(100);if(stats().liveAllocations)throw Error('leak');}
  return {results,...stats()};
}
if(typeof module!=='undefined')module.exports={runProbe,instantiateProbe};
