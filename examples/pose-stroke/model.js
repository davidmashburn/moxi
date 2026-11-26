// Synthetic normalized feature samples. No tracker, media, or device input.
const Mode = Object.freeze({DIRECT: "Direct", POSE: "Interpolated"});
const State = Object.freeze({FREE: "Clutch released", HOLD: "Confidence hold",
  ANCHOR: "Anchored", ACTIVE: "Engaged"});
const threshold = 0.7;
const poses = [
  [0.25, 0.25, 1, false], [0.25, 0.25, 1, true],
  [0.50, 0.50, 1, true], [0.75, 0.50, 1, true],
  [0.10, 0.90, 0.3, true], [0.90, 0.10, 0.2, true],
  [0.90, 0.10, 0.9, true], [0.80, 0.20, 1, true],
  [0.10, 0.70, 1, false], [0.10, 0.70, 1, true],
  [0.30, 0.70, 1, true],
].map(([curl, spread, confidence, clutch]) => ({curl, spread, confidence, clutch}));

function mappedWidth(mode, {curl, spread}) {
  const closed = 4 + 24 * curl;
  if (mode === Mode.DIRECT) return closed;
  if (mode !== Mode.POSE) throw new Error("Unknown mapping");
  const open = 16 - 4 * curl;
  return closed * (1 - spread) + open * spread;
}

class Stroke {
  constructor(mode) {
    this.mode = mode;
    this.width = 12;
    this.previous = null;
    this.state = State.FREE;
  }
  accept(sample) {
    if (!sample.clutch || sample.confidence < threshold) {
      this.previous = null;
      this.state = sample.clutch ? State.HOLD : State.FREE;
      return;
    }
    const target = mappedWidth(this.mode, sample);
    this.state = this.previous === null ? State.ANCHOR : State.ACTIVE;
    if (this.previous !== null) {
      this.width = Math.max(4, Math.min(28, this.width + (target - this.previous)));
    }
    this.previous = target;
  }
}
if (typeof module !== "undefined") module.exports = {Mode, State, poses, mappedWidth, Stroke};
