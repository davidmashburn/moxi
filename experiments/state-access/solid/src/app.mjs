import {
  batch,
  createComponent,
  createContext,
  createRenderEffect,
  createRoot,
  createSignal,
  getOwner,
  onCleanup,
  runWithOwner,
  useContext,
} from "solid-js";
import { createStore } from "solid-js/store";

export const EXPERIMENT_VERSION = 2;

export const SINK_KEY = Object.freeze({
  CURRENT: "current",
  DRAFT: "draft",
  NOTE: "note",
  ERROR: "error",
  APPLY_ENABLED: "applyEnabled",
});

export const SINK_KEYS = Object.freeze(Object.values(SINK_KEY));

export const RESULT_CODE = Object.freeze({
  OK: "ok",
  MISSING_CONTEXT: "missing-context",
  DOCUMENT_REPLACED: "document-replaced",
  READ_ONLY: "read-only",
  STALE_REVISION: "stale-revision",
  EMPTY_NAME: "empty-name",
  NAME_TOO_LONG: "name-too-long",
  NO_HISTORY: "no-history",
});

export const COMMIT_KIND = Object.freeze({
  INITIAL: "initial",
  RENAME: "rename",
});

export const IRRELEVANT_SETTING_KEY = "irrelevant";

const UNSET = Symbol("unset");
let nextDocumentId = 1;

export const DocumentContext = createContext(undefined, { name: "DocumentContext" });
export const SettingsContext = createContext(undefined, { name: "SettingsContext" });

function missingContext(name) {
  throw new Error(`Missing ${name} provider`);
}

export function useDocument() {
  return useContext(DocumentContext) ?? missingContext("DocumentContext");
}

export function useSettings() {
  return useContext(SettingsContext) ?? missingContext("SettingsContext");
}

function makeCounterMap() {
  return Object.fromEntries(SINK_KEYS.map((key) => [key, 0]));
}

export function createInstrumentation() {
  const evaluations = makeCounterMap();
  const changedWrites = makeCounterMap();
  let setupCount = 0;
  let liveCount = 0;
  let disposedCount = 0;
  let peakLiveCount = 0;

  function registerEditor() {
    setupCount += 1;
    liveCount += 1;
    peakLiveCount = Math.max(peakLiveCount, liveCount);
    let disposed = false;
    return () => {
      if (disposed) return;
      disposed = true;
      liveCount -= 1;
      disposedCount += 1;
    };
  }

  function recordEvaluation(key) {
    evaluations[key] += 1;
  }

  function recordChangedWrite(key) {
    changedWrites[key] += 1;
  }

  function resetActivityCounters() {
    for (const key of SINK_KEYS) {
      evaluations[key] = 0;
      changedWrites[key] = 0;
    }
  }

  function snapshot() {
    return {
      evaluations: { ...evaluations },
      changedWrites: { ...changedWrites },
      setupCount,
      liveCount,
      disposedCount,
      peakLiveCount,
    };
  }

  return {
    registerEditor,
    recordEvaluation,
    recordChangedWrite,
    resetActivityCounters,
    snapshot,
  };
}

export function createDocumentHandle(name, options = {}) {
  const identity = options.id ?? `document-${nextDocumentId++}`;
  const revision = options.revision ?? 0;
  const initialHistory = options.history ?? [
    {
      kind: COMMIT_KIND.INITIAL,
      documentId: identity,
      name,
      revision,
    },
  ];
  const initialCommits = options.commits ?? [];
  const [state, setState] = createStore({
    id: identity,
    name,
    revision,
    commits: initialCommits,
    history: initialHistory,
  });
  return Object.freeze({ identity, state, setState });
}

export function createDocumentSlot(initialHandle) {
  const [handle, setHandle] = createSignal(initialHandle);

  return Object.freeze({
    current: () => handle().state,
    currentHandle: () => handle(),
    identity: () => handle().identity,
    replace(nextHandle) {
      setHandle(() => nextHandle);
    },
    rename(input) {
      return renameDocument(handle(), input);
    },
    undo(settings) {
      return undoDocument(handle(), settings);
    },
  });
}

export function createSettingsSlot(options = {}) {
  const [state, setState] = createStore({
    maxLength: options.maxLength ?? 24,
    writable: options.writable ?? true,
    [IRRELEVANT_SETTING_KEY]: options[IRRELEVANT_SETTING_KEY] ?? "initial",
  });

  return Object.freeze({
    current: () => state,
    setMaxLength(maxLength) {
      setState("maxLength", maxLength);
    },
    setWritable(writable) {
      setState("writable", writable);
    },
    setIrrelevant(value) {
      setState(IRRELEVANT_SETTING_KEY, value);
    },
  });
}

