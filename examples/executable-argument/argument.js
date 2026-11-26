const el = id => document.getElementById(id);
const original = Object.freeze({riders: "40", dispatch: "120", supported: true, note: ""});
let step = 0;
let checkpoint;
let alternative;
let insertion;

function read() {
  return {riders: el("riders").value, dispatch: el("dispatch").value,
          supported: el("supported").checked, note: el("note").value};
}
function apply(state) {
  for (const key of ["riders", "dispatch", "note"]) el(key).value = state[key];
  el("supported").checked = state.supported;
  render();
}
function finding(delta) {
  if (delta === 0) return "Both proposals cost the same.";
  return (delta > 0 ? "Shuttle saves" : "Vouchers save") + " $" + Math.abs(delta) + " per run.";
}
function drawSensitivity(model, riders) {
  const container = el("chart");
  container.innerHTML = model.chart;
  const svg = container.querySelector("svg");
  const points = svg.querySelector("polyline").points;
  function mark(tag, attrs) {
    const node = document.createElementNS(svg.namespaceURI, tag);
    for (const [key, value] of Object.entries(attrs)) node.setAttribute(key, value);
    svg.appendChild(node);
    return node;
  }
  const tie = points.getItem(model.threshold);
  const left = points.getItem(0).x;
  const right = points.getItem(points.numberOfItems - 1).x;
  mark("line", {x1:left, x2:right, y1:tie.y, y2:tie.y, stroke:"#586c6b", "stroke-dasharray":"3 3"});
  mark("text", {x:left - 6, y:tie.y + 4, "text-anchor":"end", "font-size":12}).textContent = "$0";
  for (const [x, label] of [[left, "0"], [tie.x, String(model.threshold)], [right, "60"]]) {
    mark("text", {x, y:114, "text-anchor":"middle", "font-size":12}).textContent = label;
  }
  if (riders !== null) {
    const pt = points.getItem(riders);
    mark("circle", {cx:pt.x, cy:pt.y, r:5, fill:"#ac4b18", stroke:"white"});
  }
}
function render() {
  const state = read();
  const model = fixture.cases[state.dispatch];
  const valid = state.riders !== "" && el("riders").validity.valid;
  const row = valid && state.supported && model.rows[Number(state.riders)];
  if (valid) el("scrub").value = state.riders;
  el("result").classList.toggle("error", !row);
  el("result").textContent = row ? finding(row.delta) : state.supported
    ? "Enter a whole number of riders from 0 to 60." : "Demand premise withdrawn. Conclusion unavailable.";
  el("costs").textContent = row ? `Vouchers $${row.voucher} · Shuttle $${row.shuttle}` : "";
  drawSensitivity(model, row ? Number(state.riders) : null);
  el("condition").textContent = `At $${state.dispatch} dispatch, costs tie at ${model.threshold} riders. Below that demand vouchers cost less; above it the shuttle costs less.`;
  el("save").disabled = el("insert").disabled = !row;
}
const [voucherRate, shuttleRate] = fixture.rates;
el("formula").textContent = `Vouchers = $${voucherRate} × riders. Shuttle = dispatch + $${shuttleRate} × riders.`;
el("observations").textContent = "Fixture T1 (riders, voucher $, variable shuttle $): " +
  fixture.observations.map(row => "(" + row.join(", ") + ")").join(", ") +
  ". Each unit rate is fitted through zero: sum(riders × spend) / sum(riders²). Dispatch is an assumed fixed cost.";
for (const id of ["riders", "dispatch", "supported"]) el(id).oninput = render;
el("scrub").oninput = () => { el("riders").value = el("scrub").value; render(); };

const steps = [
  "Follow five actions, or edit the exploration copy directly.",
  "Start with the authored demand and dispatch assumptions.",
  "Trace both cost rates to the synthetic observations.",
  "Set demand to the break-even point. Checkpoint saved.",
  "Reduce demand by ten riders and compare the costs.",
  "Raise demand above break-even and inspect the reversal."
];
function showStep() {
  el("stepText").textContent = step ? `${step} / 5 · ${steps[step]}` : steps[0];
  el("next").disabled = step === 5;
  el("checkpoint").disabled = !checkpoint;
}
el("next").onclick = () => {
  step++;
  // Each action names a complete state so an intervening edit cannot alter playback.
  const threshold = fixture.cases[original.dispatch].threshold;
  const demand = [null, 40, 40, threshold, threshold - 10, threshold + 10][step];
  apply({...original, riders: String(demand)});
  el("details").open = step >= 2;
  if (step === 3) checkpoint = read();
  showStep();
};
el("checkpoint").onclick = () => {
  step = 3;
  apply(checkpoint);
  el("details").open = true;
  showStep();
};
el("restore").onclick = () => {
  step = 0;
  el("details").open = false;
  apply(original);
  showStep();
};
el("save").onclick = () => {
  alternative = read();
  el("saved").textContent = `Saved for this session: ${alternative.riders} riders, $${alternative.dispatch} dispatch. ${alternative.note}`;
  el("reopen").disabled = false;
};
el("reopen").onclick = () => apply(alternative);
el("insert").onclick = () => {
  const state = read();
  insertion = {
    text: `${state.riders} riders at $${state.dispatch} dispatch. ${el("costs").textContent}. ${el("result").textContent} ${state.note}`,
    condition: el("condition").textContent, chart: el("chart").innerHTML
  };
  el("inserted").textContent = insertion.text + " Source: fixture T1, through-zero cost fit.";
  el("export").disabled = false;
};
el("export").onclick = () => {
  const doc = document.implementation.createHTMLDocument("Shuttle cost comparison");
  doc.documentElement.lang = "en";
  doc.head.append(document.querySelector("style").cloneNode(true));
  const main = doc.body.appendChild(doc.createElement("main"));
  function add(tag, text) { main.appendChild(doc.createElement(tag)).textContent = text; }
  add("h1", "When does the shuttle cost less?");
  add("h2", "Authored argument");
  add("p", "At 40 riders and $120 dispatch: vouchers $240, shuttle $200. Shuttle saves $40 per run.");
  add("h2", "Inserted comparison");
  add("p", insertion.text);
  add("p", insertion.condition);
  main.appendChild(doc.createElement("figure")).innerHTML = insertion.chart;
  add("p", document.querySelector("figcaption").textContent);
  add("h2", "Model, source and limit");
  for (const id of ["formula", "observations"]) add("p", el(id).textContent);
  add("p", el("source").lastElementChild.textContent);
  const url = URL.createObjectURL(new Blob(["<!doctype html>", doc.documentElement.outerHTML], {type:"text/html"}));
  const link = document.createElement("a");
  link.href = url;
  link.download = "shuttle-comparison.html";
  link.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
};
render();
showStep();
