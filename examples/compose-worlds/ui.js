
const el = id => document.getElementById(id);
const seed = 2407;
const branchNames = Array.from(el('active').options, option => option.value);
function initialSettings() {
  return {shared: BASE, overrides: Object.fromEntries(branchNames.map(name => [name, null]))};
}
let settings = initialSettings();
let promotions = [];
const current = () => el('active').value;
const effective = name => settings.overrides[name] ?? settings.shared;
let baseline = run(seed, rules[BASE].values);
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
  const midpoint = effective(current());
  el('rule').value = midpoint;
  el('shared').value = settings.shared;
  el('sharedValue').textContent = settings.shared + '%';
  el('branchName').textContent = current();
  const inherited = name => settings.overrides[name] === null;
  el('settings').textContent = branchNames.map(name =>
    `${name} ${effective(name)}% (${inherited(name) ? 'shared' : 'local'})`).join(' · ');
  el('source').textContent = `${current()} · ${inherited(current()) ? 'Inherited' : 'Local override'}. Select the chart to edit its formula.`;
  el('promote').disabled = el('inherit').disabled = inherited(current());
  el('undo').disabled = !promotions.length;
  el('formulaPanel').hidden = true;
  el('curve').innerHTML = rules[midpoint].svg;
  el('curve').setAttribute('aria-label', `Edit feeding formula. Feeding strength at zero, half and full kelp cover: 0, ${midpoint} and 100 percent`);
  el('value').textContent = midpoint + '%';
}

function rewind(message) {
  baseline = run(seed, rules[settings.shared].values);
  branch = baseline;
  el('season').value = 0;
  el('season').disabled = true;
  el('status').textContent = message;
  showRule();
  inspect();
}

function compare(trial, replay) {
  if (replay) {
    settings = structuredClone(trial.settings);
    promotions = structuredClone(trial.promotions);
    el('active').value = trial.name;
  }
  baseline = run(seed, rules[settings.shared].values);
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
  row.append(`${trial.name} · Shared ${settings.shared}% · Midpoint ${trial.midpoint}% · Predicted ${trial.prediction} · Observed ${observed} `);
  const button = document.createElement('button');
  button.textContent = `Replay trial ${trials.length}`;
  button.onclick = () => compare(trial, true);
  row.append(button);
  el('history').append(row);
}

function editOverride(value) {
  promotions = [];
  settings.overrides[current()] = value;
  rewind('Branch updated. Both beds are at season zero.');
}

el('rule').oninput = () => editOverride(Number(el('rule').value));
el('shared').oninput = () => {
  settings.shared = Number(el('shared').value);
  promotions = [];
  rewind('Shared midpoint updated.');
};
el('inherit').onclick = () => editOverride(null);
el('promote').onclick = () => {
  promotions.push(structuredClone(settings));
  settings.shared = effective(current());
  settings.overrides[current()] = null;
  rewind(`${current()} midpoint promoted to shared.`);
};
el('undo').onclick = () => {
  settings = promotions.pop();
  rewind('Restored the settings before promotion.');
};
el('active').onchange = el('prediction').onchange = () => rewind('Draft ready. Both beds are at season zero.');
el('season').oninput = inspect;
el('compare').onclick = () => compare({
  midpoint: effective(current()), prediction: el('prediction').value, name: current(),
  settings: structuredClone(settings), promotions: structuredClone(promotions)
}, false);
el('reset').onclick = () => {
  settings = initialSettings();
  promotions = [];
  el('active').selectedIndex = 0;
  el('prediction').value = Prediction.more;
  rewind('Beds and rule reset. Replay any recorded trial.');
};

const formula = el('formula');
el('curve').onclick = () => {
  if (el('formulaPanel').hidden) {
    formula.value = `knots(0, ${effective(current())}, 100)`;
    el('formulaPanel').hidden = false;
    el('formulaError').textContent = '';
    const start = formula.value.indexOf(', ') + 2;
    formula.setSelectionRange(start, formula.value.indexOf(',', start));
  }
  formula.focus();
};
el('apply').onclick = () => {
  const match = /^\s*knots\(\s*0\s*,\s*(0|[1-9]0|100)\s*,\s*100\s*\)\s*$/.exec(formula.value);
  if (!match) {
    el('formulaError').textContent = 'Use knots(0, midpoint, 100) with a midpoint from 0 to 100 in steps of ten.';
    formula.focus();
    return;
  }
  editOverride(Number(match[1]));
  el('curve').focus();
};

let selection;
el('define').onclick = () => {
  selection = [formula.selectionStart, formula.selectionEnd, formula.selectionDirection];
  el('definition').showModal();
};
el('back').onclick = () => el('definition').close();
el('definition').onclose = () => {
  formula.focus();
  formula.setSelectionRange(...selection);
};
rewind('Choose a prediction and a branch rule.');
