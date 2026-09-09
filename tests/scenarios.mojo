"""Canonical scenario registry contract test."""

from moxi import (
    SCENARIO_CAPABILITY,
    SCENARIO_COLLECTION,
    SCENARIO_FORM,
    SCENARIO_FRACTAL,
    SCENARIO_PLOT,
    SCENARIO_TEXT,
    SCENARIO_THEME,
    ScenarioRegistry,
    canonical_scenarios,
    canonical_capability_steps,
    canonical_fractal_depths,
    canonical_fractal_cases,
    canonical_fractal_preset_ids,
    canonical_theme_modes,
    test_check,
)
from moxi_demo import DemoCatalog


def main():
    var registry = canonical_scenarios()
    test_check(registry.is_valid())
    test_check(registry.count() == 7)
    test_check(registry.index_for_id(SCENARIO_FORM) == 0)
    test_check(registry.index_for_id(SCENARIO_THEME) == 1)
    test_check(registry.index_for_id(SCENARIO_COLLECTION) == 2)
    test_check(registry.index_for_id(SCENARIO_TEXT) == 3)
    test_check(registry.index_for_id(SCENARIO_PLOT) == 4)
    test_check(registry.index_for_id(SCENARIO_CAPABILITY) == 5)
    test_check(registry.index_for_id(SCENARIO_FRACTAL) == 6)
    test_check(registry.index_for_fixture("plot") == 4)
    test_check(registry.entry(0).command() == "pixi run form-demo")
    test_check(registry.entry(0).test_source == "tests/form.mojo")
    test_check(registry.entry(2).benchmark_source == "benchmarks/interaction_foundation.mojo")
    test_check(registry.entry(2).fixture_size == 10000)
    test_check(registry.entry(2).fixture_seed == 1000)
    test_check(registry.entry(1).fixture_size == len(canonical_theme_modes()))
    test_check(registry.entry(4).fixture_size == 48)
    test_check(registry.entry(4).fixture_seed == 1700000000)
    test_check(registry.entry(5).fixture_size == 10)
    test_check(len(canonical_capability_steps()) == registry.entry(5).fixture_size)
    test_check(len(canonical_fractal_cases()) == registry.entry(6).fixture_size)
    test_check(len(canonical_fractal_preset_ids()) == registry.entry(6).fixture_size)
    test_check(len(canonical_fractal_depths()) == registry.entry(6).fixture_size)
    test_check(registry.entry(4).golden_names == "plot-gallery")
    test_check(registry.entry(5).golden_names.count_codepoints() == 0)
    test_check(registry.entry(2).semantic_hint.count_codepoints() > 20)
    test_check(registry.entry(4).counter_hint.count_codepoints() > 20)

    # Keep the registry's source/task metadata tied to real catalog entries.
    # The registry is deliberately independent of the browser implementation,
    # so this check catches drift without making scenarios own a window.
    var catalog = DemoCatalog()
    for scenario_index in range(registry.count()):
        var scenario = registry.entry(scenario_index)
        var found = False
        for demo_index in range(catalog.count()):
            var demo = catalog.entry(demo_index)
            if demo.source == scenario.source and demo.task == scenario.task:
                test_check(catalog.scenario_id_for(demo_index) == scenario.id)
                found = True
                break
        test_check(found)
    print("Moxi scenario registry test passed")
