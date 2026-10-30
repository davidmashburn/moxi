export const Code = Object.freeze({ OK: 'ok', REPLACED: 'document-replaced', READ_ONLY: 'read-only', STALE: 'stale-revision', EMPTY: 'empty-name', LONG: 'name-too-long', NO_HISTORY: 'no-history' });
export const Sink = Object.freeze({ CURRENT: 'current', DRAFT: 'draft', NOTE: 'note', ERROR: 'error', ENABLED: 'applyEnabled' });
export const keys = Object.values(Sink);
export function initial(name = 'Ada', id = 1) {
  return { id, name, revision: 0, commits: 0, history: [] };
}
export function rename(document, settings, proposed, id, revision) {
  let code = Code.OK;
  const name = proposed.trim();
  if (id !== document.id) code = Code.REPLACED;
  else if (!settings.writable) code = Code.READ_ONLY;
  else if (revision !== document.revision) code = Code.STALE;
  else if (!name) code = Code.EMPTY;
  else if ([...name].length > settings.maxLength) code = Code.LONG;
  const next = code !== Code.OK || name === document.name ? document : {
    ...document, name, revision: document.revision + 1,
    commits: document.commits + 1, history: [...document.history, document.name],
  };
  return { code, document: next };
}
export function undo(document, settings) {
  if (!settings.writable || !document.history.length) return document;
  return { ...document, name: document.history.at(-1), history: document.history.slice(0, -1), revision: document.revision + 1 };
}
