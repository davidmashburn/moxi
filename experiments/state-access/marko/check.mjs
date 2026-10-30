import App from './src/app.marko';
import { editors, evaluations, reset, live } from './src/probe.mjs';
import { Code, Sink, keys, initial } from './src/domain.mjs';
const assertions = [];
function assert(condition, label, detail) {
  if (!condition) throw new Error(`${label}: ${JSON.stringify(detail)}`);
  assertions.push(label);
}
// Two frame boundaries let Marko drain both microtask and deferred-frame updates.
const settle = async () => { await new Promise(requestAnimationFrame); await new Promise(requestAnimationFrame); };
const fixture = document.querySelector('#fixture');
function node(id, sink) { return fixture.querySelector(`[data-editor="${id}"] [data-sink="${sink}"]`); }
function snapshot() {
  return [...fixture.querySelectorAll('[data-editor]')].map(section => Object.fromEntries(keys.map(key => {
    const element = section.querySelector(`[data-sink="${key}"]`);
    return [key, key === Sink.ENABLED ? !element.disabled : element instanceof HTMLInputElement ? element.value : element.textContent];
  })));
}
async function type(id, sink, value) {
  const element = node(id, sink);
  element.value = value;
  element.dispatchEvent(new Event('input', {bubbles: true}));
  await settle();
}
async function click(id, sink) { node(id, sink).click(); await settle(); }
async function measure(action) {
  const before = snapshot(); reset(); await action(); await settle();
  const after = snapshot();
  const changedValues = Object.fromEntries(keys.map(key => [key, after.filter((item, i) => item[key] !== before[i][key]).length]));
  return { evaluations: {...evaluations}, changedValues };
}
async function mount(count) {
  const instance = App.mount({count}, fixture); await settle();
  assert(fixture.querySelectorAll('[data-editor]').length === count, `mount ${count} editors`);
  return instance;
}
async function destroy(instance) { instance.destroy(); await settle(); assert(live === 0 && editors.size === 0 && fixture.children.length === 0, 'destroy clears registrations and DOM'); }
async function behavior() {
  const app = await mount(2);
  await type(0, Sink.DRAFT, '  Alpha  ');
  await type(1, Sink.DRAFT, 'Beta');
  await type(0, Sink.NOTE, 'Private');
  await click(0, Sink.ENABLED);
  assert(app.value.document().name === 'Alpha' && app.value.document().revision === 1 && app.value.document().commits === 1, 'DOM Apply normalizes and commits once');
  assert(node(1, Sink.DRAFT).value === 'Beta' && node(0, Sink.NOTE).value === 'Private', 'independent drafts and notes survive shared write');
  await click(1, Sink.ENABLED);
  assert(node(1, Sink.ERROR).textContent === Code.STALE && app.value.document().name === 'Alpha', 'stale editor rejected');
  editors.get(1).reload(); await settle();
  assert(node(1, Sink.DRAFT).value === 'Alpha' && node(1, Sink.ERROR).textContent === '', 'explicit reload synchronizes draft');
  await type(1, Sink.DRAFT, '  Alpha '); await click(1, Sink.ENABLED);
  assert(app.value.document().revision === 1 && app.value.document().commits === 1, 'normalized no-op leaves revision and history unchanged');
  await type(1, Sink.DRAFT, ' '); await click(1, Sink.ENABLED);
  assert(node(1, Sink.ERROR).textContent === Code.EMPTY, 'empty name rejected');
  await type(1, Sink.DRAFT, 'x'.repeat(25)); await click(1, Sink.ENABLED);
  assert(node(1, Sink.ERROR).textContent === Code.LONG, 'long name rejected');
  app.value.configure({maxLength: 2}); await settle();
  await type(1, Sink.DRAFT, ' é🙂 '); await click(1, Sink.ENABLED);
  assert(app.value.document().name === 'é🙂', 'Unicode code points and normalization');
  app.value.configure({writable: false}); await settle();
  assert(!snapshot()[0][Sink.ENABLED] && !snapshot()[1][Sink.ENABLED], 'read-only disables both Apply buttons');
  assert(editors.get(1).apply() === Code.READ_ONLY, 'command checks permission even outside disabled button'); await settle();
  app.value.undo(); await settle(); assert(app.value.document().name === 'é🙂', 'read-only undo rejected');
  app.value.configure({writable: true, maxLength: 24}); await settle();
  app.value.undo(); await settle();
  assert(app.value.document().name === 'Alpha' && app.value.document().revision === 3 && app.value.document().commits === 2, 'undo changes revision without new rename commit');
  editors.get(0).reload(); await settle();
  const revision = app.value.document().revision;
  app.value.replace({...initial('Replacement', 2), revision}); await settle();
  assert(editors.get(0).apply() === Code.REPLACED, 'same-revision replacement rejected by identity'); await settle();
  editors.get(0).reload(); await settle();
  await type(0, Sink.DRAFT, 'Kept');
  const originalNode = fixture.querySelector('[data-editor="0"]');
  app.value.setItems([{id: 1}, {id: 0}]); await settle();
  assert(fixture.lastElementChild === originalNode && node(0, Sink.DRAFT).value === 'Kept', 'keyed reorder preserves DOM and private draft');
  const retained = editors.get(0);
  app.value.setItems([{id: 1}]); await settle();
  assert(live === 1 && !editors.has(0), 'removed editor registration disposed');
  // Deliberately retain an escaped callback. UI disposal need not revoke command authority.
  const before = app.value.document().commits;
  const retainedCode = retained.apply(); await settle();
  const retainedCommitted = app.value.document().commits > before;
  assert(node(1, Sink.CURRENT).textContent === `Current: ${app.value.document().name}`, 'live sibling reflects any retained command result');
  app.value.setItems([{id: 1}, {id: 0}]); await settle();
  assert(node(0, Sink.DRAFT).value === app.value.document().name && fixture.lastElementChild !== originalNode, 'remove then reuse key creates fresh state and DOM');
  for (let i = 0; i < 25; i++) {
    app.value.setItems([{id: 1}]); await settle();
    app.value.setItems([{id: 1}, {id: 0}]); await settle();
    assert(live === 2 && editors.size === 2, `registration count bounded after cycle ${i + 1}`);
  }
  await destroy(app);
  return {retainedCode, retainedCommitted, cycles: 25};
}
async function scales() {
  const results = {};
  for (const count of [2, 100, 1000]) {
    const app = await mount(count);
    const rows = {};
    rows.draft = await measure(() => type(0, Sink.DRAFT, 'Local'));
    rows.note = await measure(() => type(0, Sink.NOTE, 'Note'));
    rows.name = await measure(() => app.value.rename('Grace', 1, 0));
    rows.writable = await measure(() => app.value.configure({writable: false}));
    rows.unrelated = await measure(() => app.value.configure({irrelevant: 1}));
    const expectedChanges = {draft: [Sink.DRAFT, 1], note: [Sink.NOTE, 1], name: [Sink.CURRENT, count], writable: [Sink.ENABLED, count], unrelated: [Sink.ERROR, 0]};
    for (const [operation, row] of Object.entries(rows)) {
      const [changedKey, amount] = expectedChanges[operation];
      for (const key of keys) assert(row.changedValues[key] === (key === changedKey ? amount : 0), `${count}/${operation}/${key} changed output`, row);
    }
    results[count] = rows;
    await destroy(app);
  }
  return results;
}
window.runExperiment = async () => {
  const manifest = await (await fetch('/manifest.json')).json();
  assertions.length = 0;
  const sequence = await behavior();
  const scale = await scales();
  const result = {ok: true, manifest, variant: new URL(location.href).searchParams.get('variant') ?? 'baseline', assertionCount: assertions.length, assertions, sequence, scale, userAgent: navigator.userAgent};
  window.results = result;
  document.querySelector('#status').textContent = JSON.stringify({ok: true, assertions: assertions.length, scale, sequence}, null, 2);
  return result;
};
window.ready = true;
