"""Behavioral acceptance of the opt-in Wave A schema and geometry."""
import copy
import json
from pathlib import Path
import pytest
from moxi import PlotSpec, plot
from moxi.specialized import GlyphKind, LayoutVersion, PALETTE, layout

CASES = json.loads((Path(__file__).parents[1]/'fixtures/wave_a/cases.json').read_text())


def make(case):
    spec=PlotSpec(case['id'])
    identity=spec.add_catalog_mark(case['id'],x_field='category',y_field='value',**case['channels'])
    spec.specialize(identity,**case['layout'])
    return plot(case['columns'],spec)


@pytest.mark.parametrize('case',CASES,ids=lambda c:c['id'])
def test_all_families_have_row_identity_exports_and_roundtrip(case):
    f=make(case)
    decoded=PlotSpec.from_json(f.spec.to_json())
    assert decoded.layers[0].layout_version is LayoutVersion.SPECIALIZED
    assert decoded.to_json()==f.spec.to_json()
    result=layout(f.spec.layers[0],f.data)
    assert len(result.rows)==len(case['columns']['category'])
    assert f.table()==[dict(row,layer=1) for row in result.rows]
    assert len([r for r in f.accessibility() if r['role']=='row'])==len(result.rows)
    assert f.to_png().startswith(b'\x89PNG')
    assert f.to_svg().startswith(b'<svg')
    assert f.to_pdf().startswith(b'%PDF')
    for layer,g in f._render_geometries():
        if not g.interactive:continue
        if g.rects:
            a,b,c,d,_=g.rects[0]
        elif g.segments:a,b,c,d=g.segments[0]
        else:
            a,b=g.points[0];c,d=a,b
        hit=f.hit_test((a+c)/2,(b+d)/2,1)
        assert hit is not None
        assert hit['row_index']==g.source_row
        assert 'source_rows' not in hit  # Wave A's existing hit-result contract.


def result(name):
    f=make(next(c for c in CASES if c['id']==name))
    return layout(f.spec.layers[0],f.data)


def test_upstream_waterfall_total_is_cumulative_including_its_delta():
    case=copy.deepcopy(CASES[1]);case['columns']['value'][-1]=2
    r=layout(make(case).spec.layers[0],make(case).data)
    assert r.rows[-1]['end']==25
    assert r.rows[-1]['start']==0
    assert [g.interactive for g in r.glyphs if g.part=='connector']==[False]*3


def test_candlestick_doji_is_preserved_and_has_wick():
    r=result('candlestick')
    doji=[g for g in r.glyphs if g.row==2 and g.part=='body'][0]
    assert doji.bounds[1]==doji.bounds[3]==7
    assert len([g for g in r.glyphs if g.part=='wick'])==4


def test_bullet_ranges_are_disjoint_background_and_target_is_last():
    r=result('bullet')
    assert [g.part for g in r.glyphs[:5]]==['range:0','range:1','range:2','measure','target']
    assert [g.bounds[1::2] for g in r.glyphs[:3]]==[(0,40),(40,60),(60,100)]


def test_stacks_have_independent_positive_negative_sums():
    r=result('stacked_bar')
    assert r.y_domain==(-5,10)
    assert [g.bounds[1::2] for g in r.glyphs[:3]]==[(0,6),(6,10),(0,-2)]


def test_gantt_and_span_are_distinct_and_reversed_intervals_are_sorted():
    gantt=result('gantt');span=result('span_chart')
    assert gantt.glyphs[-1].bounds==(8,-.4,10,.4)
    assert span.glyphs[-1].bounds==(1.6,6,2.4,12)


def test_pyramid_uses_magnitudes_and_symmetric_domain():
    r=result('population_pyramid')
    assert r.x_domain==(-45,45)
    assert r.glyphs[2].bounds[0]==-45
    assert r.glyphs[5].bounds[2]==38


def test_percent_zero_column_and_horizontal_transpose():
    case=copy.deepcopy(CASES[5]);case['layout'].update(percent=True,horizontal=True)
    for key in ('value','north','south','west'):case['columns'][key]=[0,2,4]
    f=make(case);r=layout(f.spec.layers[0],f.data)
    assert r.x_domain==(0,100)
    assert r.glyphs[0].bounds[0]==r.glyphs[0].bounds[2]==0
    assert r.glyphs[5].bounds[2]==100


@pytest.mark.parametrize('name,field,value',[
    ('candlestick','low',[20,4,6,2]),
    ('bullet','fair',[20,50,75]),
    ('grouped_bar','north_error',[-1,.5,.8]),
    ('lollipop','value',[1,float('nan'),3,4]),
    ('waterfall','total',[1,0,2,1]),
])
def test_malformed_layout_data_is_rejected_before_export(name,field,value):
    case=copy.deepcopy(next(c for c in CASES if c['id']==name));case['columns'][field]=value
    with pytest.raises(ValueError):make(case)


