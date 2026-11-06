"""P01-only LLVM 24 -> Apple LLVM 21 conversion, not a portable compiler."""
from pathlib import Path
import re
import struct
import sys


def float32_hex(value):
    return '0x' + struct.pack('>d', struct.unpack('>f', struct.pack('>f', value))[0]).hex().upper()


def convert(source):
    # Mojo's UTF-8 validator uses AArch64 TBL1. Lower this exact 16-byte lookup
    # to portable LLVM: out-of-range byte indices produce zero. Never pass an
    # invalid index to extractelement (which would produce poison).
    intrinsic = 'llvm.aarch64.neon.tbl1.v16i8'
    if '@' + intrinsic in source:
        source = re.sub(r'^declare <16 x i8> @' + re.escape(intrinsic) + r'[^\n]*\n', '', source, flags=re.M)
        source = source.replace('@' + intrinsic, '@moxi_tbl1')
        body = ['define internal <16 x i8> @moxi_tbl1(<16 x i8> %table, <16 x i8> %indices) {']
        for i in range(16):
            body += [f'  %idx{i} = extractelement <16 x i8> %indices, i32 {i}',
                     f'  %ok{i} = icmp ult i8 %idx{i}, 16',
                     f'  %safe{i} = and i8 %idx{i}, 15',
                     f'  %byte{i} = extractelement <16 x i8> %table, i8 %safe{i}',
                     f'  %value{i} = select i1 %ok{i}, i8 %byte{i}, i8 0',
                     f'  %out{i} = insertelement <16 x i8> ' + ('zeroinitializer' if i == 0 else f'%out{i-1}') + f', i8 %value{i}, i32 {i}']
        body += ['  ret <16 x i8> %out15', '}']
        source += '\n' + '\n'.join(body) + '\n'
    # Reject all other host-specific operations rather than silently miscompile them.
    if re.search(r'@llvm\.(aarch64|x86|riscv)\.|\basm\s+(sideeffect\s+)?"', source):
        raise ValueError('host-specific intrinsic or inline assembly')
    source = re.sub(r'^target (datalayout|triple) = .*\n', '', source, flags=re.M)
    source = re.sub(r' "target-[^"]+"="[^"]*"', '', source)
    source = re.sub(r'\bf0x([0-9A-Fa-f]{16})\b', r'0x\1', source)
    source = re.sub(r'\bf0x([0-9A-Fa-f]{8})\b',
                    lambda m: float32_hex(struct.unpack('>f', bytes.fromhex(m[1]))[0]), source)
    lines = []
    for line in source.splitlines():
        # LLVM 24 permits rounded decimal Float32 constants that LLVM 21 rejects.
        # Only convert unambiguous float-only instructions; mixed types fail closed
        # at the downstream compiler instead of guessing an operand's type.
        if re.search(r'\bfloat\b', line) and not re.search(r'\bdouble\b', line):
            line = re.sub(r'(?<![\w.])-?\d+\.\d+e[+-]\d+',
                          lambda m: float32_hex(float(m[0])), line)
        if '@llvm.lifetime.' not in line:
            lines.append(line.replace('nocreateundeforpoison ', ''))
    source = '\n'.join(lines) + '\n'
    for number in re.findall(r'attributes #(\d+) = \{\s*\}', source):
        source = re.sub(r'attributes #' + number + r' = \{\s*\}\n', '', source)
        source = re.sub(r' #' + number + r'\b', '', source)
    return source


if __name__ == '__main__':
    path = Path(sys.argv[1])
    path.with_suffix('.portable.ll').write_text(convert(path.read_text()))
