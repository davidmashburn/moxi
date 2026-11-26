import assert from 'node:assert/strict';
import test from 'node:test';

const api = await import('./model.mjs').catch(() => ({}));
test('I21 exposes a bounded lossless equation model', () => {
  assert.equal(typeof api.parse, 'function', 'Missing bounded equation text/layout model');
});

if (api.parse) {
  const {parse, Field, ParseKind, INITIAL, replaceScalar, angleSource, EquationLinkage, endpoint} = api;
  const precise = '\tL  =  00100.5000 mm # length\r\nθ = +030.000 deg\r\nx = L · cos(θ)\r\ny = L * sin(θ)\r\n';

  test('parse/structured leaves retain exact source, spelling, units, comments and CRLF', () => {
    const doc = parse(precise);
    assert.equal(doc.kind, ParseKind.Ready);
    assert.equal(doc.source, precise);
    assert.equal(doc.leaves[Field.Length].raw, '00100.5000');
    assert.equal(doc.leaves[Field.Angle].raw, '+030.000');
    assert.equal(doc.length, 100.5);
    for (const leaf of Object.values(doc.leaves)) {
      assert.equal(doc.source.slice(leaf.start, leaf.end), leaf.raw);
    }
    assert.equal(replaceScalar(precise, Field.Length, '00120.2500'), precise.replace('00100.5000', '00120.2500'));
  });

  test('malformed and unsupported notation are retained, never evaluated or silently rewritten', () => {
    for (const source of ['', INITIAL.replace('100.00', ''), INITIAL.replace('cos', 'tan'),
      INITIAL.replace('100.00', 'Infinity'), INITIAL.replace('30.0', '91'),
      INITIAL.replace('100.00', '39.999'), INITIAL.replace('sin(θ)', 'sin(θ) + 1'),
      INITIAL + '<img onerror="throw 1">', 'a'.repeat(5000)]) {
      const doc = parse(source);
      assert.equal(doc.kind, ParseKind.Invalid);
      assert.equal(doc.source, source);
    }
  });

  test('geometry pose edits replace only theta and preserve its lexical style', () => {
    assert.equal(angleSource(precise, 45), precise.replace('+030.000', '+045.000'));
    assert.equal(angleSource(precise, 30), precise);
    assert.equal(angleSource(precise, 0), precise.replace('+030.000', '+000.000'));
    assert.throws(() => angleSource(precise, 91), RangeError);
    assert.throws(() => replaceScalar(precise, 'unknown', '7'), TypeError);
  });

  test('long precise angle spelling survives geometry edits without toFixed limits', () => {
    const raw = '030.' + '0'.repeat(120);
    const source = INITIAL.replace('30.0', raw);
    assert.equal(parse(source).kind, ParseKind.Ready);
    assert.equal(angleSource(source, 45), source.replace(raw, '045.' + '0'.repeat(120)));
  });

  test('draft/cancel/apply/undo/redo share exact text and derived geometry', () => {
    const model = new EquationLinkage(precise);
    const original = endpoint(model.display);
    model.setDraft(replaceScalar(precise, Field.Length, '00120.2500'));
    assert.equal(model.source, precise);
    assert.notDeepEqual(endpoint(model.display), original);
    model.cancel();
    assert.equal(model.draft, precise);
    assert.deepEqual(endpoint(model.display), original);
    assert.equal(model.apply(), false);
    assert.equal(model.canUndo, false);
    model.setDraft(replaceScalar(precise, Field.Length, '00120.2500'));
    assert.equal(model.apply(), true);
    const afterLength = model.source;
    model.setDraft(angleSource(model.source, 45));
    assert.equal(model.apply(), true);
    model.undo();
    assert.equal(model.draft, afterLength);
    model.undo();
    assert.equal(model.source, precise);
    assert.deepEqual(endpoint(model.display), original);
    model.redo();
    assert.equal(model.source, afterLength);
    model.setDraft(afterLength.replace('00120.2500', '00125.7500'));
    model.apply();
    assert.equal(model.canRedo, false);
  });

  test('invalid drafts survive mode changes and cannot commit or move committed geometry', () => {
    const model = new EquationLinkage();
    const point = endpoint(model.display);
    const bad = INITIAL.replace('100.00', '1..');
    model.setDraft(bad);
    assert.equal(model.draft, bad);
    assert.equal(model.parsed.kind, ParseKind.Invalid);
    assert.deepEqual(endpoint(model.display), point);
    assert.equal(model.apply(), false);
    assert.equal(model.source, INITIAL);
    assert.equal(model.canUndo, false);
    model.cancel();
    assert.equal(model.draft, INITIAL);
  });

  test('history commands discard pending drafts and restore applied source, including CRLF', () => {
    const model = new EquationLinkage(precise);
    const changed = replaceScalar(precise, Field.Length, '00130.0000');
    model.setDraft(changed); model.apply();
    model.setDraft(changed.replace('00130.0000','bad'));
    model.undo();
    assert.equal(model.draft, precise);
    model.setDraft(precise.replace('+030.000','bad'));
    model.redo();
    assert.equal(model.draft, changed);
    assert.equal(model.parsed.kind, ParseKind.Ready);
  });

  test('geometric constraints and trace endpoints agree throughout the allowed domain', () => {
    for (const length of [40, 100.5, 140]) {
      for (let angle = 0; angle <= 90; angle++) {
        const source = angleSource(replaceScalar(INITIAL, Field.Length, String(length)), angle);
        const doc = parse(source);
        const {x, y} = endpoint(doc);
        assert.ok(Math.abs(Math.hypot(x, y) - length) < 1e-10);
        assert.ok(Math.abs(x - length * Math.cos(angle * Math.PI / 180)) < 1e-10);
        assert.ok(Math.abs(y - length * Math.sin(angle * Math.PI / 180)) < 1e-10);
      }
    }
  });
}
