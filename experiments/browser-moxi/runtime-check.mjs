import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {instantiateMoxi,RuntimeState} from './runtime.mjs';
const bytes=await readFile(new URL('./dist/runtime-test.wasm',import.meta.url));
const runtime=await instantiateMoxi(bytes);
for(let lane=0;lane<16;lane++)for(let index=0;index<256;index++)assert.equal(runtime.invoke('moxi_table',index,lane),index<16?index+11:0);
assert.equal(runtime.invoke('moxi_float32'),Math.fround(Math.fround(.56)+Math.fround(.56)));
const limbs=[0n,1n,-1n,0x8000000000000000n,0x0123456789abcdefn];
let products=0;
for(const al of limbs)for(const ah of limbs)for(const bl of limbs)for(const bh of limbs){
 const a=(BigInt.asUintN(64,ah)<<64n)|BigInt.asUintN(64,al),b=(BigInt.asUintN(64,bh)<<64n)|BigInt.asUintN(64,bl), product=BigInt.asUintN(128,a*b);
 assert.equal(BigInt.asUintN(64,runtime.invoke('moxi_multiply',al,ah,bl,bh,0)),BigInt.asUintN(64,product));
 assert.equal(BigInt.asUintN(64,runtime.invoke('moxi_multiply',al,ah,bl,bh,1)),product>>64n);products++;
}
assert.throws(()=>runtime.invoke('moxi_fail'),/Unsupported Mojo diagnostic path/);
assert.equal(runtime.stats().state,RuntimeState.failed);
assert.throws(()=>runtime.invoke('moxi_table',0,0),/runtime failed/);
runtime.dispose();assert.equal(runtime.stats().state,RuntimeState.disposed);
const unknown=Buffer.from(bytes),before=Buffer.from('KGEN_CompilerRT_GetStackTrace'),after=Buffer.from('x'.repeat(before.length));
for(let offset=unknown.indexOf(before);offset>=0;offset=unknown.indexOf(before,offset+after.length))after.copy(unknown,offset);
await assert.rejects(instantiateMoxi(unknown),/Unapproved runtime import/);
console.log(JSON.stringify({tableLookups:4096,products,float32:true,diagnosticPoisoning:true,unknownImportRejection:true}));
