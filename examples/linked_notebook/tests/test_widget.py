import json
import os
from pathlib import Path
import subprocess
import uuid

import pytest
from moxi_linked_notebook.widget import Backend, Kind, LinkedPlot, render, sample_rows, static_html, validate_rows

BINARY = Path(os.environ['MOXI_LINKED_BINARY'])


@pytest.fixture
def widget():
    w = LinkedPlot(slot='test', binary=BINARY)
    w.replies = []
    w.send = lambda m: w.replies.append(m)
    yield w
    w.close()


def message(w, seq=1, kind=Kind.HELLO, **extra):
    return dict(v=1, session=w.session, generation=w.generation, view=w.view or str(uuid.uuid4()), seq=seq, kind=kind, **extra)


def deliver(w, **kwargs):
    m = message(w, **kwargs)
    w._receive(w, m, [])
    return m


def state(w, **kwargs):
    return dict(selected=3, minimum=0, finals=1, dataVersion=w.data_version, **kwargs)


def test_real_moxi_plot_and_selection(widget):
    deliver(widget)
    deliver(widget, seq=2, kind=Kind.STATE, state=state(widget))
    f = widget.frame
    assert f['selected'] == 3 and f['detail']['label'] == 'Sample 04'
    assert f['selectionSemantic'] == 1 and f['sceneCommands'] > 40
    assert len(f['points']) == 12
    assert f['spec']['version'] == 1 and f['spec']['layers'][0]['mark'] == 'scatter'
    s = state(widget); s.update(minimum=70, finals=2)
    deliver(widget, seq=3, kind=Kind.STATE, state=s)
    assert widget.frame['selected'] == -1 and widget.frame['detail'] is None
    assert [r['key'] for r in widget.frame['rows']] == [5,7,8,9,10,11]
    assert widget.frame['selectionSemantic'] == 0


@pytest.mark.parametrize('field,value', [('v',2), ('v',True), ('session','old'), ('generation',0), ('generation',True), ('seq',True), ('seq',0), ('view','invalid'), ('kind','arbitrary')])
def test_reject_envelopes(widget, field, value):
    m=message(widget);m[field]=value;widget._receive(widget,m,[])
    assert widget.rejected == 1 and not widget.replies and widget.sequence == 0


@pytest.mark.parametrize('patch', [{'selected':True}, {'selected':64}, {'minimum':-1}, {'minimum':101}, {'minimum':float('nan')}, {'finals':-1}, {'finals':2**53}, {'dataVersion':0}, {'extra':1}])
def test_reject_state(widget, patch):
    deliver(widget); s=state(widget);s.update(patch)
    deliver(widget, seq=2, kind=Kind.STATE, state=s)
    assert widget.rejected == 1 and widget.frame['selected'] == -1


def test_hello_sequence_identity_exact_fields(widget):
    deliver(widget, kind=Kind.STATE, state=state(widget));assert widget.rejected==1
    m=deliver(widget);widget._receive(widget,m,[]);assert widget.rejected==2
    m=message(widget,seq=2);m['extra']=0;widget._receive(widget,m,[])
    assert widget.rejected==3
    m=message(widget,seq=2);m['view']=str(uuid.uuid4());widget._receive(widget,m,[])
    assert widget.rejected==4
    m=message(widget,seq=2);widget._receive(widget,m,[b'x']);assert widget.rejected==5


def test_final_counter_recovery_and_dispose(widget):
    deliver(widget);deliver(widget,seq=2,kind=Kind.STATE,state=state(widget))
    s=state(widget);s['finals']=0;deliver(widget,seq=3,kind=Kind.STATE,state=s)
    assert widget.rejected==1
    widget.set_backend_available(False);deliver(widget,seq=4,kind=Kind.PING)
    assert widget.replies[-1]['kind'] is Kind.ERROR
    widget.set_backend_available(True);deliver(widget,seq=5)
    assert widget.replies[-1]['kind'] is Kind.ACK and widget.frame['selected']==3
    deliver(widget,seq=6,kind=Kind.DISPOSE);assert widget.backend is Backend.CLOSED


def test_atomic_update_and_stale_data(widget):
    deliver(widget);old=widget.frame
    with pytest.raises(ValueError): widget.update([{'label':'bad','x':101,'y':0}])
    assert widget.frame is old
    widget.update([{'label':'New <script> & 🧪','x':40,'y':70}])
    assert widget.data_version==2 and widget.frame['selected']==-1
    s=state(widget);s.update(selected=0,dataVersion=1)
    deliver(widget,seq=2,kind=Kind.STATE,state=s);assert widget.rejected==1
    html=static_html(widget.frame)
    assert '<script>' not in html and '&lt;script&gt;' in html


