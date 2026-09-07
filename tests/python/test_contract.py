from moxi import PlotSpec


def test_plot_spec_uses_the_mojo_field_contract():
    spec = PlotSpec("contract")
    spec.add_scatter("points")
    value = spec.to_json()
    assert value.startswith('{"version":1,"title":"contract"')
    assert '"layers":[{"id":1,"mark":"scatter"' in value
    assert '"encodings":[{"layer":1,"channel":"x"' in value
