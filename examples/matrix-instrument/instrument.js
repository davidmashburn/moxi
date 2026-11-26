"use strict";
// Canonical entries are integer thousandths. Text drafts and selection are
// separate; only committed numeric edits and vector moves enter one history.
const Basis = Object.freeze({U: "u", V: "v"});
const Coordinate = Object.freeze({X: 0, Y: 2});
const RankState = Object.freeze({REGULAR: "regular", NEAR: "near-singular", SINGULAR: "singular"});
const UNIT = 1000, LIMIT = 3 * UNIT, HISTORY_LIMIT = 100;
const INITIAL = [2000, 0, 0, 2000];
const fields = [...document.querySelectorAll("input[data-index]")];
const byId = id => document.getElementById(id);
let matrix = [...INITIAL], selection = {basis: Basis.U, coordinate: Coordinate.X};
let past = [], future = [], dirty = false, revision = 0, controller;

function text(ticks) { return (ticks / UNIT).toFixed(3).replace(/\.?0+$/, "") || "0"; }
function index(basis, coordinate) { return (basis === Basis.U ? 0 : 1) + coordinate; }
function snapshot() { return {matrix: [...matrix], selection: {...selection}}; }
function error(message = "") { byId("error").textContent = message; }
function parseEntry(value) {
  const normalized = value.trim();
  if (!/^[+-]?(?:\d+(?:\.\d{0,3})?|\.\d{1,3})$/.test(normalized)) return null;
  const ticks = Math.round(Number(normalized) * UNIT);
  return Number.isSafeInteger(ticks) && Math.abs(ticks) <= LIMIT ? ticks : null;
}
function syncSelection() {
  document.querySelectorAll("[data-column]").forEach(e => {e.dataset.selected = String(e.dataset.column === selection.basis);});
  document.querySelectorAll("#plot [data-basis]").forEach(e => {e.dataset.selected = String(e.dataset.basis === selection.basis);});
  for (const basis of Object.values(Basis)) byId(`basis-${basis}`).setAttribute("aria-pressed", String(basis === selection.basis));
}
function select(basis, coordinate = selection.coordinate) {
  selection = {basis, coordinate};
  syncSelection();
}
function syncActions() {
  byId("apply").disabled = !dirty;
  byId("discard").disabled = !dirty;
  byId("undo").disabled = dirty || !past.length;
  byId("redo").disabled = dirty || !future.length;
  byId("identity").disabled = dirty;
  byId("draft").textContent = dirty ? "Draft entries · frame still shows committed values." : "Entries match the frame.";
}
function syncFields() {
  fields.forEach(e => {e.value = text(matrix[Number(e.dataset.index)]); e.removeAttribute("aria-invalid");});
  for (const basis of Object.values(Basis)) {
    byId(`coords-${basis}`).textContent = `(${text(matrix[index(basis, Coordinate.X)])}, ${text(matrix[index(basis, Coordinate.Y)])})`;
  }
  dirty = false;
  syncSelection();
  syncActions();
}
function historyText(action) {
  byId("history").textContent = `${action} · ${past.length} undo / ${future.length} redo. Up to ${HISTORY_LIMIT} edits retained.`;
}
function commit(next, label, nextSelection = selection) {
  if (next.every((value, i) => value === matrix[i])) {syncFields(); error(); return;}
  const before = snapshot();
  matrix = [...next]; selection = {...nextSelection};
  past.push({before, after: snapshot(), label});
  if (past.length > HISTORY_LIMIT) past.shift();
  future = [];
  syncFields(); error(); historyText(label); draw();
}
function restore(state) {matrix = [...state.matrix]; selection = {...state.selection}; syncFields(); error(); draw();}