function failure(code, message, state) {
  return {
    ok: false,
    code,
    message,
    documentId: state.id,
    revision: state.revision,
    name: state.name,
  };
}

export function renameDocument(handle, input) {
  const state = handle.state;
  const settings = input.settings.current();

  if (input.expectedDocumentId !== handle.identity) {
    return failure(
      RESULT_CODE.DOCUMENT_REPLACED,
      "The document was replaced; reload this editor before applying.",
      state,
    );
  }
  if (!settings.writable) {
    return failure(RESULT_CODE.READ_ONLY, "The document is read-only.", state);
  }
  if (input.expectedRevision !== state.revision) {
    return failure(
      RESULT_CODE.STALE_REVISION,
      "The editor revision is stale; reload before applying.",
      state,
    );
  }

  const stripped = input.proposedName.trim();
  if (stripped.length === 0) {
    return failure(RESULT_CODE.EMPTY_NAME, "The name must not be empty.", state);
  }

  const codePointLength = Array.from(stripped).length;
  if (codePointLength > settings.maxLength) {
    return failure(
      RESULT_CODE.NAME_TOO_LONG,
      `The name is ${codePointLength} code points; the limit is ${settings.maxLength}.`,
      state,
    );
  }

  if (stripped === state.name) {
    return { ok: true, code: RESULT_CODE.OK, documentId: state.id,
      name: state.name, revision: state.revision };
  }

  const nextRevision = state.revision + 1;
  const commit = {
    kind: COMMIT_KIND.RENAME,
    documentId: state.id,
    from: state.name,
    to: stripped,
    revision: nextRevision,
  };
  const historyEntry = {
    kind: COMMIT_KIND.RENAME,
    documentId: state.id,
    name: stripped,
    revision: nextRevision,
  };
  batch(() => {
    handle.setState({
      name: stripped,
      revision: nextRevision,
      commits: [...state.commits, commit],
      history: [...state.history, historyEntry],
    });
  });
  return {
    ok: true,
    code: RESULT_CODE.OK,
    documentId: state.id,
    name: stripped,
    revision: nextRevision,
  };
}

export function undoDocument(handle, settings) {
  const state = handle.state;
  if (!settings.current().writable) {
    return failure(RESULT_CODE.READ_ONLY, "The document is read-only.", state);
  }
  if (state.history.length < 2) {
    return failure(RESULT_CODE.NO_HISTORY, "There is no committed name to undo.", state);
  }
  const previous = state.history[state.history.length - 2];
  const nextRevision = state.revision + 1;
  // Same contract as Mojo: pop history, advance revision, do not record a rename.
  batch(() => handle.setState({
    name: previous.name,
    revision: nextRevision,
    history: state.history.slice(0, -1),
  }));
  return { ok: true, code: RESULT_CODE.OK, documentId: state.id,
    name: state.name, revision: state.revision };
}

function createTrackedSink({ key, read, instrumentation }) {
  const state = {
    value: UNSET,
    evaluations: 0,
    changedWrites: 0,
  };
  createRenderEffect(() => {
    state.evaluations += 1;
    instrumentation.recordEvaluation(key);
    const next = read();
    if (state.value !== next) {
      state.value = next;
      state.changedWrites += 1;
      instrumentation.recordChangedWrite(key);
    }
  });
  return state;
}

