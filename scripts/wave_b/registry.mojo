"""Serialize the registry owned by src/moxi/scenarios.mojo for every E02 consumer."""
from moxi.scenarios import canonical_wave_b_scenarios


def main():
    for entry in canonical_wave_b_scenarios():
        print(entry.name,"|",entry.fixture_path,"|",entry.row_count,"|",entry.seed,"|",entry.width,"|",entry.height,"|",entry.schema_version,"|",entry.reference_revision,"|",entry.reference_available)
