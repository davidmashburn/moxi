"""Independent malformed inputs replayed at both language boundaries."""
import copy,json
from fixtures import CASES,figure

def negatives():
    cases={c['id']:c for c in CASES};out=[]
    def add(name,field=None,values=None,option=None):
        c=cases[name];data=copy.deepcopy(c['columns']);doc=json.loads(figure(c).spec.to_json())
        if field:data[field]=values
        if option:doc['layers'][0].update(option)
        out.append((c,data,doc))
    for name,c in cases.items():
        doc=json.loads(figure(c).spec.to_json());out.append((c,{k:[] for k in c['columns']},doc))
        numeric=next(k for k,v in c['columns'].items() if not isinstance(v[0],str))
        for value in (float('inf'),float('nan')):
            values=c['columns'][numeric][:];values[0]=value;add(name,numeric,values)
    for name in ('treemap','sunburst','tree'):
        add(name,'id',['root','A','B','a1','a1','b1','b2'])
        add(name,'parent',['','missing','root','A','A','B','B'])
        add(name,'parent',['','a1','root','A','A','B','B'])
        add(name,'parent',['','','root','A','A','B','B'])
        add(name,'value',[0]*7);add(name,'value',[0,0,0,-1,2,3,1])
    for name in ('sankey','chord','graph'):
        add(name,'value',[-1,3,5,3,2]);add(name,'source',['','A','B','C','A'])
    for name in ('sankey','chord'):add(name,'value',[0]*5)
    add('sankey','target',['B','C','A','D','D'])
    add('sankey','target',['A','C','D','D','D'])
    for flag in (0,None,'false'):
        add('treemap',option={'horizontal':flag})
    add('corrplot','A',[1.01,.5,-.8]);add('corrplot',option={'series_fields':['A','B']})
    add('marimekko','north',[-1,2,3]);add('marimekko',option={'series_fields':['north','north']})
    c=cases['marimekko'];data={**c['columns'],'north':[0]*3,'south':[0]*3};out.append((c,data,json.loads(figure(c).spec.to_json())))
    add('punchcard','count',[-1,50,0,90,35]);add('calendar_heatmap','date',['2023-02-29','2024-02-29','2024-04-17','2024-07-04','2024-12-31'])
    add('calendar_heatmap','date',['2023-01-01','2024-02-29','2024-04-17','2024-07-04','2024-12-31'])
    add('barbs','u',[0,5,10,15,50,60000])
    for triangles in ([[0,0,1]],[[0,1,8]],[[0,1,2],[2,0,1]],[[0,1,4],[0,1,2],[0,1,3]],[[0,1]],[[0,1,2.0]],[[True,1,2]],[[0,1,2],[]]):add('tricontour',option={'triangles':triangles})
    for levels in ([],[1,1],[2,1],[True]):add('tricontour',option={'levels':levels})
    add('tricontour','y',[0]*5)
    add('tricontour',option={'triangles':[[0,1,2],[0,1,4]]})
    c=cases['tricontour'];data={**c['columns'],'x':[0,2,2,0,1],'y':[0,0,2,2,0]};doc=json.loads(figure(c).spec.to_json());doc['layers'][0]['triangles']=[[0,1,2],[0,4,3]];out.append((c,data,doc))
    return out


def positives():
    out=[]
    for name,changes in [('treemap',{'value':[99,0,0,6,2,0,0]}),('sunburst',{'value':[99,0,0,6,2,0,0]}),('sankey',{'value':[0,3,5,3,2]}),('chord',{'value':[0,3,5,3,2]}),('graph',{'value':[0]*5}),('marimekko',{'north':[0,2,3],'south':[0,4,1]}),('tricontour',{'z':[1]*5})]:
        c=next(c for c in CASES if c['id']==name);out.append((c,{**c['columns'],**changes}))
    for name in ('treemap','sunburst','tree'):
        c=next(c for c in CASES if c['id']==name);out.append((c,{'id':['root'],'parent':[''],'value':[1]}))
    return out
