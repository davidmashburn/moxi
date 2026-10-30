// An intentionally small Marko-AST -> Moxi experiment, not a Marko translator.
const fs = require('node:fs');
const path = require('node:path');
const { compileFileSync } = require('@marko/compiler');
const translator = require.resolve('marko/translator');
const literal = JSON.stringify;
const value = (code, type, writable = false) => ({ code, type, writable });
const truth = x => x.type === 'Bool' ? x.code : `(${x.code} != ${x.type === 'String' ? '""' : '0'})`;
const string = x => x.type === 'String' ? x.code : `String(${x.code})`;

class Compiler {
  constructor() { this.fields = []; this.nodes = []; this.regions = []; this.serial = 0; this.stack = []; }
  error(n, message) {
    throw new Error(`${this.file}:${n?.loc?.start.line || 1}:${(n?.loc?.start.column || 0) + 1}: ${message}`);
  }
  require(ok, n, message) { if (!ok) this.error(n, message); }
  expression(n, env, inputs) {
    const e = x => this.expression(x, env, inputs);
    switch (n?.type) {
      case 'StringLiteral': return value(literal(n.value), 'String');
      case 'NumericLiteral':
        this.require(Number.isSafeInteger(n.value), n, 'Only safe integer literals are supported');
        return value(String(n.value), 'Int');
      case 'BooleanLiteral': return value(n.value ? 'True' : 'False', 'Bool');
      case 'Identifier':
        this.require(Object.hasOwn(env, n.name), n, `Unknown value ${n.name}`);
        return env[n.name];
      case 'MemberExpression':
        this.require(!n.computed && n.object.name === 'input' && Object.hasOwn(inputs, n.property.name), n, 'Only supplied input properties are supported');
        return inputs[n.property.name];
      case 'UnaryExpression': {
        this.require(n.operator === '!', n, 'Only ! is supported');
        return value(`(not ${truth(e(n.argument))})`, 'Bool');
      }
      case 'ConditionalExpression': {
        const a = e(n.consequent), b = e(n.alternate);
        this.require(a.type === b.type, n, 'Conditional branches must have the same type');
        return value(`(${a.code} if ${truth(e(n.test))} else ${b.code})`, a.type);
      }
      case 'BinaryExpression': {
        const a = e(n.left), b = e(n.right);
        this.require(a.type === b.type && ['===', '!==', '+', '>', '>=', '<', '<='].includes(n.operator), n, 'Unsupported binary expression');
        this.require(n.operator !== '+' || a.type !== 'Bool', n, 'Boolean addition is unsupported');
        const op = { '===': '==', '!==': '!=' }[n.operator] || n.operator;
        return value(`(${a.code} ${op} ${b.code})`, op === '+' ? a.type : 'Bool');
      }
      case 'LogicalExpression': {
        this.require(['&&', '||'].includes(n.operator), n, 'Unsupported logical operator');
        const a = e(n.left), b = e(n.right);
        this.require(a.type === 'Bool' && b.type === 'Bool', n, 'Logical operators require booleans in this subset');
        return value(`(${a.code} ${n.operator === '&&' ? 'and' : 'or'} ${b.code})`, 'Bool');
      }
      case 'CallExpression': {
        this.require(n.callee.type === 'MemberExpression' && !n.callee.computed && n.callee.property.name === 'trim' && n.arguments.length === 0, n, 'Only string.trim() calls are supported');
        const a = e(n.callee.object);
        this.require(a.type === 'String', n, 'trim() requires a string');
        return value(`String(${a.code}.strip())`, 'String');
      }
      case 'TemplateLiteral': {
        const parts = [];
        n.quasis.forEach((q, i) => { parts.push(literal(q.value.cooked)); if (i < n.expressions.length) parts.push(string(e(n.expressions[i]))); });
        return value(`(${parts.join(' + ')})`, 'String');
      }
      default: this.error(n, `Unsupported expression ${n?.type}`);
    }
  }
  writable(n, env, inputs) {
    const x = this.expression(n, env, inputs);
    this.require(x.writable, n, 'Binding/assignment requires a writable value');
    return x;
  }
  field(name, initial, region) {
    const field = { name: `s${this.serial++}_${name}`, type: initial.type, initial: initial.code, region };
    this.fields.push(field);
    return value(`self.${field.name}`, field.type, true);
  }
  attributes(n, allowed) {
    const attrs = Object.create(null);
    for (const a of n.attributes) {
      this.require(a.type === 'MarkoAttribute' && allowed.includes(a.name) && !Object.hasOwn(attrs, a.name) && !a.modifier, a, `Unsupported or duplicate attribute ${a.name || a.type}`);
      attrs[a.name] = a;
    }
    return attrs;
  }
  text(body, env, inputs) {
    const parts = body.map(n => {
      if (n.type === 'MarkoText') return literal(n.value.replace(/\s+/g, ' '));
      this.require(n.type === 'MarkoPlaceholder' && n.escape, n, 'Only text and escaped placeholders are supported here');
      return string(this.expression(n.value, env, inputs));
    });
    return parts.length ? `String((${parts.join(' + ')}).strip())` : '""';
  }
  statements(n, env, inputs) {
    this.require(n.type === 'FunctionExpression' && !n.async && !n.generator && n.params.length === 0, n, 'onClick requires a synchronous zero-argument function');
    this.require(n.body.body.length > 0, n, 'Empty handlers are unsupported');
    return n.body.body.map(s => {
      this.require(s.type === 'ExpressionStatement', s, 'Handlers support assignments and integer increments only');
      const a = s.expression;
      if (a.type === 'UpdateExpression') {
        const x = this.writable(a.argument, env, inputs);
        this.require(x.type === 'Int' && a.operator === '++', a, 'Only integer ++ is supported');
        return `${x.code} += 1`;
      }
      this.require(a.type === 'AssignmentExpression' && a.operator === '=', a, 'Only = assignments and ++ are supported');
      const x = this.writable(a.left, env, inputs), y = this.expression(a.right, env, inputs);
      this.require(x.type === y.type, a, 'Assignment types differ');
      return `${x.code} = ${y.code}`;
    });
  }
  fileBody(filename, inputs, region = null) {
    const prior = this.file;
    this.file = path.resolve(filename);
    this.require(!this.stack.includes(this.file), null, 'Recursive components are unsupported');
    this.stack.push(this.file);
    const ast = compileFileSync(this.file, { output: 'source', ast: true, code: false, translator }).ast;
    const env = Object.create(null), imports = Object.create(null);
    const result = this.body(ast.program.body, env, inputs, imports, region);
    this.stack.pop(); this.file = prior;
    return result;
  }
  body(body, env, inputs, imports, region) {
    let returned;
    for (const n of body) {
      if (n.type === 'ImportDeclaration') {
        this.require(n.specifiers.length === 1 && n.specifiers[0].type === 'ImportDefaultSpecifier' && /^\.\/[^/]+\.marko$/.test(n.source.value), n, 'Only sibling .marko default imports are supported');
        imports[n.specifiers[0].local.name] = path.resolve(path.dirname(this.file), n.source.value);
        continue;
      }
      if (n.type === 'MarkoText' && !n.value.trim()) continue;
      this.require(n.type === 'MarkoTag' && n.name.type === 'StringLiteral' && !n.arguments?.length && !n.body.params.length && !n.attributeTags.length, n, 'Unsupported tag structure');
      const tag = n.name.value;
      const declare = x => {
        this.require(n.var?.type === 'Identifier' && !Object.hasOwn(env, n.var.name), n, 'Tag variable must be a new identifier');
        env[n.var.name] = x;
      };
      if (['let', 'const', 'return'].includes(tag)) {
        const a = this.attributes(n, ['value']).value;
        this.require(a && !n.body.body.length, n, `${tag} needs a value and no body`);
        const x = this.expression(a.value, env, inputs);
        if (tag === 'return') {
          this.require(!returned && !n.var && a.bound && x.writable, n, 'Only one unconditional writable return is supported');
          returned = x;
        } else if (tag === 'const') {
          this.require(!a.bound, a, 'const cannot be bound'); declare({ ...x, writable: false });
        } else {
          // A controllable let aliases a supplied binding; a literal input initializes local state.
          this.require(!a.bound || (a.value.type === 'MemberExpression' && a.value.object.name === 'input'), a, 'Controllable let must bind input.property');
          declare(a.bound && x.writable ? x : this.field(n.var?.name || 'value', x, region));
        }
        continue;
      }
      if (Object.hasOwn(imports, tag)) {
        this.require(!n.body.body.length, n, 'Component body content is unsupported');
        const supplied = Object.create(null);
        for (const a of n.attributes) {
          this.require(a.type === 'MarkoAttribute' && !a.default && !a.modifier && !Object.hasOwn(supplied, a.name), a, 'Unsupported component attribute');
          const x = a.bound ? this.writable(a.value, env, inputs) : this.expression(a.value, env, inputs);
          // Reactive readonly props need a separate implementation; do not quietly freeze them.
          this.require(a.bound || ['StringLiteral', 'NumericLiteral', 'BooleanLiteral'].includes(a.value.type), a, 'Unbound props must be literals in this experiment');
          supplied[a.name] = { ...x, writable: !!a.bound };
        }
        const result = this.fileBody(imports[tag], supplied, region);
        if (n.var) { this.require(result, n, 'Child has no return'); declare(result); }
        continue;
      }
      this.require(!n.var, n, `Tag variables unsupported on ${tag}`);
      if (tag === 'if') {
        const a = this.attributes(n, ['value']).value;
        this.require(a && !a.bound, n, 'if requires an unbound condition');
        const r = { name: `mounted${this.regions.length}`, condition: truth(this.expression(a.value, env, inputs)), parent: region };
        this.regions.push(r);
        const result = this.body(n.body.body, { ...env }, inputs, { ...imports }, r);
        this.require(!result, n, 'Conditional returns are unsupported');
        continue;
      }
      this.require(['p', 'label', 'button', 'input'].includes(tag), n, `Unsupported tag ${tag}`);
      const a = this.attributes(n, tag === 'input' ? ['value', 'type', 'checked', 'aria-label'] : tag === 'button' ? ['disabled', 'onClick'] : []);
      const node = { id: this.nodes.length + 1, tag, region, source: `${path.basename(this.file)}:${n.loc.start.line}` };
      if (tag === 'input') {
        this.require(!n.body.body.length, n, 'Input cannot have body content');
        const kind = a.type?.value;
        this.require(!kind || (kind.type === 'StringLiteral' && ['checkbox', 'text'].includes(kind.value) && !a.type.bound), n, 'Only text and checkbox inputs are supported');
        node.tag = kind?.value === 'checkbox' ? 'checkbox' : 'input';
        const binding = a[node.tag === 'checkbox' ? 'checked' : 'value'];
        this.require(binding?.bound && !(a.checked && a.value), n, 'Input needs exactly one writable value/checked binding');
        node.binding = this.writable(binding.value, env, inputs);
        this.require(node.binding.type === (node.tag === 'checkbox' ? 'Bool' : 'String'), n, 'Wrong input binding type');
        if (a['aria-label']) {
          this.require(!a['aria-label'].bound, n, 'aria-label cannot be bound');
          node.label = this.expression(a['aria-label'].value, env, inputs);
          this.require(node.label.type === 'String', n, 'aria-label must be a string');
        }
        if (node.tag === 'input') node.editor = `editor${node.id}`;
      } else {
        node.text = this.text(n.body.body, env, inputs);
        if (tag === 'button') {
          this.require(a.onClick && !a.onClick.bound && !a.disabled?.bound, n, 'Button requires onClick; bound attributes unsupported');
          node.actions = this.statements(a.onClick.value, env, inputs);
          node.enabled = a.disabled ? `(not ${truth(this.expression(a.disabled.value, env, inputs))})` : 'True';
        }
      }
      this.nodes.push(node);
    }
    return returned;
  }
  generate(filename, name) {
    this.fileBody(filename, Object.create(null));
    const lines = ['# Generated by compile.cjs. Edit the .marko sources.', 'from moxi import ColumnView, Component, Event, Rect, TextInputState', 'from runtime import available, activated, edit, add_input', '', `struct ${name}(Component):`];
    const put = (n, s) => lines.push('    '.repeat(n) + s);
    const editors = this.nodes.filter(n => n.editor);
    for (const f of this.fields) put(1, `var ${f.name}: ${f.type}`);
    for (const r of this.regions) put(1, `var ${r.name}: Bool`);
    for (const n of editors) put(1, `var ${n.editor}: TextInputState`);
    put(1, 'def __init__(out self):');
    for (const f of this.fields) put(2, `self.${f.name} = ${f.initial}`);
    for (const r of this.regions) put(2, `self.${r.name} = False`);
    for (const n of editors) put(2, `self.${n.editor} = TextInputState(${n.binding.code})`);
    put(2, 'self.settle()');
    put(1, 'def settle(mut self):');
    if (!this.regions.length && !editors.length) put(2, 'pass');
    for (const r of this.regions) {
      put(2, `var next_${r.name} = ${r.parent ? `self.${r.parent.name} and ` : ''}${r.condition}`);
      put(2, `if next_${r.name} and not self.${r.name}:`);
      put(3, 'pass');
      for (const f of this.fields.filter(f => f.region === r)) put(3, `self.${f.name} = ${f.initial}`);
      for (const n of editors.filter(n => n.region === r)) put(3, `self.${n.editor} = TextInputState(${n.binding.code})`);
      put(2, `self.${r.name} = next_${r.name}`);
    }
    for (const n of editors) {
      put(2, `if ${n.region ? `self.${n.region.name} and ` : ''}self.${n.editor}.text != ${n.binding.code}:`);
      put(3, `self.${n.editor}.set_text(${n.binding.code})`);
    }
    put(1, 'def build(self, bounds: Rect) -> ColumnView:');
    put(2, 'var view = ColumnView(bounds, 16.0, 8.0)');
    for (const n of this.nodes) {
      let indent = 2;
      if (n.region) { put(2, `if self.${n.region.name}:`); indent = 3; }
      if (n.tag === 'input') put(indent, `add_input(view, ${n.id}, self.${n.editor})`);
      else if (n.tag === 'checkbox') put(indent, `view.add_checkbox(${n.id}, "", ${n.binding.code}, 24.0)`);
      else if (n.tag === 'button') put(indent, `view.add_button_enabled(${n.id}, ${n.text}, 36.0, ${n.enabled})`);
      else put(indent, `view.add_label(${n.id}, ${n.text}, 24.0)`);
      if (n.label) put(indent, `view.set_accessibility_label(${n.id}, ${n.label.code})`);
    }
    put(2, 'view.layout()'); put(2, 'return view^');
    put(1, 'def update(mut self, event: Event, view: ColumnView) -> Bool:');
    put(2, 'if not available(view, event.target):'); put(3, 'return False');
    for (const n of this.nodes.filter(n => ['input', 'button', 'checkbox'].includes(n.tag))) {
      put(2, `if event.target == ${n.id}${n.region ? ` and self.${n.region.name}` : ''}:`);
      put(3, `if ${n.editor ? `edit(self.${n.editor}, event)` : 'activated(event)'}:`);
      if (n.editor) put(4, `${n.binding.code} = self.${n.editor}.text`);
      else if (n.tag === 'checkbox') put(4, `${n.binding.code} = not ${n.binding.code}`);
      else for (const action of n.actions) put(4, action);
      put(4, 'self.settle()'); put(4, 'return True');
    }
    put(2, 'return False');
    // Clipboard hooks keep the logical value synchronized after native editing.
    for (const operation of ['copy', 'cut', 'paste']) {
      put(1, `def clipboard_${operation}(mut self, target: Int, ${operation === 'paste' ? 'text: String, ' : ''}view: ColumnView) -> ${operation === 'paste' ? 'Bool' : 'String'}:`);
      for (const n of editors) {
        put(2, `if target == ${n.id} and available(view, target):`);
        if (operation === 'copy') put(3, `return self.${n.editor}.selected_text()`);
        else if (operation === 'cut') {
          put(3, `var copied = self.${n.editor}.selected_text()`);
          put(3, `_ = self.${n.editor}.cut_selection()`);
          put(3, `${n.binding.code} = self.${n.editor}.text`);
          put(3, 'self.settle()'); put(3, 'return copied');
        } else {
          put(3, `var changed = self.${n.editor}.insert_text(text)`);
          put(3, `${n.binding.code} = self.${n.editor}.text`);
          put(3, 'self.settle()'); put(3, 'return changed');
        }
      }
      put(2, `return ${operation === 'paste' ? 'False' : '""'}`);
    }
    return { code: lines.join('\n') + '\n', manifest: this.nodes.map(({ id, tag, source }) => ({ id, tag, source })) };
  }
}
function compile(filename, name, directory) {
  const result = new Compiler().generate(filename, name);
  fs.mkdirSync(directory, { recursive: true });
  fs.writeFileSync(path.join(directory, `${name}.mojo`), result.code);
  fs.writeFileSync(path.join(directory, `${name}.json`), JSON.stringify(result.manifest, null, 2) + '\n');
  return result;
}
module.exports = { Compiler, compile };
if (require.main === module) {
  const out = path.join(__dirname, 'generated');
  for (const [file, name] of [['counters', 'Counters'], ['greeting-form', 'GreetingForm']]) {
    const result = compile(path.join(__dirname, 'examples', file + '.marko'), name, out);
    console.log(`${file}.marko -> ${name}.mojo (${result.manifest.length} native controls)`);
  }
}
