import {initial, validate} from "./score.mjs";

export const scoreKey = "moxi.v03.score.v1";
export const recoveryKey = scoreKey + ".recovery";

function readRecoveries(storage) {
  const raw = storage.getItem(recoveryKey);
  if (raw === null) return [];
  const sources = JSON.parse(raw);
  if (!Array.isArray(sources) || !sources.every(source => typeof source === "string")) {
    throw new Error("Recovery archive could not be opened. No saved source was replaced.");
  }
  return sources;
}

// Resolve storage lazily: even access to window.localStorage can be denied.
export function openScore(storage = () => localStorage) {
  let doc = initial(), unreadableSource = null, readFailed = false;
  try {
    const raw = storage().getItem(scoreKey);
    if (raw !== null) {
      try { doc = validate(JSON.parse(raw)); }
      catch { unreadableSource = raw; }
    }
  } catch { readFailed = true; }

  return {
    doc,
    loadFailed: readFailed || unreadableSource !== null,
    get unreadableSource() { return unreadableSource; },
    recoverySources() {
      const sources = readRecoveries(storage());
      if (unreadableSource !== null && !sources.includes(unreadableSource)) sources.push(unreadableSource);
      return sources;
    },
    save(next) {
      if (readFailed) throw new Error("Saved score could not be read. Reload once storage is available before saving.");
      const raw = JSON.stringify(validate(next));
      const target = storage();
      if (unreadableSource !== null) {
        const sources = readRecoveries(target);
        if (!sources.includes(unreadableSource)) {
          // Preserve the exact original string before touching the active key.
          // If either write fails, the caller must keep its current document.
          target.setItem(recoveryKey, JSON.stringify([...sources, unreadableSource]));
        }
      }
      target.setItem(scoreKey, raw);
      unreadableSource = null;
    }
  };
}
