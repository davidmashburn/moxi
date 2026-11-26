import assert from 'node:assert/strict';
import {BASE, HEIGHT, WIDTH, SEASONS, Prediction, initial, response, run, outcome, step} from './world.mjs';

const seed = 2407, reference = run(seed, [0, BASE, 100]);
assert.equal(reference.length, SEASONS + 1);
assert.equal(reference[0].length, WIDTH * HEIGHT);
assert.notDeepEqual(initial(seed + 1), reference[0]);
for (let mid = 0; mid <= 100; mid += 10) {
  const knots = [0, mid, 100];
  assert.deepEqual([0, 0.5, 1].map(x => response(x, knots)), knots.map(y => y / 100));
  assert.equal(response(0.25, knots), mid / 200);
  const branch = run(seed, knots);
  assert.deepEqual(branch[0], reference[0]);
  assert.deepEqual(run(seed, knots), branch);
  const expected = mid === BASE ? Prediction.equal : mid > BASE ? Prediction.more : Prediction.fewer;
  assert.equal(outcome(reference.at(-1), branch.at(-1)), expected);
  for (const season of branch) {
    assert.ok(season.every(({kelp, grazers}) => kelp >= 0 && kelp <= 1 && grazers >= 0 && grazers <= 1));
  }
}
const bare = initial(seed).map(() => ({kelp: 0, grazers: 0}));
bare[0].grazers = 1;
const dispersed = step(bare, [0, BASE, 100]);
assert.ok(dispersed[WIDTH - 1].grazers > 0 && dispersed[(HEIGHT - 1) * WIDTH].grazers > 0);
assert.equal(dispersed[WIDTH + 1].grazers, 0);
assert.equal(bare[0].grazers, 1);
console.log('PASS: seeded trajectories, response knots, branch outcomes, density bounds and wrapped dispersal');
