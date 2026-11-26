import assert from "node:assert/strict";
import test from "node:test";
import {Cursor, TARGET, MOVE} from "./interaction.mjs";

test("preview, cancel, coalesced commit and one undo", () => {
  const cursor = new Cursor();
  for (const value of [0, 32, 100]) cursor.preview(value);
  assert.deepEqual([cursor.position, cursor.revision, cursor.history.length], [25, 0, 0]);
  cursor.cancel();
  assert.equal(cursor.draft, null);
  for (const value of [50, 60, 70]) cursor.preview(value);
  const saved = cursor.commit();
  assert.deepEqual(JSON.parse(saved), {version:1,operation:MOVE,target:TARGET,revision:0,from:25,to:70});
  assert.equal(cursor.history.length, 1);
  cursor.undo();
  assert.deepEqual([cursor.position, cursor.revision, cursor.history.length], [25, 2, 0]);
  assert.throws(() => cursor.apply(saved), /Stale/);
  assert.throws(() => cursor.undo(), /No committed/);
  const copy = new Cursor();
  copy.apply(saved);
  assert.deepEqual([copy.position, copy.revision, copy.history.length], [70, 1, 1]);
});

test("invalid preview and malformed or incompatible records preserve state", () => {
  const cursor = new Cursor();
  cursor.preview(50);
  const command = JSON.parse(cursor.commit());
  cursor.preview(52);
  const before = JSON.stringify(cursor);
  for (const value of [-1, 0.5, 101, NaN, "50"]) assert.throws(() => cursor.preview(value));
  for (const patch of [{version:2},{operation:"delete"},{target:"other"},{to:null},{revision:99}])
    assert.throws(() => cursor.apply(JSON.stringify({...command, ...patch})));
  assert.throws(() => cursor.apply("{"));
  assert.equal(JSON.stringify(cursor), before);
});
