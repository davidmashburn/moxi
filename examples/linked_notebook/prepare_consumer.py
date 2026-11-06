#!/usr/bin/env python3
"""Assemble a local source-free macOS consumer; no package publication."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess

HERE=Path(__file__).resolve().parent
LIBRARIES=('libKGENCompilerRTShared.dylib','libMSupportGlobals.dylib','libAsyncRTRuntimeGlobals.dylib')


def run(*args):return subprocess.check_output(args,text=True)


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--destination',type=Path,default=Path('/tmp/moxi-p05-consumer'))
    args=parser.parse_args();dest=args.destination.resolve()
    if platform.system()!='Darwin' or platform.machine()!='arm64':
        raise RuntimeError('Clean runtime assembly validated only for macOS ARM64')
    binary=HERE/'dist/moxi-linked'
    rpaths=re.findall(r'cmd LC_RPATH\n\s+cmdsize \d+\n\s+path (.+?) \(offset',run('otool','-l',str(binary)))
    if len(rpaths)!=1 or not Path(rpaths[0]).is_absolute():raise RuntimeError('Unexpected executable rpaths')
    runtime=Path(rpaths[0]);dest.mkdir(parents=True,exist_ok=True);(dest/'lib').mkdir(exist_ok=True)
    shutil.copy2(binary,dest/'moxi-linked')
    for name in LIBRARIES:
        source=runtime/name
        dependencies=run('otool','-L',str(source))
        for dep in re.findall(r'^\s+(\S+) \(',dependencies,re.M):
            if dep.startswith('@rpath/') and Path(dep).name in LIBRARIES:continue
            if dep.startswith(('/usr/lib/','/System/Library/')):continue
            raise RuntimeError(f'Unaccounted runtime dependency: {dep}')
        shutil.copy2(source,dest/'lib'/name)
    subprocess.run(['install_name_tool','-rpath',str(runtime),'@executable_path/lib',str(dest/'moxi-linked')],check=True)
    subprocess.run(['codesign','--force','--sign','-',str(dest/'moxi-linked')],check=True,capture_output=True)
    for p in [HERE/'linked.ipynb',*sorted((HERE/'dist').glob('*.whl'))]:shutil.copy2(p,dest/p.name)
    # Actual dynamic-loader evidence, independent of the notebook test. No parent
    # environment files are renamed, removed or edited to simulate isolation.
    result=subprocess.run([str(dest/'moxi-linked'),'1','-1','0','10','20'],env=dict(os.environ,DYLD_PRINT_LIBRARIES='1'),capture_output=True,text=True,check=True,cwd=dest)
    loaded=[line for line in result.stderr.splitlines() if any(name in line for name in LIBRARIES)]
    if len(loaded)!=len(LIBRARIES) or any(str(dest/'lib') not in line for line in loaded):
        raise RuntimeError('Runtime escaped the copied consumer bundle')
    manifest={'platform':platform.platform(),'runtimeLibraries':{name:hashlib.sha256((dest/'lib'/name).read_bytes()).hexdigest() for name in LIBRARIES},'binarySha256':hashlib.sha256((dest/'moxi-linked').read_bytes()).hexdigest(),'runtimeLoadedFromConsumer':True,'dependencyScope':'copied three Mojo runtime dylibs plus macOS system libraries; no compiler/source paths in executable rpath'}
    (dest/'runtime.json').write_text(json.dumps(manifest,indent=2)+'\n')
    (dest/'loader.log').write_text('\n'.join(loaded)+'\n')
    print(json.dumps(manifest))


if __name__=='__main__':main()