function createEditorRuntime(id, dispose, instrumentation) {
  const documentSlot = useDocument();
  const settingsSlot = useSettings();
  const disposeLifecycle = instrumentation.registerEditor();
  onCleanup(disposeLifecycle);

  const initialDocument = documentSlot.current();
  const [draft, setDraft] = createSignal(initialDocument.name);
  const [note, setNote] = createSignal("");
  const [error, setError] = createSignal("");
  const [baseRevision, setBaseRevision] = createSignal(initialDocument.revision);
  const [baseDocumentId, setBaseDocumentId] = createSignal(documentSlot.identity());

  const sinks = {
    [SINK_KEY.CURRENT]: createTrackedSink({
      key: SINK_KEY.CURRENT,
      read: () => `Current: ${documentSlot.current().name}`,
      instrumentation,
    }),
    [SINK_KEY.DRAFT]: createTrackedSink({
      key: SINK_KEY.DRAFT,
      read: () => draft(),
      instrumentation,
    }),
    [SINK_KEY.NOTE]: createTrackedSink({
      key: SINK_KEY.NOTE,
      read: () => note(),
      instrumentation,
    }),
    [SINK_KEY.ERROR]: createTrackedSink({
      key: SINK_KEY.ERROR,
      read: () => error(),
      instrumentation,
    }),
    [SINK_KEY.APPLY_ENABLED]: createTrackedSink({
      key: SINK_KEY.APPLY_ENABLED,
      read: () => settingsSlot.current().writable,
      instrumentation,
    }),
  };

  function apply() {
    const result = documentSlot.rename({
      expectedDocumentId: baseDocumentId(),
      expectedRevision: baseRevision(),
      proposedName: draft(),
      settings: settingsSlot,
    });
    if (result.ok) {
      setDraft(result.name);
      setBaseRevision(result.revision);
      setBaseDocumentId(result.documentId);
      setError("");
    } else {
      setError(result.message);
    }
    return result;
  }

  function reload() {
    const current = documentSlot.current();
    setDraft(current.name);
    setBaseRevision(current.revision);
    setBaseDocumentId(documentSlot.identity());
    setError("");
    return {
      documentId: current.id,
      name: current.name,
      revision: current.revision,
    };
  }

  function snapshot() {
    return {
      id,
      baseDocumentId: baseDocumentId(),
      baseRevision: baseRevision(),
      draft: draft(),
      note: note(),
      error: error(),
      sinks: Object.fromEntries(
        SINK_KEYS.map((key) => [key, sinks[key].value === UNSET ? null : sinks[key].value]),
      ),
      sinkStats: Object.fromEntries(
        SINK_KEYS.map((key) => [key, {
          evaluations: sinks[key].evaluations,
          changedWrites: sinks[key].changedWrites,
        }]),
      ),
    };
  }

  return Object.freeze({
    id,
    actions: Object.freeze({
      apply,
      reload,
      setDraft(value) {
        batch(() => { setDraft(value); setError(""); });
      },
      setNote,
    }),
    dispose,
    snapshot,
  });
}

export function Editor(props) {
  const owner = getOwner();
  const instrumentation = props.instrumentation ?? createInstrumentation();
  return createRoot(
    (dispose) => createEditorRuntime(String(props.id), dispose, instrumentation),
    owner,
  );
}

export function Group(props) {
  const owner = getOwner();
  const editors = new Map();

  function mountEditor(id) {
    const key = String(id);
    if (editors.has(key)) {
      throw new Error(`Editor ${key} is already mounted`);
    }
    const editor = runWithOwner(owner, () => createComponent(Editor, {
      id: key,
      instrumentation: props.instrumentation,
    }));
    editors.set(key, editor);
    return editor;
  }

  function removeEditor(id) {
    const key = String(id);
    const editor = editors.get(key);
    if (editor === undefined) return undefined;
    editors.delete(key);
    editor.dispose();
    return editor;
  }

  for (const id of props.editorIds) {
    mountEditor(id);
  }

  onCleanup(() => {
    for (const editor of editors.values()) {
      editor.dispose();
    }
    editors.clear();
  });

  return Object.freeze({
    componentPath: ["Shell", "Workspace", "Group", "Editor"],
    getEditor: (id) => editors.get(String(id)),
    listEditors: () => [...editors.values()],
    mountEditor,
    removeEditor,
    owner,
  });
}

export function Workspace(props) {
  return createComponent(Group, props);
}

export function Shell(props) {
  return createComponent(Workspace, props);
}

export function mountEditorWithProviders({ owner, id, documentSlot, settingsSlot, instrumentation }) {
  const provided = runWithOwner(owner, () => createComponent(DocumentContext.Provider, {
    value: documentSlot,
    get children() {
      return createComponent(SettingsContext.Provider, {
        value: settingsSlot,
        get children() {
          return createComponent(Editor, { id, instrumentation });
        },
      });
    },
  }));
  return typeof provided === "function" ? provided() : provided;
}

export function mountApplication(options = {}) {
  const instrumentation = options.instrumentation ?? createInstrumentation();
  const initialDocument = options.document ?? createDocumentHandle(
    options.documentName ?? "Base",
    options.documentOptions,
  );
  const documentSlot = options.documentSlot ?? createDocumentSlot(initialDocument);
  const settingsSlot = options.settingsSlot ?? createSettingsSlot(options.settings);
  const editorIds = options.editorIds ?? ["A", "B"];
  let disposeRoot;
  let tree;

  createRoot((dispose) => {
    disposeRoot = dispose;
    const provided = createComponent(DocumentContext.Provider, {
      value: documentSlot,
      get children() {
        return createComponent(SettingsContext.Provider, {
          value: settingsSlot,
          get children() {
            return createComponent(Shell, {
              editorIds,
              instrumentation,
            });
          },
        });
      },
    });
    tree = typeof provided === "function" ? provided() : provided;
  });

  return Object.freeze({
    dispose: disposeRoot,
    document: documentSlot,
    settings: settingsSlot,
    tree,
    instrumentation,
    getEditor: (id) => tree.getEditor(id),
  });
}
