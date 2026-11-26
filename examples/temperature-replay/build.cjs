// Build the example against this checkout; no installed Moxi package or service.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const {execFileSync} = require('node:child_process');
const {createHash} = require('node:crypto');
const temperature = require('./model.js');
const sensor = require('./sensor.js');
const root = path.resolve(__dirname, '../..');
const output = path.join(root, 'dist/temperature-replay');
const hash = file => createHash('sha256').update(fs.readFileSync(path.join(root, file))).digest('hex');
fs.mkdirSync(output, {recursive: true});
execFileSync('pixi', ['run', 'mojo', 'build', '-I', 'src',
  'examples/temperature-replay/replay_app.mojo', '-o', path.join(output, 'moxi-replay')], {cwd: root, stdio: 'inherit'});

const RenderMode = Object.freeze({TEMPERATURE: 0, PROXY: 1});
const scenarios = [{id: 'temperature', mode: RenderMode.TEMPERATURE, samples: temperature.heldOut,
  rows: temperature.rows.map(r => ({...r, without: r.prediction, withProxy: r.prediction})),
  radii: {without: temperature.radius, withProxy: temperature.radius}},
  ...sensor.evaluation.map(s => ({...s, mode: RenderMode.PROXY, radii: sensor.radii}))];
const frames = {};
for (const s of scenarios) {
  const values = [...s.samples.map(p => p.temperature), ...s.rows.flatMap(r =>
    [r.without - s.radii.without, r.without + s.radii.without,
      r.withProxy - s.radii.withProxy, r.withProxy + s.radii.withProxy])];
  const minimum = Math.floor((Math.min(...values) - 0.15) * 2) / 2;
  const maximum = Math.ceil((Math.max(...values) + 0.15) * 2) / 2;
  frames[s.id] = {};
  for (const row of s.rows) {
    const args = [s.mode, row.origin.time, row.without, row.withProxy,
      s.radii.without, s.radii.withProxy, minimum, maximum,
      ...s.samples.flatMap(p => [p.time, p.temperature, p.proxy ?? sensor.proxyCenter])].map(String);
    const frame = JSON.parse(execFileSync(path.join(output, 'moxi-replay'), args, {encoding: 'utf8', maxBuffer: 1024 * 1024}));
    assert.equal(frame.origin, row.origin.time);
    assert.equal(frame.sampleCount, 25);
    assert.equal(frame.canvases, s.mode + 1);
    assert.ok(frame.appPaintCommands >= frame.canvases);
    assert.ok(frame.sceneCommands > 50);
    assert.ok(Math.abs(frame.without - row.without) < 0.0001);
    assert.ok(Math.abs(frame.withProxy - row.withProxy) < 0.0001);
    assert.match(frame.svg, /<svg xmlns=/);
    assert.match(frame.svg, /Temperature/);
    if (s.mode === RenderMode.PROXY) assert.match(frame.svg, /Artificial CO2 proxy/);
    frames[s.id][row.origin.time] = frame;
  }
}
const sourceFiles = ['model.js', 'sensor.js', 'replay_app.mojo', 'build.cjs', 'consumer.html', 'consumer.js']
  .map(name => 'examples/temperature-replay/' + name);
const coreFiles = execFileSync('git', ['ls-files', 'src/moxi', 'src/moxi_plot'], {cwd: root, encoding: 'utf8'}).trim().split('\n');
const coreHash = createHash('sha256');
for (const file of coreFiles) coreHash.update(file + '\0' + hash(file) + '\n');
const manifest = {format: 1, revision: execFileSync('git', ['rev-parse', 'HEAD'], {cwd: root, encoding: 'utf8'}).trim(),
  sourceHashes: Object.fromEntries(sourceFiles.map(file => [file, hash(file)])),
  moxiSourceHash: coreHash.digest('hex'),
  compiler: execFileSync('pixi', ['run', 'mojo', '--version'], {cwd: root, encoding: 'utf8'}).trim(),
  consumer: 'App[ReplayApp] -> reconciled Canvas bounds -> PlotSpec/Plot -> Scene -> SvgSceneRenderer',
  frameCount: Object.values(frames).reduce((n, f) => n + Object.keys(f).length, 0)};
const report = {coefficient: sensor.coefficient, radii: sensor.radii,
  splits: Object.fromEntries(['training', 'calibration', 'heldOut'].map(key => [key, sensor[key].map(s => s.id)])),
  sessions: sensor.evaluation.map(s => ({id: s.id, regime: s.regime, ...sensor.summarize(s.rows)})),
  aggregate: sensor.summarize(sensor.evaluation.flatMap(s => s.rows))};
fs.writeFileSync(path.join(output, 'moxi-frames.js'), 'const MoxiFrames = ' + JSON.stringify({manifest, frames}) + ';\n');
fs.writeFileSync(path.join(output, 'build-manifest.json'), JSON.stringify(manifest, null, 2) + '\n');
fs.writeFileSync(path.join(output, 'evaluation.json'), JSON.stringify(report, null, 2) + '\n');
for (const file of ['model.js', 'sensor.js', 'consumer.js']) fs.copyFileSync(path.join(__dirname, file), path.join(output, file));
fs.copyFileSync(path.join(__dirname, 'consumer.html'), path.join(output, 'index.html'));
console.log('Built and checked ' + manifest.frameCount + ' actual Moxi App/Plot frames in dist/temperature-replay.');
console.log(JSON.stringify(report, null, 2));
