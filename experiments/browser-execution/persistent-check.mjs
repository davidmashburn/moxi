import fs from 'node:fs';
import path from 'node:path';
import {createRequire} from 'node:module';
import {fileURLToPath} from 'node:url';
const dir=path.dirname(fileURLToPath(import.meta.url)),require=createRequire(import.meta.url);
const {instantiateProbe}=require('./runtime.js'),{runPersistentProbe}=require('./persistent-runtime.js');
const bytes=fs.readFileSync(path.join(dir,'dist/persistent.wasm'));
const native=fs.readFileSync(path.join(dir,'dist/persistent-native.txt'),'utf8').trim().split(/\s+/).map(Number);
if(native.length!==720||!native.every(Number.isFinite))throw Error('Invalid native fixture');
const fixtures=Array.from({length:4},(_,i)=>native.slice(i*180,(i+1)*180));
const result=await runPersistentProbe(bytes,fixtures,instantiateProbe);
fs.writeFileSync(path.join(dir,'dist/persistent-node-result.json'),JSON.stringify(result,null,2));
const runtime=fs.readFileSync(path.join(dir,'runtime.js'),'utf8')+'\n'+fs.readFileSync(path.join(dir,'persistent-runtime.js'),'utf8');
const html=`<!doctype html><meta charset="utf-8"><title>Persistent Mojo browser execution probe</title>
<pre id="result">Running persistent FDG checks…</pre><script>
${runtime}
(async()=>{try{
const bytes=Uint8Array.from(atob('${bytes.toString('base64')}'),c=>c.charCodeAt(0));
const result=await runPersistentProbe(bytes,${JSON.stringify(fixtures)},instantiateProbe);
window.probeResult={...result,userAgent:navigator.userAgent};
document.getElementById('result').textContent=JSON.stringify(window.probeResult,null,2);
}catch(error){window.probeError=String(error);document.getElementById('result').textContent=String(error);}})();
</script>`;
fs.writeFileSync(path.join(dir,'dist/persistent-probe.html'),html);
console.log(JSON.stringify(result,null,2));
