import assert from "node:assert/strict";
import test from "node:test";
import {DURATION, PEAK_GAIN, ScoreKind, flight, gesture, knots, sample, recordHeight, editHeight, scheduleGain} from "./gesture.mjs";

test("capture is bounded in time, count and height, with silent endpoints", () => {
    const score = gesture(.3);
    assert.equal(score.kind, ScoreKind.GESTURE);
    for (let ms = -50; ms < 2050; ms++) recordHeight(score, ms / 1000, ms % 2 ? -2 : 3);
    assert.equal(score.heights.length, 201);
    assert.equal(score.heights[0], 0);
    assert.equal(score.heights.at(-1), 0);
    assert(score.heights.every(h => h >= 0 && h <= 1));
    assert.equal(knots(score).at(-1).time, DURATION);
    const saved = structuredClone(score);
    assert.equal(recordHeight(score, 2.1, .5), null);
    assert.deepEqual(score, saved);
});

test("a performed change affects future audio-clock samples, preserving the prefix", () => {
    const score = gesture(.3);
    const before = structuredClone(score);
    assert.equal(recordHeight(score, .503, .8), 53);
    assert.deepEqual(score.heights.slice(0, 53), before.heights.slice(0, 53));
    assert.equal(sample(score, .52).height, .3);
    assert.equal(sample(score, .525).height.toFixed(6), "0.550000");
    assert.equal(sample(score, .53).height, .8);
    assert.equal(sample(score, 3).height, 0);
    assert.equal(sample(score, -1).height, 0);
});

test("stopped editing changes one shared sample without moving or unpinning endpoints", () => {
    const score = gesture(.3);
    editHeight(score, 750, .9);
    editHeight(score, 0, .7);
    editHeight(score, 2000, .7);
    assert(Math.abs(sample(score, .75).height - .9) < 1e-12);
    assert.equal(sample(score, .74).height, .3);
    assert.equal(sample(score, .76).height, .3);
    assert.equal(score.heights[0], 0);
    assert.equal(score.heights.at(-1), 0);
});

test("the same captured curve produces identical gain automation at any absolute start", () => {
    const score = gesture(.2);
    recordHeight(score, .4, .9);
    recordHeight(score, 1.2, .1);
    function events(start, from = 0) {
        const calls = [];
        scheduleGain({cancelScheduledValues: t => calls.push(["cancel", t - start]),
            setValueAtTime: (v, t) => calls.push(["set", v, +(t - start).toFixed(8)]),
            linearRampToValueAtTime: (v, t) => calls.push(["ramp", v, +(t - start).toFixed(8)])}, score, start, from);
        return calls;
    }
    assert.deepEqual(events(0), events(100));
    const ramps = events(0).slice(2);
    assert.equal(ramps.length, 200);
    ramps.forEach(([, value, time]) => {
        assert(Math.abs(value - sample(score, time).height * PEAK_GAIN) < 1e-10);
    });
    assert.equal(events(0, 42).length, 160);
    assert.equal(events(0, 42).at(-1)[1], 0);
});

test("the original editable flight keeps its three knots and shared apex", () => {
    const score = flight(1370);
    assert.equal(score.kind, ScoreKind.FLIGHT);
    assert.equal(knots(score).length, 3);
    assert.deepEqual(sample(score, 1.37), {height: 1, x: .35});
    assert.deepEqual(sample(score, 2), {height: 0, x: 1});
});
