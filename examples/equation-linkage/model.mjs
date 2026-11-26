// A lossless, deliberately finite grammar. Source is the document; numeric
// values are projections. Neither parsing nor history serializes those values.
export const Field = Object.freeze({Length: 'length', Angle: 'angle'});
export const ParseKind = Object.freeze({Ready: 'ready', Invalid: 'invalid'});
export const Limits = Object.freeze({minLength: 40, maxLength: 140, minAngle: 0, maxAngle: 90, sourceLength: 4096, history: 100});
export const INITIAL = 'L = 100.00 mm\nθ = 30.0 deg\nx = L * cos(θ)\ny = L * sin(θ)\n';

const number = '\\+?(?:\\d+(?:\\.\\d*)?|\\.\\d+)';
const space = '[ \\t]*';
const end = `${space}(?:#[^\\r\\n]*)?`;
const equation = new RegExp(
  `^\\s*L${space}=${space}(?<length>${number})${space}mm${end}\\r?\\n` +
  `${space}θ${space}=${space}(?<angle>${number})${space}deg${end}\\r?\\n` +
  `${space}x${space}=${space}L${space}[*·]${space}cos${space}\\(${space}θ${space}\\)${end}\\r?\\n` +
  `${space}y${space}=${space}L${space}[*·]${space}sin${space}\\(${space}θ${space}\\)${end}\\s*$`, 'd');

export function parse(source) {
  if (typeof source !== 'string') throw new TypeError('Equation source must be text.');
  const invalid = message => ({kind: ParseKind.Invalid, source, message});
  if (source.length > Limits.sourceLength) return invalid('Equations exceed the 4096-character evaluation bound. Text is retained.');
  const match = equation.exec(source);
  if (!match) return invalid('Use the four supported equations shown below. Incomplete or unsupported text is retained; geometry shows the applied state.');
  const leaves = Object.fromEntries(Object.values(Field).map(field => {
    const [start, end] = match.indices.groups[field];
    return [field, {start, end, raw: source.slice(start, end)}];
  }));
  const length = Number(leaves[Field.Length].raw), angle = Number(leaves[Field.Angle].raw);
  if (!Number.isFinite(length) || length < Limits.minLength || length > Limits.maxLength)
    return invalid('Length must be 40–140 mm. Text is retained; geometry shows the applied state.');
  if (!Number.isFinite(angle) || angle < Limits.minAngle || angle > Limits.maxAngle)
    return invalid('Angle must be 0–90 degrees. Text is retained; geometry shows the applied state.');
  return {kind: ParseKind.Ready, source, leaves, length, angle};
}

export function replaceScalar(source, field, raw) {
  if (!Object.values(Field).includes(field) || typeof raw !== 'string') throw new TypeError('Unknown equation leaf or non-text replacement.');
  const doc = parse(source);
  if (doc.kind !== ParseKind.Ready) throw new TypeError('Structured editing needs supported equations. Edit the retained source to recover.');
  const leaf = doc.leaves[field];
  return source.slice(0, leaf.start) + raw + source.slice(leaf.end);
}

// Pointer/slider routes are whole degrees. Keep the original sign, zero
// padding and fractional zeros; returning to the starting value is lossless.
export function angleSource(source, angle) {
  if (!Number.isInteger(angle) || angle < Limits.minAngle || angle > Limits.maxAngle) throw new RangeError('Pose must be a whole degree from 0 to 90.');
  const doc = parse(source);
  if (doc.kind !== ParseKind.Ready) throw new TypeError('Cannot move unsupported equations.');
  if (doc.angle === angle) return source;
  const raw = doc.leaves[Field.Angle].raw;
  const unsigned = raw.replace(/^\+/, '');
  const [integer, fraction] = unsigned.split('.');
  const replacement = (raw.startsWith('+') ? '+' : '') + String(angle).padStart(integer.length, '0') +
    (fraction === undefined ? '' : '.' + '0'.repeat(fraction.length));
  return replaceScalar(source, Field.Angle, replacement);
}

export function endpoint(doc) {
  if (doc.kind !== ParseKind.Ready) throw new TypeError('Endpoint needs supported equations.');
  const radians = doc.angle * Math.PI / 180;
  return {x: doc.length * Math.cos(radians), y: doc.length * Math.sin(radians)};
}

export class EquationLinkage {
  constructor(source = INITIAL) {
    if (parse(source).kind !== ParseKind.Ready) throw new TypeError('Starting equations must be valid.');
    this.source = this.draft = source;
    this.past = [];
    this.future = [];
  }
  get parsed() { return parse(this.draft); }
  get display() { const doc = this.parsed; return doc.kind === ParseKind.Ready ? doc : parse(this.source); }
  get dirty() { return this.draft !== this.source; }
  get canUndo() { return this.past.length > 0; }
  get canRedo() { return this.future.length > 0; }
  setDraft(source) { if (typeof source !== 'string') throw new TypeError('Draft must be text.'); this.draft = source; }
  cancel() { this.draft = this.source; }
  apply() {
    if (!this.dirty || this.parsed.kind !== ParseKind.Ready) return false;
    this.past.push(this.source);
    if (this.past.length > Limits.history) this.past.shift();
    this.source = this.draft;
    this.future = [];
    return true;
  }
  undo() {
    if (!this.canUndo) return false;
    this.future.push(this.source);
    this.source = this.draft = this.past.pop();
    return true;
  }
  redo() {
    if (!this.canRedo) return false;
    this.past.push(this.source);
    this.source = this.draft = this.future.pop();
    return true;
  }
}
