import { createHash } from "node:crypto";
import { readdir, readFile, writeFile } from "node:fs/promises";
import { dirname, join, relative } from "node:path";
import { fileURLToPath } from "node:url";
import {
  EXPERIMENT_VERSION,
  IRRELEVANT_SETTING_KEY,
  RESULT_CODE,
  SINK_KEY,
  SINK_KEYS,
  createDocumentHandle,
  createDocumentSlot,
  createInstrumentation,
  createSettingsSlot,
  mountApplication,
  mountEditorWithProviders,
  useDocument,
  useSettings,
} from "./src/app.mjs";
import { createRoot } from "solid-js";

const HERE = dirname(fileURLToPath(import.meta.url));
const RESULTS_PATH = join(HERE, "results.json");
const assertionLog = [];

function assert(condition, label, details = undefined) {
  if (!condition) {
    const suffix = details === undefined ? "" : `: ${JSON.stringify(details)}`;
    throw new Error(`Assertion failed: ${label}${suffix}`);
  }
  assertionLog.push({ label, passed: true, details });
}

function sameJSON(actual, expected, label) {
  assert(JSON.stringify(actual) === JSON.stringify(expected), label, { actual, expected });
}

function sinkZeros() {
  return Object.fromEntries(SINK_KEYS.map((key) => [key, 0]));
}

function copyMeasurement(measurement) {
  return {
    evaluations: { ...measurement.evaluations },
    changedWrites: { ...measurement.changedWrites },
    setupCount: measurement.setupCount,
    liveCount: measurement.liveCount,
    disposedCount: measurement.disposedCount,
    peakLiveCount: measurement.peakLiveCount,
  };
}

function readDocument(app) {
  const document = app.document.current();
  return {
    id: document.id,
    name: document.name,
    revision: document.revision,
    commits: document.commits,
    history: document.history,
  };
}

function setDraftAndApply(editor, draft) {
  editor.actions.setDraft(draft);
  return editor.actions.apply();
}

function assertMandatoryContexts() {
  let documentError;
  try {
    createRoot(() => useDocument());
  } catch (error) {
    documentError = error;
  }
  assert(documentError?.message === "Missing DocumentContext provider", "document context is mandatory");

  let settingsError;
  try {
    createRoot(() => useSettings());
  } catch (error) {
    settingsError = error;
  }
  assert(settingsError?.message === "Missing SettingsContext provider", "settings context is mandatory");
}

