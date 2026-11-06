"""Independent input mutations shared by runtime boundary checks, not a mark registry."""
import copy
from fixtures import load_cases


def examples():
    cases=load_cases();out=[]
    def add(c,label,valid,change):
        c=copy.deepcopy(c);change(c);out.append((c['id']+'-'+label,c,valid))
    for c in cases:
        add(c,'empty',False,lambda c:c.update(columns={k:[] for k in c['columns']}))
        for value,label in [(float('nan'),'nan'),(float('inf'),'infinite'),(1e16,'too-large')]:
            add(c,label,False,lambda c,v=value:c['columns'][c['y']].__setitem__(0,v))
        if isinstance(c['columns'][c['x']][0],(float,int)):
            add(c,'too-large-x',False,lambda c:c['columns'][c['x']].__setitem__(0,1e16))
    for c in cases:
        if c['id'] in ('pie','donut','polar','polar_bar','radialbar','nightingale','radar','streamgraph'):
            add(c,'negative',False,lambda c:c['columns'][c['y']].__setitem__(0,-1))
        if c['id'] in ('pie','donut','polar','polar_bar','radialbar','nightingale'):
            add(c,'zero',False,lambda c:c['columns'].__setitem__(c['y'],[0]*c['rows']))
        if c['id'] in ('beeswarm','violin','ridgeline'):
            add(c,'constant',True,lambda c:c['columns'].__setitem__(c['y'],[-2]*c['rows']))
        if c['id'] in ('contour','contourf'):
            add(c,'missing-cell',False,lambda c:c.update(columns={k:v[:-1] for k,v in c['columns'].items()}))
            add(c,'duplicate',False,lambda c:[v.__setitem__(-1,v[0]) for v in c['columns'].values()])
            add(c,'plane',True,lambda c:c.update(columns={'x':[0,1,0,1],'y':[0,0,1,1],'z':[0,1,1,2]}))
            add(c,'flat',True,lambda c:c['columns'].__setitem__(c['channels']['y2_field'],[2]*c['rows']))
            add(c,'nonfinite-z',False,lambda c:c['columns'][c['channels']['y2_field']].__setitem__(0,float('inf')))
        if c['id']=='gauge':
            add(c,'inverted-bounds',False,lambda c:c['columns']['minimum'].__setitem__(0,200))
            add(c,'clamped',True,lambda c:c['columns'][c['y']].__setitem__(0,-100))
    return out
