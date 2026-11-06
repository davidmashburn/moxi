import gc
import io
import json
from concurrent.futures import ThreadPoolExecutor
import xml.etree.ElementTree as ET

import numpy as np
import pytest
from PIL import Image
from pypdf import PdfReader
from moxi import PlotSpec, render as reference
import moxi_native as native
from moxi_native import Column, ColumnKind, InputError, UnsupportedError, NativeStatus, NativeOutput
from fixture import canonical, WIDTH, HEIGHT


def call(spec=None, columns=None, format=native.RenderFormat.RGBA):
    default_spec, default_columns = canonical()
    return native.render(spec or default_spec.to_json(), columns if columns is not None else default_columns,
                         WIDTH, HEIGHT, format)


def test_compiled_version_and_named_states():
    assert native._core.abi_version() == 1
    assert isinstance(Column(np.array([1.0]), kind='numeric').kind, ColumnKind)
    assert Column(np.array([1.0]), kind='numeric').kind is ColumnKind.NUMERIC
    assert NativeStatus(0) is NativeStatus.OK
    assert NativeOutput(1) is NativeOutput.SVG
    assert native.capabilities()['abi3'] is False
    assert native.capabilities()['retained_mojo_objects'] is False


def test_native_formats_and_reference_contracts():
    spec, cols = canonical()
    rgba = call()
    assert len(rgba) == WIDTH * HEIGHT * 4
    assert len(set(rgba)) > 10
    png = call(format=native.RenderFormat.PNG)
    image = Image.open(io.BytesIO(png))
    assert image.size == (WIDTH, HEIGHT) and image.convert('RGBA').tobytes() == rgba
    svg = ET.fromstring(call(format=native.RenderFormat.SVG))
    assert svg.attrib['width'] == str(WIDTH)
    assert len(list(svg.iter())) > 10
    pdf = PdfReader(io.BytesIO(call(format=native.RenderFormat.PDF)))
    assert len(pdf.pages) == 1 and tuple(pdf.pages[0].mediabox)[2:] == (WIDTH, HEIGHT)
    assert pdf.pages[0].images[0].image.convert('RGB').tobytes() == image.convert('RGB').tobytes()
    data = {name: col.values for name, col in cols.items()}
    for format in native.RenderFormat:
        exported = reference(spec.to_json(), data, WIDTH, HEIGHT, format.value)
        assert exported and isinstance(exported, bytes)
        if format is native.RenderFormat.RGBA:
            assert len(exported) == len(rgba)
    # This is a distinct native renderer, not a subprocess/facade render alias.
    assert rgba != reference(spec.to_json(), data, WIDTH, HEIGHT, 'rgba')


@pytest.mark.parametrize('dtype', ['float32', 'float64', 'int32', 'int64'])
def test_numeric_dtypes_and_owned_result(dtype):
    spec, cols = canonical()
    converted = {k: Column(v.values.astype(dtype)) for k, v in cols.items()}
    before = call(spec.to_json(), converted)
    assert before == call()
    converted['value'].values[:] = 0
    assert call(spec.to_json(), converted) != before
    assert before == call()  # previously returned bytes never alias inputs


def test_builtin_xy_and_nullable():
    spec = PlotSpec()
    spec.add_scatter()
    mask = np.array([True, False, True])
    cols = {'x': Column(np.array([0., 1., 2.])),
            'y': Column(np.array([1., np.nan, 3.]), mask)}
    nullable = call(spec.to_json(), cols)
    filtered = {'x': Column(np.array([0., 2.])), 'y': Column(np.array([1., 3.]))}
    assert nullable == call(spec.to_json(), filtered)
    cols['x'] = Column(np.array([np.inf, 1., 2.]), np.array([False, True, True]))
    assert call(spec.to_json(), cols)


@pytest.mark.parametrize('kind,dtype', [(ColumnKind.CATEGORY, 'int32'),
                                      (ColumnKind.STRING, 'U1'),
                                      (ColumnKind.TIMESTAMP, 'datetime64[D]')])
def test_rich_types_explicitly_rejected(kind, dtype):
    _, cols = canonical()
    cols['sample'] = Column(np.zeros(6).astype(dtype), kind=kind)
    with pytest.raises(UnsupportedError, match='metadata'):
        call(columns=cols)


def test_categories_and_invalid_kind():
    _, cols = canonical()
    cols['sample'] = Column(np.arange(6.), categories=('a', 'b'))
    with pytest.raises(UnsupportedError): call(columns=cols)
    with pytest.raises(UnsupportedError): Column(np.arange(2.), kind='accidental')


@pytest.mark.parametrize('value', [np.arange(12.)[::2], np.ones((2, 3)),
    np.arange(6.).astype('>f8'), np.arange(6).astype('uint64'), np.zeros(6, dtype='bool'),
    np.zeros(6, dtype='complex128'), np.array(['x'] * 6), np.array([None] * 6),
    np.ma.array(np.arange(6.), mask=[False] * 6), np.array([np.nan] * 6),
    np.array([np.inf] * 6), np.array([1e9] * 6), np.array([]), np.arange(4097.)])
def test_bad_values(value):
    _, cols = canonical()
    cols['sample'] = Column(value)
    with pytest.raises(InputError): call(columns=cols)


@pytest.mark.parametrize('mask', [np.ones(5, dtype=bool), np.ones(6, dtype='uint8'),
                                   np.ones((2, 3), dtype=bool), np.ones(12, dtype=bool)[::2]])
def test_bad_validity(mask):
    _, cols = canonical()
    cols['value'] = Column(cols['value'].values, mask)
    with pytest.raises(InputError): call(columns=cols)


