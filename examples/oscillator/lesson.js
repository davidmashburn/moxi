const el = id => document.getElementById(id);
const fields = ["m", "k", "a", "t"];
let cases, committed, checkpoint, exploring = false, revision = 0;
const LessonStage = Object.freeze({Prediction: "prediction", Comparison: "comparison", Explanation: "explanation", Revealed: "revealed"});
let stage = LessonStage.Prediction, revealRevision = 0, playbackStep = 0, stepPending = false;
const Action = Object.freeze({Predict: "predict", SetTrial: "set-trial", Compare: "compare", Inspect: "inspect", Observe: "observe"});
// Authored semantic record, not DOM events or screen coordinates. Deliberately
// bounded to this model/version; this is a player, not a general-purpose recorder.
const recordedExplanation = Object.freeze({version: 1, model: "undamped-spring-v1", steps: Object.freeze([
    Object.freeze({action: Action.Predict, label: "Predict the period change", text: "Four times the mass should double the period."}),
    Object.freeze({action: Action.SetTrial, label: "Set a 4 kg trial", p: Object.freeze({m:"4", k:"16", a:"0.5", t:"0"})}),
    Object.freeze({action: Action.Compare, label: "Compare with the 1 kg reference; pause to explore"}),
    Object.freeze({action: Action.Inspect, label: "Inspect velocity at 0.5 s", time: "0.5", column: 1}),
    Object.freeze({action: Action.Observe, label: "Explain the comparison", text: "Quadrupling mass doubles the period; the 1 kg reference is unchanged."})
])});
for (const step of recordedExplanation.steps) {
    const item = document.createElement("li");
    item.textContent = step.label;
    el("recordedSteps").append(item);
}
const values = () => Object.fromEntries(fields.map(key => [key, el(key).value]));
const describe = p => `m = ${p.m} kg, k = ${p.k} N/m, A = ${p.a} m`;
const fmt = value => value.toFixed(3);
function message(text) { el("error").textContent = text; }
function requireText(id, text) {
    if (el(id).value.trim()) return true;
    message(text);
    el(id).focus();
    return false;
}
async function read(url) {
    const response = await fetch(url);
    const data = await response.json();
    if (!response.ok) throw new Error(data.error);
    return data;
}
el("lock").disabled = true;
read("/cases").then(data => {
    cases = data;
    const r = data.reference;
    el("ref").textContent = `Mass ${r.mass} kg · stiffness ${r.stiffness} N/m · amplitude ${r.amplitude} m`;
    el("lock").disabled = false;
    el("play").disabled = false;
}).catch(err => message(err.message));

