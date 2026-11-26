// Domain operations stay in the example; every visible brush comes from Moxi.
const get = id => document.getElementById(id);
const Operation = Object.freeze({NEXT: "next", HOLD: "hold", RESET: "reset", CALIBRATE: "calibrate"});
const brushes = Object.values(Mode).map(mode => {
  const panel = get("brush").content.firstElementChild.cloneNode(true);
  panel.querySelector("h2").textContent = mode;
  get("brushes").appendChild(panel);
  return {scene: panel.querySelector(".scene"), output: panel.querySelector("output")};
});
let instrument = {frame: 0, heldOpen: false, mapping: defaultCalibration,
  controllers: Object.values(Mode).map(mode => new Stroke(mode))};
let busy = false;
let ready = false;
const controls = [...document.querySelectorAll("button, input")];

function fields(mapping) {
  for (const key of Object.values(CalibrationKey)) get(key).value = mapping[key];
}
function message(text) { get("notice").textContent = text; }
function lock(value) {
  busy = value;
  for (const control of controls) control.disabled = value || !ready;
  get("next").disabled ||= instrument.frame === poses.length - 1;
  // Restart can retry the initial render when Moxi was unavailable at startup.
  get("reset").disabled = value;
  get("brushes").setAttribute("aria-busy", value);
}
function display(sample, response) {
  brushes.forEach((brush, i) => {
    brush.scene.innerHTML = response.svgs[i];
    brush.output.textContent = instrument.controllers[i].width.toFixed(2) + " px";
  });
  get("status").textContent = "Sample " + (instrument.frame + 1) + " / " + poses.length
    + " · " + instrument.controllers[0].state;
  get("features").textContent = "Curl " + sample.curl.toFixed(2) + " · Spread " + sample.spread.toFixed(2)
    + " · Confidence " + sample.confidence.toFixed(2) + " · Clutch " + (sample.clutch ? "down" : "up");
  get("hold").setAttribute("aria-pressed", instrument.heldOpen);
  get("render-state").textContent = response.renderer;
  get("render-state").dataset.binarySha256 = response.binary_sha256;
}
async function operate(operation, mapping) {
  if (busy || (operation === Operation.NEXT && instrument.frame === poses.length - 1)) return;
  const focused = document.activeElement;
  lock(true);
  try {
    const next = {...instrument, controllers: instrument.controllers.map(brush => brush.copy())};
    switch (operation) {
      case Operation.NEXT: next.frame++; break;
      case Operation.HOLD: next.heldOpen = !next.heldOpen; break;
      case Operation.RESET:
        next.frame = 0;
        next.heldOpen = false;
        next.controllers = Object.values(Mode).map(mode => new Stroke(mode, next.mapping));
        break;
      case Operation.CALIBRATE:
        next.mapping = calibration(mapping);
        for (const brush of next.controllers) brush.recalibrate(next.mapping);
        break;
      default: throw new Error("Unknown operation");
    }
    const sample = {...poses[next.frame], clutch: !next.heldOpen && poses[next.frame].clutch};
    for (const brush of next.controllers) brush.accept(sample);
    const response = await fetch("/scene", {method: "POST", headers: {"Content-Type": "application/json"},
      body: JSON.stringify({widths: next.controllers.map(brush => brush.width)}), signal: AbortSignal.timeout(15000)});
    if (!response.ok) throw new Error("Moxi render unavailable (" + response.status + "). Retry the operation.");
    const result = await response.json();
    if (!Array.isArray(result.svgs) || result.svgs.length !== 2
        || result.svgs.some(svg => typeof svg !== "string" || !svg.startsWith("<svg ")))
      throw new Error("Invalid Moxi scene response");
    instrument = next; // Commit only after both Moxi scenes arrive.
    ready = true;
    display(sample, result);
    if (operation === Operation.CALIBRATE) fields(instrument.mapping);
    message(operation === Operation.CALIBRATE ? "Calibration applied. Widths held; control re-anchored." : "");
  } catch (error) {
    if (!ready) get("render-state").textContent = "Moxi unavailable";
    message(error.message + " Last rendered state retained. Start the local host from the README if needed.");
  } finally {
    lock(false);
    if (focused && !focused.disabled) focused.focus({preventScroll: true});
  }
}
function save() {
  if (busy || !ready) return;
  try {
    localStorage.setItem(SAVED_MAPPING_KEY, savedMapping(instrument.mapping));
    message("Applied mapping saved in this browser. Reopen it after reload at this address.");
  } catch (error) { message("Mapping not saved: " + error.message); }
}
function reopen() {
  if (busy || !ready) return;
  try {
    const text = localStorage.getItem(SAVED_MAPPING_KEY);
    if (text === null) throw new Error("No saved mapping at this address");
    void operate(Operation.CALIBRATE, reopenedMapping(text));
  } catch (error) { message("Mapping not reopened: " + error.message); }
}
get("next").onclick = () => void operate(Operation.NEXT);
get("hold").onclick = () => void operate(Operation.HOLD);
get("reset").onclick = () => void operate(Operation.RESET);
get("mapping").onsubmit = event => {
  event.preventDefault();
  void operate(Operation.CALIBRATE,
    Object.fromEntries(Object.values(CalibrationKey).map(key => [key, get(key).valueAsNumber])));
};
get("revert").onclick = () => { fields(instrument.mapping); message("Draft reverted to applied calibration."); };
get("save").onclick = save;
get("reopen").onclick = reopen;
document.addEventListener("keydown", event => {
  if ((event.metaKey || event.ctrlKey) && ["s", "o"].includes(event.key.toLowerCase())) {
    event.preventDefault();
    if (event.key.toLowerCase() === "s") save(); else reopen();
  } else if (event.key === "Escape" && get("mapping").contains(event.target) && !busy) {
    fields(instrument.mapping);
    message("Draft reverted to applied calibration.");
  }
});
fields(instrument.mapping);
void operate(Operation.RESET);