function runRequiredSequence() {
  const sequenceStart = assertionLog.length;
  assertMandatoryContexts();
  const instrumentation = createInstrumentation();
  const app = mountApplication({
    documentName: "Base",
    settings: { maxLength: 12, writable: true, [IRRELEVANT_SETTING_KEY]: "root" },
    instrumentation,
  });
  const editorA = app.getEditor("A");
  const editorB = app.getEditor("B");
  assert(app.tree.componentPath.join(" > ") === "Shell > Workspace > Group > Editor", "nested component path");
  assert(editorA !== undefined && editorB !== undefined, "two reusable editors mounted");

  let document = readDocument(app);
  assert(document.name === "Base" && document.revision === 0, "initial document state");
  assert(editorA.snapshot().sinks[SINK_KEY.CURRENT] === "Current: Base", "current sink initializes");
  assert(editorA.snapshot().sinks[SINK_KEY.APPLY_ENABLED] === true, "apply enabled initializes");

  editorA.actions.setDraft("Alpha");
  editorB.actions.setDraft("Beta");
  assert(editorA.snapshot().draft === "Alpha", "editor A keeps its private draft");
  assert(editorB.snapshot().draft === "Beta", "editor B keeps its private draft");
  assert(readDocument(app).name === "Base", "local drafts do not commit automatically");

  editorA.actions.setNote("private");
  assert(editorB.snapshot().note === "", "local note stays private");
  const successfulRename = editorA.actions.apply();
  assert(successfulRename.ok && successfulRename.code === RESULT_CODE.OK, "successful shared rename");
  document = readDocument(app);
  assert(document.name === "Alpha" && document.revision === 1, "rename updates name and revision");
  assert(document.commits.length === 1 && document.history.length === 2, "rename updates commits and history");
  assert(editorB.snapshot().draft === "Beta", "sibling draft does not auto-sync after rename");
  assert(editorB.snapshot().sinks[SINK_KEY.CURRENT] === "Current: Alpha", "shared current label updates both live editors");

  const staleRename = editorB.actions.apply();
  assert(!staleRename.ok && staleRename.code === RESULT_CODE.STALE_REVISION, "stale sibling rejects");
  assert(editorB.snapshot().sinks[SINK_KEY.ERROR].includes("stale"), "stale error reaches sibling sink");

  const reloadResult = editorB.actions.reload();
  assert(reloadResult.name === "Alpha" && reloadResult.revision === 1, "reload reads current document");
  assert(editorB.snapshot().draft === "Alpha" && editorB.snapshot().error === "", "reload replaces draft and clears error");

  const beforeNoop = JSON.stringify(readDocument(app));
  editorA.actions.setDraft("  Alpha  ");
  assert(editorA.actions.apply().ok, "normalized unchanged name succeeds");
  assert(JSON.stringify(readDocument(app)) === beforeNoop, "unchanged rename does not advance revision or history");
  editorA.actions.setDraft("   ");
  const emptyRename = editorA.actions.apply();
  assert(!emptyRename.ok && emptyRename.code === RESULT_CODE.EMPTY_NAME, "whitespace-only name rejects");
  assert(readDocument(app).name === "Alpha", "empty rejection does not mutate document");

  editorA.actions.setDraft("1234567890123");
  const longRename = editorA.actions.apply();
  assert(!longRename.ok && longRename.code === RESULT_CODE.NAME_TOO_LONG, "codepoint length rejection");
  assert(editorA.snapshot().sinks[SINK_KEY.APPLY_ENABLED] === true, "permission-only apply allows validation errors to be shown");

  app.settings.setWritable(false);
  editorA.actions.setDraft("Gamma");
  const readOnlyRename = editorA.actions.apply();
  assert(!readOnlyRename.ok && readOnlyRename.code === RESULT_CODE.READ_ONLY, "read-only rejection");
  assert(editorA.snapshot().sinks[SINK_KEY.APPLY_ENABLED] === false, "read-only disables apply");
  const readOnlyUndo = app.document.undo(app.settings);
  assert(!readOnlyUndo.ok && readOnlyUndo.code === RESULT_CODE.READ_ONLY, "undo respects read-only permission");
  assert(app.document.current().name === "Alpha", "read-only undo does not mutate document");
  app.settings.setWritable(true);

  const beforeUndoRevision = app.document.current().revision;
  const undoResult = app.document.undo(app.settings);
  assert(undoResult.ok && undoResult.code === RESULT_CODE.OK, "undo succeeds");
  document = readDocument(app);
  assert(document.name === "Base", "undo restores previous name");
  assert(document.revision === beforeUndoRevision + 1, "undo increments revision");
  assert(document.commits.length === 1, "undo does not increment rename commit count");
  assert(document.history.length === 1, "undo pops history back to initial state");
  const noHistory = app.document.undo(app.settings);
  assert(!noHistory.ok && noHistory.code === RESULT_CODE.NO_HISTORY, "exhausted undo does not toggle history forward");
  editorA.actions.reload();

  editorA.actions.setDraft("LongName");
  app.settings.setMaxLength(5);
  const maxRejected = editorA.actions.apply();
  assert(!maxRejected.ok && maxRejected.code === RESULT_CODE.NAME_TOO_LONG, "dynamic maxLength affects command validation");
  assert(editorA.snapshot().sinks[SINK_KEY.APPLY_ENABLED] === true, "maxLength is not an enabled-sink dependency");
  app.settings.setMaxLength(12);
  assert(editorA.snapshot().sinks[SINK_KEY.APPLY_ENABLED] === true, "writable apply stays enabled after maxLength change");
  app.settings.setWritable(false);
  assert(editorA.snapshot().sinks[SINK_KEY.APPLY_ENABLED] === false, "dynamic writable toggle disables apply");
  app.settings.setWritable(true);
  assert(editorA.snapshot().sinks[SINK_KEY.APPLY_ENABLED] === true, "dynamic writable toggle re-enables apply");
  const currentBeforeIrrelevant = editorA.snapshot();
  app.settings.setIrrelevant("changed");
  const currentAfterIrrelevant = editorA.snapshot();
  sameJSON(currentAfterIrrelevant.sinks, currentBeforeIrrelevant.sinks, "irrelevant settings do not change sinks");

  const shadowDocument = createDocumentHandle("Shadow", { id: "shadow-document" });
  const shadowDocumentSlot = createDocumentSlot(shadowDocument);
  const shadowSettings = createSettingsSlot({ maxLength: 5, writable: false, [IRRELEVANT_SETTING_KEY]: "shadow" });
  const shadowEditor = mountEditorWithProviders({
    owner: app.tree.owner,
    id: "shadow",
    documentSlot: shadowDocumentSlot,
    settingsSlot: shadowSettings,
    instrumentation,
  });
  assert(shadowEditor.snapshot().sinks[SINK_KEY.CURRENT] === "Current: Shadow", "nested provider shadows document");
  assert(shadowEditor.snapshot().sinks[SINK_KEY.APPLY_ENABLED] === false, "nested provider shadows settings");
  assert(app.document.current().name === "Base", "nested document does not replace root document");
  shadowSettings.setWritable(true);
  shadowEditor.actions.setDraft("Shade");
  const shadowRename = shadowEditor.actions.apply();
  assert(shadowRename.ok && shadowDocumentSlot.current().name === "Shade", "shadow editor writes shadow document");
  assert(app.document.current().name === "Base", "shadow write does not mutate root document");
  shadowEditor.dispose();

  editorB.actions.reload();
  editorB.actions.setDraft("AfterRemoval");
  const retainedApply = editorB.actions.apply;
  const disposedSinkBefore = editorB.snapshot();
  const removedEditor = app.tree.removeEditor("B");
  assert(removedEditor === editorB, "editor removal returns disposed editor");
  assert(instrumentation.snapshot().liveCount === 1, "disposed editor leaves one live editor");
  editorA.actions.reload();
  const afterRemovalRename = setDraftAndApply(editorA, "AfterRemoval");
  assert(afterRemovalRename.ok, "live sibling can write after removal");
  const disposedSinkAfterSharedWrite = editorB.snapshot();
  sameJSON(disposedSinkAfterSharedWrite.sinks, disposedSinkBefore.sinks, "disposed sink is not updated by shared write");
  sameJSON(disposedSinkAfterSharedWrite.sinkStats, disposedSinkBefore.sinkStats, "disposed sink has no further effect activity");

  editorB.actions.reload();
  editorB.actions.setDraft("RetainWrite");
  const retainedResult = retainedApply();
  assert(retainedResult.ok, "retained callback remains callable after disposal");
  assert(app.document.current().name === "RetainWrite", "retained callback still performs its domain command");
  assert(editorB.snapshot().sinks[SINK_KEY.CURRENT] === disposedSinkBefore.sinks[SINK_KEY.CURRENT], "retained callback does not revive UI sinks");

  const remountedB = app.tree.mountEditor("B");
  assert(remountedB !== editorB, "remount creates a fresh editor instance");
  assert(remountedB.snapshot().draft === "RetainWrite", "remount takes a clean draft from current document");
  assert(remountedB.snapshot().note === "", "remount does not retain private note");

  const rootSlotIdentity = app.document;
  editorA.actions.reload();
  editorA.actions.setDraft("DraftBeforeReplace");
  const currentRevision = app.document.current().revision;
  const replacement = createDocumentHandle("Replacement", {
    id: "replacement-document",
    revision: currentRevision,
  });
  app.document.replace(replacement);
  assert(app.document === rootSlotIdentity, "root document slot remains stable");
  assert(app.document.current().revision === currentRevision, "replacement keeps the same revision");
  assert(editorA.snapshot().sinks[SINK_KEY.CURRENT] === "Current: Replacement", "stable slot updates current readers");
  assert(editorA.snapshot().draft === "DraftBeforeReplace", "replacement does not auto-sync local draft");
  const replacedCommit = editorA.actions.apply();
  assert(!replacedCommit.ok && replacedCommit.code === RESULT_CODE.DOCUMENT_REPLACED, "same-revision replacement rejects stale draft");
  assert(app.document.current().name === "Replacement", "replacement guard prevents stale commit");
  editorA.actions.reload();
  assert(editorA.snapshot().draft === "Replacement", "reload adopts replacement document");
  const postReplacement = setDraftAndApply(editorA, "PostReplace");
  assert(postReplacement.ok && app.document.current().name === "PostReplace", "reloaded editor can commit replacement");

  const cycleCount = 25;
  const beforeCycles = instrumentation.snapshot();
  for (let index = 0; index < cycleCount; index += 1) {
    const id = `cycle-${index}`;
    app.tree.mountEditor(id);
    app.tree.removeEditor(id);
  }
  const afterCycles = instrumentation.snapshot();
  assert(afterCycles.liveCount === 2, "repeated mount/dispose leaves only live editors");
  assert(afterCycles.disposedCount - beforeCycles.disposedCount === cycleCount, "repeated mount/dispose disposes each temporary editor");
  instrumentation.resetActivityCounters();
  const cycleWrite = app.document.rename({
    expectedDocumentId: app.document.identity(),
    expectedRevision: app.document.current().revision,
    proposedName: "AfterCycles",
    settings: app.settings,
  });
  assert(cycleWrite.ok, "shared write after mount/dispose cycles succeeds");
  const postCycleActivity = instrumentation.snapshot();
  assert(postCycleActivity.evaluations[SINK_KEY.CURRENT] === 2, "post-cycle write only evaluates live current sinks");
  assert(postCycleActivity.changedWrites[SINK_KEY.CURRENT] === 2, "post-cycle write only changes live current sinks");

  const result = {
    finalDocument: readDocument(app),
    instrumentation: instrumentation.snapshot(),
    retainedCallback: {
      resultCode: retainedResult.code,
      callableAfterDispose: retainedResult.ok,
      disposedEditorSinkRemainedDetached: true,
    },
    repeatedMountDispose: {
      cycles: cycleCount,
      setupDelta: afterCycles.setupCount - beforeCycles.setupCount,
      disposedDelta: afterCycles.disposedCount - beforeCycles.disposedCount,
      liveAfterCycles: afterCycles.liveCount,
      postCycleActivity,
    },
  };
  app.dispose();
  assert(instrumentation.snapshot().liveCount === 0, "root disposal disposes remaining editors");
  result.assertions = assertionLog.slice(sequenceStart);
  result.assertionCount = result.assertions.length;
  result.afterRootDispose = instrumentation.snapshot();
  return result;
}

