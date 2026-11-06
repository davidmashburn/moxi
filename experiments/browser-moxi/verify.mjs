import {instantiateMoxi, EventKind, AppField, NodeField, Control, Status, Limits, RuntimeState} from './runtime.mjs';
const assert = (value, message) => { if (!value) throw new Error(message); };
function throws(fn, pattern) { let error; try { fn(); } catch (e) { error = e; } assert(error && pattern.test(String(error)), `Expected ${pattern}; got ${error}`); }
const summarize = values => { const sorted = [...values].sort((a,b)=>a-b); return {samples: values.length, medianMs: sorted[Math.floor(sorted.length/2)], p95Ms: sorted[Math.min(sorted.length-1, Math.floor(sorted.length*.95))]}; };

export async function verify(bytes, fixture, nativeInitial, nativeFinal) {
  const runtime = await instantiateMoxi(bytes), app = runtime.create();
  let comparisons = 0, maxError = 0;
  function near(actual, expected, tolerance) {
    const error = Math.abs(actual - expected); maxError = Math.max(maxError, error); comparisons++;
    assert(Number.isFinite(actual) && error <= tolerance, `native parity: ${actual} != ${expected} (error ${error})`);
  }
  function svgParity(actual, expected) {
    // Compare both structure/text and every numeric token, with subpixel tolerance.
    const number = /-?\d+(?:\.\d+)?(?:e[+-]?\d+)?/gi;
    assert(actual.replace(number, '#') === expected.replace(number, '#'), 'native SVG structure/text differs');
    const a = actual.match(number), b = expected.match(number);
    assert(a.length === b.length, 'SVG numeric field count');
    a.forEach((n,i) => near(Number(n), Number(b[i]), 0.001));
  }
  svgParity(app.render().svg, nativeInitial);
  for (const line of fixture.trim().split('\n')) {
    const [type, ...parts] = line.trim().split(' '), numbers = parts.map(Number);
    if (type === 'APP') numbers.forEach((value, field) => near(app.inspect(-1, field), value, 0.001));
    else if (type === 'NODE') numbers.slice(1).forEach((value, field) => near(app.inspect(numbers[0], field), value, field >= NodeField.screenX ? 0.001 : 1e-8));
    else if (type === 'EVENT') app.event(numbers[0], {x: numbers[1], y: numbers[2], value: numbers[3], key: numbers[4]});
    else if (type === 'RESIZE') app.resize(...numbers);
    else if (type === 'TEXT') app.text(parts.join(' '));
    else throw new Error(`unrecognized native fixture: ${type}`);
  }
  const finalFrame = app.render(); svgParity(finalFrame.svg, nativeFinal);
  assert(app.inspect(-1, AppField.selected) === 12, 'text search selects node-12');
  assert(finalFrame.semantics.some(n => n.id === Control.search && n.value === 'node-12'), 'Moxi search semantics');
  // Malformed operations reject before any application mutation.
  const baseline = Array.from({length: 7}, (_, i) => app.inspect(0, i));
  for (const args of [[999,0,0,0,0,0], [EventKind.down,NaN,0,0,0,0], [EventKind.scroll,0,0,Infinity,0,0], [EventKind.down,0,0,0,0,99]]) {
    assert(runtime.invoke('moxi_event', app.handle, ...args) === Status.invalidInput, 'invalid event rejected');
  }
  for (const [w,h] of [[0,760],[1000,Infinity],[4097,760]]) assert(runtime.invoke('moxi_resize',app.handle,w,h) === Status.invalidInput, 'invalid size rejected');
  baseline.forEach((v,i)=>assert(app.inspect(0,i)===v,'invalid operation mutated graph'));
  for (const handle of [0n, -1n, 9223372036854775807n, ...Array.from({length:128},(_,i)=>BigInt(10000+i*797))]) {
    assert(runtime.invoke('moxi_destroy',handle) === Status.invalidHandle, 'forged destroy');
    assert(runtime.invoke('moxi_event',handle,EventKind.frame,0,0,0,0,0) === Status.invalidHandle, 'forged event');
    assert(runtime.invoke('moxi_render',handle) === Status.invalidHandle, 'forged render');
  }
  throws(()=>app.text('x'.repeat(Limits.textBytes+1)), /rejected/);
  throws(()=>app.event(EventKind.action,{key:Control.export,value:1}), /rejected: -3/);
  const oldHandle = app.handle; assert(app.dispose() && !app.dispose(), 'idempotent owner disposal');
  throws(()=>app.render(), /disposed/);
  assert(runtime.stats().liveAllocations === 0, 'initial lifecycle leaked');
  const other = runtime.create(), first = runtime.create();
  const otherX = other.inspect(0, NodeField.x);
  first.event(EventKind.frame);
  assert(other.inspect(0, NodeField.x) === otherX, 'instance isolation');
  assert(runtime.invoke('moxi_destroy', oldHandle) === Status.invalidHandle, 'stale handle after address reuse');
  assert(runtime.invoke('moxi_event', oldHandle, EventKind.frame,0,0,0,0,0) === Status.invalidHandle, 'stale event after address reuse');
  other.dispose(); first.dispose();
  const owners = Array.from({length:Limits.instances},()=>runtime.create());
  throws(()=>runtime.create(), /capacity/); owners.forEach(o=>o.dispose());
  for (const graph of [{groups:Array(257).fill(0),links:[]},{groups:[0],links:Array(1025).fill([0,0,1])},{groups:[0],links:[[0,1,1]]},{groups:[0],links:[[0,0,NaN]]},{groups:[-1],links:[]},{groups:[0],links:[[0.5,0,1]]}]) throws(()=>runtime.create({graph}), /capacity|invalid/);
  // Array.map skips holes: explicitly reject sparse input before calling Wasm.
  throws(()=>runtime.create({graph:{groups:Array(1),links:[]}}), /invalid group/);
  throws(()=>runtime.create({graph:{groups:[0],links:Array(1)}}), /edge must be/);
  assert(runtime.stats().state===RuntimeState.ready,'invalid graph poisoned runtime');
  const empty = runtime.create({graph:{groups:[],links:[]}}); assert(empty.inspect(-1,AppField.nodes)===0,'empty graph'); empty.render(); empty.dispose();
  const max = runtime.create({graph:{groups:Array.from({length:256},(_,i)=>i%6), links:Array.from({length:1024},(_,i)=>[i%256,(i*13)%256,(i%7)/2])}});
  max.event(EventKind.frame); const maxFrame=max.render(); assert(max.inspect(-1,AppField.links)===1024,'capacity graph'); max.dispose();
  const sceneTimes=[], transferTimes=[], layoutTimes=[], renderSizes=[];
  for (let cycle=0; cycle<100; cycle++) {
    const current=runtime.create();
    const start=performance.now(); current.event(EventKind.frame); layoutTimes.push(performance.now()-start);
    const frame=current.render(); sceneTimes.push(frame.sceneMs); transferTimes.push(frame.transferMs); renderSizes.push(new TextEncoder().encode(frame.svg).length);
    current.dispose(); assert(runtime.stats().liveAllocations===0,`leak after cycle ${cycle}`);
  }
  const unicode = runtime.create();
  const search = unicode.render().semantics.find(n=>n.id===Control.search).bounds;
  unicode.event(EventKind.down,{x:search.x+5,y:search.y+5}); unicode.event(EventKind.up,{x:search.x+5,y:search.y+5});
  unicode.text('éλ🙂'.repeat(8));
  assert(unicode.render().semantics.find(n=>n.id===Control.search).value==='éλ🙂'.repeat(8),'UTF-8 validation and text transfer');
  unicode.dispose();
  const stats=runtime.stats(); runtime.dispose();
  let unsupported=false; try { await instantiateMoxi(bytes,{memory64:false}); } catch(e) { unsupported=/Unsupported runtime/.test(String(e)); } assert(unsupported,'feature gate');
  const limited=await instantiateMoxi(bytes,{heapLimit:131072});
  let trapped=false; try { const a=limited.create(); a.render(); } catch(e) { trapped=/capacity/.test(String(e)); }
  assert(trapped && limited.stats().state===RuntimeState.failed,'OOM must poison entire module');
  throws(()=>limited.create(), /runtime failed/); limited.dispose();
  return {comparisons,maxAbsoluteError:maxError,capacitySvgBytes:new TextEncoder().encode(maxFrame.svg).length,layoutAndDispatch:summarize(layoutTimes),sceneAndSerialization:summarize(sceneTimes),transfer:summarize(transferTimes),frameBytes:renderSizes[0],...stats};
}
