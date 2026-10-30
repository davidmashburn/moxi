import http from 'node:http';
import {readFile} from 'node:fs/promises';
const variants = new Set(['baseline', 'narrow', 'projected']);
const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, 'http://127.0.0.1:4179');
  const variant = url.searchParams.get('variant') ?? 'baseline';
  if (url.pathname === '/manifest.json') { res.setHeader('Content-Type', 'application/json'); res.end(await readFile('dist/manifest.json')); return; }
  if (url.pathname === '/' && variants.has(variant)) {
    res.setHeader('Content-Type', 'text/html');
    res.end(`<!doctype html><title>Marko Tags API experiment</title><h1>Marko 6: ${variant}</h1><p><a href="/?variant=baseline">Baseline</a> · <a href="/?variant=narrow">Callback alias</a> · <a href="/?variant=projected">Narrow props</a></p><button onclick="this.disabled=true; runExperiment().then(r=>{const a=document.createElement('a');a.href=URL.createObjectURL(new Blob([JSON.stringify(r,null,2)],{type:'application/json'}));a.download='browser-${variant}.json';a.click();}).catch(e=>document.querySelector('#status').textContent=e.stack)">Run checks and download results</button><pre id="status">Ready</pre><main id="fixture"></main><script type="module" src="/${variant}/check.js"></script>`);
    return;
  }
  if ([...variants].some(value => url.pathname === `/${value}/check.js`)) {
    res.setHeader('Content-Type', 'text/javascript'); res.end(await readFile('dist' + url.pathname)); return;
  }
  res.statusCode = 404; res.end();
});
server.listen(4179, '127.0.0.1', () => console.log('Marko experiment: http://127.0.0.1:4179'));
