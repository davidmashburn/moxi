"""Exercise the real native I/O boundary without launching another application."""
import ctypes as c
import hashlib
from pathlib import Path
import sys
import tempfile
lib=c.CDLL(sys.argv[1])
for name, args in {'read':[c.c_char_p], 'write':[c.c_char_p]*3+[c.c_int], 'recover':[c.c_char_p], 'import':[c.c_char_p]}.items():
    f=getattr(lib,'moxi_mm_'+name); f.argtypes=args; f.restype=c.c_uint64
for name,args,ret in [('result_ok',[c.c_uint64],c.c_int),('result_length',[c.c_uint64,c.c_int],c.c_int),('result_codepoint',[c.c_uint64,c.c_int,c.c_int],c.c_int),('result_free',[c.c_uint64],None)]:
    f=getattr(lib,'moxi_mm_'+name);f.argtypes=args;f.restype=ret

def call(name,*args):
    h=getattr(lib,'moxi_mm_'+name)(*[a.encode() if isinstance(a,str) else a for a in args]); fields=[]
    try:
        for f in range(3):
            out='';i=0
            while i<lib.moxi_mm_result_length(h,f):
                cp=lib.moxi_mm_result_codepoint(h,f,i);out+=chr(cp);i+=2 if cp>65535 else 1
            fields.append(out)
        return bool(lib.moxi_mm_result_ok(h)),fields
    finally:lib.moxi_mm_result_free(h)

with tempfile.TemporaryDirectory(prefix='moxi-d04-storage-') as temp:
    p=Path(temp)/'map.moxi'; text='MOXI-MINDMAP\t1\t1\t2\t0\nT\t1\t-1\t1\t0\t0\t0\t日本語 🙂\t\t\t\t\n'
    ok,r=call('write',str(p),text,'absent',0);assert ok,r
    digest=r[2];assert p.read_text()==text
    assert not call('write',str(p),'bad','absent',0)[0] and p.read_text()==text
    assert call('write',str(p),text+'\n',digest,1)[0]
    assert call('recover',str(p))[1][0]==text+'\n' and p.read_text()==text
    p.write_text('external');assert not call('recover',str(p))[0]
    for data in (b'\xff', b'nul\x00value'):
        p.write_bytes(data); assert not call('read',str(p))[0]
        assert not call('import',str(p))[0]
    # Interrupted envelope and failed destination leave the saved file intact.
    p.write_text(text)
    Path(str(p)+'.recovery').write_text('MOXI-RECOVERY\t1\ttruncated')
    assert not call('recover',str(p))[0] and p.read_text()==text
    assert not call('write',str(Path(temp)/'missing'/'map.moxi'),text,'absent',0)[0]
    symlink=Path(temp)/'symlink';symlink.symlink_to(p)
    assert not call('read',str(symlink))[0]
    assert not call('write',str(symlink),'bad',digest,0)[0]
    for name in ('supported','loss'):
        path=Path('tests/mindmap/fixtures')/(name+'.mm');before=path.read_bytes()
        ok,r=call('import',str(path));assert ok,r
        assert path.read_bytes()==before and 'never become' not in r[0]
        if name=='loss':assert 'Element omitted' in r[1] and 'javascript' not in r[0]
    bad=['<map><node ID="x"><node ID="x"/></node></map>','<!DOCTYPE map [<!ENTITY x SYSTEM "file:///etc/passwd">]><map><node TEXT="&x;"/></map>','<map><node></map>','<map><node/><node/></map>', '<map>'+('<node>'*258)+('</node>'*258)+'</map>', '<map><node TEXT="'+('a'*65537)+'"/></map>', '<map><node>'+('<node/>'*10000)+'</node></map>']
    for i,data in enumerate(bad):
        path=Path(temp)/f'bad{i}.mm';path.write_text(data);assert not call('import',str(path))[0],i
    path=Path(temp)/'misnested.mm'
    path.write_text('<map><node><icon BUILTIN="x"><node TEXT="misnested"/></icon></node></map>')
    assert not call('import',str(path))[0]
    path.write_text('<map extra="x"><node POSITION="unknown" FOLDED="unknown"><icon BUILTIN="x" extra="y"/></node></map>')
    ok, report=call('import',str(path)); assert ok, report
    assert all(word in report[1] for word in ('POSITION','FOLDED','Map attribute','Icon attribute'))
    p.write_bytes(b'x'*8388609);assert not call('read',str(p))[0]
print('PASS native atomic save, revision guard, recovery mismatch, UTF-8, symlink/size/depth/ID/XXE/malformed rejection, inert loss report')
