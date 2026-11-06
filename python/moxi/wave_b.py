"""Specialized Wave B geometry. See docs/plot-specialized-wave-b.md.

Radial, KDE, swarm and stream algorithms adapted from dataviz_mojo v0.8.0
3fd5a7e7c622d6130c99a290b88c4fee039deab2 (MIT; wave_a/DATAVIZ-LICENSE).
Contours are Moxi's piecewise-linear grid algorithm: that pin has no contour API.
"""
from enum import Enum
from math import cos, sin, pi, sqrt, exp, isfinite, floor
from .specialized import Glyph, GlyphKind, Layout, PALETTE, INK


class WaveBMark(str, Enum):
    PIE = 'pie'
    DONUT = 'donut'
    RADAR = 'radar'
    GAUGE = 'gauge'
    POLAR = 'polar'
    POLAR_BAR = 'polar_bar'
    RADIALBAR = 'radialbar'
    BEESWARM = 'beeswarm'
    VIOLIN = 'violin'
    RIDGELINE = 'ridgeline'
    NIGHTINGALE = 'nightingale'
    STREAMGRAPH = 'streamgraph'
    CONTOUR = 'contour'
    CONTOURF = 'contourf'


RADIAL = frozenset((WaveBMark.PIE, WaveBMark.DONUT, WaveBMark.RADAR,
                   WaveBMark.GAUGE, WaveBMark.POLAR, WaveBMark.POLAR_BAR,
                   WaveBMark.RADIALBAR, WaveBMark.NIGHTINGALE))
DISTRIBUTIONS = frozenset((WaveBMark.BEESWARM, WaveBMark.VIOLIN, WaveBMark.RIDGELINE))
GRIDS = frozenset((WaveBMark.CONTOUR, WaveBMark.CONTOURF))
KDE_SAMPLES = 30
CONTOUR_BANDS = 8
ARC_STEPS = 128


def validate(layer):
    mark = WaveBMark(layer.mark)
    if layer.horizontal or layer.percent or layer.range_fields or layer.error_fields or layer.total_field:
        raise ValueError('Wave B v1 does not support Wave A layout options')
    if any(getattr(layer, f) for f in ('x2','color_field','fill_field','stroke_field','size_field','opacity_field','text_field','median_field')):
        raise ValueError('Wave B v1 uses layout colors and source-row text')
    if layer.series_fields and mark not in (WaveBMark.RADAR, WaveBMark.STREAMGRAPH):
        raise ValueError('series_fields require radar or streamgraph')
    if mark is WaveBMark.STREAMGRAPH and not layer.series_fields:
        raise ValueError('streamgraph requires series_fields')
    if layer.y2 and mark not in (*GRIDS, WaveBMark.RADAR):
        raise ValueError('y2 requires radar maxima or contour grid values')
    if mark in GRIDS and not layer.y2:
        raise ValueError('contour requires x/y coordinates and y2 scalar field')
    if (layer.stat_low_field or layer.stat_high_field) and mark is not WaveBMark.GAUGE:
        raise ValueError('stat_low/high fields are gauge bounds only')
    if mark is WaveBMark.GAUGE and bool(layer.stat_low_field) != bool(layer.stat_high_field):
        raise ValueError('gauge bounds must be supplied together')
    for fields in (layer.series_fields, layer.range_fields, layer.error_fields):
        if not isinstance(fields, list) or any(not isinstance(f,str) or not f for f in fields) or len(set(fields)) != len(fields):
            raise ValueError('layout fields must be distinct nonempty column names')


def _extent(values):
    lo, hi = min(values), max(values)
    pad = (hi-lo)*.05 if hi > lo else 1.
    return lo-pad, hi+pad


