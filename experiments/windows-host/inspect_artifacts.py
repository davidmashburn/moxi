"""Check this leaf's COFF/PE/import-library contract using only the standard library."""

import argparse
from enum import IntEnum
from pathlib import Path
import struct


class Machine(IntEnum):
    AMD64 = 0x8664
    ARM64 = 0xAA64


SYMBOL = b"moxi_mobile_increment\0"
DLL_NAME = b"moxi-counter.dll\0"


def require(condition, message):
    if not condition:
        raise ValueError(message)


def u16(data, offset):
    return struct.unpack_from("<H", data, offset)[0]


def u32(data, offset):
    return struct.unpack_from("<I", data, offset)[0]


def inspect(directory, machine, check_object=False):
    if check_object:
        obj = (directory / "counter.obj").read_bytes()
        require(u16(obj, 0) == machine, "COFF object machine mismatch")

    dll = (directory / DLL_NAME[:-1].decode()).read_bytes()
    require(dll[:2] == b"MZ", "missing DOS header")
    pe = u32(dll, 0x3C)
    require(dll[pe:pe + 4] == b"PE\0\0", "missing PE signature")
    require(u16(dll, pe + 4) == machine, "DLL machine mismatch")
    require(u16(dll, pe + 22) & 0x2002 == 0x2002, "PE image is not an executable DLL")
    optional = pe + 24
    require(u16(dll, optional) == 0x20B, "DLL is not PE32+")
    require(u32(dll, optional + 16) == 0, "leaf DLL unexpectedly has an entry point")
    require(u32(dll, optional + 108) >= 2, "missing PE data directories")
    export_rva, export_size, import_rva, import_size = struct.unpack_from(
        "<IIII", dll, optional + 112
    )
    require(export_rva and export_size, "missing export directory")
    require(import_rva == import_size == 0, "leaf DLL unexpectedly imports a dependency")

    sections = optional + u16(dll, pe + 20)

    def offset(rva):
        for index in range(u16(dll, pe + 6)):
            section = sections + index * 40
            size, address, raw_size, raw = struct.unpack_from("<IIII", dll, section + 8)
            if address <= rva < address + max(size, raw_size):
                require(rva - address < raw_size, "RVA has no file data")
                return raw + rva - address
        raise ValueError("RVA outside DLL sections")

    exports = offset(export_rva)
    require(u32(dll, exports + 20) == 1, "expected exactly one exported function")
    require(u32(dll, exports + 24) == 1, "expected exactly one named export")
    name = offset(u32(dll, offset(u32(dll, exports + 32))))
    require(dll[name:name + len(SYMBOL)] == SYMBOL, "wrong exported name")
    require(u16(dll, offset(u32(dll, exports + 36))) == 0, "wrong export ordinal")
    function_rva = u32(dll, offset(u32(dll, exports + 28)))
    require(function_rva != 0 and not export_rva <= function_rva < export_rva + export_size,
            "expected a function, not an export forwarder")
    offset(function_rva)

    library = (directory / "moxi-counter.lib").read_bytes()
    require(library[:8] == b"!<arch>\n", "import library is not a COFF archive")
    cursor, imports = 8, 0
    while cursor < len(library):
        header = library[cursor:cursor + 60]
        require(len(header) == 60 and header[58:] == b"`\n", "invalid archive member")
        size = int(header[48:58])
        member = library[cursor + 60:cursor + 60 + size]
        require(len(member) == size, "truncated archive member")
        if header[:16].strip() not in (b"/", b"//", b"/SYM64/"):
            if member[:4] == b"\0\0\xff\xff":
                require(u16(member, 6) == machine, "import member machine mismatch")
                require(u16(member, 18) == 4, "expected a named code import")
                require(u32(member, 12) == len(SYMBOL + DLL_NAME), "wrong import size")
                require(member[20:] == SYMBOL + DLL_NAME, "wrong imported symbol or DLL")
                imports += 1
            else:
                require(u16(member, 0) == machine, "archive member machine mismatch")
        cursor += 60 + size + size % 2
    require(cursor == len(library) and imports == 1, "expected one short import member")
    print(f"PASS: {machine.name} PE32+ DLL, one scalar export, no imports; matching import library")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("architecture", choices=[machine.name for machine in Machine])
    parser.add_argument("directory", type=Path)
    parser.add_argument("--object", action="store_true", help="also verify the build's COFF object")
    args = parser.parse_args()
    try:
        inspect(args.directory, Machine[args.architecture], args.object)
    except (OSError, ValueError, struct.error) as error:
        raise SystemExit(f"FAIL: {error}") from error