function measureScaleOperation(app, operation) {
  app.instrumentation.resetActivityCounters();
  operation();
  return copyMeasurement(app.instrumentation.snapshot());
}

function runScaleCase(editorCount) {
  const instrumentation = createInstrumentation();
  const app = mountApplication({
    documentName: "Ada",
    editorIds: Array.from({ length: editorCount }, (_, index) => `editor-${index}`),
    settings: { maxLength: 24, writable: true, [IRRELEVANT_SETTING_KEY]: 0 },
    instrumentation,
  });
  const firstEditor = app.getEditor("editor-0");
  const afterMount = instrumentation.snapshot();
  instrumentation.resetActivityCounters();
  const resetAfterMount = instrumentation.snapshot();
  assert(resetAfterMount.evaluations[SINK_KEY.CURRENT] === 0, `scale ${editorCount} counters reset after mount`);

  const operations = {
    draftEdit: measureScaleOperation(app, () => firstEditor.actions.setDraft("Local")),
    noteEdit: measureScaleOperation(app, () => firstEditor.actions.setNote("Note")),
    sharedNameRename: measureScaleOperation(app, () => {
      const current = app.document.current();
      app.document.rename({
        expectedDocumentId: app.document.identity(),
        expectedRevision: current.revision,
        proposedName: "Grace",
        settings: app.settings,
      });
    }),
    writableToggle: measureScaleOperation(app, () => app.settings.setWritable(false)),
    irrelevantSettingsProperty: measureScaleOperation(app, () => app.settings.setIrrelevant(1)),
  };

  const afterOperations = instrumentation.snapshot();
  const inferred = {
    note: "Only evaluations and changed sink writes are instrumented. These derived expectations describe the dependency graph and are not runtime counters.",
    draftEdit: {
      evaluations: { [SINK_KEY.DRAFT]: 1 },
      changedWrites: { [SINK_KEY.DRAFT]: 1 },
    },
    noteEdit: {
      evaluations: { [SINK_KEY.NOTE]: 1 },
      changedWrites: { [SINK_KEY.NOTE]: 1 },
    },
    sharedNameRename: {
      evaluations: { [SINK_KEY.CURRENT]: editorCount },
      changedWrites: { [SINK_KEY.CURRENT]: editorCount },
    },
    writableToggle: {
      evaluations: { [SINK_KEY.APPLY_ENABLED]: editorCount },
      changedWrites: { [SINK_KEY.APPLY_ENABLED]: editorCount },
    },
    irrelevantSettingsProperty: {
      evaluations: {},
      changedWrites: {},
    },
  };
  for (const [operation, expected] of Object.entries(inferred)) {
    if (operation === "note") continue;
    sameJSON(operations[operation].evaluations, { ...sinkZeros(), ...expected.evaluations }, `scale ${editorCount} ${operation} exact evaluations`);
    sameJSON(operations[operation].changedWrites, { ...sinkZeros(), ...expected.changedWrites }, `scale ${editorCount} ${operation} exact writes`);
  }
  assert(operations.sharedNameRename.evaluations[SINK_KEY.CURRENT] === editorCount, `scale ${editorCount} current fanout measured`);
  assert(operations.writableToggle.evaluations[SINK_KEY.APPLY_ENABLED] === editorCount, `scale ${editorCount} writable fanout measured`);
  assert(Object.values(operations.irrelevantSettingsProperty.evaluations).every((count) => count === 0), `scale ${editorCount} irrelevant setting has no evaluations`);
  assert(afterMount.setupCount === editorCount && afterMount.liveCount === editorCount, `scale ${editorCount} setup and live counts measured`);

  app.dispose();
  assert(instrumentation.snapshot().liveCount === 0, `scale ${editorCount} root disposal clears live editors`);
  return {
    editorCount,
    countersResetAfterMount: true,
    afterMount: {
      setupCount: afterMount.setupCount,
      liveCount: afterMount.liveCount,
      disposedCount: afterMount.disposedCount,
      peakLiveCount: afterMount.peakLiveCount,
    },
    operations,
    inferred,
    afterOperations,
    afterDispose: instrumentation.snapshot(),
  };
}