el("prediction").oninput = () => message("");
function recordPrediction() {
    if (!requireText("prediction", "Enter a prediction before changing the spring.")) return;
    message("");
    el("prediction").readOnly = true;
    el("lock").disabled = true;
    el("lab").hidden = false;
    stage = LessonStage.Comparison;
    el("m").focus();
}
el("lock").onclick = recordPrediction;
async function compare(p = values(), focusSample = false) {
    const request = ++revision;
    try {
        const data = await read("/run?" + new URLSearchParams(p));
        if (request !== revision) return false;
        displayRun({p: {...p}, data});
        message("");
        if (focusSample) el("t").focus();
        return true;
    } catch (err) {
        if (request === revision) message(err.message + " Correct the trial and compare again.");
        return false;
    }
}
function displayRun(run) {
    committed = run;
    const {p, data} = run;
    el("chart").innerHTML = data.svg;
    el("scrub").value = p.t;
    el("bob").style.left = ((data.position + 1) * 50) + "%";
    el("summary").textContent = `Natural period T = 2π√(m/k). Reference ${fmt(data.reference)} s · trial ${fmt(data.period)} s (${fmt(data.period/data.reference)}×).`;
    el("point").textContent = `At ${p.t} s, displacement = ${fmt(data.position)} m and velocity = ${fmt(data.velocity)} m/s.`;
    el("basis").textContent = `Phase basis for (cos ωt, sin ωt): (${p.a}, 0) and (0, ${fmt(-p.a*data.omega)}), in displacement–velocity coordinates.` +
        (+p.a === 0 ? " Singular matrix: both basis vectors collapse. The spring stays at rest; no cycle can be measured." : "");
    showTerm();
    el("result").hidden = false;
    el("insert").disabled = !exploring;
}
function showTerm() {
    const {p, data} = committed;
    const phase = data.omega * Number(p.t);
    const displacement = el("column").selectedIndex === 0;
    // Show the two phase columns in physical coordinates. A unit of
    // displacement spans 180 px; a unit of velocity spans 2 px.
    el("displacementVector").setAttribute("x2", 30 + 180 * Number(p.a));
    el("velocityVector").setAttribute("y2", 22 + 2 * Number(p.a) * data.omega);
    el("displacementVector").setAttribute("stroke-width", displacement ? 5 : 2);
    el("velocityVector").setAttribute("stroke-width", displacement ? 2 : 5);
    el("term").textContent = displacement
        ? `Selected [A, 0] × cos(ωt): ${p.a} × ${fmt(Math.cos(phase))} gives x = ${fmt(data.position)} m at the probe.`
        : `Selected [0, −Aω] × sin(ωt): ${fmt(-p.a * data.omega)} × ${fmt(Math.sin(phase))} gives v = ${fmt(data.velocity)} m/s at the probe.`;
}
el("column").onchange = showTerm;
for (const key of fields) el(key).oninput = () => {
    revision++;
    el("insert").disabled = true;
    message("Edits pending. Compare or inspect to update the displayed run.");
};
el("compare").onclick = () => compare(values(), true);
el("scrub").oninput = () => {
    el("t").value = el("scrub").value;
    compare();
};
el("sample").onclick = () => compare();
let selection;
el("inspect").onclick = () => {
    selection = [el("note").selectionStart, el("note").selectionEnd, el("note").selectionDirection];
    el("definition").hidden = true;
    el("detail").showModal();
};
el("define").onclick = () => { el("definition").hidden = false; };
el("back").onclick = () => el("detail").close();
el("detail").onclose = () => {
    el("note").focus();
    el("note").setSelectionRange(...selection);
};
el("branch").onclick = () => {
    if (fields.some(key => values()[key] !== committed.p[key])) {
        message("Compare the pending values before checkpointing."); return;
    }
    saveCheckpoint();
};
function saveCheckpoint() {
    checkpoint = structuredClone({run: committed, note: el("note").value,
        noteSelection: [el("note").selectionStart, el("note").selectionEnd, el("note").selectionDirection],
        column: el("column").selectedIndex, stage, playbackStep,
        prediction: el("prediction").value, answer: el("answer").value,
        definitionHidden: el("definition").hidden,
        prompt: el("prompt").textContent, answerError: el("answerError").textContent,
        feedback: el("feedback").textContent, error: el("error").textContent});
    exploring = true;
    el("branch").disabled = true;
    el("restore").disabled = false;
    el("checkpoint").textContent = "Checkpoint saved. Change the working copy, then compare.";
    updatePlayback();
    el("m").focus();
}
el("restore").onclick = () => {
    // Restore the saved result synchronously. In-flight exploration requests must
    // never overwrite the restored run or reveal an answer after this boundary.
    revision++;
    revealRevision++;
    for (const key of fields) el(key).value = checkpoint.run.p[key];
    stage = checkpoint.stage;
    playbackStep = checkpoint.playbackStep;
    el("prediction").value = checkpoint.prediction;
    el("prediction").readOnly = stage !== LessonStage.Prediction;
    el("lock").disabled = stage !== LessonStage.Prediction;
    el("lab").hidden = stage === LessonStage.Prediction;
    el("transfer").hidden = stage !== LessonStage.Explanation && stage !== LessonStage.Revealed;
    el("answer").value = checkpoint.answer;
    el("definition").hidden = checkpoint.definitionHidden;
    el("answer").readOnly = el("reveal").disabled = stage === LessonStage.Revealed;
    for (const key of ["prompt", "answerError", "feedback"]) el(key).textContent = checkpoint[key];
    el("note").value = checkpoint.note;
    el("note").setSelectionRange(...checkpoint.noteSelection);
    el("column").selectedIndex = checkpoint.column;
    exploring = false;
    displayRun(structuredClone(checkpoint.run));
    el("branch").disabled = false;
    el("insert").disabled = el("restore").disabled = true;
    el("checkpoint").textContent = "Checkpoint restored.";
    message(checkpoint.error);
    updatePlayback();
    el("t").focus();
};
el("insert").onclick = () => {
    const {p, data} = committed;
    el("entry").textContent = [
        "Model: undamped spring, released from rest. T = 2π√(m/k).",
        "Prediction: " + el("prediction").value,
        `Plotted reference: ${describe(data.referenceParameters)}; T = ${fmt(data.reference)} s`,
        `Checkpoint: ${describe(checkpoint.run.p)}; T = ${fmt(checkpoint.run.data.period)} s (not plotted)`,
        `Exploration: ${describe(p)}; T = ${fmt(data.period)} s`,
        `T = ${fmt(data.period)} s; at ${p.t} s, x = ${fmt(data.position)} m.`,
        "Observation: " + el("note").value
    ].join("\n");
    el("snapshot").innerHTML = data.svg;
    el("report").hidden = false;
};
el("download").onclick = () => {
    const url = URL.createObjectURL(new Blob(["<!doctype html><meta charset=utf-8><title>Spring report</title><h1>Spring report</h1>", el("entry").outerHTML, el("snapshot").innerHTML], {type:"text/html"}));
    const anchor = document.createElement("a");
    anchor.href = url; anchor.download = "spring-report.html"; anchor.click();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
};
el("next").onclick = () => {
    const r = cases.transfer;
    el("prompt").textContent = describe({m:r.mass, k:r.stiffness, a:r.amplitude});
    el("transfer").hidden = false;
    if (stage !== LessonStage.Revealed) stage = LessonStage.Explanation;
    el("answer").focus();
};
el("reveal").onclick = async () => {
    if (!el("answer").value.trim()) {
        el("answerError").textContent = "Write an explanation before revealing the model.";
        el("answer").focus();
        return;
    }
    el("answerError").textContent = "";
    const r = cases.transfer;
    const request = ++revealRevision;
    try {
        const data = await read("/run?" + new URLSearchParams({m:r.mass, k:r.stiffness, a:r.amplitude, t:0}));
        if (request !== revealRevision) return;
        stage = LessonStage.Revealed;
        el("answer").readOnly = el("reveal").disabled = true;
        message("");
        el("feedback").textContent = `Model period ${fmt(data.period)} s. Mass and stiffness both doubled, preserving m/k. Amplitude changes displacement but leaves the ideal period unchanged.`;
    } catch (err) { if (request === revealRevision) message(err.message); }
};

