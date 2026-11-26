import {MoxiWebHost} from "../../native/hosts/moxi_web_host.mjs";
import {MoxiWidgetView, MoxiCanvas2D} from "../../native/hosts/moxi_web_view.mjs";
import {instantiateFractal, EventKind} from "./runtime.mjs";

const root = document.querySelector("#app");
const frameBudgetMs = 4;
const batchSize = 2048;

async function start() {
  const response = await fetch("./dist/fractal.wasm");
  if (!response.ok) throw new Error("Build the web fractal module before opening this page.");
  const runtime = await instantiateFractal(await response.arrayBuffer());
  const app = runtime.create();

  let dirty = true;
  let lastWidgets = 0;
  let host;
  const view = new MoxiWidgetView(root, (id, kind, value) => {
    if (app.widgetEvent(id, kind, value)) dirty = true;
    // Refresh synchronously so the next edit replaces the current text.
    refreshWidgets();
    host.requestFrame();
  });
  function refreshWidgets() {
    view.render(app.widgets(root.clientWidth, window.innerHeight));
    lastWidgets = performance.now();
  }
  root.replaceChildren();
  refreshWidgets();
  const canvas = root.querySelector("canvas");
  const painter = new MoxiCanvas2D(canvas);
  let activePointer = null, pendingMove = null, lastDown = performance.now();
  function flushMove() {
    if (pendingMove) dirty = app.event(EventKind.move, pendingMove) || dirty;
    pendingMove = null;
  }
  host = new MoxiWebHost(canvas.parentElement, {
    event(kind, id, x, y) {
      const point = {x: x * canvas.width / host.width, y: y * canvas.height / host.height};
      if (kind === EventKind.down && activePointer === null) {
        const now = performance.now();
        app.event(EventKind.frame, {deltaSeconds: (now - lastDown) / 1000});
        lastDown = now;
        activePointer = id;
        dirty = app.event(kind, point) || dirty;
      } else if (id === activePointer && kind === EventKind.move) {
        pendingMove = point;
      } else if (id === activePointer && (kind === EventKind.up || kind === EventKind.cancel)) {
        flushMove();
        dirty = app.event(kind, point) || dirty;
        activePointer = null;
      } else return;
      host.requestFrame();
    },
    frame() {
      flushMove();
      const deadline = performance.now() + frameBudgetMs;
      let complete = app.complete();
      while (!complete && performance.now() < deadline) {
        dirty = app.advance(batchSize) || dirty;
        complete = app.complete();
      }
      if (dirty) {
        app.paint(painter);
        if (complete || performance.now() - lastWidgets > 100) refreshWidgets();
        dirty = false;
      }
      if (!complete) host.requestFrame();
    },
  }, {continuousFrames: false});
  root.setAttribute("aria-busy", "false");
  const resize = () => { refreshWidgets(); dirty = true; host.requestFrame(); };
  window.addEventListener("resize", resize);
  window.addEventListener("error", () => {
    if (runtime.stats().failure) {
      host.stop();
      window.removeEventListener("resize", resize);
      showError(new Error(runtime.stats().failure));
    }
  });
  window.addEventListener("pagehide", event => {
    host.stop();
    if (!event.persisted) { window.removeEventListener("resize", resize); app.dispose(); }
  });
  window.addEventListener("pageshow", event => { if (event.persisted) host.start(); });
  host.start();
}

function showError(error) {
  root.setAttribute("aria-busy", "false");
  root.setAttribute("role", "alert");
  root.textContent = error.message;
}
start().catch(showError);
