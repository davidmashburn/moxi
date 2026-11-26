import {MoxiRasterPresenter} from "./moxi_web_host.mjs";

// Wire values from view_node.mojo, layout.mojo and event.mojo.
const Widget = Object.freeze({label: 1, button: 2, text: 5, container: 7, checkbox: 8, canvas: 22});
const Layout = Object.freeze({linear: 0, grid: 2, portal: 4, rowAxis: 1});
const justifyContent = ["start", "center", "end", "space-between"];
const alignItems = ["start", "center", "end", "stretch"];
export const WidgetEvent = Object.freeze({activate: 20, replaceText: 3, enter: 2});
const cssColor = rgba => "#" + (rgba >>> 0).toString(16).padStart(8, "0");

// Widget snapshots contain only scalar properties from the Wasm bridge.
function unchanged(previous, next) {
  if (!previous) return false;
  for (const key in next) if (next[key] !== previous[key]) return false;
  return true;
}

export class MoxiCanvas2D {
  constructor(canvas) {
    this.ctx = canvas.getContext("2d");
    this.layer = canvas.ownerDocument.createElement("canvas");
    this.upload = new MoxiRasterPresenter(this.layer.getContext("2d"));
  }
  clip(x, y, w, h) {
    this.ctx.save();
    this.ctx.beginPath();
    this.ctx.rect(x, y, w, h);
    this.ctx.clip();
  }
  end() { this.ctx.restore(); }
  rect(x, y, w, h, fill, stroke, width) {
    this.ctx.fillStyle = cssColor(fill);
    this.ctx.fillRect(x, y, w, h);
    if (width > 0) {
      this.ctx.lineWidth = width;
      this.ctx.strokeStyle = cssColor(stroke);
      this.ctx.strokeRect(x, y, w, h);
    }
  }
  line(x0, y0, x1, y1, color, width) {
    this.ctx.beginPath();
    this.ctx.moveTo(x0, y0);
    this.ctx.lineTo(x1, y1);
    this.ctx.strokeStyle = cssColor(color);
    this.ctx.lineWidth = width;
    this.ctx.stroke();
  }
  circle(x, y, radius, fill, stroke, width) {
    this.ctx.beginPath();
    this.ctx.arc(x, y, radius, 0, 2 * Math.PI);
    this.ctx.fillStyle = cssColor(fill);
    this.ctx.fill();
    if (width > 0) {
      this.ctx.strokeStyle = cssColor(stroke);
      this.ctx.lineWidth = width;
      this.ctx.stroke();
    }
  }
  bitmap(pixels, width, height, x, y, w, h) {
    if (this.layer.width !== width) this.layer.width = width;
    if (this.layer.height !== height) this.layer.height = height;
    this.upload.present(pixels, width, height);
    this.ctx.drawImage(this.layer, x, y, w, h);
  }
}

