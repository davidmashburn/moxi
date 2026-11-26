from std.sys import argv
from model import Investigation, Fit, ModelKind, MembershipMode, FixtureState
from panel import panel_json, parse_panel, load_panel


def check(condition: Bool, description: String) raises:
    if not condition:
        raise Error(description)


def near(actual: Float64, expected: Float64, description: String) raises:
    check(abs(actual - expected) < 1e-7, description)

def main() raises:
    var args = argv()
    if len(args) == 3 and String(args[1]) == "--validate":
        var model = load_panel(String(args[2]))
        print(panel_json(model))
        return
    var model = Investigation()
    model.collect()
    check(model.ids() == "[318,429,530,641,752,863]", "I20 cohort membership")
    check(model.notebook.writes == 1, "I20 handler executed")
    model.fit_model(ModelKind.LINEAR)
    near(model.fit.c0, 100.0/3, "linear intercept")
    near(model.fit.c1, 16, "linear slope")
    near(model.sse(model.fit), 448.0/3, "linear SSE")
    near(model.residual(2, model.fit), 20.0/3, "residual sign and value")
    var constant = model.least_squares(ModelKind.MEAN)
    near(model.sse(constant), 13888.0/3, "mean SSE")
    model.fit_model(ModelKind.QUADRATIC)
    near(model.fit.c0, 68, "quadratic c0")
    near(model.fit.c1, -2, "quadratic c1")
    near(model.fit.c2, 2, "quadratic c2")
    near(model.sse(model.fit), 0, "quadratic error")
    model.fit.c0 += 1
    near(model.sse(model.fit), 6, "edited model error")
    model.name = "Warm \"α\" sensors"
    model.hypothesis = "Curvature ≠ causation"
    var json = panel_json(model)
    var restored = parse_panel(json)
    check(restored.name == model.name and restored.hypothesis == model.hypothesis, "Unicode JSON round-trip")
    check(restored.mode == MembershipMode.FROZEN and restored.fit.kind == ModelKind.QUADRATIC and restored.fixture == FixtureState.BASELINE, "parsed domain members")
    check(panel_json(restored) == json, "full saved configuration round-trip")
    near(restored.sse(restored.fit), 6, "restored coefficients control intended observations")
    model.set_fixture(FixtureState.CROSSING)
    check(not model.fitted and not model.contains(207), "frozen IDs and stale fit invalidation")
    model.mode = MembershipMode.LIVE
    model.collect()
    check(model.contains(207), "live rule crosses threshold")
    model.set_fixture(FixtureState.BASELINE)
    check(not model.contains(207), "live member leaves rule")
    model.notebook.rows[1].reading = 70
    model.collect()
    check(model.contains(207), "I20 inclusive boundary")
    model.members.clear()
    model.members.append(318)
    var failed = False
    try:
        model.fit_model(ModelKind.LINEAR)
    except:
        failed = True
    check(failed, "insufficient samples rejected")
    model.name = ""
    failed = False
    var writes = model.notebook.writes
    try:
        model.collect()
    except:
        failed = True
    check(failed and model.notebook.writes == writes, "empty name rejects before operation")
    var invalid_edit = Investigation()
    invalid_edit.collect()
    invalid_edit.set_mode(MembershipMode.LIVE)
    invalid_edit.fit_model(ModelKind.LINEAR)
    invalid_edit.name = ""
    failed = False
    try:
        invalid_edit.set_fixture(FixtureState.CROSSING)
    except:
        failed = True
    check(failed and invalid_edit.fixture == FixtureState.BASELINE and invalid_edit.notebook.rows[1].reading == 58 and invalid_edit.fitted, "failed live refresh preserves source and fit")
    failed = False
    try:
        invalid_edit.set_mode(MembershipMode.FROZEN)
    except:
        failed = True
    check(failed and invalid_edit.mode == MembershipMode.LIVE and invalid_edit.fitted, "failed mode edit preserves current model")
    print("PASS domain: I20 IDs, OLS coefficients, residuals, alternatives, edits, Unicode round-trip, live/frozen, boundary and invalid inputs")
