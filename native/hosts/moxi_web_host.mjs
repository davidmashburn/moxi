/* Browser host shim for the same scalar callback ABI used by the mobile
 * sources. It deliberately does not require a framework: a canvas can use a
 * WebGPU/WebGL renderer, an SVG element can use presentSVG(), and both receive
 * identical pointer, keyboard, IME, resize, frame, and teardown callbacks. */

export const MOXI_HOST_POINTER_DOWN = 1;
export const MOXI_HOST_TEXT_INPUT = 3;
export const MOXI_HOST_WINDOW_RESIZED = 4;
export const MOXI_HOST_POINTER_UP = 5;
export const MOXI_HOST_POINTER_MOVE = 6;
export const MOXI_HOST_SCROLL = 11;
export const MOXI_HOST_COMPOSITION_UPDATE = 8;
export const MOXI_HOST_COMPOSITION_END = 9;
export const MOXI_HOST_TOUCH_BEGIN = 16;
export const MOXI_HOST_TOUCH_UPDATE = 17;
export const MOXI_HOST_TOUCH_END = 18;
export const MOXI_HOST_POINTER_CANCEL = 19;
export const MOXI_HOST_ACTION_PRESS = 1;
export const MOXI_HOST_ACTION_INCREMENT = 2;
export const MOXI_HOST_ACTION_DECREMENT = 4;
export const MOXI_HOST_ACTION_SELECT = 8;
export const MOXI_HOST_ACTION_EXPAND = 16;
export const MOXI_HOST_ACTION_COLLAPSE = 32;

export const MOXI_MOD_SHIFT = 1;
export const MOXI_MOD_COMMAND = 2;
export const MOXI_MOD_CONTROL = 4;
export const MOXI_MOD_OPTION = 8;

/* The numeric roles mirror src/moxi/accessibility.mojo. A null role is
 * intentional: ARIA has no portable role for a presentational label, so the
 * accessible name is retained without manufacturing an invalid role token. */
export const MOXI_AX_ROLE_MAP = Object.freeze({
  1: null,
  2: "button",
  3: "textbox",
  4: null,
  5: "group",
  6: "checkbox",
  7: "progressbar",
  8: "slider",
  9: "switch",
  10: "radio",
  11: "img",
  12: "textbox",
  13: "combobox",
  14: "listbox",
  15: "table",
  16: "tree",
  17: "menu",
  18: "dialog",
  19: "tablist",
  20: "application",
  21: "separator",
});

const MOXI_AX_INTERACTIVE_ROLES = new Set([
  "button", "textbox", "checkbox", "slider", "switch", "radio",
  "combobox", "listbox", "table", "tree", "menu", "dialog", "tablist",
  "application",
]);

function accessibilityRole(role) {
  if (typeof role === "string") return role.toLowerCase();
  return MOXI_AX_ROLE_MAP[role] || null;
}

function accessibilityBoolean(node, key) {
  return Object.prototype.hasOwnProperty.call(node, key) ? !!node[key] : null;
}

/**
 * Convert one Moxi semantic node into stable ARIA attributes.
 *
 * This helper is pure so hosts can test the mapping without a browser DOM and
 * native adapters can use the same contract when they are not rendering an
 * HTML accessibility overlay.
 */
export function accessibilityAttributes(node = {}) {
  const attributes = {};
  const role = accessibilityRole(node.role);
  if (role) attributes.role = role;

  const label = node.label ?? node.name;
  if (label !== undefined && label !== null && String(label).length > 0) {
    attributes["aria-label"] = String(label);
  }
  const hint = node.hint ?? node.description;
  if (hint !== undefined && hint !== null && String(hint).length > 0) {
    attributes["aria-description"] = String(hint);
  }
  const value = node.value;
  if (value !== undefined && value !== null && String(value).length > 0) {
    attributes["aria-valuetext"] = String(value);
  }

  if (node.enabled === false) attributes["aria-disabled"] = "true";
  const selected = accessibilityBoolean(node, "selected");
  if (selected !== null) attributes["aria-selected"] = String(selected);
  const checked = accessibilityBoolean(node, "checked");
  if (checked !== null && ["checkbox", "switch", "radio"].includes(role)) {
    attributes["aria-checked"] = String(checked);
  }
  const expanded = accessibilityBoolean(node, "expanded");
  if (expanded !== null && ["combobox", "tree", "menu", "dialog"].includes(role)) {
    attributes["aria-expanded"] = String(expanded);
  }

  const hasRange = node.has_value_range ?? node.hasValueRange;
  if (hasRange) {
    attributes["aria-valuemin"] = String(node.value_min ?? node.valueMin ?? 0);
    attributes["aria-valuemax"] = String(node.value_max ?? node.valueMax ?? 0);
    attributes["aria-valuenow"] = String(node.value_now ?? node.valueNow ?? 0);
  }

  if (node.hidden === true) attributes.hidden = "";
  if (MOXI_AX_INTERACTIVE_ROLES.has(role)) {
    attributes.tabIndex = node.focused ? "0" : "-1";
  }
  return attributes;
}

