
const el = id => document.getElementById(id);
const seed = 2407;
const baseline = run(seed, rules[BASE].values);
let branch = baseline;
const trials = [];
el('seed').textContent = seed;

function draw(id, world) {
  const canvas = el(id), size = 12;
  canvas.width = WIDTH * size;
  canvas.height = HEIGHT * size;
  const ctx = canvas.getContext('2d');
  world.forEach(({kelp, grazers}, i) => {
    const x = i % WIDTH * size, y = Math.floor(i / WIDTH) * size;
    ctx.fillStyle = `rgb(${15 + 65 * kelp},${46 + 125 * kelp},${51 + 55 * kelp})`;
    ctx.fillRect(x, y, size, size);
    if (grazers > 0) {
      ctx.fillStyle = '#ffbf66';
      ctx.beginPath();
      ctx.arc(x + size/2, y + size/2, 5 * Math.sqrt(grazers), 0, 2*Math.PI);
      ctx.fill();
    }
  });
}

function inspect() {
  const season = Number(el('season').value);
  el('seasonValue').textContent = season;
  for (const [id, stats, world] of [['reference', 'baseStats', baseline[season]],
                                     ['branch', 'branchStats', branch[season]]]) {
    draw(id, world);
    el(stats).textContent = ['kelp', 'grazers'].map(key =>
      `${cover(world, key).toFixed(2)}% ${key}`).join(' · ');
  }
}

function showRule() {
  const midpoint = el('rule').value;
  el('curve').innerHTML = rules[midpoint].svg;
  el('curve').setAttribute('aria-label', `Feeding strength at zero, half and full kelp cover: 0, ${midpoint} and 100 percent`);
  el('value').textContent = midpoint + '%';
}

function rewind(message) {
  branch = baseline;
  el('season').value = 0;
  el('season').disabled = true;
  el('status').textContent = message;
  showRule();
  inspect();
}

function compare(trial, replay) {
  el('rule').value = trial.midpoint;
  el('prediction').value = trial.prediction;
  branch = run(seed, rules[trial.midpoint].values);
  const observed = outcome(baseline[SEASONS], branch[SEASONS]);
  el('season').disabled = false;
  el('season').value = SEASONS;
  el('status').textContent = `Season 12 · Predicted ${trial.prediction}, observed ${observed}. Prediction ${observed === trial.prediction ? 'matched' : 'missed'}.`;
  showRule();
  inspect();
  if (replay) return;
  trials.push(trial);
  const row = document.createElement('li');
  row.append(`Midpoint ${trial.midpoint}% · Predicted ${trial.prediction} · Observed ${observed} `);
  const button = document.createElement('button');
  button.textContent = `Replay trial ${trials.length}`;
  button.onclick = () => compare(trial, true);
  row.append(button);
  el('history').append(row);
}

el('rule').oninput = el('prediction').onchange = () => rewind('Draft ready. Both beds are at season zero.');
el('season').oninput = inspect;
el('compare').onclick = () => compare({midpoint: Number(el('rule').value), prediction: el('prediction').value}, false);
el('reset').onclick = () => {
  el('rule').value = BASE;
  el('prediction').value = Prediction.more;
  rewind('Beds and rule reset. Replay any recorded trial.');
};
rewind('Choose a prediction and a branch rule.');
