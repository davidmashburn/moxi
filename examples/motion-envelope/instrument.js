const $ = id => document.getElementById(id);
const duration = 2;
const peakGain = .25;
const initial = 1000;
let authored = initial, draft = initial, revision = 0, checkpoint = null;
let audio, voice, generation = 0;

function chart(id, color) {
    const svg = $(id).querySelector("svg");
    svg.setAttribute("role", "img");
    svg.setAttribute("aria-label", $(id).querySelector("h2").textContent);
    const line = svg.querySelector("polyline[data-mark=line]");
    const knots = Array.from(line.points, p => ({x: p.x, y: p.y}));
    const marker = document.createElementNS(svg.namespaceURI, "circle");
    marker.setAttribute("r", 7);
    marker.setAttribute("fill", color);
    svg.append(marker);
    return {line, knots, marker};
}
const path = chart("path", "#086b65");
const gain = chart("gain", "#9d421a");
function cursor(seconds) {
    const apex = draft / 1000;
    const segment = seconds <= apex ? 0 : 1;
    const fraction = segment ? (seconds - apex) / (duration - apex) : seconds / apex;
    for (const {knots, marker} of [path, gain]) {
        const a = knots[segment], b = knots[segment + 1];
        marker.setAttribute("cx", a.x + fraction * (b.x - a.x));
        marker.setAttribute("cy", a.y + fraction * (b.y - a.y));
    }
}
function inspect() {
    const ms = Number($("seek").value);
    $("position").textContent = ms + " ms";
    cursor(ms / 1000);
}
$("seek").oninput = () => { stop(); inspect(); $("message").textContent = "Inspecting stopped phrase."; };
function render() {
    const [a, b, c] = gain.knots;
    b.x = a.x + draft / 1000 / duration * (c.x - a.x);
    gain.line.points.getItem(1).x = b.x;
    $("beat").value = draft;
    $("beat").setAttribute("aria-valuetext", draft + " milliseconds");
    $("value").textContent = draft + " ms";
    $("score").textContent = "Revision " + revision + " · Authored apex " + authored + " ms"
        + (checkpoint === null ? "" : " · Checkpoint " + checkpoint.apex + " ms");
    $("commit").disabled = $("discard").disabled = authored === draft;
    $("restore").disabled = checkpoint === null;
    inspect();
}
function stop() {
    generation++;
    if (voice) { voice.stop(); voice.disconnect(); voice = null; }
}
function edit(value, message) {
    stop();
    draft = value;
    render();
    $("message").textContent = message;
}
const beat = $("beat");
beat.oninput = () => edit(Number(beat.value), "Previewing the shared apex.");
$("commit").onclick = () => {
    authored = draft;
    revision++;
    edit(authored, "Timing committed.");
};
function discard() { edit(authored, "Authored timing restored."); }
$("discard").onclick = discard;
$("save").onclick = () => {
    stop();
    checkpoint = {apex: authored, position: $("seek").value};
    render();
    $("message").textContent = "Checkpoint set from the authored phrase.";
};
$("restore").onclick = () => {
    if (authored !== checkpoint.apex) revision++;
    authored = checkpoint.apex;
    $("seek").value = checkpoint.position;
    edit(authored, "Checkpoint restored.");
};
// Suppress subsequent native slider input from the same cancelled gesture.
let held = false, cancelled = false;
beat.addEventListener("pointerdown", () => { held = true; cancelled = false; });
window.addEventListener("pointerup", () => { held = false; });
beat.addEventListener("pointercancel", () => { held = false; discard(); });
beat.addEventListener("input", event => {
    if (cancelled) { beat.value = draft; event.stopImmediatePropagation(); }
}, true);
beat.addEventListener("keydown", () => { cancelled = false; });
document.addEventListener("keydown", event => {
    if (event.key === "Escape") { cancelled = held; discard(); }
});

// The offline measurement uses this same automation and source lifetime.
function schedule(ctx, source, start, apex) {
    const envelope = ctx.createGain();
    envelope.gain.setValueAtTime(0, start);
    envelope.gain.linearRampToValueAtTime(peakGain, start + apex);
    envelope.gain.linearRampToValueAtTime(0, start + duration);
    source.connect(envelope).connect(ctx.destination);
    source.onended = () => { source.disconnect(); envelope.disconnect(); };
    source.start(start);
    source.stop(start + duration);
}
$("play").onclick = async () => {
    stop();
    const token = generation;
    try {
        audio ??= new AudioContext();
        await audio.resume();
        if (token !== generation) return;
        voice = audio.createOscillator();
        voice.frequency.value = 220;
        const start = audio.currentTime + .05;
        schedule(audio, voice, start, draft / 1000);
        $("message").textContent = "Playing · motion follows the audio clock.";
        const frame = () => {
            if (token !== generation) return;
            const seconds = Math.max(0, audio.currentTime - start);
            cursor(Math.min(seconds, duration));
            $("seek").value = Math.round(Math.min(seconds, duration) * 1000);
            $("position").textContent = Math.round(Math.min(seconds, duration) * 1000) + " ms";
            if (seconds < duration) requestAnimationFrame(frame);
            else { voice = null; $("message").textContent = "Playback complete."; }
        };
        frame();
    } catch (error) {
        if (token === generation) edit(authored, "Playback unavailable · " + error.message);
    }
};
render();

// A constant unit signal exposes the actual rendered gain samples to the probe.
export async function measure(rate, apices) {
    const lead = .125, stride = duration + .125;
    const ctx = new OfflineAudioContext(1, Math.ceil((lead + apices.length * stride) * rate), rate);
    apices.forEach((ms, i) => schedule(ctx, ctx.createConstantSource(), lead + i * stride, ms / 1000));
    const samples = (await ctx.startRendering()).getChannelData(0);
    return apices.map((ms, i) => {
        const start = Math.round((lead + i * stride) * rate);
        const planned = (lead + i * stride + ms / 1000) * rate;
        let peak = start;
        for (let j = start; j < start + duration * rate; j++)
            if (samples[j] > samples[peak]) peak = j;
        return {ms, planned, peak, errorSamples: peak - planned, amplitude: samples[peak],
            landing: samples[Math.round((lead + i * stride + duration) * rate)]};
    });
}
if (location.hash === "#measure") window.measurePhrase = measure;
