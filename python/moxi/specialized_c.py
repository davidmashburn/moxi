"""Wave C algorithms adapted from dataviz_mojo v0.8.0 (MIT).

See docs/plot-specialized-wave-c.md for provenance and deliberately bounded
interaction. Triangular contours are Moxi marching-triangle segments: the pinned
upstream has no tricontour implementation. No runtime dependency on dataviz.
"""
from enum import Enum
from math import cos, sin, pi, hypot, isfinite
from datetime import date
from .specialized import Glyph, GlyphKind, Layout, PALETTE


class WaveCMark(str, Enum):
    TREEMAP = 'treemap'
    SUNBURST = 'sunburst'
    TREE = 'tree'
    SANKEY = 'sankey'
    CHORD = 'chord'
    GRAPH = 'graph'
    CALENDAR = 'calendar_heatmap'
    CORRPLOT = 'corrplot'
    PUNCHCARD = 'punchcard'
    MARIMEKKO = 'marimekko'
    BARBS = 'barbs'
    TRICONTOUR = 'tricontour'


def validate(layer):
    mark = WaveCMark(layer.mark)
    if type(layer.horizontal) is not bool or type(layer.percent) is not bool:
        raise ValueError("layout flags must be booleans")
    if layer.horizontal or layer.percent or layer.range_fields or layer.error_fields or layer.total_field:
        raise ValueError('Wave C does not accept Wave A options')
    if any(getattr(layer, n) for n in ('x2', 'color_field', 'fill_field', 'stroke_field', 'size_field', 'opacity_field', 'text_field', 'median_field', 'stat_low_field', 'stat_high_field')):
        raise ValueError('Wave C uses specialized geometry and source table text')
    fields = layer.series_fields
    if not isinstance(fields, list) or any(not isinstance(f,str) or not f for f in fields) or len(set(fields)) != len(fields):
        raise ValueError('series_fields must be distinct nonempty column names')
    if mark in (WaveCMark.CORRPLOT, WaveCMark.MARIMEKKO) and not fields:
        raise ValueError('matrix layout requires series_fields')
    expected = {WaveCMark.BARBS: 2, WaveCMark.TRICONTOUR: 1, WaveCMark.PUNCHCARD: 1}
    if mark in expected and len(fields) != expected[mark]:
        raise ValueError('wrong number of series_fields')
    if mark not in expected and mark not in (WaveCMark.CORRPLOT, WaveCMark.MARIMEKKO) and fields:
        raise ValueError('unused series_fields')
    if mark in (WaveCMark.TREE,WaveCMark.TREEMAP,WaveCMark.SUNBURST,WaveCMark.SANKEY,WaveCMark.CHORD,WaveCMark.GRAPH) and not layer.y2:
        raise ValueError('hierarchy/edge layout needs y2 parent/target')
    if mark is not WaveCMark.TRICONTOUR and (layer.triangles or layer.levels):
        raise ValueError('triangles/levels require tricontour')
    if mark is WaveCMark.TRICONTOUR:
        if not isinstance(layer.triangles,list) or not layer.triangles or any(not isinstance(t,list) or len(t)!=3 or any(type(v) is not int or v<0 for v in t) or len(set(t))!=3 for t in layer.triangles):
            raise ValueError('triangles must contain three distinct nonnegative vertex indices')
        if len({tuple(sorted(t)) for t in layer.triangles}) != len(layer.triangles):
            raise ValueError('duplicate triangle')
        if not isinstance(layer.levels,list) or not layer.levels or any(type(v) not in (int,float) or not isfinite(v) for v in layer.levels) or any(a>=b for a,b in zip(layer.levels,layer.levels[1:])):
            raise ValueError('levels must be finite, strictly increasing')


