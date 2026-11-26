import test from "node:test";
import assert from "node:assert/strict";
import {Kind, initial, append, edit} from "./score.mjs";
import {openScore, scoreKey, recoveryKey} from "./persistence.mjs";

function memory(entries = []) {
  const values = new Map(entries), writes = [];
  return {
    writes,
    getItem(key) { return values.get(key) ?? null; },
    setItem(key, value) { writes.push(key); values.set(key, value); }
  };
}

const unsupported = {...initial(), format: 99};
let incompatible = append(initial(), Kind.group);
incompatible = edit(incompatible, d => { d.selected = 2; });
incompatible = append(append(incompatible, Kind.motion), Kind.motion);
incompatible.schema.capacity = 1;

for (const [name, raw] of [
  ["malformed", ' \r\n {"unfinished": "original ☀️ source"'],
  ["unsupported", JSON.stringify(unsupported, null, 2) + "\r\n"],
  ["incompatible", JSON.stringify(incompatible, null, 2) + "\r\n"],
  ["empty", ""]
]) {
  test(`${name} saved source survives starter selection, editing and reload byte for byte`, () => {
    const storage = memory([[scoreKey, raw]]);
    const session = openScore(() => storage);
    assert.equal(session.loadFailed, true);
    assert.deepEqual(session.doc, initial());
    assert.equal(storage.getItem(scoreKey), raw);
    assert.deepEqual(session.recoverySources(), [raw]);

    const selection = edit(session.doc, d => { d.selected = 1; });
    session.save(selection);
    assert.deepEqual(storage.writes, [recoveryKey, scoreKey]);
    const changed = edit(append(selection, Kind.motion), d => { d.sketch.note = "Starter edit"; });
    session.save(changed);
    const reopened = openScore(() => storage);
    assert.equal(reopened.loadFailed, false);
    assert.deepEqual(reopened.doc, changed);
    assert.deepEqual(reopened.recoverySources(), [raw]);
    assert.deepEqual(JSON.parse(storage.getItem(recoveryKey)), [raw]);
  });
}

test("a failed recovery write blocks replacement and can be retried", () => {
  const raw = "unreadable original", storage = memory([[scoreKey, raw]]);
  const session = openScore(() => storage), write = storage.setItem;
  storage.setItem = () => { throw new Error("Storage full"); };
  assert.throws(() => session.save(append(session.doc, Kind.motion)), /Storage full/);
  assert.equal(storage.getItem(scoreKey), raw);
  assert.equal(storage.getItem(recoveryKey), null);
  assert.equal(session.unreadableSource, raw);
  assert.deepEqual(openScore(() => storage).recoverySources(), [raw]);
  storage.setItem = write;
  session.save(append(session.doc, Kind.motion));
  assert.equal(openScore(() => storage).doc.root.children.length, 1);
  assert.deepEqual(openScore(() => storage).recoverySources(), [raw]);
});

test("a failed active write keeps the original and its recovery copy; retry does not duplicate it", () => {
  const raw = "unknown document", storage = memory([[scoreKey, raw]]);
  const session = openScore(() => storage), write = storage.setItem;
  storage.setItem = (key, value) => {
    if (key === scoreKey) throw new Error("Active write failed");
    write(key, value);
  };
  assert.throws(() => session.save(append(session.doc, Kind.motion)), /Active write failed/);
  assert.equal(storage.getItem(scoreKey), raw);
  assert.deepEqual(JSON.parse(storage.getItem(recoveryKey)), [raw]);
  assert.equal(session.unreadableSource, raw);
  storage.setItem = write;
  session.save(append(session.doc, Kind.motion));
  assert.equal(session.unreadableSource, null);
  assert.deepEqual(openScore(() => storage).recoverySources(), [raw]);
});

test("recovery retains earlier sources and deduplicates exact copies", () => {
  const storage = memory([[scoreKey, "new original"], [recoveryKey, JSON.stringify(["older original"])]]);
  openScore(() => storage).save(initial());
  storage.setItem(scoreKey, "new original");
  openScore(() => storage).save(initial());
  assert.deepEqual(openScore(() => storage).recoverySources(), ["older original", "new original"]);
});

test("an unreadable recovery archive is never overwritten to make room for a starter", () => {
  for (const archive of ["malformed", '{"format":99}']) {
    const storage = memory([[scoreKey, "original"], [recoveryKey, archive]]);
    assert.throws(() => openScore(() => storage).save(initial()));
    assert.equal(storage.getItem(scoreKey), "original");
    assert.equal(storage.getItem(recoveryKey), archive);
    assert.deepEqual(storage.writes, []);
  }
});

test("failed initial reads block writes even if storage later becomes writable", () => {
  const raw = JSON.stringify(append(initial(), Kind.motion));
  const storage = memory([[scoreKey, raw]]);
  const session = openScore(() => { throw new Error("Access denied"); });
  assert.equal(session.loadFailed, true);
  assert.throws(() => session.save(initial()), /Reload once storage is available/);
  const read = storage.getItem;
  storage.getItem = () => { throw new Error("Read denied"); };
  const deniedRead = openScore(() => storage);
  storage.getItem = read;
  assert.throws(() => deniedRead.save(initial()), /Reload once storage is available/);
  assert.equal(storage.getItem(scoreKey), raw);
  assert.deepEqual(storage.writes, []);
  assert.equal(openScore(() => storage).doc.root.children.length, 1);
});