async function hashExperimentSources() {
  const files = [];
  async function visit(directory) {
    const entries = await readdir(directory, { withFileTypes: true });
    for (const entry of entries) {
      if (entry.name === "node_modules" || entry.name === "results.json") continue;
      const path = join(directory, entry.name);
      if (entry.isDirectory()) {
        await visit(path);
      } else if (entry.isFile()) {
        files.push(path);
      }
    }
  }
  await visit(HERE);
  files.sort();
  const hashes = {};
  for (const path of files) {
    const contents = await readFile(path);
    hashes[relative(HERE, path)] = createHash("sha256").update(contents).digest("hex");
  }
  return hashes;
}

async function packageMetadata() {
  const packageJson = JSON.parse(await readFile(join(HERE, "package.json"), "utf8"));
  const packageLock = JSON.parse(await readFile(join(HERE, "package-lock.json"), "utf8"));
  const solidPackage = packageLock.packages["node_modules/solid-js"];
  const resolvedSolid = fileURLToPath(import.meta.resolve("solid-js"));
  const resolvedSolidStore = fileURLToPath(import.meta.resolve("solid-js/store"));
  return {
    packageJsonVersion: packageJson.dependencies["solid-js"],
    lockfileVersion: packageLock.lockfileVersion,
    pinnedSolidVersion: solidPackage.version,
    resolvedSolid,
    resolvedSolidStore,
  };
}

