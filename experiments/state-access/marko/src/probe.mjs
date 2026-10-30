import { keys } from './domain.mjs';
export const evaluations = Object.fromEntries(keys.map(key => [key, 0]));
export function probe(key, value) { evaluations[key]++; return value; }
export function reset() { for (const key of keys) evaluations[key] = 0; }
export const editors = new Map();
export let live = 0;
export function register(id, actions, signal) {
  live++;
  editors.set(id, actions);
  signal.onabort = () => { live--; if (editors.get(id) === actions) editors.delete(id); };
}
