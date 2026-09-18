"""Compare identical workbench lanes without dropping raw samples or outliers."""

import argparse
import json
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("before", type=Path)
    parser.add_argument("after", type=Path)
    args = parser.parse_args()
    before = json.loads(args.before.read_text())
    after = json.loads(args.after.read_text())
    if before["lane"] != after["lane"]:
        parser.error("Compare the same lane; software and AppKit are different workloads")
    for field in ("host_model", "cpu_brand", "os_version", "mojo_version"):
        if before["environment"][field] != after["environment"][field]:
            parser.error(f"Environment mismatch: {field}")
    for field in ("window_dimensions", "resize_dimensions", "native_bitmap_dimensions",
                  "native_bitmap_scale", "key_distribution", "selection_density", "cycle_reset"):
        if before["workload"].get(field) != after["workload"].get(field):
            parser.error(f"Workload mismatch: {field}")
    old = {(s["rows"], s["operation"]): s for s in before["summary"]}
    if set(old) != {(s["rows"], s["operation"]) for s in after["summary"]}:
        parser.error("Case sets differ")
    print("rows\toperation\tbefore_p50_ms\tafter_p50_ms\tchange_percent\tbefore_process_medians\tafter_process_medians")
    for result in after["summary"]:
        key = (result["rows"], result["operation"])
        previous = old[key]
        lhs = previous["in_process_elapsed_ms"]["p50"]
        rhs = result["in_process_elapsed_ms"]["p50"]
        medians = lambda s: ",".join(f"{v['p50']:.3f}" for v in s["per_process_elapsed_ms"].values())
        print(f"{key[0]}\t{key[1]}\t{lhs:.3f}\t{rhs:.3f}\t{100 * (rhs / lhs - 1):.2f}\t{medians(previous)}\t{medians(result)}")


if __name__ == "__main__":
    main()
