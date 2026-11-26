// Compare the original HTML panel (f0e4073) with the shared Moxi panel.
// Pass the path to a built checkout of f0e4073 and start the current demo server.
import assert from "node:assert/strict";
import path from "node:path";
import {readFile} from "node:fs/promises";

const beforeRoot = process.argv[2];
if (!beforeRoot) throw new Error("Pass the path to the built f0e4073 checkout");
const url = process.env.MOXI_DEMO_URL || "http://127.0.0.1:8776/experiments/fractal-web/";
const {chromium} = await import(process.env.MOXI_PLAYWRIGHT_MODULE || "playwright");
const browser = await chromium.launch({executablePath: process.env.MOXI_CHROME, headless: true});

async function openDemo(before) {
  const page = await browser.newPage({viewport: {width: 1280, height: 850}, deviceScaleFactor: 1});
  if (before) {
    // Serve the earlier build at the same origin. All loads finish before timing.
    const types = {".html": "text/html", ".mjs": "text/javascript", ".js": "text/javascript",
      ".wasm": "application/wasm", ".css": "text/css"};
    await page.route(new URL(url).origin + "/**", async route => {
      const pathname = new URL(route.request().url()).pathname;
      const file = path.join(beforeRoot, pathname, pathname.endsWith("/") ? "index.html" : "");
      try {
        await route.fulfill({body: await readFile(file), contentType: types[path.extname(file)]});
      } catch {
        await route.fulfill({status: 404, body: ""});
      }
    });
  }
  await page.goto(url);
  if (!before) {
    await page.getByRole("button", {name: "Peano Serpent", exact: true}).click();
    await page.getByRole("textbox", {name: "Depth"}).fill("6");
    await page.getByRole("checkbox", {name: "Random colors"}).check();
  }
  await page.waitForFunction(() => {
    const progress = document.querySelector('#status,[data-moxi-id="3019"]')?.textContent;
    return /Complete/.test(progress) && /1,000,000|1000000/.test(progress);
  });
  return page;
}

async function timeReset(page) {
  await page.bringToFront();
  return page.evaluate(async () => {
    await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
    const reset = [...document.querySelectorAll("button")].find(e => e.textContent.includes("Reset"));
    const status = document.querySelector('#status,[data-moxi-id="3019"]');
    return new Promise((resolve, reject) => {
      const timeout = setTimeout(() => reject(new Error("Timed out at " + status.textContent)), 10000);
      let sawDrawing = false;
      const observer = new MutationObserver(() => {
        if (!status.textContent.includes("Complete")) sawDrawing = true;
        else if (sawDrawing && /1,000,000|1000000/.test(status.textContent)) {
          const elapsed = performance.now() - start;
          observer.disconnect();
          clearTimeout(timeout);
          resolve(elapsed);
        }
      });
      observer.observe(status, {subtree: true, childList: true, characterData: true});
      const start = performance.now();
      reset.click();
    });
  });
}

try {
  const pages = {before: await openDemo(true), after: await openDemo(false)};
  const samples = {before: [], after: []};
  for (let trial = 0; trial < 9; trial++) {
    for (const name of trial % 2 ? ["after", "before"] : ["before", "after"]) {
      const ms = await timeReset(pages[name]);
      assert.ok(ms > 0);
      if (trial >= 2) samples[name].push(ms);
    }
  }
  console.log(JSON.stringify({chrome: browser.version(), samples}));
} finally {
  await browser.close();
}