const noop = () => {};

function modifierMask(event) {
  let modifiers = 0;
  if (event.shiftKey) modifiers |= MOXI_MOD_SHIFT;
  if (event.metaKey) modifiers |= MOXI_MOD_COMMAND;
  if (event.ctrlKey) modifiers |= MOXI_MOD_CONTROL;
  if (event.altKey) modifiers |= MOXI_MOD_OPTION;
  return modifiers;
}

export class MoxiWebHost {
  constructor(target, callbacks = {}, options = {}) {
    if (!target || typeof target.addEventListener !== "function") {
      throw new TypeError("MoxiWebHost requires an EventTarget-like surface");
    }
    this.target = target;
    this.svgTarget = options.svgTarget || null;
    this.accessibilityTarget = options.accessibilityTarget || null;
    this.callbacks = {
      event: callbacks.event || noop,
      key: callbacks.key || noop,
      text: callbacks.text || noop,
      composition: callbacks.composition || noop,
      scroll: callbacks.scroll || noop,
      resize: callbacks.resize || noop,
      frame: callbacks.frame || noop,
      accessibilityAction: callbacks.accessibilityAction || noop,
    };
    this.started = false;
    this.frameHandle = null;
    this.resizeObserver = null;
    this.listeners = [];
    this.width = 1;
    this.height = 1;
    this.scale = 1;
    this.accessibilitySnapshot = [];
    this.accessibilityRoot = null;
    this.accessibilityElements = new Map();
    this.capturedPointers = new Set();
    this.scrollEnabled = typeof callbacks.scroll === "function";
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
    const pointerId = event.pointerId ?? 0;
    const terminal = kind === MOXI_HOST_POINTER_UP || kind === MOXI_HOST_POINTER_CANCEL;
    if (kind === MOXI_HOST_POINTER_DOWN) this._capturePointer(pointerId);
    try {
      this.callbacks.event(
        kind,
        pointerId,
        point.x,
        point.y,
        event.buttons || 0,
        modifierMask(event),
      );
    } finally {
      if (terminal) this._releasePointer(pointerId);
    }
  }

  _touch(kind, touch) {
    const point = this._point(touch);
    this.callbacks.event(kind, touch.identifier || 0, point.x, point.y, 1, 0);
  }

  _capturePointer(pointerId) {
    if (typeof this.target.setPointerCapture !== "function") return;
    try {
      this.target.setPointerCapture(pointerId);
      this.capturedPointers.add(pointerId);
    } catch (_) {
      /* Pointer capture is optional for EventTarget-like test/worker hosts. */
    }
  }

  _releasePointer(pointerId) {
    if (!this.capturedPointers.has(pointerId)) return;
    this.capturedPointers.delete(pointerId);
    if (typeof this.target.releasePointerCapture !== "function") return;
    try {
      this.target.releasePointerCapture(pointerId);
    } catch (_) {
      /* The browser may release capture before the terminal event arrives. */
    }
  }