def _validate_mesh(x,y,triangles):
    def orient(a,b,c):return (x[b]-x[a])*(y[c]-y[a])-(y[b]-y[a])*(x[c]-x[a])
    if len(set(zip(x,y)))!=len(x):raise ValueError('duplicate vertex coordinates')
    for t in triangles:
        if max(t)>=len(x):raise ValueError('missing triangle vertex')
        if not isfinite(orient(*t)) or orient(*t)==0:raise ValueError('invalid triangle area')
    for i,t in enumerate(triangles):
        for u in triangles[:i]:
            for vertex,other in [(v,u) for v in t]+[(v,t) for v in u]:
                for a,b in zip(other,other[1:]+other[:1]):
                    if vertex not in (a,b) and orient(a,b,vertex)==0 and min(x[a],x[b])<=x[vertex]<=max(x[a],x[b]) and min(y[a],y[b])<=y[vertex]<=max(y[a],y[b]):raise ValueError('mesh T junction')
            for a in t:
                if a not in u:
                    signs=[orient(u[j],u[(j+1)%3],a) for j in range(3)]
                    if min(signs)>0 or max(signs)<0:raise ValueError('overlapping triangles')
            for a in u:
                if a not in t:
                    signs=[orient(t[j],t[(j+1)%3],a) for j in range(3)]
                    if min(signs)>0 or max(signs)<0:raise ValueError('overlapping triangles')
            for a,b in zip(t,t[1:]+t[:1]):
                for c,d in zip(u,u[1:]+u[:1]):
                    if {a,b}=={c,d}:
                        ta=next(v for v in t if v not in (a,b));ua=next(v for v in u if v not in (a,b))
                        if orient(a,b,ta)*orient(a,b,ua)>=0:raise ValueError('same-side shared edge')
                    elif not {a,b}&{c,d}:
                        if orient(a,b,c)*orient(a,b,d)<=0 and orient(c,d,a)*orient(c,d,b)<=0 and max(min(x[a],x[b]),min(x[c],x[d]))<=min(max(x[a],x[b]),max(x[c],x[d])) and max(min(y[a],y[b]),min(y[c],y[d]))<=min(max(y[a],y[b]),max(y[c],y[d])):raise ValueError('crossing mesh edges')

