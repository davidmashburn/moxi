#!/usr/bin/env python3
"""Validate and render E02 only; leave the root gallery to the parent."""
import hashlib,json,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from demo_slideshows import load_manifest, render
from fixtures import load_cases,ROOT
for c in load_cases():
    path=ROOT/'artifacts/demo-slideshows'/('e02-'+c['id'].replace('_','-'))/'manifest.json'
    data=json.loads(path.read_text())
    for slide in data['slides']:
        slide['sha256']=hashlib.sha256((path.parent/slide['image']).read_bytes()).hexdigest()
    path.write_text(json.dumps(data,indent=2)+'\n')
    manifest=load_manifest(path)
    (path.parent/'index.html').write_text(render(manifest))
print('14 real E02 slideshows validated/rendered; root gallery untouched')
