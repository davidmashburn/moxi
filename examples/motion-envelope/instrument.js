import {DURATION, ScoreKind, flight, gesture, knots, sample, recordHeight, editHeight, scheduleGain} from "./gesture.mjs";

const $ = id => document.getElementById(id);
const Activity = Object.freeze({STOPPED: "stopped", PLAYING: "playing", RECORDING: "recording",
    STARTING_PLAYBACK: "starting-playback", STARTING_RECORDING: "starting-recording"});
let authored = flight(), draft = flight(), revision = 0, checkpoint = null;
let audio, voice, generation = 0, activity = Activity.STOPPED, session = null, coefficient = .5;
const copy = score => structuredClone(score);
const isRecording = () => activity === Activity.RECORDING || activity === Activity.STARTING_RECORDING;
const isStopped = () => activity === Activity.STOPPED;

function chart(id, color) {
    const svg = $(id).querySelector("svg");
    svg.setAttribute("role", "img");
    svg.setAttribute("aria-label", $(id).querySelector("h2").textContent);
    const line = svg.querySelector("polyline[data-mark=line]");
    const [a, b, c] = Array.from(line.points, p => ({x: p.x, y: p.y}));
    const marker = document.createElementNS(svg.namespaceURI, "circle");
    marker.setAttribute("r", 7);
    marker.setAttribute("fill", color);
    svg.append(marker);
    return {line, marker, a, b, c};
}
const path = chart("path", "#086b65");
const gain = chart("gain", "#9d421a");
function place(chart, x, height) {
    return [chart.a.x + x * (chart.c.x - chart.a.x),
        chart.a.y + height * (chart.b.y - chart.a.y)];
}
function curve() {
    const points = knots(draft);
    for (const chart of [path, gain]) {
        chart.line.setAttribute("points", points.map(p =>
            place(chart, chart === path ? p.x : p.time / DURATION, p.height).join(",")).join(" "));
    }
}
function cursor(seconds) {
    const pose = sample(draft, seconds);
    for (const chart of [path, gain]) {
        const [x, y] = place(chart, chart === path ? pose.x : seconds / DURATION, pose.height);
        chart.marker.setAttribute("cx", x);
        chart.marker.setAttribute("cy", y);
    }
}
function inspect() {
    const ms = Number($("seek").value);
    $("position").textContent = ms + " ms";
    cursor(ms / 1000);
    $("set-height").disabled = !isStopped() || draft.kind !== ScoreKind.GESTURE || ms === 0 || ms === 2000;
}
function heightValue() {
    const value = coefficient;
    $("height").value = value;
    $("height-value").textContent = value.toFixed(2);
    $("height").setAttribute("aria-valuetext", value.toFixed(2) + " of full height");
    return value;
}
function describe(score) {
    return score.kind === ScoreKind.FLIGHT ? "apex " + score.apex + " ms" : "recorded gesture · 201 samples";
}
function render() {
    const recorded = draft.kind === ScoreKind.GESTURE;
    if (!recorded) $("beat").value = draft.apex;
    $("beat").disabled = !isStopped() || recorded;
    $("beat").setAttribute("aria-valuetext", $("beat").value + " milliseconds");
    $("value").textContent = recorded ? "recorded curve" : draft.apex + " ms";
    $("score").textContent = "Revision " + revision + " · Authored " + describe(authored)
        + (checkpoint === null ? "" : " · Checkpoint " + describe(checkpoint.score));
    const unchanged = JSON.stringify(authored) === JSON.stringify(draft);
    $("commit").disabled = $("discard").disabled = !isStopped() || unchanged;
    $("restore").disabled = !isStopped() || checkpoint === null;
    $("save").disabled = $("seek").disabled = $("play").disabled = $("record").disabled = !isStopped();
    $("flight").disabled = !isStopped() || !recorded;
    $("height").disabled = !isStopped() && !isRecording();
    $("cancel").disabled = isStopped();
    $("cancel").textContent = isRecording() ? "Cancel recording" : "Stop playback";
    $("take").textContent = isRecording() ? "Recording draft · release the slider to hold a height; capture ends at 2 seconds."
        : recorded ? "Recorded curve · seek, set a height, then commit. Endpoints stay at zero."
        : "Record a height gesture, or edit the flight’s apex above.";
    curve();
    inspect();
    heightValue();
}
function stop() {
    generation++;
    if (voice) { voice.source.stop(); voice.source.disconnect(); voice.envelope.disconnect(); voice = null; }
    activity = Activity.STOPPED;
}
function cancel(message) {
    const recording = isRecording();
    cancelBeat();
    cancelHeight();
    stop();
    if (session) {
        draft = session.score;
        $("seek").value = session.position;
        coefficient = session.height;
        session = null;
    }
    render();
    $("message").textContent = message ?? (recording ? "Recording cancelled · previous curve restored." : "Playback stopped · inspection restored.");
}
function edit(score, message) {
    stop();
    session = null;
    draft = score;
    render();
    $("message").textContent = message;
}
$("seek").oninput = () => {
    stop();
    session = null;
    inspect();
    if (draft.kind === ScoreKind.GESTURE) coefficient = sample(draft, Number($("seek").value) / 1000).height;
    render();
    $("message").textContent = "Inspecting stopped phrase.";
};
const beat = $("beat");
beat.oninput = () => edit(flight(Number(beat.value)), "Previewing the shared apex.");
$("commit").onclick = () => {
    authored = copy(draft);
    revision++;
    edit(copy(authored), "Phrase committed.");
};
function discard() { edit(copy(authored), "Authored phrase restored."); }
$("discard").onclick = discard;
$("save").onclick = () => {
    checkpoint = {score: copy(authored), position: $("seek").value};
    render();
    $("message").textContent = "Checkpoint set from the authored phrase.";
};
$("restore").onclick = () => {
    if (JSON.stringify(authored) !== JSON.stringify(checkpoint.score)) revision++;
    authored = copy(checkpoint.score);
    $("seek").value = checkpoint.position;
    edit(copy(authored), "Checkpoint restored.");
};
$("flight").onclick = () => edit(flight(), "Flight curve preview · commit to replace the gesture.");
$("set-height").onclick = () => {
    editHeight(draft, Number($("seek").value), heightValue());
    render();
    $("message").textContent = "Stopped height edit · motion and gain share this sample.";
};

