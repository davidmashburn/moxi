// instantiateProbe is supplied by runtime.js in the browser and injected in Node.
async function runPersistentProbe(bytes, fixtures, instantiate) {
  const {instance,stats}=await instantiate(bytes), api=instance.exports;
  function assert(condition,message){if(!condition)throw Error(message);}
  function createGraph() {
    let address=api.fdg_create();
    if(address===0n)throw Error('graph creation failed');
    const valid=()=>{if(address===null)throw Error('disposed graph');return address;};
    const integer=v=>{if(!Number.isInteger(v)||v<-(2**31)||v>=2**31)throw Error('invalid integer');return v;};
    const status=n=>{if(n!==0)throw Error('invalid graph operation');};
    return {
      step:n=>status(api.fdg_step(valid(),integer(n))),
      pin:(i,x,y)=>status(api.fdg_pin(valid(),integer(i),x,y)),
      release:i=>status(api.fdg_release(valid(),integer(i))),
      snapshot:()=>Array.from({length:36},(_,i)=>Array.from({length:5},(_,f)=>api.fdg_coordinate(valid(),i,f))).flat(),
      destroy:()=>{const ptr=valid();address=null;api.fdg_destroy(ptr);}
    };
  }
  let maxAbsoluteError=0, comparisons=0, rejected=0;
  const throws=fn=>{let caught=false;try{fn();}catch{caught=true;}assert(caught,'expected rejection');rejected++;};
  const compare=(actual,expected)=>{
    assert(actual.length===expected.length,'fixture dimensions');
    for(let i=0;i<actual.length;i++){
      const error=Math.abs(actual[i]-expected[i]);
      assert(Number.isFinite(actual[i])&&error<=1e-8,'per-node native mismatch at '+i+': '+error);
      maxAbsoluteError=Math.max(maxAbsoluteError,error);comparisons++;
    }
  };
  assert(fixtures.length===4&&fixtures.every(x=>x.length===180),'four 36-node native fixtures required');
  const graph=createGraph(), independent=createGraph();
  try {
    compare(graph.snapshot(),fixtures[0]);
    graph.step(10);compare(graph.snapshot(),fixtures[1]);
    graph.pin(3,120,-80);graph.step(5);compare(graph.snapshot(),fixtures[2]);
    const pinned=graph.snapshot();assert(pinned[15]===120&&pinned[16]===-80&&pinned[19]===1,'pin persistence');
    graph.release(3);graph.step(20);compare(graph.snapshot(),fixtures[3]);
    compare(independent.snapshot(),fixtures[0]);
    const before=graph.snapshot();
    for(const action of [()=>graph.step(-1),()=>graph.step(1001),()=>graph.step(0.5),
      ()=>graph.step(2**32),()=>graph.pin(-1,0,0),()=>graph.release(36),
      ()=>graph.pin(3,NaN,0),()=>graph.pin(3,0,Infinity),()=>graph.pin(3,1e7,0)])throws(action);
    assert(JSON.stringify(graph.snapshot())===JSON.stringify(before),'invalid operation mutated graph');
  } finally {graph.destroy();independent.destroy();}
  throws(()=>graph.step(1));throws(()=>graph.destroy());
  // A newly allocated graph may reuse the old address; the old owner stays dead.
  for(let i=0;i<100;i++){
    const current=createGraph();
    try {current.step(10);current.pin(3,120,-80);current.step(5);current.release(3);current.step(20);
      compare(current.snapshot(),fixtures[3]);throws(()=>graph.pin(0,0,0));
    } finally {current.destroy();}
    assert(stats().liveAllocations===0,'live allocations after disposal');
  }
  return {passed:true,sessionsCreated:102,comparisons,maxAbsoluteError,rejectedOperations:rejected,...stats()};
}
if(typeof module!=='undefined')module.exports={runPersistentProbe};