@pytest.mark.parametrize('spec', ['{', '[]', '{}', '{"version":true}',
                                  '{"version":1,"version":1}', '{"version":NaN}',
                                  '{"version":1,"layers":[null]}', 'x' * 16385])
def test_malformed_specs(spec):
    with pytest.raises(InputError): call(spec)


def test_unsupported_specs_and_bounds():
    spec, cols = canonical()
    for field, value in [('composition', 'facet'), ('title', '非ASCII'), ('unexpected', 1)]:
        raw = spec.as_dict(); raw[field] = value
        with pytest.raises(InputError): call(json.dumps(raw))
    for field, value in [('mark', 'pie'), ('x', 'missing'), ('size', 65), ('color', [float('inf')] * 4), ('horizontal', True)]:
        raw = spec.as_dict(); raw['layers'][0][field] = value
        with pytest.raises(InputError): call(json.dumps(raw))
    for width, height in [(0, HEIGHT), (1025, HEIGHT), (True, HEIGHT), (WIDTH, 63), (WIDTH, 64.5)]:
        with pytest.raises(InputError): native.render(spec.to_json(), cols, width, height)
    with pytest.raises(UnsupportedError): call(format='jpeg')
    with pytest.raises(InputError): call(columns={})
    with pytest.raises(InputError): call(columns={'bad name': Column(np.ones(6))})
    with pytest.raises(InputError): call(columns={'sample': np.ones(6)})


def test_private_c_boundary_and_mojo_failure_mapping():
    # Independent wire literals verify native states and memory bounds.
    columns = ((b'x', np.array([0., 1.]).tobytes(), b'\x01\x01'),
               (b'y', np.array([1., 2.]).tobytes(), b'\x01\x01'))
    status, result = native._core.render(b'{invalid}', columns, 64, 64, 0)
    assert status == 1 and NativeStatus(status) is NativeStatus.INVALID_SPEC and result == b''
    bad = [(), ((b'x', b'123', b'\x01'),), ((b'x', b'\0' * 16, b'\x01\x02'),),
           columns + (columns[0],), ((b'x', b'\0' * 8, b'\1'), columns[1]),
           ((b'x', np.array([float('nan')]).tobytes(), b'\1'),),
           ((b'x\0', b'\0' * 8, b'\1'),)]
    for value in bad:
        with pytest.raises(ValueError, match='native boundary: invalid argument'):
            native._core.render(b'{}', value, 64, 64, 0)
    for kind in (-1, 2, 999):
        with pytest.raises(ValueError): native._core.render(b'{}', columns, 64, 64, kind)


def test_repeated_lifetime_and_recovery():
    spec, columns = canonical()
    expected = native.render(spec.to_json(), columns, 64, 64)
    retained = []
    for index in range(500):
        ephemeral = {k: Column(v.values.copy()) for k, v in columns.items()}
        result = native.render(spec.to_json(), ephemeral, 64, 64)
        for col in ephemeral.values(): col.values[:] = -1
        del ephemeral
        assert result == expected
        if index % 50 == 0:
            retained.append(result)
            gc.collect()
        with pytest.raises(InputError): native.render('{bad}', columns, 64, 64)
        status, empty = native._core.render(b'{bad}', native._columns(columns), 64, 64, 0)
        assert NativeStatus(status) is NativeStatus.INVALID_SPEC and empty == b''
    assert all(value == expected for value in retained)
    with ThreadPoolExecutor(max_workers=4) as pool:
        assert all(value == expected for value in pool.map(
            lambda _: native.render(spec.to_json(), columns, 64, 64), range(40)))
    assert native.render(spec.to_json(), columns, 64, 64) == expected


def test_readonly_unaligned_buffers_and_all_invalid():
    spec, cols = canonical()
    for name, column in list(cols.items()):
        storage = bytearray(1 + column.values.nbytes)
        unaligned = np.ndarray(column.values.shape, dtype='float64', buffer=storage, offset=1)
        unaligned[:] = column.values
        unaligned.flags.writeable = False
        cols[name] = Column(unaligned)
    assert call(spec.to_json(), cols) == call()
    all_invalid = {name: Column(col.values, np.zeros(6, dtype=bool)) for name, col in cols.items()}
    assert len(call(spec.to_json(), all_invalid)) == WIDTH * HEIGHT * 4


def test_stable_native_exception(monkeypatch):
    monkeypatch.setattr(native._core, 'render', lambda *args: (1, b''))
    with pytest.raises(native.NativeRenderError) as raised:
        call()
    assert raised.value.status is NativeStatus.INVALID_SPEC
    assert str(raised.value) == 'Mojo render failed: INVALID_SPEC'


def test_json_boundary_types_and_shared_scales():
    spec, _ = canonical()
    for value in [123, None, [], {}]:
        raw = spec.as_dict(); raw['title'] = value
        with pytest.raises(InputError): call(json.dumps(raw))
    raw = spec.as_dict(); raw['shared_scales'] = {'x': False, 'y': False}
    with pytest.raises(UnsupportedError): call(json.dumps(raw))
    with pytest.raises(InputError): call('"\ud800"')


@pytest.mark.parametrize('label', ['closing } brace', 'opening { brace', 'quote " and \\ slash'])
def test_json_punctuation_in_layer_labels_preserves_geometry(label):
    spec, columns = canonical()
    original = json.loads(spec.to_json())
    expected = call(json.dumps(original), columns)
    for layer in original['layers']:
        layer['label'] = label
    assert call(json.dumps(original), columns) == expected