def _density(values):
    mean = sum(values)/len(values)
    std = sqrt(sum((v-mean)**2 for v in values)/len(values))
    bandwidth = .9*std*len(values)**(-.2) if std > 0 else 1.
    lo, hi = min(values), max(values)
    samples = [lo+(hi-lo)*i/(KDE_SAMPLES-1) for i in range(KDE_SAMPLES)]
    density = [sum(exp(-.5*((x-v)/bandwidth)**2)/sqrt(2*pi) for v in values)/(len(values)*bandwidth) for x in samples]
    return samples, [d/max(density) for d in density]


def _clip(poly, level, above):
    result = []
    for a,b in zip(poly, poly[1:]+poly[:1]):
        ai,bi = (a[2]>=level,b[2]>=level) if above else (a[2]<=level,b[2]<=level)
        if ai: result.append(a)
        if ai != bi:
            t = (level-a[2])/(b[2]-a[2])
            result.append((a[0]+t*(b[0]-a[0]),a[1]+t*(b[1]-a[1]),level))
    return result


def layout(layer, data, width=560., height=416.):
    validate(layer)
    mark = WaveBMark(layer.mark)
    cats = list(data.column(layer.x)); n = len(cats)
    if not n or any(c is None or (isinstance(c,(float,int)) and (not isfinite(float(c)) or abs(float(c))>1e15)) for c in cats):
        raise ValueError('specialized layout requires nonempty nonnull source rows')
    def col(name):
        vals = list(data.column(name))
        if len(vals)!=n or any(isinstance(v,(str,bool)) or v is None or not isfinite(float(v)) or abs(float(v))>1e15 for v in vals):
            raise ValueError(name+': expected finite numeric values within ±1e15')
        return [float(v) for v in vals]
    v = col(layer.y)
    if mark not in (*DISTRIBUTIONS,*GRIDS,WaveBMark.GAUGE) and min(v)<0: raise ValueError("values must be nonnegative")
    series = [col(f) for f in layer.series_fields]
    second = col(layer.y2) if layer.y2 else []
    glyphs = []
    rows = [{**{f:vals[i] for f,vals in data.columns.items()}, "row_index":i} for i in range(n)]
    def emit(kind, ids, part, points, color=layer.color, interactive=True):
        if not points: return
        xs,ys=zip(*points)
        bounds=(min(xs),min(ys),max(xs),max(ys)) if kind is GlyphKind.POLYGON else (*points[0],*points[-1])
        glyphs.append(Glyph(kind,ids[0],part,bounds,tuple(color),interactive,tuple(points),tuple(ids)))
    def poly(ids,part,points,color=layer.color,interactive=True): emit(GlyphKind.POLYGON,ids,part,points,color,interactive)
    def segment(ids,part,a,b,color=layer.color): emit(GlyphKind.SEGMENT,ids,part,[a,b],color)
    def point(i,part,p,color=layer.color): emit(GlyphKind.POINT,[i],part,[p],color)
    def polar(a,r): return r*cos(a),r*sin(a)
    def sector(i,part,a,b,outer,inner=0.,color=layer.color,interactive=True):
        steps=max(1,int((b-a)/(2*pi)*ARC_STEPS+.999999))
        pts=[polar(a+(b-a)*j/steps,outer) for j in range(steps+1)]
        pts += [polar(a+(b-a)*j/steps,inner) for j in range(steps,-1,-1)] if inner else [(0.,0.)]
        if b>a and outer>inner: poly([i],part,pts,color,interactive)
    xd,yd=(-.5,n-.5),_extent(v)
    if mark in RADIAL:
        aspect=max(1.,width)/max(1.,height)
        xd=(-max(1.,aspect)/.9,max(1.,aspect)/.9);yd=(-max(1.,1/aspect)/.9,max(1.,1/aspect)/.9)
    if mark in (WaveBMark.PIE,WaveBMark.DONUT,WaveBMark.POLAR_BAR,WaveBMark.NIGHTINGALE,WaveBMark.RADIALBAR):
        if min(v)<0 or max(v)<=0: raise ValueError('radial values must be nonnegative and include a positive value')
        angle=pi/2
        for i,value in enumerate(v):
            color=PALETTE[i%len(PALETTE)]
            if mark in (WaveBMark.PIE,WaveBMark.DONUT):
                span=2*pi*value/sum(v);sector(i,'wedge',angle-span,angle,1.,.5 if mark is WaveBMark.DONUT else 0.,color);angle-=span
            elif mark is WaveBMark.RADIALBAR:
                outer=1-i/n-.125/n;inner=1-(i+1)/n+.125/n
                sector(i,'track',pi/2-2*pi,pi/2,outer,inner,(.9,.9,.9,1.),False)
                sector(i,'arc',pi/2-2*pi*value/max(v),pi/2,outer,inner,color)
            else:
                span=2*pi/n;gap=span*.1 if mark is WaveBMark.POLAR_BAR else 0.
                sector(i,'wedge',angle-span+gap,angle-gap,value/max(v),color=color);angle-=span
    elif mark is WaveBMark.GAUGE:
        if n!=1: raise ValueError('gauge requires exactly one source row')
        lo=col(layer.stat_low_field)[0] if layer.stat_low_field else 0.
        hi=col(layer.stat_high_field)[0] if layer.stat_high_field else 100.
        if lo>=hi: raise ValueError('gauge minimum must be below maximum')
        breaks=[0.,.2,.8,1.]
        for j in range(3):sector(0,'band:'+str(j),-3*pi/4-3*pi/2*breaks[j+1],-3*pi/4-3*pi/2*breaks[j],1.,.7,PALETTE[j],False)
        a=-3*pi/4-3*pi/2*max(0.,min(1.,(v[0]-lo)/(hi-lo)))
        segment([0],'needle',(0.,0.),polar(a,.9),INK);point(0,'pivot',(0.,0.),INK)
    elif mark is WaveBMark.POLAR:
        angles=col(layer.x)
        if min(v)<0 or max(v)<=0:raise ValueError('polar needs nonnegative radii and a positive maximum')
        pts=[polar(-a,r/max(v)) for a,r in zip(angles,v)]
        for i in range(1,n):segment([i-1,i],'line',pts[i-1],pts[i])
        for i,p in enumerate(pts):point(i,'sample',p)
    elif mark is WaveBMark.RADAR:
        if not 3<=n<=4095:raise ValueError('radar requires 3–4095 indicators (extended ScenePath capacity)')
        series=series or [v]
        maxima=second or [max(s[i] for s in series) for i in range(n)]
        if any(x<0 for s in series for x in s) or min(maxima)<0:raise ValueError('radar values/maxima must be nonnegative')
        for j,s in enumerate(series):
            pts=[polar(pi/2-2*pi*i/n,s[i]/maxima[i] if maxima[i]>0 else 0.) for i in range(n)]
            color=PALETTE[j%len(PALETTE)]
            poly(list(range(n)),'series:'+str(j),pts,(*color[:3],.25))
            for i,p in enumerate(pts):segment([i,(i+1)%n],'edge:'+str(j),p,pts[(i+1)%n],color)
            for i,p in enumerate(pts):point(i,'indicator:'+str(j),p,color)
    elif mark in DISTRIBUTIONS:
        groups=list(dict.fromkeys(cats));xd=(-.5,len(groups)-.5)
        for g,category in enumerate(groups):
            ids=[i for i,c in enumerate(cats) if c==category];values=[v[i] for i in ids]
            if mark is WaveBMark.BEESWARM:
                pixels=[floor((yd[1]-value)/(yd[1]-yd[0])*height+.5) for value in values]
                order=sorted(range(len(ids)),key=lambda j:(pixels[j],j));start=0
                spacing=max(1,int(layer.size))
                for end in range(1,len(ids)+1):
                    if end==len(ids) or pixels[order[end]]-pixels[order[end-1]]>spacing:
                        for k in range(end-start):
                            j=order[start+k];offset=0 if k==0 else ((k+1)//2)*spacing*(1 if k%2 else -1)
                            point(ids[j],'sample',(g+offset*len(groups)/max(1.,width),values[j]))
                        start=end
            else:
                samples,density=_density(values)
                if mark is WaveBMark.VIOLIN:
                    pts=[(g+.32*d,x) for x,d in zip(samples,density)]+[(g-.32*d,x) for x,d in reversed(list(zip(samples,density)))]
                else:
                    base=len(groups)-1-g
                    pts=[(samples[0],base)]+[(x,base+1.3*d) for x,d in zip(samples,density)]+[(samples[-1],base)]
                poly(ids,'density',pts)
        if mark is WaveBMark.RIDGELINE:xd,yd=_extent(v),(0.,float(len(groups)))
    elif mark is WaveBMark.STREAMGRAPH:
        if n<2 or any(x<0 for s in series for x in s):raise ValueError('streamgraph needs two categories and nonnegative series')
        totals=[sum(s[i] for s in series) for i in range(n)];running=[-t/2 for t in totals]
        bound=max(totals)*.55 if max(totals)>0 else 1.;yd=(-bound,bound)
        for j,s in enumerate(series):
            top=[running[i]+s[i] for i in range(n)]
            # One quadrilateral per interval preserves both contributing source rows.
            for i in range(n-1):poly([i,i+1],layer.series_fields[j],[(i,top[i]),(i+1,top[i+1]),(i+1,running[i+1]),(i,running[i])],PALETTE[j%len(PALETTE)])
            running=top
    elif mark in GRIDS:
        x=col(layer.x);y=v;z=second;xs=sorted(set(x));ys=sorted(set(y))
        if len(xs)<2 or len(ys)<2 or len(xs)*len(ys)!=n or len(set(zip(x,y)))!=n:raise ValueError('contour requires a complete unique rectangular grid of at least 2×2')
        lookup={(a,b):i for i,(a,b) in enumerate(zip(x,y))};xd=(xs[0],xs[-1]);yd=(ys[0],ys[-1]);lo,hi=min(z),max(z)
        if lo==hi: return Layout([],xd,yd,rows)
        levels=[lo+(hi-lo)*i/CONTOUR_BANDS for i in range(CONTOUR_BANDS+1)]
        for gy in range(len(ys)-1):
            for gx in range(len(xs)-1):
                corners=[lookup[(xs[gx],ys[gy])],lookup[(xs[gx+1],ys[gy])],lookup[(xs[gx+1],ys[gy+1])],lookup[(xs[gx],ys[gy+1])]]
                for tri in ((corners[0],corners[1],corners[2]),(corners[0],corners[2],corners[3])):
                    pts=[(x[i],y[i],z[i]) for i in tri]
                    if mark is WaveBMark.CONTOUR:
                        for k,level in enumerate(levels[1:-1],1):
                            hits=[]
                            for a,b in zip(pts,pts[1:]+pts[:1]):
                                if (a[2]<level) != (b[2]<level):
                                    t=(level-a[2])/(b[2]-a[2]);hits.append((a[0]+t*(b[0]-a[0]),a[1]+t*(b[1]-a[1])))
                            if len(hits)==2 and hits[0]!=hits[1]:segment(list(tri),'level:'+str(k),*hits,PALETTE[(k-1)%len(PALETTE)])
                    else:
                        for k in range(CONTOUR_BANDS):
                            if k<CONTOUR_BANDS-1 and all(p[2]==levels[k+1] for p in pts):continue
                            clipped=_clip(_clip(pts,levels[k],True),levels[k+1],False)
                            area=sum(a[0]*b[1]-b[0]*a[1] for a,b in zip(clipped,clipped[1:]+clipped[:1]))
                            if len(clipped)>=3 and abs(area)>0:poly(list(tri),'band:'+str(k),[(a,b) for a,b,_ in clipped],PALETTE[k%len(PALETTE)])
    return Layout(glyphs,xd,yd,rows)
