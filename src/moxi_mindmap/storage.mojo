"""Optional macOS local I/O adapter. Model/layout/codec remain backend neutral."""
from std.ffi import external_call
from .model import MindMapDocument
from .codec import encode, decode

@fieldwise_init
struct ResultField(Equatable, ImplicitlyCopyable):
    var value: Int
    comptime PAYLOAD = Self(0)
    comptime REPORT = Self(1)
    comptime DIGEST = Self(2)

struct LocalResult:
    var handle: UInt64
    def __init__(out self, handle: UInt64):
        self.handle = handle
    def __deinit__(deinit self):
        external_call["moxi_mm_result_free", NoneType](self.handle)
    def text(self, field: ResultField) -> String:
        var count = Int(external_call["moxi_mm_result_length", Int32](self.handle, Int32(field.value)))
        var value = String()
        var offset = 0
        while offset < count:
            var code = Int(external_call["moxi_mm_result_codepoint", Int32](self.handle, Int32(field.value), Int32(offset)))
            value += chr(code)
            offset += 2 if code > 65535 else 1
        return value
    def check(self) raises:
        if external_call["moxi_mm_result_ok", Int32](self.handle) == 0:
            raise Error(self.text(ResultField.REPORT))

struct LocalFile:
    var path: String
    var digest: String
    var report: String
    def __init__(out self, path: String = ""):
        self.path = String(path[byte=0:path.byte_length()-9]) if path.endswith(".recovery") else path
        self.digest = "absent"
        self.report = ""
    def load(mut self, recovery: Bool = False) raises -> MindMapDocument:
        var path = self.path
        var handle: UInt64
        if recovery:
            handle = external_call["moxi_mm_recover", UInt64](path.as_c_string_span().ptr())
        else:
            handle = external_call["moxi_mm_read", UInt64](path.as_c_string_span().ptr())
        var result = LocalResult(handle)
        result.check()
        var doc = decode(result.text(ResultField.PAYLOAD))
        self.digest = result.text(ResultField.DIGEST)
        self.report = result.text(ResultField.REPORT)
        return doc^
    def save(mut self, doc: MindMapDocument, recovery: Bool = False) raises:
        doc.validate()
        var path = self.path
        var payload = encode(doc)
        var expected = self.digest
        var result = LocalResult(external_call["moxi_mm_write", UInt64](path.as_c_string_span().ptr(), payload.as_c_string_span().ptr(), expected.as_c_string_span().ptr(), Int32(recovery)))
        result.check()
        self.digest = result.text(ResultField.DIGEST)
        self.report = result.text(ResultField.REPORT)

def import_mm(path: String) raises -> Tuple[MindMapDocument, String]:
    var owned = path
    var result = LocalResult(external_call["moxi_mm_import", UInt64](owned.as_c_string_span().ptr()))
    result.check()
    return (decode(result.text(ResultField.PAYLOAD)), result.text(ResultField.REPORT))

def draft_file() raises -> LocalFile:
    var result = LocalResult(external_call["moxi_mm_draft_path", UInt64]())
    result.check()
    return LocalFile(result.text(ResultField.PAYLOAD))

def destination_file(path: String) raises -> LocalFile:
    """Snapshot a confirmed Save As destination without adopting or changing it."""
    if path == "":
        raise Error("File choice cancelled")
    if path.endswith(".recovery"):
        raise Error("The .recovery suffix is reserved; choose a document destination")
    var candidate = LocalFile(path)
    var owned = candidate.path
    var result = LocalResult(external_call["moxi_mm_destination", UInt64](owned.as_c_string_span().ptr()))
    result.check()
    candidate.digest = result.text(ResultField.DIGEST)
    return candidate^

struct LocalSession:
    """Transactional file adoption and recovery, shared by the native loop/tests."""
    var file: LocalFile
    var draft: LocalFile
    var saved_generation: Int
    var recovered_generation: Int

    def __init__(out self, generation: Int = 0):
        self.file = LocalFile()
        self.draft = LocalFile()
        self.saved_generation = generation
        self.recovered_generation = generation

    def save(mut self, doc: MindMapDocument, generation: Int) raises:
        if self.file.path == "":
            raise Error("Choose a Save As destination")
        self.file.save(doc)
        self.saved_generation = generation
        self.recovered_generation = -1

    def save_as(mut self, doc: MindMapDocument, generation: Int, var candidate: LocalFile) raises:
        if candidate.path == "":
            raise Error("File choice cancelled")
        # Re-selecting the open file must not refresh away its external-change
        # guard. Save As provides an escape by choosing a different destination.
        if candidate.path == self.file.path:
            candidate.digest = self.file.digest
        candidate.save(doc)
        self.file = candidate^
        self.saved_generation = generation
        self.recovered_generation = -1

    def recover(mut self, doc: MindMapDocument, generation: Int) raises -> String:
        if generation == self.recovered_generation:
            return ""
        var warning = String()
        if self.file.path != "":
            try:
                self.file.save(doc, True)
                self.recovered_generation = generation
                return ""
            except error:
                warning = String(error)
        # A failed destination or changed open file must not strand new edits.
        # Keep the previous draft until the next successful document replacement.
        if self.draft.path == "":
            self.draft = draft_file()
        self.draft.save(doc, True)
        self.recovered_generation = generation
        return "" if warning == "" else warning + "; edits recovered in " + self.draft.path + ".recovery. Use Save As for another destination."

def choose_file(save: Bool, recovery: Bool = False) raises -> String:
    var result = LocalResult(external_call["moxi_mm_choose", UInt64](Int32(2 if recovery else Int(save))))
    result.check()
    return result.text(ResultField.PAYLOAD)
