// One score drives the plotted flight, gain automation and stopped inspection.
export const DURATION = 2;
export const PEAK_GAIN = .25;
export const SAMPLE_MS = 10;
export const LOOKAHEAD = .02;
export const ScoreKind = Object.freeze({FLIGHT: "flight", GESTURE: "gesture"});
const last = DURATION * 1000 / SAMPLE_MS;
const boundedHeight = height => Math.max(0, Math.min(1, height));

export function flight(apex = 1000) {
    return {kind: ScoreKind.FLIGHT, apex};
}

export function gesture(height) {
    return {kind: ScoreKind.GESTURE, heights: Array.from({length: last + 1}, (_, i) =>
        i === 0 || i === last ? 0 : boundedHeight(height))};
}

export function knots(score) {
    if (score.kind === ScoreKind.FLIGHT) return [
        {time: 0, x: 0, height: 0},
        {time: score.apex / 1000, x: .35, height: 1},
        {time: DURATION, x: 1, height: 0},
    ];
    return score.heights.map((height, i) => ({time: i * SAMPLE_MS / 1000, x: i / last, height}));
}

export function sample(score, seconds) {
    const points = knots(score);
    const time = Math.max(0, Math.min(DURATION, seconds));
    const index = Math.max(1, points.findIndex(p => p.time >= time));
    const a = points[index - 1], b = points[index];
    if (time === b.time) return {height: b.height, x: b.x};
    const fraction = (time - a.time) / (b.time - a.time);
    return {height: a.height + fraction * (b.height - a.height),
        x: a.x + fraction * (b.x - a.x)};
}

// Replace only future samples; endpoints remain silent. The same future ramps
// are replaced on the live AudioParam, so capture and replay share score time.
export function recordHeight(score, elapsed, height) {
    const index = Math.max(1, Math.ceil((elapsed + LOOKAHEAD) * 1000 / SAMPLE_MS));
    if (index >= last) return null;
    score.heights.fill(boundedHeight(height), index, last);
    return index;
}

export function editHeight(score, milliseconds, height) {
    const index = Math.round(milliseconds / SAMPLE_MS);
    if (index > 0 && index < last) score.heights[index] = boundedHeight(height);
}

export function scheduleGain(param, score, start, from = 0) {
    const points = knots(score);
    param.cancelScheduledValues(start + points[from].time);
    if (from === 0) param.setValueAtTime(points[0].height * PEAK_GAIN, start);
    for (let i = Math.max(1, from); i < points.length; i++)
        param.linearRampToValueAtTime(points[i].height * PEAK_GAIN, start + points[i].time);
}
