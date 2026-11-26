const assert = require('node:assert/strict');
const model = require('./model.js');
const {rows, heldOut, align} = model;
assert.equal(rows.length, 21);
for (const row of rows) {
  assert.equal(row.target.time - row.origin.time, 30);
  assert.equal(row.origin.time - row.previous.time, 10);
  assert.equal(row.baseline, row.origin.temperature);
  assert.equal(row.prediction, row.baseline + 3 * (row.baseline - row.previous.temperature));
  assert.equal(row.target.position - row.origin.position, 6);
}
// A missing target must drop its origin, not slide the join forward.
assert.ok(!align(heldOut.filter(s => s.time !== 50)).some(r => r.origin.time === 20));
const calibrationErrors = align(model.calibration).map(r => Math.abs(r.prediction - r.target.temperature));
assert.equal(model.radius, calibrationErrors.sort((a,b) => a-b)[18]);
const drift = rows.find(r => r.origin.time === model.driftTime);
assert.ok(drift.target.temperature < drift.origin.temperature);
assert.ok(drift.prediction - drift.target.temperature > model.radius);
const scores = model.summarize(rows);
assert.equal(scores.covered, 17);
assert.equal(scores.model.toFixed(3), '0.278');
assert.equal(scores.baseline.toFixed(3), '0.473');
console.log('21 timestamp joins, calibration band, held-out errors and drift miss verified.');