// Native HTML controls supply keyboard activation, editing, IME and accessibility.
// The Mojo view supplies their identity, containment, presentation and behavior.
export class MoxiWidgetView {
  constructor(root, dispatch) {
    this.root = root;
    this.dispatch = dispatch;
    this.elements = new Map();
  }
  create(node) {
    const doc = this.root.ownerDocument;
    const make = tag => doc.createElement(tag);
    let element, control;
    switch (node.kind) {
      case Widget.container: element = make("div"); break;
      case Widget.label: element = make("span"); break;
      case Widget.button:
        element = control = make("button");
        element.type = "button";
        element.onclick = () => this.dispatch(node.id, WidgetEvent.activate);
        break;
      case Widget.checkbox:
        element = make("label");
        control = make("input");
        control.type = "checkbox";
        control.onchange = () => this.dispatch(node.id, WidgetEvent.activate);
        element.append(control, make("span"));
        break;
      case Widget.text:
        element = control = make("input");
        element.type = "text";
        element.oninput = e => { if (!e.isComposing) this.dispatch(node.id, WidgetEvent.replaceText, element.value); };
        element.oncompositionstart = () => { element.dataset.composing = "true"; };
        element.oncompositionend = () => {
          delete element.dataset.composing;
          this.dispatch(node.id, WidgetEvent.replaceText, element.value);
        };
        element.onkeydown = e => {
          if (e.key === "Enter" && !e.isComposing) this.dispatch(node.id, WidgetEvent.enter);
        };
        break;
      case Widget.canvas:
        element = make("div");
        control = make("canvas");
        element.append(control);
        break;
      default: throw new Error("Unsupported Moxi widget kind " + node.kind);
    }
    element.dataset.moxiId = node.id;
    element.className = "moxi-widget";
    return {element, control, kind: node.kind};
  }
  render(nodes) {
    const seen = new Set();
    const previousSibling = new Map();
    for (const n of nodes) {
      let record = this.elements.get(n.id);
      if (!record || record.kind !== n.kind) {
        record?.element.remove();
        record = this.create(n);
        this.elements.set(n.id, record);
      }
      const {element, control} = record;
      const parent = this.elements.get(n.parent)?.element ?? this.root;
      const previous = previousSibling.get(parent);
      const next = previous ? previous.nextElementSibling : parent.firstElementChild;
      if (element !== next) parent.insertBefore(element, next);
      previousSibling.set(parent, element);
      seen.add(n.id);
      // Reconcile native edits even if Mojo restored the previous value.
      if (n.kind === Widget.text && !element.dataset.composing && element.value !== n.text) {
        element.value = n.text;
      } else if (n.kind === Widget.checkbox && control.checked !== n.checked) {
        control.checked = n.checked;
      }
      if (unchanged(record.node, n)) continue;
      record.node = n;
      if (control) {
        if (n.label) control.setAttribute("aria-label", n.label);
        else control.removeAttribute("aria-label");
        if (n.hint) control.setAttribute("aria-description", n.hint);
        else control.removeAttribute("aria-description");
        if ("disabled" in control) control.disabled = !n.enabled;
      }
      if (n.kind === Widget.container) {
        if (![Layout.linear, Layout.grid, Layout.portal].includes(n.layout)) {
          throw new Error("Unsupported Moxi container layout " + n.layout);
        }
        const grid = n.layout === Layout.grid;
        element.style.justifyContent = justifyContent[n.justify];
        element.style.alignItems = alignItems[n.align];
        element.style.display = grid ? "grid" : "flex";
        element.style.flexDirection = n.axis === Layout.rowAxis ? "row" : "column";
        element.style.flexWrap = n.axis === Layout.rowAxis ? "wrap" : "nowrap";
        element.style.gap = n.spacing + "px";
        element.style.padding = n.padding + "px";
        if (grid) element.style.gridTemplateColumns =
          `repeat(auto-fit,minmax(min(100%,max(9rem,calc((100% - ${(n.columns-1)*n.spacing}px) / ${n.columns}))),1fr))`;
      } else if (n.kind === Widget.canvas) {
        if (control.width !== n.width) control.width = n.width;
        if (control.height !== n.height) control.height = n.height;
        element.style.width = n.width + "px";
      } else {
        let caption = element;
        if (n.kind === Widget.text) {
          caption = null;
        } else if (n.kind === Widget.checkbox) {
          caption = element.lastElementChild;
        }
        if (caption && caption.textContent !== n.text) caption.textContent = n.text;
        if (n.width > 0) element.style.width = n.width + "px";
        element.style.minHeight = n.height + "px";
      }
      Object.assign(element.style, {
        backgroundColor: cssColor(n.fill), color: cssColor(n.ink), fontSize: n.font + "px",
        borderRadius: n.radius + "px", border: n.borderWidth + "px solid " + cssColor(n.border),
      });
    }
    for (const [id, record] of this.elements) {
      if (!seen.has(id)) { record.element.remove(); this.elements.delete(id); }
    }
  }
}
