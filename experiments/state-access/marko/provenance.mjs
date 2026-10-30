import {createHash} from 'node:crypto';
import {readFile, readdir} from 'node:fs/promises';
export const sha = data => createHash('sha256').update(data).digest('hex');
export async function sources(directory = '.', prefix = '') {
  const hashes = {};
  for (const entry of await readdir(directory, {withFileTypes: true})) {
    if (['node_modules', 'dist', 'results.json', 'comparison.json'].includes(entry.name) || entry.name.startsWith('browser-')) continue;
    const name = prefix + entry.name;
    const path = `${directory}/${entry.name}`;
    if (entry.isDirectory()) Object.assign(hashes, await sources(path, name + '/'));
    else hashes[name] = sha(await readFile(path));
  }
  return hashes;
}
