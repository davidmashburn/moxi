"""One length-prefixed UTF-8 JSON frame per message, no expression parser."""
import json
import struct
from .model import VERSION, BoundaryError

MAX_FRAME = 1024 * 1024
HEADER = struct.Struct("!I")

def pack(message):
    body = json.dumps(message, allow_nan=False, separators=(",", ":")).encode()
    if len(body) > MAX_FRAME:
        raise BoundaryError("Frame exceeds 1 MiB")
    return HEADER.pack(len(body)) + body


def exact(stream, count):
    result = bytearray()
    while len(result) < count:
        chunk = stream.read(count - len(result))
        if not chunk:
            raise EOFError("Worker stream closed mid-frame")
        result.extend(chunk)
    return bytes(result)


def read(stream):
    length = HEADER.unpack(exact(stream, HEADER.size))[0]
    if not 0 < length <= MAX_FRAME:
        raise BoundaryError("Invalid/oversized frame length")
    message = json.loads(exact(stream, length))
    if not isinstance(message, dict) or message.get("version") != VERSION:
        raise BoundaryError("Unsupported protocol version")
    return message


def write(stream, message):
    stream.write(pack(message))
    stream.flush()
