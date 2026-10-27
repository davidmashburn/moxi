import fs from "node:fs";
import path from "node:path";
import {createRequire} from "node:module";
import {fileURLToPath} from "node:url";
const dir=path.dirname(fileURLToPath(import.meta.url));
const require=createRequire(import.meta.url);
const {runProbe}=require("./runtime.js");
const bytes=fs.readFileSync(path.join(dir,"dist/fdg.wasm"));
const result=await runProbe(bytes);
const native=fs.readFileSync(path.join(dir,"dist/native.txt"),"utf8").trim().split(/\s+/).map(Number);
if(native.length!==3)throw Error("Expected three native checksums");
for(let i=0;i<3;i++)if(Math.abs(native[i]-result.results[i].value)>1e-8)throw Error("Fresh native parity failed");
fs.writeFileSync(path.join(dir,"dist/node-result.json"),JSON.stringify(result,null,2));
const runtime=fs.readFileSync(path.join(dir,"runtime.js"),"utf8");
const html=`<!doctype html><meta charset="utf-8"><title>Mojo browser execution probe</title>
<pre id="result">Running the FDG solver in this browser…</pre><script>
${runtime}
(async()=>{try {
const bytes=Uint8Array.from(atob('${bytes.toString("base64")}'),c=>c.charCodeAt(0));
const result=await runProbe(bytes);
window.probeResult={...result,userAgent:navigator.userAgent};
document.getElementById('result').textContent=JSON.stringify(window.probeResult,null,2);
} catch(error) {document.getElementById('result').textContent=String(error);throw error;}})();
</script>`;
fs.writeFileSync(path.join(dir,"dist/probe.html"),html);
console.log(JSON.stringify(result,null,2));
