const el = id => document.getElementById(id);
const fields = ["m", "k", "a", "t"];
let cases, committed, checkpoint, exploring = false, revision = 0;
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
}).catch(err => message(err.message));

el("prediction").oninput = () => message("");
el("lock").onclick = () => {
    if (!requireText("prediction", "Enter a prediction before changing the spring.")) return;
    message("");
    el("prediction").readOnly = true;
    el("lock").disabled = true;
    el("lab").hidden = false;
    el("m").focus();
};
async function compare(p = values(), focusSample = false) {
    const request = ++revision;
    try {
        const data = await read("/run?" + new URLSearchParams(p));
        if (request !== revision) return false;
        committed = {p, data};
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
        message("");
        if (focusSample) el("t").focus();
        return true;
    } catch (err) {
        if (request === revision) message(err.message + " Correct the trial and compare again.");
        return false;
    }
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
    selection = [el("note").selectionStart, el("note").selectionEnd];
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
    checkpoint = {p: {...committed.p}, note: el("note").value, column: el("column").selectedIndex};
    exploring = true;
    el("branch").disabled = true;
    el("restore").disabled = false;
    el("checkpoint").textContent = "Checkpoint saved. Change the working copy, then compare.";
    el("m").focus();
};
el("restore").onclick = async () => {
    for (const key of fields) el(key).value = checkpoint.p[key];
    if (!await compare(checkpoint.p)) return;
    el("note").value = checkpoint.note;
    el("column").selectedIndex = checkpoint.column;
    showTerm();
    exploring = false;
    el("branch").disabled = false;
    el("insert").disabled = el("restore").disabled = true;
    el("checkpoint").textContent = "Checkpoint restored.";
    el("t").focus();
};
el("insert").onclick = () => {
    const {p, data} = committed;
    el("entry").textContent = [
        "Model: undamped spring, released from rest. T = 2π√(m/k).",
        "Prediction: " + el("prediction").value,
        "Checkpoint: " + describe(checkpoint.p),
        "Exploration: " + describe(p),
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
    try {
        const data = await read("/run?" + new URLSearchParams({m:r.mass, k:r.stiffness, a:r.amplitude, t:0}));
        el("answer").readOnly = el("reveal").disabled = true;
        message("");
        el("feedback").textContent = `Model period ${fmt(data.period)} s. Mass and stiffness both doubled, preserving m/k. Amplitude changes displacement but leaves the ideal period unchanged.`;
    } catch (err) { message(err.message); }
};