def layout(layer, data):
    validate(layer)
    mark=WaveCMark(layer.mark)
    n=data.row_count
    if not n: raise ValueError('Wave C requires nonempty input')
    def col(name, numeric=True):
        values=list(data.column(name))
        if len(values)!=n or any(v is None for v in values): raise ValueError('missing source values')
        if numeric:
            if any(type(v) not in (float,int) or not isfinite(v) for v in values): raise ValueError('expected finite numeric column')
            return list(map(float,values))
        if any(not isinstance(v,str) for v in values): raise ValueError('expected string identity column')
        return values
    glyphs=[]
    rows=[dict({k:v[i] for k,v in data.columns.items()},row_index=i,mark=mark.value) for i in range(n)]
    xd,yd=(0.,1.),(0.,1.)
    def emit(kind,row,part,bounds,color=None,vertices=(),sources=None,interactive=True,size=6.,stroke_width=0.):
        glyphs.append(Glyph(kind,row,part,tuple(bounds),color or PALETTE[row%len(PALETTE)],interactive,tuple(vertices),tuple(sources if sources is not None else (row,)),size,stroke_width))
    def seg(row,part,a,b,**kw): emit(GlyphKind.SEGMENT,row,part,(*a,*b),**kw)
    def rect(row,part,a,b,**kw): emit(GlyphKind.RECT,row,part,(*a,*b),**kw)
    def tri(row,part,a,b,c,**kw): emit(GlyphKind.TRIANGLE,row,part,(*a,*b),vertices=(c,),**kw)
    def quad(row,part,a,b,c,d,**kw):
        tri(row,part,a,b,c,**kw);tri(row,part,a,c,d,**kw)
    def polar(r,a): return (.5+r*cos(a),.5-r*sin(a))
    def sector(row,part,inner,outer,a,b,**kw):
        steps=max(1,int((b-a)*32/pi)+1)
        for j in range(steps):
            s=a+(b-a)*j/steps;t=a+(b-a)*(j+1)/steps
            quad(row,part,polar(inner,s),polar(outer,s),polar(outer,t),polar(inner,t),**kw)

    if mark in (WaveCMark.TREEMAP,WaveCMark.SUNBURST,WaveCMark.TREE):
        ids=col(layer.x,False);parents=col(layer.y2,False);values=col(layer.y)
        if any(not i for i in ids) or len(set(ids))!=n or any(v<0 for v in values): raise ValueError('invalid hierarchy identity/value')
        lookup={s:i for i,s in enumerate(ids)};children=[[] for _ in ids];roots=[]
        for i,p in enumerate(parents):
            if not p: roots.append(i)
            elif p not in lookup: raise ValueError('missing parent')
            else: children[lookup[p]].append(i)
        if len(roots)!=1: raise ValueError('hierarchy needs one root')
        root=roots[0];order=[root];depth=[0]*n;branch=[0]*n
        for node in order:
            for j,c in enumerate(children[node]):
                if c in order: raise ValueError('hierarchy cycle')
                depth[c]=depth[node]+1;branch[c]=j if node==root else branch[node];order.append(c)
        if len(order)!=n: raise ValueError('hierarchy cycle/disconnected node')
        totals=values[:]
        for i in reversed(order):
            if children[i]: totals[i]=sum(totals[c] for c in children[i])
        if not isfinite(totals[root]) or totals[root]<=0: raise ValueError('hierarchy needs positive finite leaf total')
        for i in range(n):rows[i].update(subtree_value=totals[i],depth=depth[i],object_id=ids[i])
        if mark is WaveCMark.TREEMAP:
            boxes={root:(0.,0.,1.,1.)}
            for i in order:
                if totals[i]==0: continue
                x0,y0,x1,y1=boxes[i]
                if not children[i]:
                    if totals[i]>0:rect(i,'leaf',(x0,y0),(x1,y1),color=PALETTE[branch[i]%4])
                elif totals[i]>0:
                    cursor=0.
                    for c in children[i]:
                        end=cursor+totals[c]/totals[i]
                        boxes[c]=(x0+(x1-x0)*cursor,y0,x0+(x1-x0)*end,y1) if depth[i]%2==0 else (x0,y1-(y1-y0)*end,x1,y1-(y1-y0)*cursor)
                        cursor=end
        elif mark is WaveCMark.SUNBURST:
            angles={root:(-pi/2,3*pi/2)};maxdepth=max(depth)
            for i in order:
                a,b=angles[i]
                if i!=root and totals[i]>0:sector(i,'sector',.45*(depth[i]-1)/maxdepth,.45*depth[i]/maxdepth,a,b,color=PALETTE[branch[i]%4])
                cursor=a
                for c in children[i]:
                    end=cursor+(b-a)*totals[c]/totals[i] if totals[i] else cursor
                    angles[c]=(cursor,end);cursor=end
        else:
            # DFS leaf order, mean child position; exactly the upstream algorithm.
            stack=[root];dfs=[]
            while stack:
                i=stack.pop();dfs.append(i);stack.extend(reversed(children[i]))
            slots=[0.]*n;leaves=[i for i in dfs if not children[i]]
            for j,i in enumerate(leaves):slots[i]=j
            for i in reversed(dfs):
                if children[i]:slots[i]=sum(slots[c] for c in children[i])/len(children[i])
            points=[(slots[i]/(len(leaves)-1) if len(leaves)>1 else .5,1-depth[i]/max(1,max(depth))) for i in range(n)]
            for i in order:
                for c in children[i]:seg(c,'parent-edge',points[i],points[c],sources=(i,c),color=PALETTE[branch[c]%4])
            for i in order:emit(GlyphKind.POINT,i,'node',(*points[i],*points[i]),color=PALETTE[branch[i]%4])
    elif mark in (WaveCMark.SANKEY,WaveCMark.CHORD,WaveCMark.GRAPH):
        starts=col(layer.x,False);ends=col(layer.y2,False);values=col(layer.y)
        if any(not s for s in starts+ends) or any(v<0 for v in values) or not isfinite(sum(values)):raise ValueError('invalid edge identity/value')
        nodes=list(dict.fromkeys(starts+ends));count=len(nodes)
        src=[nodes.index(v) for v in starts];dst=[nodes.index(v) for v in ends]
        incident=[tuple(i for i in range(n) if src[i]==j or dst[i]==j) for j in range(count)]
        for i in range(n):rows[i].update(object_id=f'edge:{i}',source=starts[i],target=ends[i])
        if mark is WaveCMark.GRAPH:
            points=[polar(.45,-pi/2+2*pi*j/count) for j in range(count)]
            for i in range(n):
                if src[i]!=dst[i]:seg(i,'edge',points[src[i]],points[dst[i]],color=PALETTE[src[i]%4],stroke_width=layer.line_width*(1+2*values[i]/max(values)) if max(values)>0 else layer.line_width)
            for j,p in enumerate(points):emit(GlyphKind.POINT,incident[j][0],'node:'+nodes[j],(*p,*p),sources=incident[j],interactive=False,color=PALETTE[j%4])
        elif mark is WaveCMark.CHORD:
            if sum(values)<=0:raise ValueError('chord needs positive total')
            totals=[sum(values[i]*((src[i]==j)+(dst[i]==j)) for i in range(n)) for j in range(count)];grand=sum(totals)
            angles=[];cursor=-pi/2
            for value in totals:angles.append(cursor);cursor+=2*pi*value/grand
            cursors=angles[:]
            for i,v in enumerate(values):
                a=cursors[src[i]];b=a+2*pi*v/grand;cursors[src[i]]=b
                c=cursors[dst[i]];d=c+2*pi*v/grand;cursors[dst[i]]=d
                # Quadratic boundaries share the circle center as control point.
                def curve(p,q,t):return ((1-t)**2*p[0]+t*t*q[0]+t*(1-t),(1-t)**2*p[1]+t*t*q[1]+t*(1-t))
                pa,pb,pc,pd=[polar(.414,t) for t in (a,b,c,d)]
                for j in range(24):
                    t=j/24;u=(j+1)/24
                    quad(i,'ribbon',curve(pa,pd,t),curve(pb,pc,t),curve(pb,pc,u),curve(pa,pd,u),color=PALETTE[src[i]%4])
                # Rim arcs fill the small circular caps omitted by the quadratic strip.
                for start,end in ((a,b),(c,d)):
                    for j in range(16):
                        tri(i,'rim',polar(.414,start),polar(.414,start+(end-start)*j/16),polar(.414,start+(end-start)*(j+1)/16),color=PALETTE[src[i]%4])
            for j,a in enumerate(angles):sector(incident[j][0],'node:'+nodes[j],.414,.45,a,a+2*pi*totals[j]/grand,sources=incident[j],interactive=False,color=PALETTE[j%4])
        else:
            if any(src[i]==dst[i] for i in range(n)):raise ValueError("Sankey self cycle")
            active=[i for i in range(n) if src[i]!=dst[i]]
            indegree=[sum(dst[i]==j for i in active) for j in range(count)];columns=[0]*count;queue=[j for j in range(count) if indegree[j]==0]
            for j in queue:
                for i in active:
                    if src[i]==j:
                        k=dst[i];columns[k]=max(columns[k],columns[j]+1);indegree[k]-=1
                        if not indegree[k]:queue.append(k)
            if len(queue)!=count:raise ValueError('Sankey requires DAG')
            if not sum(values[i] for i in active)>0:raise ValueError('Sankey needs positive non-self flow')
            edges=[]
            for i in active:
                prev=src[i]
                for c in range(columns[src[i]]+1,columns[dst[i]]):
                    dummy=len(columns);columns.append(c);edges.append((prev,dummy,i));prev=dummy
                edges.append((prev,dst[i],i))
            totals=[max(sum(values[i] for a,b,i in edges if a==j),sum(values[i] for a,b,i in edges if b==j)) for j in range(len(columns))]
            low=[0.]*len(columns);high=low[:];xs=[.96*c/max(columns) for c in columns]
            for c in range(max(columns)+1):
                members=[j for j,v in enumerate(columns) if v==c];total=sum(totals[j] for j in members);cursor=0.
                for j in members:low[j]=cursor;cursor+=totals[j]/total if total else 0.;high[j]=cursor
            out=low[:];inc=low[:]
            for a,b,i in edges:
                ah=values[i]/totals[a]*(high[a]-low[a]) if totals[a] else 0.;bh=values[i]/totals[b]*(high[b]-low[b]) if totals[b] else 0.
                quad(i,'flow',(xs[a]+.04,1-out[a]),(xs[a]+.04,1-out[a]-ah),(xs[b],1-inc[b]-bh),(xs[b],1-inc[b]),color=PALETTE[src[i]%4]);out[a]+=ah;inc[b]+=bh
            for j in range(count):rect(incident[j][0],'node:'+nodes[j],(xs[j],1-high[j]),(xs[j]+.04,1-low[j]),sources=incident[j],interactive=False,color=PALETTE[j%4])
    elif mark in (WaveCMark.CORRPLOT,WaveCMark.MARIMEKKO):
        labels=col(layer.x,False);matrix=[col(f) for f in layer.series_fields]
        if len(set(labels))!=n:raise ValueError('matrix labels must be unique')
        if mark is WaveCMark.CORRPLOT:
            if len(matrix)!=n or any(abs(v)>1 for s in matrix for v in s):raise ValueError('corrplot needs square matrix in [-1,1]')
            xd,yd=(-.5,n-.5),(-.5,n-.5)
            for i in range(n):
                for j in range(n):
                    v=matrix[j][i];r=.4*abs(v)
                    # Data-space circles tessellated, preserving cell radius on both axes.
                    for k in range(32):tri(i,'cell:'+layer.series_fields[j],(j,n-1-i),(j+r*cos(k*pi/16),n-1-i+r*sin(k*pi/16)),(j+r*cos((k+1)*pi/16),n-1-i+r*sin((k+1)*pi/16)),color=(.2+.7*max(v,0),.35,.2+.7*max(-v,0),1.))
        else:
            totals=[sum(s[i] for s in matrix) for i in range(n)];grand=sum(totals)
            if any(v<0 for s in matrix for v in s) or not isfinite(grand) or grand<=0:raise ValueError('Marimekko needs nonnegative matrix with positive total')
            x=0.
            for i in range(n):
                end=x+totals[i]/grand;y=0.
                for j,s in enumerate(matrix):
                    top=y+s[i]/totals[i] if totals[i] else y
                    if top>y:rect(i,'cell:'+layer.series_fields[j],(x,y),(end,top),color=PALETTE[j%4])
                    y=top
                x=end
    elif mark is WaveCMark.PUNCHCARD:
        x=col(layer.x,False);y=col(layer.y,False);values=col(layer.series_fields[0]);xs=list(dict.fromkeys(x));ys=list(dict.fromkeys(y))
        if any(v<0 for v in values):raise ValueError('negative punchcard size')
        xd,yd=(-.5,len(xs)-.5),(-.5,len(ys)-.5)
        for i,v in enumerate(values):
            p=(xs.index(x[i]),len(ys)-1-ys.index(y[i]));emit(GlyphKind.POINT,i,'cell',(*p,*p),size=v/5,interactive=v>0)
    elif mark is WaveCMark.CALENDAR:
        raw=col(layer.x,False);values=col(layer.y)
        try: dates=[date.fromisoformat(v) for v in raw]
        except ValueError as e:raise ValueError('invalid ISO date') from e
        year=dates[0].year
        if any(d.year!=year or d.isoformat()!=s for d,s in zip(dates,raw)) or len(set(raw))!=n:raise ValueError('calendar needs unique ISO dates in one year')
        jan=date(year,1,1);offset=(jan.weekday()+1)%7;weeks=((date(year,12,31)-jan).days+offset)//7+1;xd,yd=(0.,float(weeks)),(0.,7.)
        low,high=min(values),max(values)
        for i,d in enumerate(dates):
            day=(d-jan).days+offset;week,dow=divmod(day,7);v=(values[i]-low)/(high-low) if high>low else .5
            rect(i,'day',(week,6-dow),(week+1,7-dow),color=(.9-.7*v,.95-.4*v,1.-.2*v,1.))
    elif mark is WaveCMark.BARBS:
        x=col(layer.x);y=col(layer.y);u=col(layer.series_fields[0]);v=col(layer.series_fields[1])
        xmin,xmax=min(x),max(x);ymin,ymax=min(y),max(y)
        xd=(xmin-.2*(xmax-xmin or 1),xmax+.2*(xmax-xmin or 1));yd=(ymin-.2*(ymax-ymin or 1),ymax+.2*(ymax-ymin or 1))
        length=.08*max(xd[1]-xd[0],yd[1]-yd[0])
        for i in range(n):
            speed=hypot(u[i],v[i]);rounded=int(speed/5+.5)*5;flags,rest=divmod(rounded,50);full,half=divmod(rest,10)
            if not isfinite(speed) or speed>50000:raise ValueError('barb glyph exceeds bounded flag count')
            if not rounded:
                for k in range(32):seg(i,'calm',(x[i]+length*.15*cos(k*pi/16),y[i]+length*.15*sin(k*pi/16)),(x[i]+length*.15*cos((k+1)*pi/16),y[i]+length*.15*sin((k+1)*pi/16)))
                continue
            def p(a,b):return (x[i]+length*(-a*u[i]+b*v[i])/speed,y[i]+length*(-a*v[i]-b*u[i])/speed)
            seg(i,'staff',p(0,0),p(1,0));cursor=1.
            for j in range(flags):tri(i,'flag',p(cursor,0),p(cursor,.4),p(cursor-.25,0));cursor-=.25
            if flags:cursor-=.125
            for j in range(full):seg(i,'full',p(cursor,0),p(cursor-.125,.4));cursor-=.125
            if half:
                if not flags and not full:cursor-=.125
                seg(i,'half',p(cursor,0),p(cursor-.0625,.2))
    else:
        x=col(layer.x);y=col(layer.y);z=col(layer.series_fields[0]);xd=(min(x),max(x));yd=(min(y),max(y))
        if xd[0]==xd[1] or yd[0]==yd[1]:raise ValueError('degenerate triangle domain')
        _validate_mesh(x,y,layer.triangles)
        edge_count={}
        for ti,t in enumerate(layer.triangles):
            if max(t)>=n:raise ValueError('missing triangle vertex')
            a,b,c=t
            if (x[b]-x[a])*(y[c]-y[a])-(y[b]-y[a])*(x[c]-x[a])==0:raise ValueError('zero-area triangle')
            for a,b in zip(t,t[1:]+t[:1]):
                edge=tuple(sorted((a,b)));edge_count[edge]=edge_count.get(edge,0)+1
                if edge_count[edge]>2:raise ValueError('nonmanifold triangulation')
            for level in layer.levels:
                crossings=[]
                for a,b in zip(t,t[1:]+t[:1]):
                    # Half-open level ownership: vertices exactly on a level are deterministic.
                    if (z[a]<=level<z[b]) or (z[b]<=level<z[a]):
                        f=(level-z[a])/(z[b]-z[a]);crossings.append((x[a]+f*(x[b]-x[a]),y[a]+f*(y[b]-y[a])))
                if len(crossings)==2 and crossings[0]!=crossings[1]:seg(t[0],f'triangle:{ti}:level:{level:g}',*crossings,sources=t)
    return Layout(glyphs,xd,yd,rows)
