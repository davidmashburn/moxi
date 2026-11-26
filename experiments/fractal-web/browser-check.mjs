// Run against the built demo. Set MOXI_PLAYWRIGHT_MODULE to an installed Playwright.
import assert from "node:assert/strict";
import {mkdir} from "node:fs/promises";
import path from "node:path";
const {chromium} = await import(process.env.MOXI_PLAYWRIGHT_MODULE || "playwright");
const browser = await chromium.launch({
  executablePath: process.env.MOXI_CHROME,
  headless: true,
});
const page = await browser.newPage({viewport: {width: 1280, height: 850}});
const errors = [];
page.on("pageerror", error => errors.push(String(error)));
const output = process.argv[2];
if (output) await mkdir(output, {recursive: true});
const done = () => page.waitForFunction(() => document.querySelector("#status").value.includes("Complete"));
async function digest(id) {
  return page.locator(id).evaluate(async canvas => {
    const ctx = canvas.getContext("2d");
    // Chrome can change backing stores on repeated reads. Opaque pixels have
    // identical RGB on both paths, independent of alpha premultiplication.
    const bytes = ctx.getImageData(0, 0, canvas.width, canvas.height).data;
    for (let i = 0; i < bytes.length; i += 4) {
      if (bytes[i + 3] !== 255) bytes.fill(0, i, i + 4);
    }
    return Array.from(new Uint8Array(await crypto.subtle.digest("SHA-256", bytes))).join(",");
  });
}
try {
  await page.goto(process.env.MOXI_DEMO_URL || "http://127.0.0.1:8776/experiments/fractal-web/");
  await done();
  assert.match(await page.locator("#status").textContent(), /1,000,000 lines/);
  const original = await digest("#raster");
  await page.locator("#colors").uncheck();
  await done();
  assert.notEqual(await digest("#raster"), original);
  await page.locator("#colors").check();
  await done();
  assert.equal(await digest("#raster"), original);
  if (output) await page.screenshot({path: path.join(output, "desktop.png")});

  const guides = await digest("#overlay");
  await page.locator("#guides").uncheck();
  await page.waitForTimeout(32);
  assert.notEqual(await digest("#overlay"), guides);
  await page.locator("#guides").check();

  // Hold after moving the baseline endpoint, and observe progress before release.
  const box = await page.locator("#stage").boundingBox();
  const x = box.x + 350 / 920 * box.width, y = box.y + 150 / 620 * box.height;
  await page.mouse.move(x, y);
  await page.mouse.down();
  await page.mouse.move(x + 24, y + 15, {steps: 4});
  await done();
  assert.notEqual(await digest("#raster"), original);
  await page.mouse.up();
  await page.locator("#reset").click();
  await done();
  assert.equal(await digest("#raster"), original);

  await page.locator("#depth").fill("99999999999999999999999999999999");
  await page.getByRole("button", {name: "Increase depth"}).click();
  assert.equal(await page.locator("#depth").inputValue(), "100000000000000000000000000000000");
  await page.locator("#depth").fill("0");
  await done();
  assert.match(await page.locator("#status").textContent(), /^1 line/);
  await page.locator("#preset").selectOption("0");
  await page.locator("#depth").fill("5");
  await done();
  assert.match(await page.locator("#status").textContent(), /1,024 lines/);
  await page.setViewportSize({width: 390, height: 844});
  assert.ok(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth));
  if (output) await page.screenshot({path: path.join(output, "mobile.png")});
  await page.route("**/dist/fractal.wasm", route => route.fulfill({status: 404, body: ""}));
  await page.reload();
  await page.waitForFunction(() => document.querySelector("#status").textContent.includes("Build"));
  assert.ok(await page.locator("#depth").isDisabled());
  assert.deepEqual(errors, []);
  console.log("Passed colored replay, guides, drag while held, reset, depth, preset, mobile layout and missing-module feedback.");
} finally {
  await browser.close();
}
