// Run with the demo server up and the same Chrome/Playwright settings as browser-check.mjs.
const {chromium} = await import(process.env.MOXI_PLAYWRIGHT_MODULE || "playwright");
const browser = await chromium.launch({executablePath: process.env.MOXI_CHROME, headless: true});
try {
  const page = await browser.newPage({viewport: {width: 1280, height: 850}});
  await page.goto(process.env.MOXI_DEMO_URL || "http://127.0.0.1:8776/experiments/fractal-web/");
  await page.getByRole("button", {name: "Koch Curve", exact: true}).waitFor();
  const result = await page.evaluate(async () => {
    const {MoxiWidgetView} = await import("../../native/hosts/moxi_web_view.mjs");
    const {instantiateFractal} = await import("./runtime.mjs");
    const response = await fetch("./dist/fractal.wasm");
    const app = (await instantiateFractal(await response.arrayBuffer())).create();
    const root = document.body.appendChild(document.createElement("div"));
    const view = new MoxiWidgetView(root, () => {});
    const before = app.widgets(1280, 850);
    app.advance(128);
    const after = app.widgets(1280, 850);
    app.dispose();

    view.render(before);
    const observer = new MutationObserver(() => {});
    observer.observe(root, {subtree: true, attributes: true, childList: true});
    view.render(after);
    const mutations = observer.takeRecords().length;
    observer.disconnect();

    const samples = [];
    const repetitions = 200;
    for (let trial = 0; trial < 9; trial++) {
      const start = performance.now();
      for (let i = 0; i < repetitions; i++) view.render(i % 2 ? after : before);
      const ms = (performance.now() - start) / repetitions;
      if (trial >= 2) samples.push(ms);
    }
    return {nodes: before.length, mutations, medianMs: samples.toSorted((a, b) => a - b)[3], samples};
  });
  console.log(JSON.stringify({chrome: browser.version(), ...result}));
} finally {
  await browser.close();
}
