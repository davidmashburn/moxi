"""Emit the canonical scenario registry for repository-level checks."""

from moxi import canonical_scenarios


def main():
    var registry = canonical_scenarios()
    for index in range(registry.count()):
        var scenario = registry.entry(index)
        print(
            "SCENARIO|",
            scenario.id,
            "|",
            scenario.fixture,
            "|",
            scenario.source,
            "|",
            scenario.task,
            "|",
            scenario.test_source,
            "|",
            scenario.benchmark_source,
            "|",
            scenario.golden_names,
        )
