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
const progress = '[data-moxi-id="3019"]';
const done = () => page.waitForFunction(selector => document.querySelector(selector)?.textContent.startsWith("Complete"), progress);
const depth = page.getByRole("textbox", {name: "Depth"});
const colors = page.getByRole("checkbox", {name: "Random colors"});
const guidesControl = page.getByRole("checkbox", {name: "Show guides"});
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
  const response = await page.goto(process.env.MOXI_DEMO_URL || "http://127.0.0.1:8776/experiments/fractal-web/");
  assert.doesNotMatch(await response.text(), /<(form|button|input|canvas|select)\b/i);
  await done();
  const presets = page.getByRole("button", {name: /^Presets/});
  const options = page.getByRole("button", {name: "Options", exact: true});
  const koch = page.getByRole("button", {name: "Koch Curve", exact: true});
  assert.equal(await page.getByRole("button").count(), 4);
  assert.equal(await koch.count(), 0);
  assert.equal(await colors.count(), 0);
  assert.equal(await depth.inputValue(), "5");
  await presets.click();
  assert.ok(await koch.isDisabled());
  await page.getByRole("button", {name: "Experimental", exact:true}).click();
  assert.equal(await koch.count(), 0);
  assert.ok(await page.getByRole("button", {name:"Kite Spine", exact:true}).isVisible());
  await page.getByRole("button", {name: "Classic", exact:true}).click();
  assert.match(await page.locator(progress).textContent(), /Complete · rendered 1024$/);
  await page.getByRole("button", {name: "Peano Serpent", exact: true}).click();
  assert.equal(await koch.count(), 0);
  await options.click();
  assert.equal(await colors.isChecked(), false);
  await depth.fill("6");
  await colors.check();
  await done();
  assert.match(await page.locator(progress).textContent(), /Complete · rendered 1000000/);
  const original = await digest("canvas");
  await colors.uncheck();
  await done();
  assert.notEqual(await digest("canvas"), original);
  await colors.check();
  await done();
  assert.equal(await digest("canvas"), original);
  if (output) await page.screenshot({path: path.join(output, "desktop.png")});

  const guides = await digest("canvas");
  await guidesControl.uncheck();
  await page.waitForTimeout(32);
  assert.notEqual(await digest("canvas"), guides);
  await guidesControl.check();

  // Hold after moving the baseline endpoint, and observe progress before release.
  await page.locator("canvas").scrollIntoViewIfNeeded();
  const box = await page.locator("canvas").boundingBox();
  const x = box.x + 350 / 920 * box.width, y = box.y + 150 / 620 * box.height;
  await page.mouse.move(x, y);
  await page.mouse.down();
  await page.mouse.move(x + 24, y + 15, {steps: 4});
  await done();
  assert.notEqual(await digest("canvas"), original);
  await page.mouse.up();
  await page.getByRole("button", {name:"Reset current preset"}).click();
  await done();
  assert.equal(await digest("canvas"), original);

  await depth.fill("99999999999999999999999999999999");
  await page.getByRole("button", {name: "+", exact:true}).click();
  assert.equal(await depth.inputValue(), "100000000000000000000000000000000");
  await depth.fill("oops");
  await depth.press("Enter");
  assert.equal(await depth.inputValue(), "100000000000000000000000000000000");
  assert.ok(await depth.evaluate(e => e === document.activeElement));
  await depth.fill("0");
  await done();
  assert.match(await page.locator(progress).textContent(), /^Complete · rendered 1$/);
  await presets.click();
  await koch.focus();
  await koch.press("Enter");
  assert.equal(await koch.count(), 0);
  assert.match(await presets.textContent(), /Koch Curve/);
  await depth.fill("5");
  await done();
  assert.match(await page.locator(progress).textContent(), /Complete · rendered 1024/);
  await page.setViewportSize({width: 390, height: 844});
  assert.ok(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth));
  await page.evaluate(() => window.scrollTo(0, 0));
  if (output) await page.screenshot({path: path.join(output, "mobile.png")});
  await presets.click();
  assert.ok(await koch.isDisabled());
  assert.ok(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth));
  await page.route("**/dist/fractal.wasm", route => route.fulfill({status: 404, body: ""}));
  await page.reload();
  await page.getByRole("alert").waitFor();
  assert.match(await page.getByRole("alert").textContent(), /Build/);
  assert.equal(await depth.count(), 0);
  assert.deepEqual(errors, []);
  console.log("Passed colored replay, guides, drag while held, reset, depth, preset, mobile layout and missing-module feedback.");
} finally {
  await browser.close();
}
