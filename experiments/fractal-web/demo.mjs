import {
  MoxiRasterPresenter, MoxiWebHost, MOXI_HOST_POINTER_DOWN, MOXI_HOST_POINTER_MOVE,
  MOXI_HOST_POINTER_UP, MOXI_HOST_POINTER_CANCEL,
} from "../../native/hosts/moxi_web_host.mjs";
import {instantiateFractal, EventKind, RuntimeState} from "./runtime.mjs";

const byId = id => document.getElementById(id);
const controls = byId("controls");
const stage = byId("stage");
const status = byId("status");
const overlay = byId("overlay").getContext("2d");
const presenter = new MoxiRasterPresenter(byId("raster").getContext("2d"));
const width = overlay.canvas.width;
const height = overlay.canvas.height;
const frameBudgetMs = 4;
const batchSize = 2048;

function drawOverlay(state, complete) {
  overlay.clearRect(0, 0, width, height);
  if (!complete) {
    overlay.beginPath();
    for (const line of state.preview) {
      overlay.moveTo(line.x0, line.y0);
      overlay.lineTo(line.x1, line.y1);
    }
    overlay.strokeStyle = "#73978b88";
    overlay.lineWidth = 1;
    overlay.stroke();
  }
  const baseColor = "#3570a9";
  const generatorColor = "#a74046";
  function polyline(points, color, weight) {
    overlay.beginPath();
    points.forEach(({x, y}, i) => i ? overlay.lineTo(x, y) : overlay.moveTo(x, y));
    overlay.strokeStyle = color;
    overlay.lineWidth = weight;
    overlay.stroke();
  }
  function handle({x, y}, radius, color) {
    overlay.beginPath();
    overlay.arc(x, y, radius, 0, 2 * Math.PI);
    overlay.fillStyle = color;
    overlay.fill();
    overlay.lineWidth = 1;
    overlay.strokeStyle = "#fff";
    overlay.stroke();
  }
  polyline(state.baseline, baseColor, 3);
  if (state.guides) {
    polyline(state.points, generatorColor, 2);
    for (const point of state.points) handle(point, 8, generatorColor);
  }
  for (const [i, point] of state.baseline.entries()) {
    const docked = state.endpointDocked[i];
    const revealed = state.endpointRevealed[i];
    handle(point, 9.5, docked && !revealed ? generatorColor : baseColor);
    if (docked) handle(point, 4.5, revealed ? generatorColor : baseColor);
  }

}

async function start() {
  const response = await fetch("./dist/fractal.wasm");
  if (!response.ok) throw new Error("Build the web fractal module before opening this page.");
  const runtime = await instantiateFractal(await response.arrayBuffer());
  const app = runtime.create({preset: 12, depth: "6"});
  app.setFlags({guides: true, randomColors: true});
  const preset = byId("preset");
  for (const {name, id} of runtime.presets) preset.add(new Option(name, id));
  preset.value = "12";

  let geometry = app.inspect();
  let overlayDirty = true;
  let rasterDirty = true;
  let pointer = null;
  let pendingMove = null;
  let lastDown = performance.now();
  function invalidate() {
    status.value = "Drawing…";
    geometry = app.inspect();
    overlayDirty = rasterDirty = true;
    host.requestFrame();
  }
  function applyMove() {
    if (pendingMove && app.event(MOXI_HOST_POINTER_MOVE, pendingMove)) invalidate();
    pendingMove = null;
  }
  const host = new MoxiWebHost(stage, {
    event(kind, id, x, y) {
      const point = {x: x * width / host.width, y: y * height / host.height};
      if (kind === MOXI_HOST_POINTER_DOWN && pointer === null) {
        const now = performance.now();
        app.event(EventKind.frame, {deltaSeconds: (now - lastDown) / 1000});
        lastDown = now;
        pointer = id;
        if (app.event(kind, point)) invalidate();
      } else if (id === pointer && kind === MOXI_HOST_POINTER_MOVE) {
        pendingMove = point;
        host.requestFrame();
      } else if (id === pointer && (kind === MOXI_HOST_POINTER_UP || kind === MOXI_HOST_POINTER_CANCEL)) {
        applyMove();
        if (app.event(kind, point)) invalidate();
        pointer = null;
      }
    },
    frame() {
      applyMove();
      const end = performance.now() + frameBudgetMs;
      let complete = app.complete();
      while (!complete && performance.now() < end) {
        rasterDirty = app.advance(batchSize) || rasterDirty;
        complete = app.complete();
        if (complete) overlayDirty = true;
      }
      if (rasterDirty) {
        const raster = app.raster();
        presenter.present(raster.pixels, raster.width, raster.height);
        rasterDirty = false;
      }
      if (overlayDirty) {
        drawOverlay(geometry, complete);
        overlayDirty = false;
      }
      const progress = app.status();
      const lines = BigInt(progress.emitted).toLocaleString();
      status.textContent = lines + (progress.emitted === "1" ? " line · " : " lines · ") + (complete ? "Complete" : "Drawing")
        + (progress.coordinateOverflow ? " · Coordinates overflowed" : "");
      if (!complete) host.requestFrame();
    },
  }, {continuousFrames: false});

  const depth = byId("depth");
  function setDepth() {
    if (!depth.validity.valid) return;
    app.setDepth(depth.value);
    invalidate();
  }
  depth.addEventListener("input", setDepth);
  for (const [id, delta] of [["less", -1n], ["more", 1n]]) {
    byId(id).onclick = () => {
      const next = BigInt(depth.validity.valid ? depth.value : geometry.depth) + delta;
      depth.value = String(next < 0n ? 0n : next);
      setDepth();
    };
  }
  controls.onsubmit = event => event.preventDefault();
  preset.onchange = () => { app.preset(Number(preset.value)); invalidate(); };
  byId("reset").onclick = () => { app.reset(); invalidate(); };
  for (const id of ["colors", "guides"]) {
    byId(id).onchange = () => {
      app.setFlags({guides: byId("guides").checked, randomColors: byId("colors").checked});
      invalidate();
    };
  }

  window.addEventListener("error", () => {
    const {state, failure} = runtime.stats();
    if (state === RuntimeState.failed) {
      host.stop();
      runtime.dispose();
      showError(new Error(failure + ". Reload the page to restart the renderer."));
    }
  });
  host.start();
  window.addEventListener("pagehide", event => {
    host.stop();
    if (!event.persisted) app.dispose();
  });
  window.addEventListener("pageshow", event => { if (event.persisted) host.start(); });
}

function showError(error) {
  status.textContent = error.message;
  for (const input of controls.elements) input.disabled = true;
}

start().catch(showError);