def test_future_version_and_unsupported_option_fail_closed():
    f=make(CASES[0]);value=json.loads(f.spec.to_json());value['layers'][0]['layout_version']=42
    with pytest.raises(ValueError):PlotSpec.from_dict(value)
    with pytest.raises(ValueError):f.spec.specialize(1,percent=True)
    assert f.spec.layers[0].percent is False


def test_specialized_composition_and_unused_encoding_are_rejected():
    f=make(CASES[0]);f.spec.add_line()
    assert not f.spec.validate()
    f=make(CASES[0]);f.spec.layers[0].color_field='value'
    assert not f.spec.validate()
    f=make(CASES[0]);f.spec.layers[0].series_fields=['value']
    assert not f.spec.validate()
    f=make(CASES[0]);f.spec.layers[0].horizontal='false'
    assert not f.spec.validate()


def test_lollipop_endpoints_have_clip_clearance():
    r=result('lollipop')
    assert r.y_domain[0]<-3 and r.y_domain[1]>9


@pytest.mark.parametrize('version', [True, 1.0, '1'])
def test_layout_version_requires_integer_wire_type(version):
    value=json.loads(make(CASES[0]).spec.to_json())
    value['layers'][0]['layout_version']=version
    with pytest.raises(ValueError):PlotSpec.from_dict(value)


def test_row_layout_accessibility_keeps_existing_bounded_summary():
    spec = PlotSpec("Row layout")
    spec.add_line(x_field="x", y_field="y")
    figure = plot({"x": list(range(1000)), "y": list(range(1000))}, spec)
    assert [row["role"] for row in figure.accessibility()] == ["chart", "mark"]


@pytest.mark.parametrize("case", CASES, ids=lambda c: c["id"])
def test_wave_a_output_labels(case):
    import xml.etree.ElementTree as ET
    f = make(case)
    root = ET.fromstring(f.to_svg())
    labels = [e for e in root.findall(".//{*}text") if e.get("font-family") == "monospace"]
    categories = case["columns"]["category"]
    legend = case["layout"].get("series_fields", [])
    if case["id"] in ("gantt", "population_pyramid"):
        categories = categories[::-1]
    if case["id"] == "population_pyramid":
        legend = ["Left", "Right"]
    assert [e.text for e in labels] == categories + legend
    rgba = f.to_rgba()
    pdf = f.to_pdf()
    previous = []
    for index, element in enumerate(labels):
        text = element.text
        x, y = int(element.get("x")), int(element.get("y")) - 9
        right, bottom = x + 7 * len(text), y + 9
        assert 0 <= x < right <= f.width and 0 <= y < bottom <= f.height
        assert all(right <= a or x >= c or bottom <= b or y >= d for a, b, c, d in previous)
        previous.append((x, y, right, bottom))
        assert any(rgba[4 * (row * f.width + col)] == 36
                   for row in range(y, bottom) for col in range(x, right))
        assert f.hit_test(x + 2, y + 3, 1) is None
        assert b"<" + text.encode("cp1252").hex().encode() + b"> Tj" in pdf
        if index >= len(categories):
            pixel = 4 * ((y + 4) * f.width + x - 9)
            assert rgba[pixel:pixel + 4] == bytes(round(c * 255) for c in PALETTE[index - len(categories)])


def test_horizontal_and_narrow_category_labels_keep_source_identity():
    import xml.etree.ElementTree as ET
    case = copy.deepcopy(next(c for c in CASES if c["id"] == "grouped_bar"))
    case["columns"]["category"] = ["North & East", "North & East", "West"]
    case["layout"]["horizontal"] = True
    figure = make(case)
    narrow = plot(case["columns"], figure.spec, width=180, height=150)
    labels = ET.fromstring(narrow.to_svg()).findall(".//{*}text[@font-family]")
    assert labels[0].text.endswith("…") and labels[0].text == labels[1].text
    assert int(labels[0].get("y")) > int(labels[1].get("y"))
    assert [item["category"] for item in narrow.table()] == case["columns"]["category"]
    assert "North &amp; East" in figure.to_svg().decode()


def test_dense_category_axis_samples_labels_and_preserves_rows():
    import xml.etree.ElementTree as ET
    case = copy.deepcopy(next(c for c in CASES if c["id"] == "lollipop"))
    case["columns"] = {"category": list("ABCDEFGHIJKLMNOPQRSTUVWXYZ"), "value": list(range(26))}
    f = plot(case["columns"], make(case).spec, width=180, height=150)
    labels = ET.fromstring(f.to_svg()).findall(".//{*}text[@font-family]")
    assert 1 < len(labels) < len(f.table()) == 26
    assert all(int(b.get("x")) - int(a.get("x")) >= 7 for a, b in zip(labels, labels[1:]))
