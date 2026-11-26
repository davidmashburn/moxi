// Browser presentation/playback only. All plot geometry comes from Moxi's build.
const ReplaySession = Object.freeze({TEMPERATURE: 'temperature'});
const get = id => document.getElementById(id);
const cursor = get('cursor');
const fmt = value => value.toFixed(2);
const precise = value => value.toFixed(3);
const frames = typeof MoxiFrames === 'undefined' ? null : MoxiFrames;
let selected = ReplaySession.TEMPERATURE;
let timer;
function current() {
  return selected === ReplaySession.TEMPERATURE ? {samples: TemperatureReplay.heldOut, rows: TemperatureReplay.rows} :
    SensorForecast.evaluation.find(s => s.id === selected);
}
function pause() {
  clearInterval(timer);
  timer = undefined;
  get('play').textContent = 'Play';
}
function draw() {
  const session = current();
  const row = session.rows.find(r => r.origin.time === Number(cursor.value));
  const {previous, origin, target} = row;
  const legacy = selected === ReplaySession.TEMPERATURE;
  const frame = frames?.frames[selected]?.[origin.time];
  get('plot-error').hidden = Boolean(frame);
  get('plot-error').textContent = frame ? '' : 'Moxi frame unavailable. Rebuild with node examples/temperature-replay/build.cjs.';
  get('plot').innerHTML = frame?.svg ?? '';
  get('plot').dataset.frame = selected + ':' + origin.time;
  get('plot').setAttribute('aria-label', `Moxi retrospective synthetic traces, session ${selected}, origin ${origin.time} seconds, outcome ${target.time} seconds`);
  get('route').textContent = `Selected ${origin.time}–${target.time} s · Route ${origin.position}–${target.position} m · Origin ${fmt(origin.temperature)} °C`;
  if (legacy) {
    const {prediction, baseline} = row;
    const radius = TemperatureReplay.radius;
    get('details').textContent = `Trend from ${previous.time}–${origin.time} s predicts ${fmt(prediction)} °C (band ${fmt(prediction-radius)}–${fmt(prediction+radius)} °C). Persistence predicts ${fmt(baseline)} °C.`;
    get('verdict').textContent = `Synthetic outcome at ${target.time} s: ${fmt(target.temperature)} °C · ${Math.abs(target.temperature-prediction) <= radius ? 'Inside' : 'Outside'} the band`;
    const score = TemperatureReplay.summarize(session.rows);
    get('scores').textContent = `Mean absolute error over ${session.rows.length} origins: trend ${fmt(score.model)} °C · persistence ${fmt(score.baseline)} °C. Band contains ${score.covered}/${session.rows.length} outcomes.`;
  } else {
    const {radii} = SensorForecast;
    get('details').textContent = `Without proxy: ${precise(row.without)} °C ± ${precise(radii.without)}. With proxy: ${precise(row.withProxy)} °C ± ${precise(radii.withProxy)}. Persistence: ${precise(row.baseline)} °C. Input at origin: ${fmt(origin.proxy)} arbitrary units.`;
    const hit = key => Math.abs(target.temperature - row[key]) <= radii[key] ? 'inside' : 'outside';
    get('verdict').textContent = `Synthetic outcome at ${target.time} s: ${precise(target.temperature)} °C · Without proxy: ${hit('without')} band · With proxy: ${hit('withProxy')} band`;
    const score = SensorForecast.summarize(session.rows);
    get('scores').textContent = `Held-out ${selected}: without proxy MAE ${precise(score.without)} °C · with proxy MAE ${precise(score.withProxy)} °C · Δ ${precise(score.delta)} °C (${score.delta < 0 ? 'lower' : 'higher'} error with proxy). Persistence MAE ${precise(score.persistence)} °C.`;
  }
}
function select(time) { pause(); cursor.value = time; draw(); }
cursor.oninput = () => select(cursor.value);
get('reset').onclick = () => select(cursor.min);
get('inspect').onclick = () => select(TemperatureReplay.driftTime);
get('scenario').onchange = event => {
  selected = event.target.value;
  const legacy = selected === ReplaySession.TEMPERATURE;
  get('scenario-title').textContent = legacy ? 'Original temperature replay' : `Held-out proxy session ${selected}`;
  get('inspect').textContent = legacy ? 'Inspect reversal' : 'Inspect 120 s';
  get('context').textContent = legacy ? 'Original held-out session B and calibration session A are unchanged. Full trace is shown retrospectively.' :
    `Artificial indoor CO2 proxy · ${current().regime} construction. Forecasts use previous/current temperature and proxy at origin only. Full future traces are visible for retrospective inspection.`;
  select(cursor.min);
};
get('play').onclick = () => {
  if (timer) return pause();
  if (cursor.value === cursor.max) select(cursor.min);
  get('play').textContent = 'Pause';
  timer = setInterval(() => {
    cursor.value = Number(cursor.value) + TemperatureReplay.cadence;
    draw();
    if (cursor.value === cursor.max) pause();
  }, 700);
};
get('training').textContent = `Fit: T1–T3 (63 origins). Band calibration: A1–A2 (42 origins). Test: B–D (63 origins). Fixed residual coefficient ${SensorForecast.coefficient.toFixed(6)}; no tuning on test sessions.`;
const resultRows = SensorForecast.evaluation.map(s => ({id: s.id + ' · ' + s.regime, ...SensorForecast.summarize(s.rows)}));
resultRows.push({id: 'All test sessions', ...SensorForecast.summarize(SensorForecast.evaluation.flatMap(s => s.rows))});
for (const score of resultRows) {
  const tr = document.createElement('tr');
  for (const value of [score.id, precise(score.without), precise(score.withProxy), precise(score.delta),
    `${score.coveredWithout}/${score.count} / ${score.coveredWith}/${score.count}`]) {
    const td = document.createElement('td'); td.textContent = value; tr.append(td);
  }
  get('results').append(tr);
}
get('provenance').textContent = frames ? `${frames.manifest.consumer}. ${frames.manifest.frameCount} offline frames; browser controls replay these exported scenes. Source ${frames.manifest.revision.slice(0, 7)}; ${frames.manifest.compiler}.` : 'Moxi build unavailable.';
get('scenario').onchange({target: get('scenario')});
