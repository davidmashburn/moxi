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
    const runtime = await instantiateFractal(await response.arrayBuffer());
    const start = runtime.create();
    const partial = runtime.create();
    partial.advance(128);
    const root = document.body.appendChild(document.createElement("div"));
    const view = new MoxiWidgetView(root, () => {});
    const before = start.widgets(1280, 850);
    const after = partial.widgets(1280, 850);
    const changed = after.filter((node, i) => node.text !== before[i].text);
    if (changed.length !== 1) throw new Error("Expected one progress label to change");

    view.render(before);
    const observer = new MutationObserver(() => {});
    observer.observe(root, {subtree: true, attributes: true, childList: true});
    view.render(after);
    const mutations = observer.takeRecords().length;
    observer.disconnect();

    const progress = root.querySelector(`[data-moxi-id="${changed[0].id}"]`);
    const progressIndex = after.indexOf(changed[0]);
    const owners = [start, partial];
    const snapshots = [before, after];
    const labels = snapshots.map(nodes => nodes[progressIndex].text);
    const paths = {
      directJs(index) { progress.textContent = labels[index]; },
      domOnly(index) { view.render(snapshots[index]); },
      publishAndRender(index) { view.render(owners[index].widgets(1280, 850)); },
    };
    const samples = {directJs: [], domOnly: [], publishAndRender: []};
    for (let trial = 0; trial < 9; trial++) {
      const names = Object.keys(paths);
      for (let n = 0; n < names.length; n++) {
        const name = names[(trial + n) % names.length];
        const update = paths[name];
        // Batch the single DOM write long enough to exceed the browser timer resolution.
        const repetitions = name === "directJs" ? 20000 : 200;
        const begin = performance.now();
        for (let i = 0; i < repetitions; i++) update(i % 2);
        const ms = (performance.now() - begin) / repetitions;
        if (progress.textContent !== labels[1]) throw new Error("Wrong progress text on " + name);
        if (trial >= 2) samples[name].push(ms);
      }
    }
    for (const owner of owners) owner.dispose();
    const timings = Object.fromEntries(Object.entries(samples).map(([name, trials]) => [
      name, {medianMs: trials.toSorted((a, b) => a - b)[3], samples: trials},
    ]));
    return {nodes: before.length, mutations, ...timings.domOnly, timings};
  });
  console.log(JSON.stringify({chrome: browser.version(), ...result}));
} finally {
  await browser.close();
}
