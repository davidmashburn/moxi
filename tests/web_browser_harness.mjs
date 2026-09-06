import assert from "node:assert/strict";
import {createReadStream, promises as fs} from "node:fs";
import http from "node:http";
import path from "node:path";
import {fileURLToPath} from "node:url";
import {
  MoxiWebHost,
  MOXI_HOST_POINTER_DOWN,
  MOXI_HOST_POINTER_UP,
  MOXI_HOST_SCROLL,
  MOXI_HOST_WINDOW_RESIZED,
  accessibilityAttributes,
} from "../native/hosts/moxi_web_host.mjs";

const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const webRoot = path.join(repo, "native");

const mimeTypes = new Map([
  [".html", "text/html; charset=utf-8"],
  [".mjs", "text/javascript; charset=utf-8"],
]);

class FakeElement extends EventTarget {
  constructor(document) {
    super();
    this.ownerDocument = document;
    this.children = [];
    this.parentNode = null;
    this.attributes = new Map();
    this.dataset = {};
    this.style = {};
    this.hidden = false;
    this.tabIndex = -1;
    this.textContent = "";
    this.focused = false;
  }

  appendChild(child) {
    if (child.parentNode) child.parentNode.removeChild(child);
    child.parentNode = this;
    this.children.push(child);
    return child;
  }

  removeChild(child) {
    const index = this.children.indexOf(child);
    if (index >= 0) this.children.splice(index, 1);
    child.parentNode = null;
    return child;
  }

  setAttribute(name, value) {
    this.attributes.set(name, String(value));
  }

  getAttribute(name) {
    return this.attributes.get(name) ?? null;
  }

  focus() {
    this.focused = true;
  }
}

class FakeDocument {
  createElement() {
    return new FakeElement(this);
  }
}

class FakeSurface {
  constructor() {
    this.listeners = new Map();
    this.width = 0;
    this.height = 0;
    this.captures = [];
    this.releases = [];
  }

  addEventListener(type, handler) {
    this.listeners.set(type, handler);
  }

  removeEventListener(type) {
    this.listeners.delete(type);
  }

  getBoundingClientRect() {
    return {left: 10, top: 20, width: 320, height: 180};
  }

  setPointerCapture(pointerId) {
    this.captures.push(pointerId);
  }

  releasePointerCapture(pointerId) {
    this.releases.push(pointerId);
  }

  emit(type, event) {
    const handler = this.listeners.get(type);
    if (handler) handler(event);
  }
}

async function serve(root) {
  const server = http.createServer(async (request, response) => {
    try {
      const requestPath = decodeURIComponent(new URL(request.url, "http://localhost").pathname);
      const relative = requestPath.replace(/^\/+/, "");
      const filePath = path.resolve(root, relative);
      if (!filePath.startsWith(`${root}${path.sep}`)) {
        response.writeHead(403);
        response.end("forbidden");
        return;
      }
      const stat = await fs.stat(filePath);
      if (!stat.isFile()) throw new Error("not a file");
      response.writeHead(200, {
        "content-type": mimeTypes.get(path.extname(filePath)) || "application/octet-stream",
        "cache-control": "no-store",
      });
      createReadStream(filePath).pipe(response);
    } catch (_) {
      response.writeHead(404);
      response.end("not found");
    }
  });
  await new Promise(resolve => server.listen(0, "127.0.0.1", resolve));
  const address = server.address();
  return {server, url: `http://127.0.0.1:${address.port}`};
}

async function main() {
  const {server, url} = await serve(webRoot);
  const surface = new FakeSurface();
  const document = new FakeDocument();
  const accessibilityTarget = new FakeElement(document);
  const events = [];
  const resizes = [];
  let prevented = false;
  const host = new MoxiWebHost(surface, {
    event: (...value) => events.push(value),
    resize: (...value) => resizes.push(value),
    scroll: (...value) => events.push([MOXI_HOST_SCROLL, ...value]),
    accessibilityAction: (...value) => events.push(["accessibility", ...value]),
  }, {accessibilityTarget});

  try {
    const html = await (await fetch(`${url}/web/host_demo.html`)).text();
    assert.match(html, /data-moxi-ready="false"/);
    assert.match(html, /__MOXI_HOST_READY__/);
    assert.match(html, /data-moxi-surface="moxi-surface"/);
    assert.match(html, /aria-label="Moxi Web host demo"/);
    const moduleResponse = await fetch(`${url}/hosts/moxi_web_host.mjs`);
    assert.equal(moduleResponse.status, 200);
    assert.match(await moduleResponse.text(), /export class MoxiWebHost/);

    assert.equal(host.start(), true);
    host.resize(320, 180, 2);
    surface.emit("pointerdown", {
      clientX: 14,
      clientY: 27,
      pointerId: 3,
      buttons: 1,
      shiftKey: true,
    });
    surface.emit("pointerup", {
      clientX: 14,
      clientY: 27,
      pointerId: 3,
      buttons: 0,
    });
    surface.emit("wheel", {
      clientX: 18,
      clientY: 32,
      deltaX: 4,
      deltaY: 12,
      cancelable: true,
      preventDefault: () => { prevented = true; },
    });
    host.updateAccessibility([{
      id: 10,
      role: 2,
      label: "Save",
      hint: "Persist the document",
      bounds: {x: 2, y: 3, width: 80, height: 24},
      focused: true,
    }]);

    assert.deepEqual(events[0].slice(0, 4), [MOXI_HOST_POINTER_DOWN, 3, 4, 7]);
    assert.deepEqual(events[1].slice(0, 4), [MOXI_HOST_POINTER_UP, 3, 4, 7]);
    assert.equal(prevented, true);
    assert.deepEqual(surface.captures, [3]);
    assert.deepEqual(surface.releases, [3]);
    assert.equal(resizes.at(-1)[0], 320);
    assert.equal(resizes.at(-1)[1], 180);
    assert.equal(resizes.at(-1)[2], 2);
    assert.equal(surface.width, 640);
    assert.equal(surface.height, 360);
    assert.deepEqual(accessibilityAttributes({role: 2, label: "Save", focused: true}), {
      role: "button",
      "aria-label": "Save",
      tabIndex: "0",
    });
    assert.equal(host.accessibilitySnapshot.length, 1);
    assert.equal(host.accessibilityRoot.children.length, 1);
    assert.equal(host.accessibilityRoot.children[0].getAttribute("role"), "button");
    assert.equal(host.accessibilityRoot.children[0].getAttribute("aria-label"), "Save");
    assert.equal(host.accessibilityRoot.children[0].focused, true);
  } finally {
    assert.equal(host.stop(), true);
    assert.equal(host.stop(), false);
    await new Promise((resolve, reject) => {
      server.close(error => error ? reject(error) : resolve());
    });
  }

  console.log(JSON.stringify({
    readyMarker: true,
    server: "started-and-torn-down",
    canvas: {width: surface.width, height: surface.height},
    aria: {role: "button", label: "Save", focused: true},
    events: events.length,
    resizeCallbacks: resizes.length,
  }));
  console.log("Moxi browser host harness passed");
}

await main();
