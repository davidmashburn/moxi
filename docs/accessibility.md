# Accessibility and native-widget contract

Moxi keeps accessibility data in the view tree and lets each platform publish
that data through its native API. The portable contract is intentionally more
precise than display text: each `Semantics` node has stable identity, a role,
label, value, hint, bounds, enabled/focused/selected state, explicit
checked/expanded state, optional numeric range metadata, and action bits.

## Portable semantics

Use the view setters when application state changes:

```mojo
node.set_accessibility_label("Playback volume")
node.set_accessibility_value("value 42")
node.set_accessibility_value_range(0.0, 100.0, 42.0)
node.set_checked(True)
node.set_expanded(False)
```

`set_accessibility_value_range` is the machine-readable path. The string
value remains useful to screen readers that want a localized description, but
native adapters do not need to parse it. `ProgressControl` publishes a
`0..1` range, `SliderControl` publishes its configured minimum/maximum/current
value, and checkbox/switch/tree/combo/dialog controls publish their boolean
state explicitly.

`AccessibilitySnapshot.is_valid()` checks duplicate ids, missing parents, and
cycles. `NativeWidgetRegistry` mirrors the same metadata for platform
presenters, so a visual widget and its accessibility node cannot silently
drift at the registry boundary.

## macOS AppKit bridge

`MacOSRenderer.update_accessibility()` rebuilds a bounded AX hierarchy for the
current laid-out frame. The AppKit bridge provides:

- stable `moxi-<id>` identifiers and parent/child navigation;
- visible-child and selected-child collections for nested list/table/tree/tab
  presenters;
- roles, labels, help text, bounds, enabled/focused/selected state;
- explicit value behavior for toggles and scalar controls, including min/max;
- dialog role/hidden state follows its open/expanded semantic state;
- AXPress, AXPick, AXIncrement, AXDecrement, AXExpand, and AXCollapse;
- value-change notifications for text, toggle, disclosure, and scalar-range
  changes, plus selected-child and focused-element notifications;
- nested hit testing that prefers the deepest control under the pointer.

The macOS SDK used by older deployments has no distinct switch role, so Moxi
uses the interoperable checkbox role with a precise `switch` role description.
This preserves compatibility while keeping the control distinguishable to
assistive technology.

## Native widget fidelity

The AppKit presenter remains custom-drawn so it can consume retained Moxi
commands without owning platform handles. The collection controls now expose
distinct visual affordances: combo open direction, selected list rows, table
headers/grid/selection, tree disclosure and branch state, menu checkmarks,
dialog title chrome, tab selection, and a canvas grid. These visuals are fed
by the same semantic selected/expanded flags used by AX.

Focused single-line text inputs now receive an AppKit `NSTextField` overlay.
AppKit owns the field editor's caret, selection, clipboard, keyboard commands,
and IME composition while Moxi continues to own the value and rebuild model.
Multiline input intentionally remains on the custom `NSTextInputClient` path
until a native text-view overlay can preserve its wrapping and composition
geometry.

This is semantic/native depth for the macOS slice, not a claim of complete
platform-native behavior. Editable table cells, menu tracking, system dialog
modality, and native ownership for every collection control remain platform
work. The contract tests assert portable state and native sources compile with
warnings as errors; device-level screen-reader automation is still a release
follow-up.

## Browser ARIA bridge

`native/hosts/moxi_web_host.mjs` exposes the same snapshot as
`host.updateAccessibility(nodes)` or an array of node objects. Pass an
optional `accessibilityTarget` DOM element to the constructor to create a
managed, positioned ARIA layer. Without a DOM (for example in a worker or a
Node test), the snapshot is still retained and the pure
`accessibilityAttributes(node)` mapper remains available.

The bridge maps roles, names, descriptions, checked/selected/expanded state,
numeric ranges, disabled state, focus order, and bounds. Enter/Space and
arrow-key activation call `callbacks.accessibilityAction(id, action)` using
the same action bits as `Semantics`. The layer is removed by `stop()`.

## iOS and Android host bridges

The iOS host exposes virtual `UIAccessibilityElement` objects through
`moxi_ios_host_set_accessibility_node()`. It preserves parent/child order,
screen-space bounds, labels, values, hints, checked/selected state, adjustable
range traits, focus notifications, and activation/increment/decrement callbacks.
The simulator demo publishes a small tree so the bridge can be inspected with
VoiceOver when run in an iOS simulator.

The Android host exposes a virtual `AccessibilityNodeProvider` without an
AndroidX dependency. The provider supports virtual hierarchy, bounds, class
roles, labels/hints/values, checkable state, accessibility focus, hover
exploration, click/adjust actions, and `ACTION_SET_TEXT`; actions cross the
NDK callback boundary as scalar target/action pairs. Its demo nodes are a
host-artifact contract test; wiring a Mojo WebAssembly/mobile runtime to
publish live snapshots remains separate work.
