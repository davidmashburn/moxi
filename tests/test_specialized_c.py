import copy,json,math,sys
from pathlib import Path
import pytest
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'scripts/wave_c'))
from fixtures import CASES,figure
from boundaries import negatives
from moxi import PlotSpec,plot
from moxi.specialized import layout,GlyphKind

def geometry(name,columns=None):
    f=figure(next(c for c in CASES if c['id']==name),columns);return layout(f.spec.layers[0],f.data)

@pytest.mark.parametrize('case,columns,document',negatives())
def test_negative(case,columns,document):
    with pytest.raises((ValueError,TypeError,KeyError)):
        f=plot(columns,PlotSpec.from_json(json.dumps(document)));layout(f.spec.layers[0],f.data)

@pytest.mark.parametrize('case',CASES,ids=lambda c:c['id'])
def test_deterministic_source_contract(case):
    f=figure(case);g=layout(f.spec.layers[0],f.data)
    assert g==layout(f.spec.layers[0],f.data)
    assert len(f.table())==len(next(iter(case['columns'].values())))
    for p in g.glyphs:assert p.source_rows and all(0<=i<len(g.rows) for i in p.source_rows)
    assert json.loads(f.spec.to_json())==json.loads(PlotSpec.from_json(f.spec.to_json()).to_json())
    assert b'<svg' in f.to_svg()

def test_hierarchy_weights_and_depth():
    g=geometry('treemap');areas={p.row:abs((p.bounds[2]-p.bounds[0])*(p.bounds[3]-p.bounds[1])) for p in g.glyphs}
    assert areas==pytest.approx({3:.5,4:1/6,5:.25,6:1/12})
    t=geometry('tree');nodes=[p for p in t.glyphs if p.part=='node']
    assert [p.bounds[0] for p in nodes]==pytest.approx([.5,1/6,5/6,0,1/3,2/3,1])
    assert {p.source_rows for p in t.glyphs if p.part=='parent-edge'}=={(0,1),(0,2),(1,3),(1,4),(2,5),(2,6)}
    s=geometry('sunburst');assert {p.row for p in s.glyphs}==set(range(1,7))

def test_flow_skip_links_and_node_identity():
    s=geometry('sankey');flows=[p for p in s.glyphs if p.part=='flow']
    assert len(flows)==12 # 5 edges, one spans an extra column, each quad two triangles
    assert {p.part:p.source_rows for p in s.glyphs if p.part.startswith('node:')}=={'node:A':(0,1,4),'node:B':(0,2),'node:C':(1,3),'node:D':(2,3,4)}
    assert all(not p.interactive for p in s.glyphs if p.part.startswith('node:'))
    g=geometry('graph');assert [p.part for p in g.glyphs[-4:]]==['node:A','node:B','node:C','node:D']
    assert g.glyphs[0].stroke_width>g.glyphs[1].stroke_width

def test_matrix_calendar_barbs_contours():
    m=geometry('marimekko');assert [p.bounds[2]-p.bounds[0] for p in m.glyphs[::2]]==pytest.approx([8/18,6/18,4/18])
    c=geometry('calendar_heatmap');assert c.glyphs[0].bounds==(0,5,1,6);assert c.glyphs[1].bounds==(8,2,9,3)
    b=geometry('barbs');staff=next(p for p in b.glyphs if p.row==1 and p.part=='staff');assert staff.bounds[2]<staff.bounds[0] # upwind
    half=next(p for p in b.glyphs if p.row==1 and p.part=='half');assert half.bounds[3]<half.bounds[1]
    t=geometry('tricontour');assert len(t.glyphs)==12
    first=t.glyphs[0];assert first.bounds==pytest.approx((1.75,.25,.25,.25));assert first.source_rows==(0,1,4)

def test_zero_edges_and_constant_contour():
    case=next(c for c in CASES if c['id']=='sankey');c=copy.deepcopy(case['columns']);c['value'][0]=0;assert geometry('sankey',c).glyphs
    case=next(c for c in CASES if c['id']=='tricontour');c=copy.deepcopy(case['columns']);c['z']=[1]*5;assert not geometry('tricontour',c).glyphs


from boundaries import positives
@pytest.mark.parametrize('case,columns',positives())
def test_degenerate_valid_boundaries(case,columns):
    f=figure(case,columns)
    g=layout(f.spec.layers[0],f.data)
    assert all(math.isfinite(v) for p in g.glyphs for v in p.bounds)
    assert len(f.table())==len(next(iter(columns.values())))

def test_zero_cell_is_not_a_hit_target():
    assert not geometry('punchcard').glyphs[2].interactive


def test_punchcard_size_six_is_data_not_style_default():
    case=next(c for c in CASES if c['id']=='punchcard')
    cols={**case['columns'],'count':[30,50,0,90,35]}
    doc=json.loads(figure(case).spec.to_json());doc['layers'][0]['size']=12
    f=plot(cols,PlotSpec.from_json(json.dumps(doc)))
    assert next(f._render_geometries())[1].sizes==[6]
