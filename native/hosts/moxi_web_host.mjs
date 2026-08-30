/* Browser host shim for the same scalar callback ABI used by the mobile
 * sources. It deliberately does not require a framework: a canvas can use a
 * WebGPU/WebGL renderer, an SVG element can use presentSVG(), and both receive
 * identical pointer, keyboard, IME, resize, frame, and teardown callbacks. */

export const MOXI_HOST_POINTER_DOWN = 1;
export const MOXI_HOST_TEXT_INPUT = 3;
export const MOXI_HOST_WINDOW_RESIZED = 4;
export const MOXI_HOST_POINTER_UP = 5;
export const MOXI_HOST_POINTER_MOVE = 6;
export const MOXI_HOST_COMPOSITION_UPDATE = 8;
export const MOXI_HOST_COMPOSITION_END = 9;
export const MOXI_HOST_TOUCH_BEGIN = 16;
export const MOXI_HOST_TOUCH_UPDATE = 17;
export const MOXI_HOST_TOUCH_END = 18;
export const MOXI_HOST_POINTER_CANCEL = 19;

const noop = () => {};

export class MoxiWebHost {
  constructor(target, callbacks = {}, options = {}) {
    if (!target || typeof target.addEventListener !== "function") {
      throw new TypeError("MoxiWebHost requires an EventTarget-like surface");
    }
    this.target = target;
    this.svgTarget = options.svgTarget || null;
    this.callbacks = {
      event: callbacks.event || noop,
      key: callbacks.key || noop,
      text: callbacks.text || noop,
      composition: callbacks.composition || noop,
      resize: callbacks.resize || noop,
      frame: callbacks.frame || noop,
    };
    this.started = false;
    this.frameHandle = null;
    this.resizeObserver = null;
    this.listeners = [];
    this.width = 1;
    this.height = 1;
    this.scale = 1;
  }

  _listen(type, handler, options) {
    this.target.addEventListener(type, handler, options);
    this.listeners.push(() => this.target.removeEventListener(type, handler, options));
  }

  _point(event) {
    const rect = typeof this.target.getBoundingClientRect === "function"
      ? this.target.getBoundingClientRect()
      : {left: 0, top: 0};
    return {x: event.clientX - rect.left, y: event.clientY - rect.top};
  }

  _pointer(kind, event) {
    const point = this._point(event);
    this.callbacks.event(
      kind,
      event.pointerId || 0,
      point.x,
      point.y,
      event.buttons || 0,
      event.shiftKey ? 1 : 0,
    );
  }

  _touch(kind, touch) {
    const point = this._point(touch);
    this.callbacks.event(kind, touch.identifier || 0, point.x, point.y, 1, 0);
  }

  _scheduleFrame() {
    if (!this.started) return;
    const raf = globalThis.requestAnimationFrame;
    if (typeof raf === "function") {
      this.frameHandle = raf(() => {
        this.frameHandle = null;
        if (!this.started) return;
        this.callbacks.frame();
        this._scheduleFrame();
      });
    } else {
      this.frameHandle = globalThis.setTimeout(() => {
        this.frameHandle = null;
        if (!this.started) return;
        this.callbacks.frame();
        this._scheduleFrame();
      }, 16);
    }
  }

  start() {
    if (this.started) return false;
    this.started = true;
    this._listen("pointerdown", event => this._pointer(MOXI_HOST_POINTER_DOWN, event));
    this._listen("pointermove", event => this._pointer(MOXI_HOST_POINTER_MOVE, event));
    this._listen("pointerup", event => this._pointer(MOXI_HOST_POINTER_UP, event));
    this._listen("pointercancel", event => this._pointer(MOXI_HOST_POINTER_CANCEL, event));
    this._listen("keydown", event => this.callbacks.key(event.keyCode || event.which || 0, event.shiftKey ? 1 : 0));
    this._listen("compositionstart", event => this.composition(MOXI_HOST_COMPOSITION_UPDATE, event.data || "", 0, 0));
    this._listen("compositionupdate", event => this.composition(MOXI_HOST_COMPOSITION_UPDATE, event.data || "", 0, 0));
    this._listen("compositionend", event => this.composition(MOXI_HOST_COMPOSITION_END, event.data || "", 0, 0));
    this._listen("resize", () => this.resizeFromTarget());
    if (typeof globalThis.PointerEvent !== "function") {
      this._listen("touchstart", event => {
        for (const touch of event.changedTouches || []) this._touch(MOXI_HOST_TOUCH_BEGIN, touch);
      }, {passive: true});
      this._listen("touchmove", event => {
        for (const touch of event.changedTouches || []) this._touch(MOXI_HOST_TOUCH_UPDATE, touch);
      }, {passive: true});
      this._listen("touchend", event => {
        for (const touch of event.changedTouches || []) this._touch(MOXI_HOST_TOUCH_END, touch);
      }, {passive: true});
      this._listen("touchcancel", event => {
        for (const touch of event.changedTouches || []) this._touch(MOXI_HOST_POINTER_CANCEL, touch);
      }, {passive: true});
    }
    if (typeof globalThis.ResizeObserver === "function") {
      this.resizeObserver = new globalThis.ResizeObserver(() => this.resizeFromTarget());
      this.resizeObserver.observe(this.target);
    }
    this.resizeFromTarget();
    this._scheduleFrame();
    return true;
  }

  stop() {
    if (!this.started) return false;
    this.started = false;
    for (const remove of this.listeners.splice(0)) remove();
    if (this.resizeObserver) this.resizeObserver.disconnect();
    this.resizeObserver = null;
    if (this.frameHandle !== null) {
      if (typeof globalThis.cancelAnimationFrame === "function") {
        globalThis.cancelAnimationFrame(this.frameHandle);
      } else if (typeof globalThis.clearTimeout === "function") {
        globalThis.clearTimeout(this.frameHandle);
      }
      this.frameHandle = null;
    }
    return true;
  }

  resize(width, height, scale = globalThis.devicePixelRatio || 1) {
    this.width = width > 0 ? width : 1;
    this.height = height > 0 ? height : 1;
    this.scale = scale > 0 ? scale : 1;
    if ("width" in this.target && "height" in this.target) {
      this.target.width = Math.max(1, Math.round(this.width * this.scale));
      this.target.height = Math.max(1, Math.round(this.height * this.scale));
    }
    this.callbacks.resize(this.width, this.height, this.scale);
  }

  resizeFromTarget() {
    const rect = typeof this.target.getBoundingClientRect === "function"
      ? this.target.getBoundingClientRect()
      : {width: this.target.clientWidth || this.width, height: this.target.clientHeight || this.height};
    this.resize(rect.width, rect.height);
  }

  text(text, start = -1, end = -1) {
    this.callbacks.text(text, start, end);
  }

  composition(kind, text, start = 0, end = 0) {
    this.callbacks.composition(kind, text, start, end);
  }

  presentSVG(markup) {
    if (this.svgTarget) this.svgTarget.innerHTML = markup;
    this.lastSVG = markup;
  }
}
