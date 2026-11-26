import {Kind, initial, nodes, selected, validate, edit, append, revise, schedule, angleAt} from "./score.mjs";

const $ = id => document.getElementById(id);
const fields = $("rules").elements;
const key = "moxi.v03.score.v1";
let doc = initial(), history = [], startupError = "";
try {
  const stored = localStorage.getItem(key);
  if (stored !== null) doc = validate(JSON.parse(stored));
} catch (error) { startupError = "Saved score could not be opened. Showing the starter score."; }
let compiled, plotRequest = 0;
function report(message) { $("status").textContent = message; }
function change(fn, message) {
  try {
    const next = fn(doc);
    localStorage.setItem(key, JSON.stringify(next));
    history.push(doc);
    doc = next;
    draw();
    report(message);
  } catch (error) {
    draw();
    report("Edit rejected. " + error.message);
  }
}
function schemaInput() {
  return {names: Object.fromEntries(Object.values(Kind).map(k => [k, fields[k].value.trim()])),
    order: fields.order.value, capacity: fields.capacity.valueAsNumber, beat: fields.beat.valueAsNumber};
}
function resetForm() {
  for (const [k,v] of Object.entries(doc.schema.names)) fields[k].value = v;
  for (const k of ["order","capacity","beat"]) fields[k].value = doc.schema[k];
}
function preview() {
  try {
    const {duration} = schedule(revise(doc, schemaInput()));
    $("candidate").textContent = `Proposed score · ${duration} ticks`;
  } catch (error) { $("candidate").textContent = "Cannot apply · " + error.message; }
}
$("rules").oninput = preview;
$("rules").onsubmit = event => {
  event.preventDefault();
  change(d => revise(d, schemaInput()), "Revision applied. Score slots retained.");
};
function selectSlot(id) {
  try {
    const next = edit(doc, d => { d.selected = id; });
    localStorage.setItem(key, JSON.stringify(next));
    doc = next;
    draw();
    $("slot-" + id).focus();
  } catch (error) { report(error.message); }
}
$("slots").onkeydown = event => {
  const list = nodes(doc.root);
  const index = list.findIndex(n => "slot-" + n.id === event.target.id);
  const step = {ArrowDown: 1, ArrowUp: -1}[event.key];
  if (index < 0 || !step) return;
  event.preventDefault();
  selectSlot(list[Math.max(0, Math.min(list.length - 1, index + step))].id);
};
function slots(n, depth) {
  const button = document.createElement("button");
  button.id = "slot-" + n.id;
  button.textContent = `${doc.schema.names[n.kind]} · #${n.id} · ${n.kind === Kind.motion ? n.beats + " beats" : n.children.length + " slots"}`;
  button.style.marginLeft = Math.min(depth,4) * 10 + "px";
  button.setAttribute("aria-pressed", String(n.id === doc.selected));
  button.onclick = () => selectSlot(n.id);
  $("slots").append(button);
  n.children?.forEach(child => slots(child, depth + 1));
}
async function plotCurve() {
  const request = ++plotRequest;
  const sampleCount = Math.min(512, Math.max(2, compiled.duration * 4));
  const angles = Array.from({length: sampleCount + 1}, (_, i) => angleAt(compiled.events, compiled.duration * i / sampleCount));
  try {
    const response = await fetch("/curve", {method:"POST", body:JSON.stringify(angles)});
    if (!response.ok) throw new Error();
    const blob = await response.blob();
    if (request !== plotRequest) return;
    URL.revokeObjectURL($("curve").src);
    $("curve").src = URL.createObjectURL(blob);
    $("curve").hidden = false;
    $("plotError").textContent = "";
  } catch {
    if (request === plotRequest) {
      $("curve").hidden = true;
      $("plotError").textContent = "Motion plot unavailable.";
    }
  }
}
function scrub() {
  const tick = Number($("tick").value);
  const angle = angleAt(compiled.events, tick);
  $("readout").textContent = `Tick ${tick.toFixed(2)} · joint ${angle.toFixed(1)}°`;
  const length = doc.sketch.arm ?? 0;
  $("arm").setAttribute("x2", doc.sketch.x + length*Math.cos(angle*Math.PI/180));
  $("arm").setAttribute("y2", doc.sketch.y - length*Math.sin(angle*Math.PI/180));
  $("arm").style.display = length ? "" : "none";
}
function draw() {
  $("revision").textContent = "rev " + doc.revision;
  $("slots").replaceChildren();
  slots(doc.root, 0);
  const n = selected(doc);
  $("duration").hidden = n.kind !== Kind.motion;
  $("beats").value = n.beats ?? 1;
  for (const k of Object.values(Kind)) {
    const b = $("add-" + k);
    b.textContent = "+ " + doc.schema.names[k];
    b.disabled = n.kind === Kind.motion;
  }
  compiled = schedule(doc);
  $("summary").textContent = `${compiled.events.length} motions · ${compiled.duration} ticks`;
  $("timeline").replaceChildren(...compiled.events.map(e => {
    const row = document.createElement("div");
    row.textContent = `#${e.id}  ${doc.schema.names.motion}   ${e.start} → ${e.end}`;
    return row;
  }));
  $("tick").max = compiled.duration;
  $("note").value = $("annotation").textContent = doc.sketch.note;
  $("formal").hidden = doc.sketch.arm !== null;
  $("length").hidden = doc.sketch.arm === null;
  $("radius").value = doc.sketch.arm;
  $("undo").disabled = !history.length;
  scrub(); preview(); plotCurve();
}
for (const k of Object.values(Kind)) {
  const b = document.createElement("button");
  b.id = "add-" + k;
  b.onclick = () => change(d => append(d, k), "Phrase added to selected slot.");
  $("insert").append(b);
}
$("tick").oninput = scrub;
$("beats").onchange = () => change(d => edit(d, x => { selected(x).beats = $("beats").valueAsNumber; }), "Timing updated.");
$("formal").onclick = () => change(d => edit(d, x => { x.sketch.arm = 40; }), "Arm attached. Scrub the preview tick.");
$("note").onchange = () => change(d => edit(d, x => { x.sketch.note = $("note").value; }), "Note saved.");
$("radius").onchange = () => change(d => edit(d, x => { x.sketch.arm = $("radius").valueAsNumber; }), "Arm length updated.");
$("undo").onclick = () => {
  if (!history.length) return;
  try {
    localStorage.setItem(key, JSON.stringify(history.at(-1)));
    doc = history.pop();
    resetForm(); draw(); report("Edit undone.");
  } catch (error) { report(error.message); }
};
resetForm(); draw(); report(startupError);
