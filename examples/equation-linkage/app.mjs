import {EquationLinkage, INITIAL, Field, ParseKind, Limits, parse, replaceScalar, angleSource, endpoint} from './model.mjs';

const Mode = Object.freeze({Layout: 'layout', Text: 'text'});
const Gesture = Object.freeze({Pointer: 'pointer', Pose: 'pose'});
const $ = id => document.getElementById(id);
const model = new EquationLinkage();
let mode = Mode.Layout, gesture = null;
const [ox, oy] = projection.origin;
const dx = projection.maximum[0] - ox, dy = projection.maximum[1] - oy;
const project = ({x, y}) => [ox + x / Limits.maxLength * dx, oy + y / Limits.maxLength * dy];

function renderLayout() {
  const container = $('layout');
  container.replaceChildren();
  const doc = model.parsed;
  if (doc.kind !== ParseKind.Ready) {
    const note = document.createElement('p');
    note.className = 'hint';
    note.textContent = 'Layout unavailable for this draft. Its exact text is kept below. Return to Equation text to repair it, or cancel.';
    const source = document.createElement('pre');
    source.textContent = model.draft;
    container.append(note, source);
    return;
  }
  for (const [field, symbol, unit, label] of [[Field.Length, 'L', 'mm', 'Layout length (mm)'], [Field.Angle, 'θ', 'deg', 'Layout angle (degrees)']]) {
    const row = document.createElement('label');
    row.className = 'equation';
    const lhs = document.createElement('span');
    lhs.textContent = symbol + ' =';
    const input = document.createElement('input');
    input.id = 'layout-' + field;
    input.setAttribute('aria-label', label);
    input.value = doc.leaves[field].raw;
    input.inputMode = 'decimal';
    const suffix = document.createElement('span');
    suffix.className = 'unit';
    suffix.textContent = unit;
    // Freeze source spans for the focused leaf, including an incomplete edit.
    // The next leaf starts from the current draft, preserving its sibling.
    let basis = doc.source;
    input.onfocus = () => { if (model.parsed.kind === ParseKind.Ready) basis = model.draft; };
    input.oninput = () => {
      model.setDraft(replaceScalar(basis, field, input.value));
      gesture = null;
      sync(false);
    };
    row.append(lhs, input, suffix);
    container.append(row);
  }
  const relations = document.createElement('div');
  relations.innerHTML = '<p><math><mi>x</mi><mo>=</mo><mi>L</mi><mo>·</mo><mi>cos</mi><mo>(</mo><mi>θ</mi><mo>)</mo></math></p><p><math><mi>y</mi><mo>=</mo><mi>L</mi><mo>·</mo><mi>sin</mi><mo>(</mo><mi>θ</mi><mo>)</mo></math></p>';
  container.append(relations);
}

function sync(layout = true, message) {
  const doc = model.parsed, shown = model.display, point = endpoint(shown);
  if ($('equation-text').value !== model.draft) $('equation-text').value = model.draft;
  $('text-view').hidden = mode !== Mode.Text;
  $('layout-view').hidden = mode !== Mode.Layout;
  $('show-text').setAttribute('aria-pressed', mode === Mode.Text);
  $('show-layout').setAttribute('aria-pressed', mode === Mode.Layout);
  if (layout) renderLayout();
  for (const input of $('layout').querySelectorAll('input'))
    input.disabled = doc.kind !== ParseKind.Ready && input !== document.activeElement;
  $('diagnostic').textContent = doc.kind === ParseKind.Invalid ? doc.message : '';
  $('apply').disabled = !model.dirty || doc.kind !== ParseKind.Ready;
  $('cancel').disabled = !model.dirty;
  $('undo').disabled = !model.canUndo;
  $('redo').disabled = !model.canRedo;
  const blocked = model.dirty && !gesture;
  $('pose').disabled = blocked;
  $('mechanism').setAttribute('aria-disabled', blocked);
  $('pose').value = shown.angle;
  $('mechanism').setAttribute('aria-valuenow', shown.angle);
  $('mechanism').setAttribute('aria-valuetext', shown.angle + ' degrees');
  const [tx, ty] = project(point);
  $('axes').setAttribute('d', `M ${ox} ${oy + dy} V ${oy} H ${ox + dx}`);
  $('bar').setAttribute('x1', ox); $('bar').setAttribute('y1', oy);
  $('bar').setAttribute('x2', tx); $('bar').setAttribute('y2', ty);
  $('pivot').setAttribute('cx', ox); $('pivot').setAttribute('cy', oy);
  $('tip').setAttribute('cx', tx); $('tip').setAttribute('cy', ty);
  $('trace').setAttribute('points', projection.trace.map(([x, y]) =>
    [ox + (x - ox) * shown.length / Limits.maxLength, oy + (y - oy) * shown.length / Limits.maxLength].join(',')).join(' '));
  $('coordinates').textContent = `L ${shown.length} mm · θ ${shown.angle}° · x ${point.x.toFixed(3)} mm · y ${point.y.toFixed(3)} mm`;
  $('phase').textContent = doc.kind === ParseKind.Invalid ? 'Invalid draft · applied geometry' : model.dirty ? 'Preview · not applied' : 'Applied configuration';
  $('status').textContent = message || (model.dirty ? 'Draft retained. Apply to keep it, or cancel.' : 'Applied state. No pending edit.');
}

