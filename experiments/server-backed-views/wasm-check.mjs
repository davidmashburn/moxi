import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {instantiateMoxi,EventKind} from '../browser-moxi/runtime.mjs';
const runtime=await instantiateMoxi(await readFile(new URL('./dist/density.wasm',import.meta.url)));
const a=runtime.create({width:640,height:480}),b=runtime.create({width:640,height:480});
assert.equal(runtime.invoke('moxi_grid',a.handle,0,0,1,1),0);
for(let i=0;i<1024;i++)assert.equal(runtime.invoke('moxi_count',a.handle,i%100),0);
assert.equal(runtime.invoke('moxi_count',a.handle,10),-2);
assert.equal(runtime.invoke('moxi_grid',a.handle,NaN,0,1,1),-2);
assert.equal(runtime.invoke('moxi_status',a.handle,0),0);
a.event(EventKind.down,{x:200,y:200});a.event(EventKind.move,{x:270,y:230});a.event(EventKind.up,{x:270,y:230});a.event(EventKind.scroll,{x:270,y:230,value:4});
const wasm=a.render().svg,native=(await readFile(new URL('./dist/native.svg',import.meta.url),'utf8')).trim();
const number=/-?\d+(?:\.\d+)?/g,colors=/rgba\([^)]*\)/g;
assert.equal(wasm.replace(number,'N'),native.replace(number,'N'),'SVG structure and text');
function closeNumbers(left,right,tolerance){const aa=left.match(number).map(Number),bb=right.match(number).map(Number);assert.equal(aa.length,bb.length);for(let i=0;i<aa.length;i++)assert.ok(Math.abs(aa[i]-bb[i])<=tolerance,`scalar ${i}: ${aa[i]} vs ${bb[i]}`);}
closeNumbers(wasm.match(colors).join(' '),native.match(colors).join(' '),1); // native FMA vs Wasm can cross an 8-bit color rounding boundary
closeNumbers(wasm.replace(colors,''),native.replace(colors,''),0.0002);

assert.notEqual(a.inspect(0,0),0);assert.equal(b.inspect(0,0),0);assert.equal(a.inspect(0,6),1024);
const before=runtime.stats().liveBytes;
for(let i=0;i<20;i++)a.render();assert.equal(runtime.stats().liveBytes,before);
a.event(EventKind.down,{x:300,y:200});a.event(EventKind.up,{x:300,y:200});assert.ok(a.inspect(0,5)>=0);
for(let i=1;i<=32;i++)assert.equal(runtime.invoke('moxi_exact',a.handle,i),0);
assert.equal(runtime.invoke('moxi_exact',a.handle,33),-2);
a.dispose();assert.equal(runtime.invoke('moxi_destroy',a.handle),-1);assert.equal(b.inspect(0,0),0);b.dispose();
assert.equal(runtime.stats().liveBytes,0);
for(let i=0;i<20;i++){const c=runtime.create({width:640,height:480});c.render();c.dispose();assert.equal(runtime.stats().liveBytes,0);}
console.log(JSON.stringify({passed:['native/Wasm SVG structure and numeric parity: geometry 0.0002px, 8-bit color 1','independent views','grid/exact caps','nonfinite rejection','stable live allocations after renders','20 dispose/recreate cycles'],stats:runtime.stats()},null,2));