  _scroll(event) {
    if (!this.scrollEnabled) return;
    if (event.cancelable && typeof event.preventDefault === "function") {
      event.preventDefault();
    }
    const point = this._point(event);
    this.callbacks.scroll(
      Number(event.deltaX || 0),
      Number(event.deltaY || 0),
      point.x,
      point.y,
      modifierMask(event),
    );
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

  _accessibilityBounds(node) {
    const bounds = node.bounds || node;
    return {
      x: Number(bounds.x ?? 0),
      y: Number(bounds.y ?? 0),
      width: Math.max(0, Number(bounds.width ?? 0)),
      height: Math.max(0, Number(bounds.height ?? 0)),
    };
  }

  _accessibilityActionFromKey(event) {
    if (event.key === "Enter" || event.key === " ") return MOXI_HOST_ACTION_PRESS;
    if (event.key === "ArrowUp" || event.key === "ArrowRight") {
      return MOXI_HOST_ACTION_INCREMENT;
    }
    if (event.key === "ArrowDown" || event.key === "ArrowLeft") {
      return MOXI_HOST_ACTION_DECREMENT;
    }
    return 0;
  }

  _clearAccessibilityDOM() {
    if (this.accessibilityRoot && this.accessibilityRoot.parentNode) {
      this.accessibilityRoot.parentNode.removeChild(this.accessibilityRoot);
    }
    this.accessibilityRoot = null;
    this.accessibilityElements.clear();
  }

  /**
   * Publish a laid-out semantic snapshot to an optional DOM accessibility
   * layer. Nodes remain cached even when no DOM is available, which keeps the
   * browser host useful in workers and in deterministic adapter tests.
   */
  updateAccessibility(snapshot = []) {
    const nodes = Array.isArray(snapshot)
      ? snapshot
      : (Array.isArray(snapshot?.nodes) ? snapshot.nodes : []);
    this.accessibilitySnapshot = nodes.slice();
    const target = this.accessibilityTarget;
    const document = target?.ownerDocument || globalThis.document;
    if (!target || !document || typeof document.createElement !== "function" ||
        typeof target.appendChild !== "function") {
      return this.accessibilitySnapshot.length;
    }

    if (!this.accessibilityRoot) {
      this.accessibilityRoot = document.createElement("div");
      this.accessibilityRoot.setAttribute("data-moxi-accessibility", "true");
      this.accessibilityRoot.style.position = "absolute";
      this.accessibilityRoot.style.left = "0";
      this.accessibilityRoot.style.top = "0";
      this.accessibilityRoot.style.width = "100%";
      this.accessibilityRoot.style.height = "100%";
      this.accessibilityRoot.style.pointerEvents = "none";
      target.appendChild(this.accessibilityRoot);
    }

    const currentIDs = new Set();
    const byID = new Map();
    for (const node of nodes) {
      if (node?.id === undefined || node?.id === null) continue;
      const id = String(node.id);
      currentIDs.add(id);
      let element = this.accessibilityElements.get(id);
      if (!element) {
        element = document.createElement("div");
        element.dataset.moxiId = id;
        element.addEventListener("click", () => {
          this.callbacks.accessibilityAction(Number(node.id), MOXI_HOST_ACTION_PRESS);
        });
        element.addEventListener("keydown", event => {
          const action = this._accessibilityActionFromKey(event);
          if (action === 0) return;
          event.preventDefault();
          this.callbacks.accessibilityAction(Number(node.id), action);
        });
        this.accessibilityElements.set(id, element);
      }
      for (const [name, value] of Object.entries(accessibilityAttributes(node))) {
        if (name === "hidden") element.hidden = true;
        else if (name === "tabIndex") element.tabIndex = Number(value);
        else element.setAttribute(name, value);
      }
      if (!Object.prototype.hasOwnProperty.call(node, "hidden") || !node.hidden) {
        element.hidden = false;
      }
      const bounds = this._accessibilityBounds(node);
      element.style.position = "absolute";
      element.style.left = `${bounds.x}px`;
      element.style.top = `${bounds.y}px`;
      element.style.width = `${bounds.width}px`;
      element.style.height = `${bounds.height}px`;
      element.style.pointerEvents = "none";
      element.textContent = node.label ?? node.name ?? "";
      byID.set(id, element);
    }

    for (const [id, element] of this.accessibilityElements) {
      if (!currentIDs.has(id)) {
        if (element.parentNode) element.parentNode.removeChild(element);
        this.accessibilityElements.delete(id);
      }
    }
    for (const node of nodes) {
      if (node?.id === undefined || node?.id === null) continue;
      const element = byID.get(String(node.id));
      const parent = node.parent_id ?? node.parentId;
      const parentElement = parent === undefined || parent === null || parent < 0
        ? this.accessibilityRoot
        : byID.get(String(parent));
      const destination = parentElement || this.accessibilityRoot;
      if (element.parentNode !== destination) destination.appendChild(element);
      if (node.focused && typeof element.focus === "function") {
        element.focus({preventScroll: true});
      }
    }
    return this.accessibilitySnapshot.length;
  }

  start() {
    if (this.started) return false;
    this.started = true;
    this._listen("pointerdown", event => this._pointer(MOXI_HOST_POINTER_DOWN, event));
    this._listen("pointermove", event => this._pointer(MOXI_HOST_POINTER_MOVE, event));
    this._listen("pointerup", event => this._pointer(MOXI_HOST_POINTER_UP, event));
    this._listen("pointercancel", event => this._pointer(MOXI_HOST_POINTER_CANCEL, event));
    this._listen("wheel", event => this._scroll(event), {passive: false});
    this._listen("keydown", event => this.callbacks.key(event.keyCode || event.which || 0, modifierMask(event)));
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
    for (const pointerId of this.capturedPointers) this._releasePointer(pointerId);
    this._clearAccessibilityDOM();
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
