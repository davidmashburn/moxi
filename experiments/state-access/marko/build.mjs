import { build } from 'esbuild';
import { compileFileSync } from '@marko/compiler';
import { createRequire } from 'node:module';
import { mkdir, writeFile, readFile, cp } from 'node:fs/promises';
import { basename, dirname } from 'node:path';
const require = createRequire(import.meta.url);
for (const variant of ['baseline', 'narrow', 'projected']) {
  const directory = `dist/${variant}`;
  await mkdir(`${directory}/compiled`, {recursive: true});
  await cp('src', `${directory}/src`, {recursive: true});
  if (variant !== 'baseline') {
    // One-line source-level control: capture the callback as its own reactive value.
    const source = await readFile('src/editor.marko', 'utf8');
    await writeFile(`${directory}/src/editor.marko`, source.replace('<let/draft', '<const/rename=input.rename>\n<let/draft').replace('input.rename(draft', 'rename(draft'));
  }
  if (variant === 'projected') {
    for (const file of ['app', 'shell', 'workspace', 'group', 'editor']) {
      const path = `${directory}/src/${file}.marko`;
      const source = await readFile(path, 'utf8');
      await writeFile(path, source.replaceAll('settings=input.settings', 'writable=input.writable')
        .replace('settings=settings', 'writable=settings.writable').replaceAll('input.settings.writable', 'input.writable'));
    }
  }
  await cp('check.mjs', `${directory}/check.mjs`);
  const metadata = [];
  await build({
    entryPoints: [`${directory}/check.mjs`], bundle: true, outfile: `${directory}/check.js`, format: 'esm', platform: 'browser',
    define: {'process.env.NODE_ENV': '"production"'},
    plugins: [{name: 'marko', setup(build) {
      build.onLoad({filter: /\.marko$/}, async ({path}) => {
        const result = compileFileSync(path, {output: 'dom', translator: require.resolve('marko/translator'), optimize: true});
        if (result.meta.api !== 'tags' || result.meta.diagnostics?.length) throw new Error(JSON.stringify(result.meta));
        metadata.push({file: basename(path), api: result.meta.api, diagnostics: result.meta.diagnostics ?? []});
        await writeFile(`${directory}/compiled/${basename(path)}.js`, result.code);
        let code = result.code;
        if (basename(path) === 'editor.marko') {
          // AFTER dependency analysis: wrap only the five existing leaf values.
          // DOM slots are pinned to this template; fail closed if compiler output changes.
          const leaves = [
            [/(_text\(\$scope\.c, )("Current: " \+ \$scope\.\w+)(\))/, 'CURRENT'],
            [/(_attr_input_value\(\$scope, "d", )(\$scope\.\w+)(,)/, 'DRAFT'],
            [/(_attr_input_value\(\$scope, "e", )(\$scope\.\w+)(,)/, 'NOTE'],
            [/(_text\(\$scope\.i, )(\$scope\.\w+)(\))/, 'ERROR'],
            [/("disabled", !)(input_(?:settings_)?writable)(\))/, 'ENABLED'],
          ];
          for (const [pattern, key] of leaves) {
            if ([...code.matchAll(new RegExp(pattern, 'g'))].length !== 1) throw new Error(`Expected one ${key} compiled leaf`);
            code = code.replace(pattern, (_, before, value, after) => `${before}probe(Sink.${key}, ${value})${after}`);
          }
          code = 'import { probe } from "./probe.mjs";\n' + code;
          await writeFile(`${directory}/compiled/editor.instrumented.js`, code);
        }
        return {contents: code, loader: 'js', resolveDir: dirname(path)};
      });
    }}],
  });
  await writeFile(`${directory}/compiler.json`, JSON.stringify(metadata, null, 2));
  console.log(`${variant}: compiled ${metadata.length} Tags API templates`);
}
const {sources, sha} = await import('./provenance.mjs');
const artifacts = {};
for (const variant of ['baseline', 'narrow', 'projected']) {
  for (const file of ['check.js', 'compiler.json', 'compiled/editor.marko.js', 'compiled/editor.instrumented.js']) {
    const path = `dist/${variant}/${file}`;
    artifacts[path] = sha(await readFile(path));
  }
}
const lock = JSON.parse(await readFile('package-lock.json', 'utf8'));
await writeFile('dist/manifest.json', JSON.stringify({
  generatedAt: new Date().toISOString(), node: process.version,
  versions: Object.fromEntries(['marko', '@marko/compiler', 'esbuild'].map(name => [name, lock.packages[`node_modules/${name}`].version])),
  sourceHashes: await sources(), artifactHashes: artifacts,
}, null, 2));
