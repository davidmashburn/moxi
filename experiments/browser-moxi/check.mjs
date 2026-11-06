import {readFile, writeFile} from 'node:fs/promises';
import {verify} from './verify.mjs';
const read = name => readFile(new URL(`./dist/${name}`, import.meta.url));
const [bytes, fixture, initial, final] = await Promise.all(['browser.wasm','native.txt','native-initial.svg','native-final.svg'].map(read));
const result = await verify(bytes,fixture.toString(),initial.toString(),final.toString());
await writeFile(new URL('./dist/node-evidence.json',import.meta.url),JSON.stringify({node:process.version,...result},null,2)+'\n');
console.log(JSON.stringify({node:process.version,...result},null,2));
