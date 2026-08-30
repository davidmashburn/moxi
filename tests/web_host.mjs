import assert from "node:assert/strict";
import {
  MoxiWebHost,
  MOXI_HOST_POINTER_DOWN,
  MOXI_HOST_TEXT_INPUT,
  MOXI_HOST_WINDOW_RESIZED,
} from "../native/hosts/moxi_web_host.mjs";

class FakeSurface {
  constructor() {
    this.listeners = new Map();
    this.width = 0;
    this.height = 0;
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

  emit(type, event) {
    const handler = this.listeners.get(type);
    if (handler) handler(event);
  }
}

const surface = new FakeSurface();
const events = [];
const resizes = [];
const text = [];
const host = new MoxiWebHost(surface, {
  event: (...value) => events.push(value),
  resize: (...value) => resizes.push(value),
  text: (...value) => text.push(value),
});

assert.equal(host.start(), true);
assert.equal(host.start(), false);
surface.emit("pointerdown", {clientX: 14, clientY: 27, pointerId: 3, buttons: 1});
assert.deepEqual(events[0], [MOXI_HOST_POINTER_DOWN, 3, 4, 7, 1, 0]);
host.resize(320, 180, 2);
assert.equal(resizes.at(-1)[0], 320);
assert.equal(resizes.at(-1)[2], 2);
assert.equal(surface.width, 640);
host.text("hello", 1, 3);
assert.deepEqual(text.at(-1), ["hello", 1, 3]);
host.presentSVG("<svg/>");
assert.equal(host.lastSVG, "<svg/>");
assert.equal(host.stop(), true);
assert.equal(host.stop(), false);
assert.equal(events.some(event => event[0] === MOXI_HOST_WINDOW_RESIZED), false);
assert.equal(text.length, 1);
assert.equal(MOXI_HOST_TEXT_INPUT, 3);
console.log("Moxi Web host test passed");
