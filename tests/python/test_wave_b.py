"""Independent numerical and boundary checks, beyond emitted-mark presence."""
import copy, math, sys
from pathlib import Path
import pytest
sys.path.insert(0,str(Path(__file__).parents[2]))
from scripts.wave_b.fixtures import load_cases, figure
from scripts.wave_b.boundaries import examples
from moxi import PlotSpec, plot
from moxi.specialized import layout, GlyphKind, LayoutVersion
from moxi.wave_b import WaveBMark, _density

CASES=load_cases()

def case(name):return copy.deepcopy(next(c for c in CASES if c['id']==name))
def result(c):
    f=figure(c);return layout(f.spec.layers[0],f.data)

@pytest.mark.parametrize('label,c,valid',examples(),ids=lambda v:v if isinstance(v,str) else None)
def test_boundary(label,c,valid):
    if not valid:
        with pytest.raises((ValueError,KeyError)):result(c)
    else:
        r=result(c)
        assert all(math.isfinite(v) for g in r.glyphs for v in g.bounds)

@pytest.mark.parametrize('c',CASES,ids=lambda c:c['id'])
def test_wire_exports_keys_and_repeated_order(c):
    f=figure(c);r=result(c)
    assert PlotSpec.from_json(f.spec.to_json()).layers[0].layout_version is LayoutVersion.SPECIALIZED
    assert r==result(c)
    assert len(f.table())==c['rows']
    assert len([row for row in f.accessibility() if row['role']=='row'])==c['rows']
    assert f.to_svg().startswith(b'<svg') and f.to_pdf().startswith(b'%PDF')
    for g in r.glyphs:
        assert g.source_rows and g.row==g.source_rows[0]
        assert all(0<=i<c['rows'] for i in g.source_rows)
    for _,g in f._render_geometries():
        if not g.interactive:continue
        p=(g.polygons[0][0] if g.polygons else g.points[0] if g.points else g.segments[0][:2])
        hit=f.hit_test(*p,1)
        assert hit is not None and hit['row_index'] in hit['source_rows']


def test_inventory_is_exactly_authoritative_wave_b():
    assert {c['id'] for c in CASES}=={m.value for m in WaveBMark}
    text=(Path(__file__).parents[2]/'docs/dataviz-capabilities.tsv').read_text()
    for c in CASES:assert c['id'] in text


def test_version_zero_polygon_hit_behavior_stays_anchor_based():
    spec=PlotSpec();spec.add_catalog_mark('pie',x_field='x',y_field='y')
    f=plot({'x':[0,1],'y':[2,3]},spec,width=640,height=480)
    _,g=next(f._render_geometries())
    # A nearby interior location is not an anchor hit under the version-0 API.
    x,y=g.points[0]
    assert f.hit_test(x,y,1) is not None
    assert f.hit_test(x+3,y+3,1) is None


def test_pie_proportions_and_donut_hole():
    r=result(case('pie'));g=r.glyphs[0]
    # 4/10 wedge, clockwise from twelve o'clock, final point is origin.
    assert g.vertices[0]==pytest.approx((math.cos(math.pi/2-.8*math.pi),math.sin(math.pi/2-.8*math.pi)))
    assert g.vertices[-1]==(0,0)
    f=figure(case('donut'));assert f.hit_test(328,236,1) is None
    assert min(math.hypot(x,y) for g in result(case('donut')).glyphs for x,y in g.vertices)==pytest.approx(.5)


def test_polar_uses_upstream_clockwise_radians():
    c=case('polar');c['columns']['angle']=[0,math.pi/2,math.pi,3*math.pi/2,0,0,0]
    r=result(c);points=[g for g in r.glyphs if g.part=='sample']
    assert points[1].bounds[:2]==pytest.approx((0,-4/6),abs=1e-12)


def test_kde_is_gaussian_silverman_not_histogram():
    samples,d=_density([-1,0,1])
    bandwidth=.9*math.sqrt(2/3)*3**(-.2)
    raw=[sum(math.exp(-.5*((x-v)/bandwidth)**2) for v in [-1,0,1]) for x in samples]
    assert d==pytest.approx([v/max(raw) for v in raw])
    assert d[0]==pytest.approx(d[-1]) and max(d)==1


def test_stream_centering_source_pairs_and_continuity():
    c=case('streamgraph');r=result(c);n=c['rows']
    total=[sum(c['columns'][f][i] for f in c['layout']['series_fields']) for i in range(n)]
    assert r.glyphs[0].vertices[3][1]==-total[0]/2
    assert r.glyphs[-1].vertices[1][1]==total[-1]/2
    assert all(len(g.source_rows)==2 for g in r.glyphs)


def test_analytic_plane_contours_and_band_area():
    for name in ('contour','contourf'):
        c=case(name);c['columns']={'x':[0,1,0,1],'y':[0,0,1,1],'z':[0,1,1,2]};r=result(c)
        if name=='contour':
            for g in r.glyphs:
                x0,y0,x1,y1=g.bounds
                assert x0+y0==pytest.approx(x1+y1)
                assert (x0+y0)*4==pytest.approx(round((x0+y0)*4))
        else:
            area=sum(abs(sum(a[0]*b[1]-b[0]*a[1] for a,b in zip(g.vertices,g.vertices[1:]+g.vertices[:1])))/2 for g in r.glyphs)
            assert area==pytest.approx(1)
        shuffled=copy.deepcopy(c);shuffled['columns']={k:[v[i] for i in [3,0,2,1]] for k,v in c['columns'].items()}
        rr=result(shuffled)
        assert [(g.part,g.bounds,g.vertices) for g in r.glyphs]==[(g.part,g.bounds,g.vertices) for g in rr.glyphs]
        assert [g.source_rows for g in r.glyphs]!=[g.source_rows for g in rr.glyphs]


def test_radar_rejects_more_vertices_than_extended_scene_path():
    c=case('radar');c['columns']={k:([v[0]]*4096) for k,v in c['columns'].items()}
    with pytest.raises(ValueError,match='4095'):result(c)


def test_plateau_band_boundary_has_single_ownership():
    c=case('contourf');c['columns']={'x':[0,1,2,0,1,2],'y':[0,0,0,1,1,1],'z':[1,1,0,1,1,2]}
    r=result(c)
    area=sum(abs(sum(a[0]*b[1]-b[0]*a[1] for a,b in zip(g.vertices,g.vertices[1:]+g.vertices[:1])))/2 for g in r.glyphs)
    assert area==pytest.approx(2)
    assert all(abs(sum(a[0]*b[1]-b[0]*a[1] for a,b in zip(g.vertices,g.vertices[1:]+g.vertices[:1])))>0 for g in r.glyphs)
