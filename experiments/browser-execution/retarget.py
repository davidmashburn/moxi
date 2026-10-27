"""Experimental host-IR conversion, scoped to this probe and compiler pair.

This is not a general cross compiler. Keep 64-bit pointers/Int via memory64;
removing a data layout cannot undo host-dependent lowering already performed.
"""
from pathlib import Path
import re
import sys

p = Path(sys.argv[1])
s = p.read_text()
s = re.sub(r'^target (datalayout|triple) = .*\n', '', s, flags=re.M)
s = re.sub(r' "target-[^"]+"="[^"]*"', '', s)
# LLVM 24 spelling for 64-bit floating constants -> LLVM 21 spelling.
s = re.sub(r'\bf0x([0-9A-Fa-f]{16})\b', r'0x\1', s)
# Drop an optimization promise unknown to LLVM 21; add no new promises.
s = s.replace('nocreateundeforpoison ', '')
# LLVM 24 changed lifetime intrinsic signatures. Omit these lifetime hints.
s = '\n'.join(line for line in s.splitlines() if '@llvm.lifetime.' not in line) + '\n'
for n in re.findall(r'attributes #(\d+) = \{\s*\}', s):
    s = re.sub(r'attributes #' + n + r' = \{\s*\}\n', '', s)
    s = re.sub(r' #' + n + r'\b', '', s)
p.with_suffix('.portable.ll').write_text(s)
