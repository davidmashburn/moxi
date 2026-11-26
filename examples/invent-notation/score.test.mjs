import test from "node:test";
import assert from "node:assert/strict";
import {Kind, Order, initial, append, edit, revise, selected, validate, schedule, angleAt} from "./score.mjs";

function score() {
  let d = append(append(initial(), Kind.motion), Kind.group);
  d = edit(d, x => { x.selected = 3; });
  d = append(append(d, Kind.motion), Kind.motion);
  return edit(d, x => { selected(x).children[1].beats = 3; });
}
test("sequences concatenate and a group spans its longest motion", () => {
  assert.deepEqual(schedule(score()), {duration:8, events:[
    {id:2,start:0,end:2}, {id:4,start:2,end:4}, {id:5,start:2,end:8}]});
});
test("revision reinterprets every instance and preserves slot identity across reopen", () => {
  const d = score();
  const next = revise(d, {...d.schema, beat:3, order:Order.reverse});
  assert.deepEqual(schedule(next), {duration:12, events:[
    {id:4,start:0,end:3}, {id:5,start:0,end:9}, {id:2,start:9,end:12}]});
  assert.equal(next.revision, 2);
  assert.equal(selected(next).id, 3);
  assert.deepEqual(next.root, d.root);
  assert.deepEqual(validate(JSON.parse(JSON.stringify(next))), next);
});
test("incompatible group, invalid timing, duplicate names and unknown types fail atomically", () => {
  const d = score(), before = JSON.stringify(d);
  for (const patch of [{capacity:1},{beat:0},{beat:1.5},{names:{...d.schema.names,group:"Sweep"}}]) {
    assert.throws(() => revise(d, {...d.schema,...patch}));
  }
  assert.throws(() => append(d, "unknown"));
  assert.equal(JSON.stringify(d), before);
});
test("moving joint sums overlapping motions and leaves the original sketch intact", () => {
  const d = score(), arm = edit(d, x => { x.sketch.arm = 36; });
  assert.deepEqual(arm.sketch, {...d.sketch,arm:36});
  assert.equal(d.sketch.arm, null);
  const {events} = schedule(arm);
  assert.equal(angleAt(events,1),60);
  assert.ok(Math.abs(angleAt(events,3)-90)<1e-8);
});
test("leaf slots and capacity enforce the insertion grammar", () => {
  const group = score();
  const full = revise(group,{...group.schema,capacity:2});
  assert.throws(() => append(full, Kind.motion), /Capacity/);
  assert.throws(() => append(edit(group, x => { x.selected=2; }),Kind.sequence), /Select a sequence/);
});
