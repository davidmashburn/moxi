"""Headless native-loop persistence transitions against real local storage."""
from std.sys import argv
from moxi_mindmap.model import MindMapDocument
from moxi_mindmap.codec import encode
from moxi_mindmap.storage import LocalFile, LocalSession, destination_file


def require(value: Bool, message: String) raises:
    if not value:
        raise Error(message)


def rejected(mut session: LocalSession, doc: MindMapDocument, generation: Int, var candidate: LocalFile) raises:
    var failed = False
    try:
        session.save_as(doc, generation, candidate^)
    except:
        failed = True
    require(failed, "Expected save failure")


def main() raises:
    var root = argv()[1]
    var session = LocalSession()
    session.draft = LocalFile(root + "/draft.moxi")
    var doc = MindMapDocument("First edit")
    _ = session.recover(doc, 1)
    var draft_path = session.draft.path
    var draft_digest = session.draft.digest
    rejected(session, doc, 1, destination_file(root + "/missing/map.moxi"))
    require(session.file.path == "" and session.saved_generation == 0, "Failed first save adopted destination or marked saved")
    require(session.draft.path == draft_path and session.draft.digest == draft_digest, "Failed first save changed draft")
    # The loop attempts recovery separately even when Save or its chooser fails.
    doc = MindMapDocument("Edit after failed save")
    _ = session.recover(doc, 2)
    var recovered = LocalFile(draft_path)
    require(encode(recovered.load(True)) == encode(doc), "Failed save stranded later draft edits")
    rejected(session, doc, 2, LocalFile())
    require(session.file.path == "" and session.saved_generation == 0, "Cancelled Save changed session")
    var cancelled = False
    try:
        _ = destination_file("")
    except:
        cancelled = True
    require(cancelled, "Empty chooser result was accepted")
    var reserved = False
    try:
        _ = destination_file(draft_path + ".recovery")
    except:
        reserved = True
    require(reserved, "Save destination was silently redirected from a recovery file to its base")
    doc = MindMapDocument("Edit after cancel")
    _ = session.recover(doc, 3)
    require(encode(recovered.load(True)) == encode(doc), "Cancelled save stranded draft recovery")
    session.save_as(doc, 3, destination_file(root + "/saved.moxi"))
    require(session.file.path == root + "/saved.moxi" and session.saved_generation == 3, "Retry failed to adopt successful destination")
    require(session.draft.path == draft_path, "Successful save discarded prior recovery path")
    _ = session.recover(doc, 3)
    recovered = LocalFile(session.file.path)
    require(encode(recovered.load(True)) == encode(doc), "Successful Save did not establish adjacent recovery")

    # Replacement confirmation snapshots an existing destination, including a
    # file other than the open document. A later external write still rejects it.
    var existing = LocalFile(root + "/existing.moxi")
    existing.save(MindMapDocument("Existing content"))
    session.save_as(doc, 3, destination_file(existing.path))
    require(session.file.path == existing.path, "Confirmed existing destination not adopted")
    var stale = destination_file(root + "/race.moxi")
    var external = LocalFile(root + "/race.moxi")
    var external_doc = MindMapDocument("External writer")
    external.save(external_doc)
    rejected(session, doc, 4, stale^)
    require(encode(external.load()) == encode(external_doc), "Destination revision guard overwrote external writer")
    require(session.file.path == existing.path and session.saved_generation == 3, "Failed Save As changed prior file")

    # Open-file conflict: ordinary Save and Save As to that same path both keep
    # the original expected revision. Draft recovery and another path escape it.
    external = LocalFile(session.file.path)
    _ = external.load()
    external.save(external_doc)
    doc = MindMapDocument("Local unsaved work")
    var failed = False
    try:
        session.save(doc, 4)
    except:
        failed = True
    require(failed and session.saved_generation == 3, "Open-file external change not guarded")
    rejected(session, doc, 4, destination_file(session.file.path))
    require(encode(external.load()) == encode(external_doc), "Reselecting open path bypassed revision guard")
    var warning = session.recover(doc, 4)
    require(warning != "" and session.recovered_generation == 4, "Open-file conflict did not report draft fallback")
    recovered = LocalFile(draft_path)
    require(encode(recovered.load(True)) == encode(doc), "Open-file conflict stranded edits")
    rejected(session, doc, 4, destination_file(root + "/missing/retry.moxi"))
    require(session.file.path == existing.path and session.draft.path == draft_path, "Failed alternate destination changed active paths")
    session.save_as(doc, 4, destination_file(root + "/rescued.moxi"))
    require(session.saved_generation == 4 and session.file.path == root + "/rescued.moxi", "Save As failed to escape external conflict")
    require(encode(external.load()) == encode(external_doc), "Save As altered original external file")
    print("PASS shared native save session: failed first save, cancel, retry, draft recovery, existing replacement, revision race, open conflict and Save As escape")
