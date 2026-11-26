const assert = require('node:assert/strict');
const temperature = require('./model.js');
const model = require('./sensor.js');
const {training, calibration, heldOut, evaluation, coefficient} = model;
const sessions = [...training, ...calibration, ...heldOut];
assert.equal(new Set(sessions.map(s => s.id)).size, 8);
assert.throws(() => model.fit(heldOut), /training sessions only/);
assert.throws(() => model.fit([...training, ...calibration]), /training sessions only/);
assert.equal(coefficient, model.fit(training));
assert.ok(Number.isFinite(coefficient));
assert.ok(coefficient > 0);
for (const s of sessions) {
  assert.equal(s.samples.length, 25);
  assert.ok(s.samples.every(p => Number.isFinite(p.proxy) && p.proxy > 300 && p.proxy < 1000));
}
for (const s of evaluation) {
  assert.equal(s.rows.length, 21);
  for (const row of s.rows) {
    assert.equal(row.without, temperature.forecast(row.previous, row.origin).prediction);
    assert.equal(row.withProxy, row.without + coefficient * model.feature(row.origin));
    assert.equal(row.target.time - row.origin.time, 30);
    // Destroy all future samples: predictions at this origin stay identical.
    const poisoned = s.samples.map(p => p.time > row.origin.time ? {...p, temperature: -999, proxy: 99999} : p);
    const other = model.align(poisoned, coefficient).find(r => r.origin.time === row.origin.time);
    assert.equal(other.withProxy, row.withProxy);
    assert.equal(other.without, row.without);
  }
  // A missing target drops the origin rather than shifting its horizon.
  assert.ok(!model.align(s.samples.filter(p => p.time !== 50), coefficient).some(r => r.origin.time === 20));
}
const calibrationRows = calibration.flatMap(s => model.align(s.samples, coefficient));
for (const key of ['without', 'withProxy']) {
  const errors = calibrationRows.map(r => Math.abs(r.target.temperature - r[key])).sort((a, b) => a - b);
  assert.equal(model.radii[key], errors[37]);
}
const missing = heldOut[0].samples.map(p => p.time === 20 ? {...p, proxy: null} : p);
const missingRows = model.align(missing, coefficient);
assert.equal(missingRows.find(r => r.origin.time === 20).withProxy, null);
assert.equal(model.summarize(missingRows).unavailable, 1);
assert.equal(model.summarize(missingRows).count, 20);
const scores = evaluation.map(s => ({id: s.id, ...model.summarize(s.rows)}));
assert.ok(scores[0].delta < 0 && scores[1].delta < 0, 'coupled synthetic sessions benefit');
assert.ok(scores[2].delta > 0, 'reversed coupling must expose harm');
console.log(JSON.stringify({coefficient, radii: model.radii, scores,
  checks: '8 disjoint sessions; 63 held-out origins; paired ablation; future poisoning; missing inputs; calibration-only bands; shifted failure'}, null, 2));
