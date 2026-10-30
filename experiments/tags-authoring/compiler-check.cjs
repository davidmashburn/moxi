const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { compileFileSync } = require('@marko/compiler');
const { Compiler, compile } = require('./compile.cjs');
const translator = require.resolve('marko/translator');
const source = path.join(__dirname, 'examples');
const out = path.join(__dirname, 'generated');
const fixtures = path.join(out, 'fixtures');
fs.mkdirSync(fixtures, { recursive: true });
for (const file of fs.readdirSync(source)) fs.copyFileSync(path.join(source, file), path.join(fixtures, file));
let referenceCount = 0;
for (const file of fs.readdirSync(source)) {
  for (const output of ['html', 'dom']) {
    const result = compileFileSync(path.join(source, file), { output, translator });
    assert.equal(result.meta.api, 'tags');
    assert.equal((result.meta.diagnostics || []).length, 0);
    referenceCount++;
  }
}
console.log(`PASS ${referenceCount} reference compilations with the official Marko translator`);
// A new validation rule is written once; the existing derived value is used by preview and Save.
const form = fs.readFileSync(path.join(source, 'greeting-form.marko'), 'utf8');
fs.writeFileSync(path.join(fixtures, 'validation.marko'), form.replace('<const/valid=selected !== "">', '<const/valid=selected !== "" && selected !== "blocked">'));
compile(path.join(fixtures, 'validation.marko'), 'Validation', out);
// Changing a single prop binding must change state ownership, without changing compiler/runtime code.
const counters = fs.readFileSync(path.join(source, 'counters.marko'), 'utf8');
fs.writeFileSync(path.join(fixtures, 'ownership.marko'), counters.replace('<Counter count:=shared/>', '<Counter count=0/>'));
compile(path.join(fixtures, 'ownership.marko'), 'Ownership', out);
// The same reusable component in a conditional must lose its local state on remount.
fs.writeFileSync(path.join(fixtures, 'lifecycle.marko'), `import Counter from "./counter.marko";
<let/show=true>
<input type="checkbox" checked:=show>
<if=show><Counter count=0/></if>
`);
compile(path.join(fixtures, 'lifecycle.marko'), 'Lifecycle', out);
// Two fields share their text value but retain separate editor state.
fs.writeFileSync(path.join(fixtures, 'editors.marko'), `import NameField from "./name-field.marko";
<let/name="Ada">
<NameField label="First" value:=name/>
<NameField label="Second" value:=name/>
`);
compile(path.join(fixtures, 'editors.marko'), 'Editors', out);
console.log('PASS generated four independent source variations');
const cases = [
  ['<let/x=0><button onClick(){ x = missing; }>X</button>', /Unknown value/],
  ['<const/x=0><button onClick(){ x++; }>X</button>', /writable/],
  ['<let/x=""><input value=x>', /writable/],
  ['<let/x=0><input value:=x>', /Wrong input binding type/],
  ['<p class="big">X</p>', /Unsupported or duplicate attribute/],
  ['<for|x| of=[1, 2]><p>${x}</p></for>', /Unsupported tag/],
  ['<p>${Date.now()}</p>', /Only string.trim/],
  ['<button onClick(){ alert("hi"); }>X</button>', /Only = assignments/],
  ['<let/x=true><const/y=x && "yes"><p>${y}</p>', /require booleans/],
  ['import Counter from "./counter.marko";\n<let/x=1><Counter count=x/>', /props must be literals/],
  ['<let/x="a"><button onClick(){ x = 2; }>X</button>', /types differ/],
];
for (const [text, expected] of cases) {
  const file = path.join(fixtures, 'unsupported.marko');
  fs.writeFileSync(file, text);
  assert.throws(() => new Compiler().generate(file, 'Unsupported'), error => {
    assert.match(error.message, /unsupported.marko:\d+:\d+:/);
    assert.match(error.message, expected);
    return true;
  });
}
console.log(`PASS ${cases.length} unsupported cases rejected with source locations`);
