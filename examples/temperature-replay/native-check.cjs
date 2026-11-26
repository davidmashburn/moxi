const assert = require('node:assert/strict');
const path = require('node:path');
const {spawnSync} = require('node:child_process');
const model = require('./sensor.js');
const session = model.evaluation[0];
const row = session.rows[0];
const binary = path.resolve(__dirname, '../../dist/temperature-replay/moxi-replay');
// Independent wire literals exercise compatibility with the Mojo mode boundary.
const args = [1, 10, row.without, row.withProxy, model.radii.without, model.radii.withProxy,
  18, 25, ...session.samples.flatMap(p => [p.time, p.temperature, p.proxy])].map(String);
const run = values => spawnSync(binary, values, {encoding: 'utf8'});
const result = run(args);
assert.equal(result.status, 0, result.stderr);
const frame = JSON.parse(result.stdout);
assert.equal(frame.canvases, 2);
assert.ok(frame.appPaintCommands >= 2);
assert.match(frame.svg, /Artificial CO2 proxy/);
assert.match(frame.svg, /Temperature/);
// Target intervals must use both bounds, rather than an area down to zero.
const intervals = svg => [...svg.matchAll(/<line\b[^>]+\/>/g)].map(([line]) =>
  Object.fromEntries([...line.matchAll(/([\w-]+)="([^"]*)"/g)].map(([, key, value]) => [key, value])))
  .filter(line => ['8.0', '4.0', '8', '4'].includes(line['stroke-width']));
const originalIntervals = intervals(frame.svg);
assert.equal(originalIntervals.length, 2);
for (const interval of originalIntervals) {
  assert.equal(interval.x1, interval.x2);
  assert.ok(Number(interval.y2) > Number(interval.y1));
}
const wider = [...args]; wider[4] = String(model.radii.without * 2);
const widerIntervals = intervals(JSON.parse(run(wider).stdout).svg);
const height = line => Number(line.y2) - Number(line.y1);
const midpoint = line => (Number(line.y2) + Number(line.y1)) / 2;
assert.ok(Math.abs(height(widerIntervals[0]) / height(originalIntervals[0]) - 2) < 0.002);
assert.ok(Math.abs(midpoint(widerIntervals[0]) - midpoint(originalIntervals[0])) < 0.001);
assert.deepEqual(widerIntervals[1], originalIntervals[1]);
const legacy = [...args]; legacy[0] = '0';
const legacyFrame = JSON.parse(run(legacy).stdout);
assert.equal(legacyFrame.canvases, 1);
assert.doesNotMatch(legacyFrame.svg, /Artificial CO2 proxy/);
const perturbed = [...args];
// Keep predictions fixed but change an observed proxy; real plotting must consume it.
perturbed[10] = String(session.samples[0].proxy + 20);
assert.notEqual(JSON.parse(run(perturbed).stdout).svg, frame.svg);
for (const [index, value, expected] of [[0, '2', /unsupported replay mode/], [1, '15', /eligible sample/],
  [2, 'NaN', /finite fixture/], [4, '-1', /calibration radii/], [6, '30', /y domain/],
  [8, '1', /fixed cadence/]]) {
  const invalid = [...args]; invalid[index] = value;
  const failed = run(invalid);
  assert.notEqual(failed.status, 0);
  assert.match(failed.stderr, expected);
}
assert.notEqual(run(args.slice(1)).status, 0);
console.log('Native Moxi App canvases, sensor geometry, two-bound residual intervals, mode compatibility and seven invalid-input boundaries verified.');