function cancel(message = 'Preview cancelled. Exact applied equations restored.') {
  gesture = null;
  model.cancel();
  sync(true, message);
}
function pose(angle, kind) {
  if (!gesture) {
    if (model.dirty) return false;
    gesture = {kind, source: model.source};
  }
  model.setDraft(angleSource(gesture.source, angle));
  sync(true, 'Angle preview. Apply stores one change; Escape cancels it.');
  return true;
}

$('show-text').onclick = () => { mode = Mode.Text; sync(); };
$('show-layout').onclick = () => { mode = Mode.Layout; sync(); };
$('equation-text').oninput = () => { gesture = null; model.setDraft($('equation-text').value); sync(false); };
$('apply').onclick = () => { gesture = null; model.apply(); sync(true, 'Change applied. Undo restores its exact source and geometry.'); };
$('cancel').onclick = () => cancel();
$('undo').onclick = () => { gesture = null; model.undo(); sync(true, 'Undone. Exact equations and linked geometry restored.'); };
$('redo').onclick = () => { gesture = null; model.redo(); sync(true, 'Redone. Exact equations and linked geometry restored.'); };
$('pose').oninput = () => pose(Number($('pose').value), Gesture.Pose);

const mechanism = $('mechanism');
let pointer = null, pointerStart = null;
function pointerAngle(event) {
  const point = new DOMPoint(event.clientX, event.clientY).matrixTransform(mechanism.getScreenCTM().inverse());
  const x = (point.x - ox) / dx, y = (point.y - oy) / dy;
  if (Math.hypot(x, y) < .015) return null; // The pivot has no defined angle.
  return Math.round(Math.max(0, Math.min(90, Math.atan2(y, x) * 180 / Math.PI)));
}
mechanism.onpointerdown = event => {
  if (event.button !== 0 || model.dirty && !gesture || pointer !== null) return;
  const angle = pointerAngle(event);
  if (angle === null) return;
  event.preventDefault();
  mechanism.focus();
  pointer = event.pointerId;
  mechanism.setPointerCapture(pointer);
  // Taking hold of the existing endpoint is not an angle edit. In particular,
  // don't quantize a precise fractional token until the pointer actually moves.
  pointerStart = event.target === $('tip') ? {x:event.clientX,y:event.clientY,source:model.draft} : null;
  if (pointerStart) gesture ||= {kind:Gesture.Pointer,source:model.source};
  else pose(angle, Gesture.Pointer);
};
mechanism.onpointermove = event => {
  if (pointer !== event.pointerId) return;
  if (pointerStart && Math.hypot(event.clientX-pointerStart.x,event.clientY-pointerStart.y)<2) {
    model.setDraft(pointerStart.source);
    sync();
    return;
  }
  const angle = pointerAngle(event);
  if (angle !== null) pose(angle, Gesture.Pointer);
};
mechanism.onpointerup = event => { if (pointer === event.pointerId) { pointer = null; pointerStart = null; } };
mechanism.onpointercancel = () => { pointer = null; pointerStart = null; if (gesture) cancel(); };
mechanism.onlostpointercapture = () => { if (pointer !== null) { pointer = null; if (gesture) cancel(); } };
mechanism.onkeydown = event => {
  const direction = {ArrowRight: 1, ArrowUp: 1, ArrowLeft: -1, ArrowDown: -1}[event.key];
  if (!direction) return;
  event.preventDefault();
  pose(Math.max(0, Math.min(90, Math.round(model.display.angle) + direction * (event.shiftKey ? 10 : 1))), Gesture.Pose);
};
document.addEventListener('keydown', event => {
  if (event.key === 'Escape') { event.preventDefault(); pointer = null; cancel(); }
  // Native textarea/input undo stays native. Buttons provide shared document
  // history; these shortcuts address it when focus is outside an editor leaf.
  if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === 'z' && !['INPUT', 'TEXTAREA'].includes(event.target.tagName)) {
    event.preventDefault(); gesture = null;
    if (event.shiftKey) model.redo(); else model.undo();
    sync();
  }
});
window.addEventListener('blur', () => { if (gesture) { pointer = null; cancel('Window focus lost. Geometry preview cancelled.'); } });
sync();
