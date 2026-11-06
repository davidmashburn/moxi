// Static fallback from the identical real Wasm solver, state, and renderer.
import {readFileSync} from 'node:fs';
import {instantiateMoxi, EventKind, Control} from '../dist/interactive/runtime.mjs';
const graph = JSON.parse(readFileSync(0, 'utf8'));
const runtime = await instantiateMoxi(readFileSync(new URL('../dist/interactive/browser.wasm', import.meta.url)));
try {
  const owner = runtime.create({width:1000,height:620,graph});
  for (let i=0;i<100;i++) owner.event(EventKind.frame);
  owner.event(EventKind.action,{key:Control.fit,value:1});
  owner.event(EventKind.action,{key:Control.pause,value:1});
  process.stdout.write(owner.render().svg);
} finally { runtime.dispose(); }
