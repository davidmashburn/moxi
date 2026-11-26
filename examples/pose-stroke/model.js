// Synthetic normalized feature samples. No tracker, media, or device input.
const Mode = Object.freeze({DIRECT: "Direct", POSE: "Interpolated"});
const State = Object.freeze({FREE: "Clutch released", HOLD: "Confidence hold",
  ANCHOR: "Anchored", ACTIVE: "Engaged"});
const threshold = 0.7;
const CalibrationKey = Object.freeze({RELAXED: "relaxed", CURLED: "curled",
  SPREAD: "spread", SPREAD_CURLED: "spreadCurled", RESPONSE: "response"});
const defaultCalibration = Object.freeze({[CalibrationKey.RELAXED]: 4,
  [CalibrationKey.CURLED]: 28, [CalibrationKey.SPREAD]: 16,
  [CalibrationKey.SPREAD_CURLED]: 12, [CalibrationKey.RESPONSE]: 1});
const MAPPING_VERSION = 1;
const SAVED_MAPPING_KEY = "moxi.pose-stroke.mapping.v1";
function calibration(value) {
  const keys = Object.values(CalibrationKey);
  if (!value || typeof value !== "object" || Object.keys(value).length !== keys.length
      || keys.some(key => !Object.hasOwn(value, key))) throw new Error("Invalid calibration fields");
  for (const key of keys) {
    const min = key === CalibrationKey.RESPONSE ? 0.25 : 4;
    const max = key === CalibrationKey.RESPONSE ? 4 : 28;
    if (typeof value[key] !== "number" || !Number.isFinite(value[key]) || value[key] < min || value[key] > max)
      throw new Error(key + " must be a finite number in [" + min + ", " + max + "]");
  }
  return Object.freeze({...value});
}
function savedMapping(value) {
  return JSON.stringify({version: MAPPING_VERSION, calibration: calibration(value)});
}
function reopenedMapping(text) {
  const value = JSON.parse(text);
  if (!value || value.version !== MAPPING_VERSION || Object.keys(value).sort().join() !== "calibration,version")
    throw new Error("Unsupported saved mapping");
  return calibration(value.calibration);
}
const poses = [
  [0.25, 0.25, 1, false], [0.25, 0.25, 1, true],
  [0.50, 0.50, 1, true], [0.75, 0.50, 1, true],
  [0.10, 0.90, 0.3, true], [0.90, 0.10, 0.2, true],
  [0.90, 0.10, 0.9, true], [0.80, 0.20, 1, true],
  [0.10, 0.70, 1, false], [0.10, 0.70, 1, true],
  [0.30, 0.70, 1, true],
].map(([curl, spread, confidence, clutch]) => ({curl, spread, confidence, clutch}));

function mappedWidth(mode, {curl, spread}, mapping = defaultCalibration) {
  const curved = curl ** mapping[CalibrationKey.RESPONSE];
  const closed = mapping[CalibrationKey.RELAXED] * (1 - curved) + mapping[CalibrationKey.CURLED] * curved;
  if (mode === Mode.DIRECT) return closed;
  if (mode !== Mode.POSE) throw new Error("Unknown mapping");
  const open = mapping[CalibrationKey.SPREAD] * (1 - curved) + mapping[CalibrationKey.SPREAD_CURLED] * curved;
  return closed * (1 - spread) + open * spread;
}

class Stroke {
  constructor(mode, mapping = defaultCalibration) {
    if (!Object.values(Mode).includes(mode)) throw new Error("Unknown mapping");
    this.mode = mode;
    this.mapping = calibration(mapping);
    this.width = 12;
    this.previous = null;
    this.state = State.FREE;
  }
  copy() {
    return Object.assign(new Stroke(this.mode, this.mapping), this);
  }
  recalibrate(mapping) {
    this.mapping = calibration(mapping);
    this.previous = null;
  }
  accept(sample) {
    if (!sample.clutch || sample.confidence < threshold) {
      this.previous = null;
      this.state = sample.clutch ? State.HOLD : State.FREE;
      return;
    }
    const target = mappedWidth(this.mode, sample, this.mapping);
    this.state = this.previous === null ? State.ANCHOR : State.ACTIVE;
    if (this.previous !== null) {
      this.width = Math.max(4, Math.min(28, this.width + (target - this.previous)));
    }
    this.previous = target;
  }
}
if (typeof module !== "undefined") module.exports = {Mode, State, poses, mappedWidth, Stroke,
  CalibrationKey, defaultCalibration, calibration, savedMapping, reopenedMapping};