// Suppress native input that arrives after Escape or a lost pointer capture.
function cancellableSlider(slider, onCancel) {
    let held = false, cancelled = false;
    slider.addEventListener("pointerdown", () => { held = true; cancelled = false; });
    window.addEventListener("pointerup", () => { held = false; });
    slider.addEventListener("pointercancel", () => { cancelled = true; held = false; onCancel(); });
    slider.addEventListener("input", event => {
        if (cancelled) { render(); event.stopImmediatePropagation(); }
    }, true);
    slider.addEventListener("keydown", event => { if (event.key !== "Escape") cancelled = false; });
    return () => { cancelled ||= held; };
}
const cancelBeat = cancellableSlider(beat, discard);
const cancelHeight = cancellableSlider($("height"), () => { if (isRecording()) cancel(); });
document.addEventListener("keydown", event => {
    if (event.key !== "Escape") return;
    cancelBeat();
    cancelHeight();
    if (isStopped()) discard();
    else cancel();
});
$("cancel").onclick = () => cancel();
window.addEventListener("blur", () => { if (isRecording()) cancel("Recording cancelled · window lost focus."); });
document.addEventListener("visibilitychange", () => {
    if (document.hidden && !isStopped()) cancel("Performance cancelled · page hidden.");
});
$("height").oninput = () => {
    coefficient = Number($("height").value);
    const value = heightValue();
    if (activity !== Activity.RECORDING) return;
    const index = recordHeight(draft, audio.currentTime - session.start, value);
    if (index !== null) {
        scheduleGain(voice.envelope.gain, draft, session.start, index);
        curve();
    }
};

function schedule(ctx, source, start, score) {
    const envelope = ctx.createGain();
    scheduleGain(envelope.gain, score, start);
    source.connect(envelope).connect(ctx.destination);
    source.onended = () => { source.disconnect(); envelope.disconnect(); };
    source.start(start);
    source.stop(start + DURATION);
    return {source, envelope};
}
async function perform(recording) {
    const before = {score: copy(draft), position: $("seek").value, height: coefficient};
    stop();
    session = before;
    const token = generation;
    activity = recording ? Activity.STARTING_RECORDING : Activity.STARTING_PLAYBACK;
    render();
    $("message").textContent = "Starting audio…";
    try {
        audio ??= new AudioContext();
        await audio.resume();
        if (token !== generation) return;
        if (recording) draft = gesture(heightValue());
        session.start = audio.currentTime + .05;
        const source = audio.createOscillator();
        source.frequency.value = 220;
        voice = schedule(audio, source, session.start, draft);
        activity = recording ? Activity.RECORDING : Activity.PLAYING;
        render();
        $("message").textContent = recording ? "Recording · move Height for two seconds." : "Playing · motion follows the audio clock.";
        const frame = () => {
            if (token !== generation) return;
            const seconds = Math.max(0, audio.currentTime - session.start);
            cursor(Math.min(seconds, DURATION));
            $("seek").value = Math.round(Math.min(seconds, DURATION) * 1000);
            $("position").textContent = Math.round(Math.min(seconds, DURATION) * 1000) + " ms";
            if (seconds < DURATION) requestAnimationFrame(frame);
            else {
                stop();
                session = null;
                render();
                $("message").textContent = recording ? "Gesture captured · inspect, edit or commit the draft." : "Playback complete.";
            }
        };
        frame();
    } catch (error) {
        if (token === generation) cancel("Audio unavailable · " + error.message + " · previous curve restored.");
    }
}
$("play").onclick = () => perform(false);
$("record").onclick = () => perform(true);
render();

// A constant unit signal exposes the actual rendered gain samples to the probe.
export async function measure(rate, apices) {
    const lead = .125, stride = DURATION + .125;
    const ctx = new OfflineAudioContext(1, Math.ceil((lead + apices.length * stride) * rate), rate);
    apices.forEach((ms, i) => schedule(ctx, ctx.createConstantSource(), lead + i * stride, flight(ms)));
    const samples = (await ctx.startRendering()).getChannelData(0);
    return apices.map((ms, i) => {
        const start = Math.round((lead + i * stride) * rate);
        const planned = (lead + i * stride + ms / 1000) * rate;
        let peak = start;
        for (let j = start; j < start + DURATION * rate; j++)
            if (samples[j] > samples[peak]) peak = j;
        return {ms, planned, peak, errorSamples: peak - planned, amplitude: samples[peak],
            landing: samples[Math.round((lead + i * stride + DURATION) * rate)]};
    });
}
if (location.hash === "#measure") window.measurePhrase = measure;
if (location.hash === "#measure") window.measureGesture = async rate => {
    const ctx = new OfflineAudioContext(1, Math.ceil((DURATION + .25) * rate), rate);
    schedule(ctx, ctx.createConstantSource(), .125, copy(draft));
    return Array.from((await ctx.startRendering()).getChannelData(0));
};
