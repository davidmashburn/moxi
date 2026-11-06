"""Evidence metadata for actual live AppKit captures, not a renderer."""
import hashlib
import json
import os
from pathlib import Path
import platform
import subprocess

class Capture:
    def __init__(self):
        self.directory=os.environ.get('MOXI_MATH_CAPTURE_DIR','')
        self.frames=[]
        self.labels=[('initial','Empty editable expression'),('interaction','Typed fraction through keyboard command path'),('interaction','Nested radical and paired scripts'),('interaction','Rectangular matrix cells and new row'),('interaction','Malformed source retained visibly'),('recovery','Undo malformed source and return to 2D'),('interaction','Selected numerator submitted asynchronously'),('recovery','Edit denominator while request runs; result is stale'),('result','Current selected-subtree result'),('result','Apply result to numerator'),('recovery','Undo result application'),('result','Save and reopen exact notation')]
        if self.directory: Path(self.directory).mkdir(parents=True,exist_ok=True)
    def configure_worker(self, session):
        if self.directory:
            # Delay only startup, then run the actual D01 SymPy worker unchanged.
            session.controller.command=[session.controller.command[0], '-c',
                'import time,runpy; time.sleep(3); runpy.run_module("moxi_math_probe.sympy_worker",run_name="__main__")']
    def path(self,index):
        return str(Path(self.directory)/f'{index+1:02d}.png')
    def record(self,index,source,revision,selected,caret,generation,measured,status,width,height):
        phase,label=self.labels[index]
        self.frames.append(dict(index=int(index),phase=phase,caption=label,source=str(source),document_revision=int(revision),selected_id=int(selected),caret_id=int(caret),geometry_generation=int(generation),measured_nodes=int(measured),status=str(status),window_points=[int(width),int(height)],capture_method='Live NSWindow contentView cacheDisplayInRect; no OS compositor or physical interaction assertion'))
    def finish(self):
        root=Path.cwd()
        files=sorted({*root.glob('src/**/*.mojo'), *root.glob('native/*.m'), *root.glob('native/*.h'), *root.glob('native/math/*'), *root.glob('python/moxi_math/*.py'), *root.glob('experiments/math-backends/moxi_math_probe/*.py'), *root.glob('examples/math/*'), *root.glob('scripts/math/*'), *root.glob('assets/math/*'), root/'pixi.toml', root/'pixi.lock'})
        digest=hashlib.sha256()
        for f in files: digest.update(str(f.relative_to(root)).encode()+b"\0"); digest.update(f.read_bytes())
        manifest=dict(version=1,demo_id='d02-native-math-editor',title='D02 · Native Moxi math editor',scenario='Editable notation, structural commands, matrix, malformed text, selected asynchronous result, undo and reopen',revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),host=platform.platform(),backend='AppKit / CoreText glyph IDs / HarfBuzz MATH',scale=1,fixture='Executable examples/math/workbench.mojo capture replay',reproduce='bash scripts/math/run.sh --capture artifacts/demo-slideshows/d02-native-math-editor; see source_provenance and frames.json fingerprint',slides=[])
        for frame in self.frames:
            # Read PNG IHDR without an imaging dependency.
            path=Path(self.path(frame['index']))
            raw=path.read_bytes()
            width=int.from_bytes(raw[16:20],'big'); height=int.from_bytes(raw[20:24],'big')
            manifest['scale']=width/frame['window_points'][0]
            manifest['slides'].append(dict(phase=frame['phase'],capture_kind='offscreen-render',image=path.name,dimensions=[width,height],caption=frame['caption']+' · live AppKit content snapshot',action=frame['caption'],expected=frame['source'],sha256=hashlib.sha256(raw).hexdigest()))
        target=Path(self.directory)
        dirty=bool(subprocess.check_output(['git','status','--porcelain','--',*[str(f.relative_to(root)) for f in files]],text=True))
        manifest['source_provenance']=dict(base_revision=manifest['revision'],uncommitted_changes=dirty,source_sha256=digest.hexdigest(),source_files=[str(f.relative_to(root)) for f in files])
        (target/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
        (target/'frames.json').write_text(json.dumps(dict(source_sha256=digest.hexdigest(),capture_method=self.frames[0]['capture_method'],base_revision=manifest['revision'],uncommitted_D02=dirty,worker_startup_delay_seconds=3,frames=self.frames),indent=2)+'\n')