function updatePlayback() {
    const complete = playbackStep === recordedExplanation.steps.length;
    el("step").disabled = !playbackStep || complete || exploring || stepPending;
    el("playStatus").textContent = playbackStep
        ? `Recording v${recordedExplanation.version} · ${playbackStep} of 5 steps. ` +
            (exploring ? "Exploring a copy. Restore checkpoint to resume the recorded path." : complete ? "Complete." : "Continue with the next recorded step.")
        : "Ready to play five recorded steps.";
    [...el("recordedSteps").children].forEach((item, i) => {
        if (i === playbackStep - 1) item.setAttribute("aria-current", "step");
        else item.removeAttribute("aria-current");
    });
}
el("play").onclick = () => {
    revision++;
    revealRevision++;
    committed = checkpoint = undefined;
    exploring = false;
    playbackStep = 0;
    stage = LessonStage.Prediction;
    for (const key of fields) el(key).value = recordedExplanation.steps[1].p[key];
    for (const key of ["note", "prediction", "answer"]) el(key).value = "";
    for (const key of ["prompt", "answerError", "feedback", "checkpoint"]) el(key).textContent = "";
    for (const key of ["lab", "result", "transfer"]) el(key).hidden = true;
    el("column").selectedIndex = 0;
    el("prediction").readOnly = el("answer").readOnly = el("reveal").disabled = false;
    el("lock").disabled = false;
    el("branch").disabled = false;
    el("restore").disabled = el("insert").disabled = true;
    playNext();
};
el("step").onclick = () => playNext();
async function playNext() {
    if (stepPending || exploring || playbackStep === recordedExplanation.steps.length) return;
    stepPending = true;
    el("play").disabled = true;
    updatePlayback();
    const step = recordedExplanation.steps[playbackStep];
    try {
        switch (step.action) {
            case Action.Predict:
                el("prediction").value = step.text;
                recordPrediction();
                break;
            case Action.SetTrial:
                for (const key of fields) el(key).value = step.p[key];
                break;
            case Action.Compare:
                for (const key of fields) el(key).value = recordedExplanation.steps[1].p[key];
                if (!await compare(recordedExplanation.steps[1].p)) return;
                break;
            case Action.Inspect:
                for (const key of fields) el(key).value = recordedExplanation.steps[1].p[key];
                el("t").value = step.time;
                if (!await compare()) return;
                el("column").selectedIndex = step.column;
                showTerm();
                break;
            case Action.Observe:
                el("note").value = step.text;
                break;
            default: throw new Error("Unsupported recorded action.");
        }
        playbackStep++;
        if (playbackStep === 3) saveCheckpoint();
    } finally {
        stepPending = false;
        el("play").disabled = false;
        updatePlayback();
    }
}
