// Deterministic fixtures. All timestamps are elapsed seconds in one session.
const TemperatureReplay = (() => {
  const cadence = 10;
  const horizon = 30;
  const driftTime = 120;

  function session(start, phase, reversal) {
    return Array.from({length: 25}, (_, i) => {
      const time = i * cadence;
      const trend = 0.012 * time;
      const drift = reversal ? -0.032 * Math.max(0, time - driftTime) : 0;
      return {time, temperature: start + trend + drift + 0.08 * Math.sin(i + phase),
              position: i * 2};
    });
  }

  // Use only observations available at the origin.
  function forecast(previous, current) {
    const slope = (current.temperature - previous.temperature) / (current.time - previous.time);
    return {baseline: current.temperature, prediction: current.temperature + horizon * slope};
  }

  function align(samples) {
    const byTime = new Map(samples.map(sample => [sample.time, sample]));
    return samples.flatMap((origin) => {
      const previous = byTime.get(origin.time - cadence);
      const target = byTime.get(origin.time + horizon);
      if (!previous || !target) return [];
      return [{previous, origin, target, ...forecast(previous, origin)}];
    });
  }

  const calibration = session(19, 0, false);
  const residual = row => Math.abs(row.target.temperature - row.prediction);
  const errors = align(calibration).map(residual).sort((a, b) => a - b);
  const radius = errors[Math.ceil(0.9 * errors.length) - 1];
  const heldOut = session(21, 1.3, true);
  const rows = align(heldOut);

  function summarize(rows) {
    const mean = fn => rows.reduce((sum, row) => sum + fn(row), 0) / rows.length;
    return {model: mean(residual), baseline: mean(row => Math.abs(row.target.temperature - row.baseline)),
            covered: rows.filter(row => residual(row) <= radius).length};
  }

  return {cadence, horizon, driftTime, calibration, heldOut, rows, forecast, align, radius, summarize};
})();
if (typeof module !== 'undefined') module.exports = TemperatureReplay;
