import assert from 'node:assert/strict';
import {readFile, writeFile} from 'node:fs/promises';
import {sources, sha} from './provenance.mjs';
const manifest = JSON.parse(await readFile('dist/manifest.json', 'utf8'));
assert.deepEqual(await sources(), manifest.sourceHashes, 'sources changed after build');
for (const [path, hash] of Object.entries(manifest.artifactHashes)) assert.equal(sha(await readFile(path)), hash, path);
const variants = {};
for (const variant of ['baseline', 'narrow', 'projected']) {
  const result = JSON.parse(await readFile(`browser-${variant}.json`, 'utf8'));
  assert.equal(result.ok, true); assert.equal(result.variant, variant);
  assert.equal(result.assertionCount, result.assertions.length);
  assert.deepEqual(result.manifest, manifest, `${variant} was tested against a different build`);
  delete result.manifest;
  variants[variant] = result;
}
const priorText = await readFile('../comparison.json');
const prior = JSON.parse(priorText);
for (const [path, hash] of Object.entries(prior.input_result_hashes)) assert.equal(sha(await readFile(`../${path}`)), hash, path);
const rows = prior.rows.map(row => {
  const next = {...row};
  for (const [variant, result] of Object.entries(variants)) {
    const measurement = result.scale[row.editors][row.operation];
    assert.equal(Object.values(measurement.changedValues).reduce((a,b)=>a+b,0), row.sink_writes, `${variant}/${row.editors}/${row.operation} changed-value parity`);
    next[`marko_${variant}_evaluations`] = Object.values(measurement.evaluations).reduce((a,b)=>a+b,0);
  }
  return next;
});
await writeFile('results.json', JSON.stringify({
  scope: 'Compiled Marko client runtime in Chromium. Five instrumented leaf evaluations and changed DOM values; not total CPU, DOM write count, allocation or latency. Input value changes may originate in native editing.',
  manifest, variants,
}, null, 2) + '\n');
await writeFile('comparison.json', JSON.stringify({priorComparisonHash: sha(priorText), markoResultsHash: sha(await readFile('results.json')), rows}, null, 2) + '\n');
console.log(JSON.stringify({ok:true, assertions:Object.values(variants).reduce((n,r)=>n+r.assertionCount,0), matchedCases:rows.length*3, variants:Object.keys(variants)}));
