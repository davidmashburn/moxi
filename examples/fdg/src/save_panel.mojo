"""App-owned macOS Save dialog; layout and scene modules stay portable."""
from std.ffi import external_call
from std.collections import List

def choose_svg_path() raises -> String:
    var buffer = List[UInt8]()
    for _ in range(4096):
        buffer.append(0)
    var length = external_call["fdg_choose_svg_path", Int64](buffer.unsafe_ptr(), Int64(len(buffer)))
    if length < 0:
        raise Error("Selected export path is too long or invalid")
    buffer.resize(Int(length), fill=0)
    return String(from_utf8=buffer)
