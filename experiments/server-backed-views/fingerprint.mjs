import {createHash} from 'node:crypto';
import {readFile,readdir} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import path from 'node:path';
export async function fingerprint(){
  const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
  const inputs=[];
  async function collect(dir){for(const e of (await readdir(path.join(root,dir),{withFileTypes:true})).sort((a,b)=>a.name.localeCompare(b.name))){const p=`${dir}/${e.name}`;if(e.isDirectory()){if(!['dist','__pycache__'].includes(e.name))await collect(p);}else if(/\.(mojo|mjs|py|sh|html)$/.test(e.name))inputs.push(p);}}
  await collect('experiments/server-backed-views');await collect('src/moxi');
  inputs.push('experiments/browser-moxi/runtime.mjs','experiments/browser-moxi/retarget.py','native/hosts/moxi_web_host.mjs','pixi.lock','pixi.toml');inputs.sort();
  const hash=createHash('sha256');for(const p of inputs)hash.update(p+'\0').update(await readFile(path.join(root,p)));
  return {sha256:hash.digest('hex'),inputs};
}
