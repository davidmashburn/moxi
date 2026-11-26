import {Cursor, LAST_SAMPLE} from "./interaction.mjs";

const el = id => document.getElementById(id);
const svg = document.querySelector("#plot svg");
const points = svg.querySelector("polyline").points;
const marker = document.createElementNS(svg.namespaceURI, "circle");
marker.setAttribute("r", "10");
marker.setAttribute("fill", "#ba561d");
marker.setAttribute("stroke", "white");
marker.setAttribute("stroke-width", "3");
svg.append(marker);
const source = new Cursor(), copy = new Cursor();
const STORAGE_KEY = "moxi.i19.last-command";
let current = source, record = null, pointer = null;
try {
  record = localStorage.getItem(STORAGE_KEY);
} catch {
  // Storage can be disabled by the browser; keep the in-session record usable.
}
const entry = el("entry");

function render(message, preserveText = false) {
  const value = current.draft ?? current.position;
  const point = points.getItem(value);
  marker.setAttribute("cx", point.x);
  marker.setAttribute("cy", point.y);
  if (!preserveText) entry.value = value;
  el("stats").textContent = `Revision ${current.revision} · Undo depth ${current.history.length}`;
  el("inspect").textContent = `Origin ${current.position} · Preview ${current.draft ?? "—"} · Target signal/cursor`;
  el("status").textContent = message;
  el("record").textContent = record ?? "No recorded move";
  el("commit").disabled = current.draft === null || current.draft === current.position;
  el("cancel").disabled = current.draft === null && entry.validity.valid && entry.value !== "";
  el("undo").disabled = !current.history.length;
  el("replay").disabled = !record || current.draft !== null;
}

function preview(value, preserveText = false) {
  try {
    current.preview(value);
    render("Preview only", preserveText);
  } catch (error) {
    current.cancel();
    render(error.message, preserveText);
  }
}
function release() {
  if (pointer !== null && svg.hasPointerCapture(pointer)) svg.releasePointerCapture(pointer);
  pointer = null;
}
function cancel() {
  release();
  current.cancel();
  render("Preview cancelled");
}
function commit() {
  if (el("commit").disabled) return;
  release();
  record = current.commit();
  try {
    localStorage.setItem(STORAGE_KEY, record);
    render("Move committed");
  } catch {
    render("Move committed · recording available for this session only");
  }
}
entry.oninput = () => preview(entry.valueAsNumber, true);
entry.onkeydown = event => { if (event.key === "Enter") commit(); };
document.addEventListener("keydown", event => { if (event.key === "Escape") cancel(); });
function drag(event) {
  if (event.pointerId !== pointer) return;
  const p = new DOMPoint(event.clientX, event.clientY).matrixTransform(svg.getScreenCTM().inverse());
  const start = points.getItem(0).x, end = points.getItem(LAST_SAMPLE).x;
  preview(Math.max(0, Math.min(LAST_SAMPLE, Math.round((p.x-start)*LAST_SAMPLE/(end-start)))));
}
marker.onpointerdown = event => {
  if (event.button !== 0 || pointer !== null) return;
  pointer = event.pointerId;
  svg.setPointerCapture(pointer);
  drag(event);
};
svg.onpointermove = drag;
svg.onpointerup = event => { if (event.pointerId === pointer) { drag(event); release(); } };
svg.onlostpointercapture = svg.onpointercancel = event => { if (event.pointerId === pointer) cancel(); };
el("commit").onclick = commit;
el("cancel").onclick = cancel;
el("undo").onclick = () => { release(); current.undo(); render("Move undone"); };
el("switchBoard").onclick = () => {
  release();
  current.cancel();
  current = current === source ? copy : source;
  const compact = current === copy;
  el("plot").classList.toggle("compact", compact);
  el("board").textContent = compact ? "Compact replay copy" : "Source trace";
  el("switchBoard").textContent = compact ? "Return to source" : "Open compact copy";
  render("Opened trace");
};
el("replay").onclick = () => {
  try {
    current.apply(record);
    render("Recorded move replayed");
  } catch (error) {
    render(error.message);
  }
};
render(record ? "Fresh trace · previous recording available" : "Ready");
