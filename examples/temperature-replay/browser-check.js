// Run checkMoxiReplay() in the built consumer's page (e.g. browser DevTools).
// Deliberately separate from product scripts; no services or device access.
async function checkMoxiReplay() {
  const checks = [];
  const get = id => document.getElementById(id);
  const expect = (condition, message) => { if (!condition) throw new Error(message); };
  const wait = ms => new Promise(resolve => setTimeout(resolve, ms));
  const choose = id => { get('scenario').value = id; get('scenario').dispatchEvent(new Event('change')); };
  const origin = time => { get('cursor').value = time; get('cursor').dispatchEvent(new Event('input')); };
  const record = (scenario, steps, expected, observed) => checks.push({scenario, steps, expected, observed, outcome: 'pass'});
  choose('temperature');
  expect(get('plot').querySelector('svg'), 'Moxi SVG absent');
  expect(get('plot').dataset.frame === 'temperature:10', 'wrong initial frame');
  expect(get('route').textContent.includes('Origin 21.18 °C'), 'original fixture changed');
  expect(get('scores').textContent.includes('trend 0.28 °C'), 'original scores changed');
  record('original initial', 'Select original temperature B', 'Moxi frame at 10 s and original metrics', get('scores').textContent);
  get('inspect').click();
  expect(get('plot').dataset.frame === 'temperature:120', 'reversal plot not updated');
  expect(get('verdict').textContent.includes('Outside the band'), 'original drift miss absent');
  record('original reversal', 'Inspect reversal', 'Outcome 150 s outside calibration band', get('verdict').textContent);
  get('reset').click();
  get('play').click();
  await wait(1000);
  get('play').click();
  const paused = get('cursor').value;
  expect(Number(paused) > 10, 'playback did not advance');
  await wait(850);
  expect(get('cursor').value === paused, 'pause did not stop playback');
  expect(get('plot').dataset.frame === 'temperature:' + paused, 'plot did not follow playback');
  origin(200); get('play').click(); await wait(1000);
  expect(get('cursor').value === '210' && get('play').textContent === 'Play', 'playback failed to stop at end');
  get('play').click(); await wait(1000); get('play').click();
  expect(Number(get('cursor').value) < 210, 'play from end did not restart');
  record('playback lifecycle', 'Play, Pause, wait; play from 200 s, then from end', 'Pause stable; automatic stop at 210 s; restart from end', 'All playback states observed');
  for (const session of SensorForecast.evaluation) {
    choose(session.id); origin(120);
    const score = SensorForecast.summarize(session.rows);
    expect(get('plot').dataset.frame === session.id + ':120', 'session frame mismatch');
    expect(get('plot').querySelector('svg').textContent.includes('Artificial CO2 proxy'), 'actual Moxi proxy plot missing');
    expect(get('details').textContent.includes('Input at origin:'), 'sensor input not displayed');
    expect(get('scores').textContent.includes(score.withProxy.toFixed(3)), 'score differs from evaluated model');
    expect(get('scores').textContent.includes(score.delta < 0 ? 'lower error' : 'higher error'), 'benefit/harm mislabeled');
    record('held-out ' + session.id, 'Select session and inspect 120 s', 'Matching Moxi frame and both ablation scores; D shows harm', get('scores').textContent);
  }
  expect(get('results').rows.length === 4, 'per-session/aggregate results missing');
  const aggregate = SensorForecast.summarize(SensorForecast.evaluation.flatMap(s => s.rows));
  expect(get('results').rows[3].cells[2].textContent === aggregate.withProxy.toFixed(3), 'aggregate wrong');
  choose('B'); origin(120);
  const saved = MoxiFrames.frames.B[120];
  try {
    delete MoxiFrames.frames.B[120]; origin(120);
    expect(!get('plot-error').hidden, 'missing frame silently accepted');
    expect(!get('plot').querySelector('svg'), 'stale plot remains after missing frame');
  } finally { MoxiFrames.frames.B[120] = saved; }
  origin(120);
  expect(get('plot-error').hidden && get('plot').querySelector('svg'), 'frame recovery failed');
  record('missing-frame recovery', 'Remove one in-memory export, redraw, restore, redraw', 'Explicit error, stale plot removed, original frame restored', 'Error and recovery observed');
  choose('temperature');
  expect(document.body.textContent.includes('instrument calibration'), 'open gates missing');
  return {capturedAt: new Date().toISOString(), url: location.protocol === 'file:' ? 'file://…/dist/temperature-replay/index.html' : location.pathname, userAgent: navigator.userAgent,
    viewport: [innerWidth, innerHeight], build: MoxiFrames.manifest, checks,
    skipped: ['VoiceOver and screen readers', 'native-window interaction', 'real instruments and field/device/robot trials']};
}
