import assert from "node:assert/strict";
import {
  MoxiWebHost,
  accessibilityAttributes,
  MOXI_AX_ROLE_MAP,
  MOXI_HOST_POINTER_DOWN,
  MOXI_HOST_POINTER_UP,
  MOXI_HOST_SCROLL,
  MOXI_HOST_TEXT_INPUT,
  MOXI_HOST_WINDOW_RESIZED,
  MOXI_MOD_COMMAND,
  MOXI_MOD_CONTROL,
  MOXI_MOD_OPTION,
  MOXI_MOD_SHIFT,
} from "../native/hosts/moxi_web_host.mjs";

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

const surface = new FakeSurface();
const events = [];
const resizes = [];
const text = [];
const scrolls = [];
let wheelPrevented = false;
const host = new MoxiWebHost(surface, {
  event: (...value) => events.push(value),
  resize: (...value) => resizes.push(value),
  text: (...value) => text.push(value),
  scroll: (...value) => scrolls.push(value),
});

assert.equal(host.start(), true);
assert.equal(host.start(), false);
surface.emit("pointerdown", {
  clientX: 14,
  clientY: 27,
  pointerId: 3,
  buttons: 1,
  shiftKey: true,
  metaKey: true,
  ctrlKey: true,
  altKey: true,
});
assert.deepEqual(events[0], [
  MOXI_HOST_POINTER_DOWN,
  3,
  4,
  7,
  1,
  MOXI_MOD_SHIFT | MOXI_MOD_COMMAND | MOXI_MOD_CONTROL | MOXI_MOD_OPTION,
]);
assert.deepEqual(surface.captures, [3]);
surface.emit("pointerup", {clientX: 14, clientY: 27, pointerId: 3, buttons: 0});
assert.deepEqual(events[1], [MOXI_HOST_POINTER_UP, 3, 4, 7, 0, 0]);
assert.deepEqual(surface.releases, [3]);
surface.emit("wheel", {
  clientX: 18,
  clientY: 32,
  deltaX: 4,
  deltaY: 12,
  shiftKey: true,
  cancelable: true,
  preventDefault: () => { wheelPrevented = true; },
});
assert.equal(wheelPrevented, true);
assert.deepEqual(scrolls[0], [4, 12, 8, 12, MOXI_MOD_SHIFT]);
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
assert.equal(MOXI_AX_ROLE_MAP[8], "slider");
assert.deepEqual(
  accessibilityAttributes({
    role: 8,
    label: "Volume",
    hint: "Adjust output level",
    enabled: false,
    has_value_range: true,
    value_min: 0,
    value_max: 10,
    value_now: 4,
    focused: true,
  }),
  {
    role: "slider",
    "aria-label": "Volume",
    "aria-description": "Adjust output level",
    "aria-disabled": "true",
    "aria-valuemin": "0",
    "aria-valuemax": "10",
    "aria-valuenow": "4",
    tabIndex: "0",
  },
);
const semanticSnapshot = [{id: 10, role: 2, label: "Save", bounds: {x: 2, y: 3, width: 80, height: 24}}];
assert.equal(host.updateAccessibility(semanticSnapshot), 1);
assert.deepEqual(host.accessibilitySnapshot, semanticSnapshot);
console.log("Moxi Web host test passed");
