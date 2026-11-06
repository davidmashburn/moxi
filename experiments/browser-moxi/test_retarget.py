"""Exercise the audited IR rewrites with a separately linked Wasm fixture."""
from pathlib import Path
from retarget import convert, float32_hex

assert float32_hex(0.56) == '0x3FE1EB8520000000'
for bad in ['call void @llvm.x86.sse2.pause()', 'call void asm sideeffect "nop", ""()']:
    try:
        convert(bad)
    except ValueError:
        pass
    else:
        raise AssertionError('host-specific operation admitted')
fixture = '''declare <16 x i8> @llvm.aarch64.neon.tbl1.v16i8(<16 x i8>, <16 x i8>)
declare void @KGEN_CompilerRT_GetStackTrace()
define i32 @moxi_table(i32 %index, i32 %lane) {
  %byte = trunc i32 %index to i8
  %indices = insertelement <16 x i8> zeroinitializer, i8 %byte, i32 %lane
  %result = call <16 x i8> @llvm.aarch64.neon.tbl1.v16i8(<16 x i8> <i8 11, i8 12, i8 13, i8 14, i8 15, i8 16, i8 17, i8 18, i8 19, i8 20, i8 21, i8 22, i8 23, i8 24, i8 25, i8 26>, <16 x i8> %indices)
  %out = extractelement <16 x i8> %result, i32 %lane
  %wide = zext i8 %out to i32
  ret i32 %wide
}
define float @moxi_float32() {
  %result = fadd float f0x3F0F5C29, 5.600000e-01
  ret float %result
}
define i64 @moxi_multiply(i64 %al, i64 %ah, i64 %bl, i64 %bh, i32 %high) {
  %a0 = zext i64 %al to i128
  %a1 = zext i64 %ah to i128
  %a2 = shl i128 %a1, 64
  %a = or i128 %a0, %a2
  %b0 = zext i64 %bl to i128
  %b1 = zext i64 %bh to i128
  %b2 = shl i128 %b1, 64
  %b = or i128 %b0, %b2
  %result = mul i128 %a, %b
  %upper = lshr i128 %result, 64
  %lo = trunc i128 %result to i64
  %hi = trunc i128 %upper to i64
  %select = icmp eq i32 %high, 1
  %out = select i1 %select, i64 %hi, i64 %lo
  ret i64 %out
}
define void @moxi_fail() {
  call void @KGEN_CompilerRT_GetStackTrace()
  ret void
}
'''
Path(__file__).with_name('dist').joinpath('runtime-test.ll').write_text(convert(fixture))
print('IR audit rejection checks pass; runtime-test.ll generated')
