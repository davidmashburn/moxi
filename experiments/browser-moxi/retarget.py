"""Narrow LLVM 24 to Apple LLVM 21 conversion for the browser experiments."""
import argparse
from pathlib import Path
import re
import struct


def float32_hex(value):
    return '0x' + struct.pack('>d', struct.unpack('>f', struct.pack('>f', value))[0]).hex().upper()


def lower_minmax(source):
    # Wasm min/max propagate a NaN; LLVM minnum/maxnum return the numeric operand.
    # Handle NaNs explicitly so the backend can use scalar Wasm instructions and
    # preserve signed zero without a host fmin/fmax call in the pixel loop.
    for operation, wasm_op in [('min', 'minimum'), ('max', 'maximum')]:
        for suffix, ty in [('f32', 'float'), ('f64', 'double')]:
            intrinsic = f'@llvm.{operation}num.{suffix}'
            if intrinsic + '(' not in source:
                continue
            wrapper = f'@moxi_{operation}num_{suffix}'
            target = f'@llvm.{wasm_op}.{suffix}'
            source = re.sub(r'^declare ' + ty + ' ' + re.escape(intrinsic) + r'\([^\n]*\n',
                            '', source, flags=re.M)
            source = source.replace(intrinsic + '(', wrapper + '(')
            if not re.search(r'^declare ' + ty + ' ' + re.escape(target) + r'\(', source, re.M):
                source += f'\ndeclare {ty} {target}({ty}, {ty})\n'
            source += f"""
define internal {ty} {wrapper}({ty} %a, {ty} %b) alwaysinline {{
  %a_nan = fcmp uno {ty} %a, %a
  %b_nan = fcmp uno {ty} %b, %b
  %both = call {ty} {target}({ty} %a, {ty} %b)
  %with_b = select i1 %b_nan, {ty} %a, {ty} %both
  %out = select i1 %a_nan, {ty} %b, {ty} %with_b
  ret {ty} %out
}}
"""
    return source


def convert(source, *, host_math=False):
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
    return source if host_math else lower_minmax(source)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('path', type=Path)
    parser.add_argument('--host-math', action='store_true',
                        help='retain host fmin/fmax calls for benchmark comparisons')
    args = parser.parse_args()
    args.path.with_suffix('.portable.ll').write_text(convert(args.path.read_text(), host_math=args.host_math))
