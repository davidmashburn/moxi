const {rows, heldOut, radius, driftTime, summarize, cadence} = TemperatureReplay;
const get = id => document.getElementById(id);
const cursor = get('cursor');
cursor.min = rows[0].origin.time;
cursor.max = rows.at(-1).origin.time;
cursor.value = cursor.min;
const x = time => 48 + 560 * time / 240;
const y = temperature => 124 - 36 * (temperature - 20);
const fmt = value => value.toFixed(2);
let timer;

function draw() {
  const row = rows.find(row => row.origin.time === Number(cursor.value));
  const {previous, origin, target, prediction, baseline} = row;
  const trace = heldOut.map(p => x(p.time) + ',' + y(p.temperature)).join(' ');
  get('plot').innerHTML = `
    <rect x="${x(origin.time)}" y="6" width="${x(target.time)-x(origin.time)}" height="120" fill="#d6ede9"/>
    ${[20,21,22,23].map(t => `<path d="M48 ${y(t)}h560" stroke="#ccd6cf"/><text x="4" y="${y(t)+4}">${t}°</text>`).join('')}
    <polyline points="${trace}" stroke="#175f63" fill="none" stroke-width="3"/>
    <circle cx="${x(origin.time)}" cy="${y(origin.temperature)}" r="5" fill="#175f63"/>
    <circle cx="${x(target.time)}" cy="${y(target.temperature)}" r="5" fill="#175f63"/>
    ${[0,60,120,180,240].map(t => `<text text-anchor="middle" x="${x(t)}" y="146">${t} s</text>`).join('')}`;
  get('route').textContent = `Selected ${origin.time}–${target.time} s · Route ${origin.position}–${target.position} m · Origin ${fmt(origin.temperature)} °C`;
  get('details').textContent = `Trend from ${previous.time}–${origin.time} s predicts ${fmt(prediction)} °C (band ${fmt(prediction-radius)}–${fmt(prediction+radius)} °C). Persistence predicts ${fmt(baseline)} °C.`;
  const inside = Math.abs(target.temperature-prediction) <= radius;
  get('verdict').textContent = `Synthetic outcome at ${target.time} s: ${fmt(target.temperature)} °C · ${inside ? 'Inside' : 'Outside'} the band`;
}
function pause() {
  clearInterval(timer);
  timer = undefined;
  get('play').textContent = 'Play';
}
function select(time) {
  pause();
  cursor.value = time;
  draw();
}
cursor.oninput = () => select(cursor.value);
get('reset').onclick = () => select(cursor.min);
get('drift').onclick = () => select(driftTime);
get('play').onclick = () => {
  if (timer) return pause();
  if (cursor.value === cursor.max) select(cursor.min);
  get('play').textContent = 'Pause';
  timer = setInterval(() => {
    cursor.value = Number(cursor.value) + cadence;
    draw();
    if (cursor.value === cursor.max) pause();
  }, 700);
};
const score = summarize(rows);
get('scores').textContent = `Mean absolute error over ${rows.length} origins: trend ${fmt(score.model)} °C · persistence ${fmt(score.baseline)} °C. Band contains ${score.covered}/${rows.length} outcomes.`;
draw();