def test_isolation_replacement(widget):
    other=LinkedPlot(slot='other',binary=BINARY)
    replacement=LinkedPlot(slot='test',binary=BINARY)
    assert widget.backend is Backend.CLOSED and other.backend is Backend.AVAILABLE
    assert replacement.generation>widget.generation and replacement.session!=widget.session
    other.close();replacement.close()


@pytest.mark.parametrize('rows', [[], sample_rows()*6, [{'label':'a','x':True,'y':1}], [{'label':'a','x':float('inf'),'y':1}], [{'label':'a','x':1,'y':-1}], [{'label':'a','x':100.000001,'y':1}], [{'label':'','x':1,'y':1}], [{'label':'x\n','x':1,'y':1}], [{'label':'x\x7f','x':1,'y':1}], [{'label':'a','x':1,'y':1,'extra':1}]])
def test_invalid_data(rows):
    with pytest.raises(ValueError):validate_rows(rows)


def test_native_boundary_and_capacity():
    for args in [('2','-1','0','1','1'),('1','-1','0','nan','1'),('1','-1','0','100.000001','1'),('1','4','0','1','1'),('1','-1','101','1','1')]:
        assert subprocess.run([str(BINARY),*args],capture_output=True).returncode != 0
    rows=[{'label':f'Row {i}','x':i,'y':i} for i in range(64)]
    f=render(BINARY,rows,63)
    assert len(f['points'])==64 and f['selected']==63
    assert len(json.dumps(f).encode())<131072
    f=render(BINARY,rows,-1,100);assert not f['rows'] and not f['points']


def test_process_failure_preserves_frame(widget, tmp_path):
    deliver(widget);old=widget.frame;widget.binary=tmp_path/'missing'
    deliver(widget,seq=2,kind=Kind.STATE,state=state(widget))
    assert widget.replies[-1]['kind'] is Kind.ERROR and widget.frame is old


def test_process_timeout_reaped(widget,tmp_path):
    script=tmp_path/'slow';script.write_text('#!/usr/bin/env python3\nimport time\ntime.sleep(10)\n');script.chmod(0o700)
    deliver(widget);widget.binary=script
    deliver(widget,seq=2,kind=Kind.STATE,state=state(widget))
    assert widget.replies[-1]['kind'] is Kind.ERROR


def test_svg_ids_are_isolated(widget):
    import re
    other=LinkedPlot(slot='svg-other',binary=BINARY)
    values=[widget.frame['svg'],other.frame['svg'],static_html(widget.frame),static_html(widget.frame)]
    ids=[re.findall(r'\bid="([^"]+)"',value) for value in values]
    assert all(ids) and len(set(sum(ids,[])))==sum(map(len,ids))
    for value,names in zip(values,ids):
        assert all(ref in names for ref in re.findall(r'url\(#([^)]+)\)',value))
    assert 'width="720.0" height="360.0"' in widget.frame['svg']
    other.close()


def test_bad_native_schema_is_visible_backend_failure(widget,tmp_path):
    script=tmp_path/'bad';script.write_text('#!/usr/bin/env python3\nprint(\'{}\\n<svg></svg>\')\n');script.chmod(0o700)
    deliver(widget);widget.binary=script
    deliver(widget,seq=2,kind=Kind.STATE,state=state(widget))
    assert widget.replies[-1]['kind'] is Kind.ERROR and widget.frame['selected']==-1


def test_native_boolean_schema_rejected(tmp_path):
    script=tmp_path/'bool-schema'
    output = '{"schema":true}\n<svg></svg>'
    script.write_text('#!/usr/bin/env python3\nprint(' + repr(output) + ')\n')
    script.chmod(0o700)
    with pytest.raises(ValueError, match='unsupported Mojo output schema'):
        render(script,sample_rows())


@pytest.mark.parametrize('patch', [
    {'selected': 1000}, {'selected': True},
    {'points': [{'key': 0, 'x': 1, 'y': 2}], 'selected': 1},
    {'points': [{'key': 0, 'x': 1, 'y': 2}] * 2},
    {'points': [{'key': True, 'x': 1, 'y': 2}]},
    {'points': [{'key': 0, 'x': float('nan'), 'y': 2}]},
])
def test_malformed_native_identity_preserves_frame(widget, tmp_path, patch):
    frame = dict(schema=1, selected=-1, points=[])
    frame.update(patch)
    output = json.dumps(frame) + '\n<svg></svg>'
    script = tmp_path / 'bad-frame'
    script.write_text('#!/usr/bin/env python3\nprint(' + repr(output) + ')\n')
    script.chmod(0o700)
    deliver(widget)
    old = widget.frame
    widget.binary = script
    deliver(widget, seq=2, kind=Kind.STATE, state=state(widget))
    assert widget.replies[-1]['kind'] is Kind.ERROR and widget.frame is old