async function main() {
  const metadata = await packageMetadata();
  assert(metadata.packageJsonVersion === metadata.pinnedSolidVersion, "package and lockfile pin the same Solid version");
  assert(metadata.pinnedSolidVersion === "1.9.17", "expected exact Solid version", metadata);
  assert(metadata.resolvedSolid.endsWith("/dist/solid.js"), "browser condition resolves the client Solid build", metadata.resolvedSolid);
  assert(metadata.resolvedSolidStore.endsWith("/store/dist/store.js"), "browser condition resolves the client Solid store build", metadata.resolvedSolidStore);

  const unicode = mountApplication({ documentName: "Ada", settings: { maxLength: 2 } });
  const unicodeResult = setDraftAndApply(unicode.getEditor("A"), "  é🙂  ");
  assert(unicodeResult.ok && unicode.document.current().name === "é🙂", "normalization counts Unicode code points");
  unicode.dispose();
  const sequence = runRequiredSequence();
  const scale = {};
  for (const editorCount of [2, 100, 1000]) {
    scale[String(editorCount)] = runScaleCase(editorCount);
  }

  const results = {
    assertionCount: assertionLog.length,
    assertions: [...assertionLog],
    experimentVersion: EXPERIMENT_VERSION,
    generatedAt: new Date().toISOString(),
    version: {
      solidJs: metadata.pinnedSolidVersion,
      packageJsonRange: metadata.packageJsonVersion,
      lockfileVersion: metadata.lockfileVersion,
    },
    execution: {
      mode: "headless-real-solid-client-runtime",
      command: "node --conditions=browser check.mjs",
      node: process.version,
      conditions: ["browser"],
      domRequired: false,
      resolvedSolid: metadata.resolvedSolid,
      resolvedSolidStore: metadata.resolvedSolidStore,
      instrumentation: "actual createRenderEffect callback evaluations and changed sink writes; inferred dependency counts are labeled separately",
    },
    sequence,
    scale,
    sourceHashes: await hashExperimentSources(),
  };
  await writeFile(RESULTS_PATH, `${JSON.stringify(results, null, 2)}\n`);
  console.log(JSON.stringify({
    ok: true,
    solidJs: metadata.pinnedSolidVersion,
    executionMode: results.execution.mode,
    assertions: assertionLog.length,
    scale: [2, 100, 1000],
    results: RESULTS_PATH,
  }));
}

try {
  await main();
} catch (error) {
  console.error(error.stack ?? error);
  process.exitCode = 1;
}
