// Artificial environmental fixtures only; no recordings, devices or controls.
const SensorForecast = (() => {
  const temperature = typeof module === 'undefined' ? TemperatureReplay : require('./model.js');
  const Split = Object.freeze({TRAIN: 'train', CALIBRATION: 'calibration', TEST: 'test'});
  const Regime = Object.freeze({COUPLED: 'coupled', REVERSED: 'reversed'});
  const proxyCenter = 650;
  const proxyScale = 180;

  function session(id, split, start, phase, regime = Regime.COUPLED) {
    let value = start;
    let increment = 0.04;
    const samples = Array.from({length: 25}, (_, i) => {
      const drive = Math.sin((i + phase) / 3.1) + 0.35 * Math.cos((i + phase) / 1.7);
      const sample = {time: i * temperature.cadence, position: i * 2,
        temperature: value, proxy: proxyCenter + proxyScale * drive};
      // Constructed coupling makes a level at the origin informative about
      // future curvature. Test D deliberately reverses that construction.
      increment += 0.012 * drive * (regime === Regime.REVERSED ? -1 : 1);
      value += increment + 0.004 * Math.sin(i * 1.9 + phase);
      return sample;
    });
    return {id, split, regime, samples};
  }

  const training = [session('T1', Split.TRAIN, 19, 0), session('T2', Split.TRAIN, 20, 4),
    session('T3', Split.TRAIN, 21, 8)];
  const calibration = [session('A1', Split.CALIBRATION, 19.5, 2),
    session('A2', Split.CALIBRATION, 20.5, 6)];
  const heldOut = [session('B', Split.TEST, 21, 1.3), session('C', Split.TEST, 18.8, 5.3),
    session('D', Split.TEST, 22, 9.3, Regime.REVERSED)];
  const feature = sample => (sample.proxy - proxyCenter) / proxyScale;

  function fit(sessions) {
    if (!sessions.length || sessions.some(s => s.split !== Split.TRAIN)) {
      throw new Error('Fit requires training sessions only');
    }
    let numerator = 0;
    let denominator = 0;
    for (const s of sessions) for (const row of temperature.align(s.samples)) {
      const x = feature(row.origin);
      numerator += x * (row.target.temperature - row.prediction);
      denominator += x * x;
    }
    if (!(denominator > 0)) throw new Error('Training proxy has no variation');
    return numerator / denominator;
  }

  // A one-feature residual correction to the exact same temperature trend.
  // These functions take previous/current observations, never the target.
  function forecast(previous, current, coefficient) {
    const without = temperature.forecast(previous, current).prediction;
    const withProxy = Number.isFinite(current.proxy) ? without + coefficient * feature(current) : null;
    return {without, withProxy};
  }
  function align(samples, coefficient) {
    return temperature.align(samples).map(row => ({...row, ...forecast(row.previous, row.origin, coefficient)}));
  }
  const coefficient = fit(training);
  const quantile = errors => [...errors].sort((a, b) => a - b)[Math.ceil(0.9 * errors.length) - 1];
  const calibrated = calibration.flatMap(s => align(s.samples, coefficient));
  const radii = Object.freeze({without: quantile(calibrated.map(r => Math.abs(r.target.temperature - r.without))),
    withProxy: quantile(calibrated.map(r => Math.abs(r.target.temperature - r.withProxy)))});

  function summarize(rows) {
    // Both arms use identical origins. Missing proxy forecasts are explicitly
    // unavailable and excluded from both arms of this paired comparison.
    const paired = rows.filter(r => r.withProxy !== null);
    if (!paired.length) return {count: 0, unavailable: rows.length};
    const mean = key => paired.reduce((n, r) => n + Math.abs(r.target.temperature - r[key]), 0) / paired.length;
    const coverage = key => paired.filter(r => Math.abs(r.target.temperature - r[key]) <= radii[key]).length;
    const without = mean('without');
    const withProxy = mean('withProxy');
    return {count: paired.length, unavailable: rows.length - paired.length, without, withProxy,
      persistence: mean('baseline'), delta: withProxy - without,
      coveredWithout: coverage('without'), coveredWith: coverage('withProxy')};
  }
  const evaluation = heldOut.map(s => ({...s, rows: align(s.samples, coefficient)}));
  return {Split, Regime, proxyCenter, proxyScale, training, calibration, heldOut, evaluation,
    feature, fit, forecast, align, coefficient, radii, summarize};
})();
if (typeof module !== 'undefined') module.exports = SensorForecast;