async function draw() {
  const current = ++revision, requested = [...matrix];
  if (controller) controller.abort();
  controller = new AbortController();
  byId("plot").hidden = true; byId("metrics").hidden = true;
  byId("retry-wrap").hidden = true; byId("render-state").hidden = false;
  byId("render-state").textContent = "Drawing current matrix…";
  byId("plot").setAttribute("aria-busy", "true");
  try {
    const response = await fetch("/render", {method: "POST", headers: {"Content-Type": "application/json"},
      body: JSON.stringify({matrix: requested}), signal: controller.signal});
    if (!response.ok) throw new Error("Render request failed");
    const result = await response.json();
    if (current !== revision) return;
    if (!Array.isArray(result.matrix) || result.matrix.length !== 4 || !result.matrix.every((n, i) => n === requested[i]) ||
        !Object.values(RankState).includes(result.rank) || typeof result.svg !== "string") throw new Error("Mismatched render");
    byId("plot").innerHTML = result.svg;
    byId("determinant").textContent = result.determinant;
    byId("area").textContent = result.area;
    const description = {
      [RankState.SINGULAR]: "Singular · det A = 0. The square collapses; the basis cannot span the plane. No inverse is defined. Move either vector, Undo, or choose Identity to recover.",
      [RankState.NEAR]: "Near singular · |det A| ≤ 0.01 × max(|entry|)². The frame is almost collapsed. Entries stay exactly as committed; nothing snaps or corrects itself.",
      [RankState.REGULAR]: "Independent basis · the square’s area scales by |det A|. A negative determinant reverses orientation."
    };
    byId("rank").textContent = description[result.rank];
    byId("rank").dataset.state = result.rank;
    syncSelection();
    byId("plot").hidden = false; byId("metrics").hidden = false;
    byId("render-state").hidden = true;
  } catch (failure) {
    if (current !== revision || failure.name === "AbortError") return;
    byId("render-state").textContent = "Drawing unavailable. Your matrix and undo history are retained. Retry, or keep editing.";
    byId("retry-wrap").hidden = false;
  } finally {
    if (current === revision) byId("plot").setAttribute("aria-busy", "false");
  }
}

fields.forEach(field => {
  field.addEventListener("focus", () => select(field.dataset.basis, Number(field.dataset.index) >= 2 ? Coordinate.Y : Coordinate.X));
  field.addEventListener("input", () => {
    dirty = fields.some(e => parseEntry(e.value) !== matrix[Number(e.dataset.index)]);
    field.removeAttribute("aria-invalid"); error(); syncActions();
  });
  field.addEventListener("keydown", event => {
    if (event.key === "Escape") {event.preventDefault(); syncFields(); error();}
  });
});
byId("entries").addEventListener("submit", event => {
  event.preventDefault();
  const next = [...matrix];
  let invalid;
  fields.forEach(field => {
    const value = parseEntry(field.value);
    field.setAttribute("aria-invalid", String(value === null));
    if (value === null) invalid ??= field;
    else next[Number(field.dataset.index)] = value;
  });
  if (invalid) {error("Use a decimal from −3 to 3 with at most three decimal places. No entries were applied."); invalid.focus(); return;}
  commit(next, "Applied numeric entries");
});
byId("discard").addEventListener("click", () => {syncFields(); error();});
for (const basis of Object.values(Basis)) {
  const control = byId(`basis-${basis}`);
  control.addEventListener("focus", () => select(basis));
  control.addEventListener("click", () => select(basis));
  control.addEventListener("keydown", event => {
    const directions = {ArrowLeft: [Coordinate.X, -1], ArrowRight: [Coordinate.X, 1], ArrowDown: [Coordinate.Y, -1], ArrowUp: [Coordinate.Y, 1]};
    const direction = directions[event.key];
    if (!direction || event.metaKey || event.ctrlKey || event.altKey) return;
    event.preventDefault();
    if (dirty) {error("Apply or discard the draft entries before moving a vector."); return;}
    const [coordinate, sign] = direction, i = index(basis, coordinate);
    const next = [...matrix]; next[i] += sign * (event.shiftKey ? 10 : 100);
    if (Math.abs(next[i]) > LIMIT) {error("Movement would leave the −3 to 3 entry range. The matrix is unchanged."); return;}
    commit(next, `Moved ${basis} ${coordinate === Coordinate.X ? "x" : "y"}`, {basis, coordinate});
  });
}
byId("plot").addEventListener("click", event => {
  const basis = event.target.closest("[data-basis]")?.dataset.basis;
  if (Object.values(Basis).includes(basis)) byId(`basis-${basis}`).focus();
});
byId("undo").addEventListener("click", () => {
  if (dirty || !past.length) return;
  const entry = past.pop(); future.push(entry); restore(entry.before); historyText(`Undid: ${entry.label}`);
});
byId("redo").addEventListener("click", () => {
  if (dirty || !future.length) return;
  const entry = future.pop(); past.push(entry); restore(entry.after); historyText(`Redid: ${entry.label}`);
});
byId("identity").addEventListener("click", () => commit([1000, 0, 0, 1000], "Set identity"));
byId("retry").addEventListener("click", draw);
syncFields(); draw();
