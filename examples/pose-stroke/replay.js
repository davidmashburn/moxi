const get = id => document.getElementById(id);
const brushes = Object.values(Mode).map(mode => {
  const panel = get("brush").content.firstElementChild.cloneNode(true);
  panel.querySelector("h2").textContent = mode;
  const path = panel.querySelector("path");
  path.setAttribute("stroke", mode === Mode.DIRECT ? "#286962" : "#a24b36");
  get("brushes").appendChild(panel);
  return {mode, path, output: panel.querySelector("output")};
});
let frame;
let heldOpen;
function display() {
  const sample = {...poses[frame]};
  if (heldOpen) sample.clutch = false;
  for (const brush of brushes) {
    brush.controller.accept(sample);
    const width = brush.controller.width;
    brush.output.textContent = width.toFixed(2) + " px";
    brush.path.setAttribute("stroke-width", width);
  }
  get("status").textContent = "Sample " + (frame + 1) + " / " + poses.length + " · " + brushes[0].controller.state;
  get("features").textContent = "Curl " + sample.curl.toFixed(2) + " · Spread " + sample.spread.toFixed(2)
    + " · Confidence " + sample.confidence.toFixed(2) + " · Clutch " + (sample.clutch ? "down" : "up");
  get("next").disabled = frame === poses.length - 1;
}
function restart() {
  heldOpen = false;
  get("hold").setAttribute("aria-pressed", false);
  frame = 0;
  for (const brush of brushes) brush.controller = new Stroke(brush.mode);
  display();
}
get("next").onclick = () => {
  frame++;
  display();
};
get("hold").onclick = () => {
  heldOpen = !heldOpen;
  get("hold").setAttribute("aria-pressed", heldOpen);
  display();
};
get("reset").onclick = restart;
restart();
