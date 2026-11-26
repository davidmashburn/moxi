const assert = require("node:assert/strict");
const {Mode, State, poses, mappedWidth, Stroke} = require("./model.js");
const close = (a,b) => assert.ok(Math.abs(a-b) < 1e-9, a + " != " + b);
const states = [State.FREE, State.ANCHOR, State.ACTIVE, State.ACTIVE, State.HOLD,
  State.HOLD, State.ANCHOR, State.ACTIVE, State.FREE, State.ANCHOR, State.ACTIVE];
for (const mode of Object.values(Mode)) {
  const direct = mode === Mode.DIRECT;
  for (const [curl,spread,width] of [[0,0,4],[1,0,28],[0,1,direct?4:16],[1,1,direct?28:12]]) {
    close(mappedWidth(mode,{curl,spread}),width);
  }
  function replay(samples) {
    const brush = new Stroke(mode);
    return samples.map((sample,i) => {
      brush.accept(sample);
      assert.equal(brush.state, states[i]);
      return brush.width;
    });
  }
  const baseline = replay(poses);
  close(baseline[2],direct ? 18 : 15.75);
  close(baseline[3],direct ? 24 : 18.25);
  for (const i of [1,4,5,6,8,9]) assert.equal(baseline[i],baseline[i-1]);
  for (const i of [7,10]) assert.notEqual(baseline[i],baseline[i-1]);
  let seed = 15;
  function jitter(x) {
    seed = (Math.imul(seed,1664525) + 1013904223) >>> 0;
    return x + 0.02 * (seed / 2**32 - 0.5);
  }
  let squared = 0, worst = 0;
  for (let trial=0;trial<100;trial++) {
    assert.deepEqual(replay(poses),baseline);
    const outputs = replay(poses.map(s => ({...s,curl:jitter(s.curl),spread:jitter(s.spread)})));
    outputs.forEach((v,i) => {
      const error = v-baseline[i];
      squared += error**2;
      worst = Math.max(worst,Math.abs(error));
    });
  }
  console.log(mode + " · 100 exact replays identical · seeded ±0.01 jitter, 1100 samples · RMS "
    + Math.sqrt(squared/(100*poses.length)).toFixed(4) + " px · max " + worst.toFixed(4) + " px");
}
