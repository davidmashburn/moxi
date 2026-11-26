export const Kind = Object.freeze({ motion: "motion", sequence: "sequence", group: "group" });
export const Order = Object.freeze({ forward: "forward", reverse: "reverse" });
const kinds = Object.values(Kind);

export function initial() {
  return {
    format: 1, revision: 1, selected: 1, next: 2,
    schema: { names: { motion: "Sweep", sequence: "Chain", group: "Unison" },
      order: Order.forward, capacity: 3, beat: 2 },
    root: { id: 1, kind: Kind.sequence, children: [] },
    sketch: { note: "Reach toward the light?", x: 70, y: 85, arm: null }
  };
}

function requireValue(condition, message) {
  if (!condition) throw new Error(message);
}
function integer(n, lo, hi) { return Number.isInteger(n) && n >= lo && n <= hi; }

export function nodes(node) { return [node, ...(node.children ?? []).flatMap(nodes)]; }
export function selected(doc) { return nodes(doc.root).find(n => n.id === doc.selected); }

export function validate(d) {
  requireValue(d.format === 1 && Number.isSafeInteger(d.revision) && d.revision > 0, "Unknown document version.");
  const s = d.schema;
  const names = kinds.map(k => s.names[k]);
  requireValue(names.every(n => typeof n === "string" && n.trim() && n.length <= 24)
    && new Set(names.map(n => n.trim().toLowerCase())).size === 3, "Give each phrase a distinct name (1–24 characters).");
  requireValue(Object.values(Order).includes(s.order), "Choose a sequence order.");
  requireValue(integer(s.capacity, 1, 8), "Group capacity must be 1–8.");
  requireValue(integer(s.beat, 1, 8), "Ticks per beat must be 1–8.");
  requireValue(d.root.kind === Kind.sequence, "The score needs a sequence root.");
  const ids = new Set();
  function visit(n, depth) {
    requireValue(depth <= 8 && ids.size < 64, "Score limit is 64 slots and eight nested levels.");
    requireValue(integer(n.id, 1, Number.MAX_SAFE_INTEGER) && !ids.has(n.id), "Invalid slot identity.");
    ids.add(n.id);
    requireValue(kinds.includes(n.kind), "Unknown phrase type.");
    if (n.kind === Kind.motion) {
      requireValue(integer(n.beats, 1, 16) && n.children === undefined, "Motion duration must be 1–16 beats.");
    } else {
      requireValue(Array.isArray(n.children), "Missing phrase slots.");
      requireValue(n.kind !== Kind.group || n.children.length <= s.capacity,
        `Group #${n.id} has ${n.children.length} slots. Capacity is ${s.capacity}.`);
      n.children.forEach(child => visit(child, depth + 1));
    }
  }
  visit(d.root, 0);
  requireValue(ids.has(d.selected) && Number.isSafeInteger(d.next) && d.next > Math.max(...ids), "Invalid cursor or slot counter.");
  const a = d.sketch;
  requireValue(typeof a.note === "string" && a.note.length <= 80 && a.x === 70 && a.y === 85
    && (a.arm === null || integer(a.arm, 10, 60)), "Invalid sketch.");
  return d;
}

export function edit(doc, change) {
  const draft = structuredClone(doc);
  change(draft);
  return validate(draft);
}
export function revise(doc, schema) {
  return edit(doc, d => { d.schema = structuredClone(schema); d.revision++; });
}
export function append(doc, kind) {
  return edit(doc, d => {
    const parent = selected(d);
    requireValue(Array.isArray(parent.children), "Select a sequence or group to add a slot.");
    const id = d.next++;
    parent.children.push(kind === Kind.motion ? { id, kind, beats: 1 } : { id, kind, children: [] });
  });
}

// All groups start together. A sequence advances by each child's full span.
export function schedule(doc) {
  const events = [];
  function walk(n, start) {
    if (n.kind === Kind.motion) {
      const ticks = n.beats * doc.schema.beat;
      events.push({ id: n.id, start, end: start + ticks });
      return ticks;
    }
    const sequential = n.kind === Kind.sequence;
    const children = sequential && doc.schema.order === Order.reverse ? [...n.children].reverse() : n.children;
    let span = 0;
    for (const child of children) {
      const duration = walk(child, start + (sequential ? span : 0));
      span = sequential ? span + duration : Math.max(span, duration);
    }
    return span;
  }
  const duration = walk(doc.root, 0);
  return { events, duration };
}

export function angleAt(events, tick) {
  return events.reduce((angle, e) => angle + (tick > e.start && tick < e.end
    ? 60 * Math.sin(Math.PI * (tick - e.start) / (e.end - e.start)) : 0), 0);
}
