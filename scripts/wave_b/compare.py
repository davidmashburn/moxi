#!/usr/bin/env python3
"""Narrow geometric silhouette checks; palette/text/grid differences are excluded."""
import json, argparse, re
from xml.etree import ElementTree as ET
from pathlib import Path
import numpy as np
from PIL import Image
from fixtures import load_cases, figure
from moxi.specialized import layout, GlyphKind

def mask(path):
    rgb=np.asarray(Image.open(path).convert('RGB')).astype(float)/255
    return ((rgb.max(axis=2)-rgb.min(axis=2))>.25)&(rgb.max(axis=2)>.45)

def main():
    p=argparse.ArgumentParser();p.add_argument('reference',type=Path);p.add_argument('actual',type=Path);a=p.parse_args();result={}
    for c in load_cases():
        name=c['id'];own=mask(a.actual/(name+'-canvas.png'))
        # Plot-only crop omits the series legend swatch and axis labels.
        own=own[28:444,48:608];assert own.sum()>20,(name,'missing actual geometry')
        row=dict(moxi_colored_pixels=int(own.sum()))
        if c['reference_available']:
            ref=mask(a.reference/(name+'.png'))[28:444,48:608]
            row.update(reference_colored_pixels=int(ref.sum()),silhouette_iou=float((own&ref).sum()/max(1,(own|ref).sum())))
            if name not in ('radar','polar','beeswarm'):
                threshold=.96 if name=='gauge' else .98
                assert row['silhouette_iou']>threshold,(name,row)
                row['assertion']='Colored silhouette IoU > '+str(threshold)+'; excludes text/grid/palette identity'
            else:
                f=figure(c);g=layout(f.spec.layers[0],f.data)
                def project(x,y):return (48+(x-g.x_domain[0])/(g.x_domain[1]-g.x_domain[0])*560,28+(g.y_domain[1]-y)/(g.y_domain[1]-g.y_domain[0])*416)
                svg=ET.parse(a.reference/(name+'.svg')).getroot()
                paths=[e for e in svg.iter() if e.tag.endswith('}path')]
                if name=='radar':
                    actual=[p for glyph in g.glyphs if glyph.kind is GlyphKind.POLYGON for p in map(lambda p:project(*p),glyph.vertices)]
                    expected=[tuple(map(float,xy)) for e in paths if e.get('fill')!='none' for xy in re.findall(r'[ML]([\d.-]+),([\d.-]+)',e.get('d'))]
                    tolerance=.001
                elif name=='polar':
                    actual=[project(*glyph.bounds[:2]) for glyph in g.glyphs if glyph.kind is GlyphKind.POINT]
                    expected=[tuple(map(float,xy)) for xy in re.findall(r'[ML]([\d.-]+),([\d.-]+)',paths[0].get('d'))]
                    tolerance=.001
                else:
                    actual=[project(*glyph.bounds[:2]) for glyph in sorted(g.glyphs,key=lambda p:p.row)]
                    expected=[(float(e.get('cx')),float(e.get('cy'))) for e in svg.iter() if e.tag.endswith('}circle')]
                    tolerance=1.0 # upstream truncates/rounds pixel coordinates
                assert len(actual)==len(expected),(name,len(actual),len(expected))
                error=max(abs(x-y) for p,q in zip(actual,expected) for x,y in zip(p,q))
                assert error<=tolerance,(name,error)
                row['max_vertex_or_anchor_pixel_error']=error
                row['assertion']='Pinned SVG vertices/row anchors within '+str(tolerance)+' px; raster IoU descriptive only' 
        result[name]=row
    (a.actual/'comparison.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
if __name__=='__main__':main()
