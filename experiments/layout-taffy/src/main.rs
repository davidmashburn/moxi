use std::env;

use layout_taffy_spike::{benchmark, run_correctness, Rect, SpikeError};

fn print_rect(rect: Rect) -> String {
    format!(
        "({:.2},{:.2},{:.2},{:.2})",
        rect.x, rect.y, rect.width, rect.height
    )
}

fn print_correctness() -> Result<(), SpikeError> {
    println!("correctness:");
    for (name, rects, counters) in run_correctness()? {
        let geometry = rects
            .iter()
            .map(|rect| print_rect(*rect))
            .collect::<Vec<_>>()
            .join(" ");
        println!(
            "  {name}: rects={geometry} callbacks={} measured={} measure_ns={}",
            counters.callback_calls,
            counters.measured_leaves,
            counters.measure_time.as_nanos()
        );
    }
    Ok(())
}

fn print_correctness_json() -> Result<(), SpikeError> {
    let reports = run_correctness()?;
    println!("[");
    for (index, (name, rects, counters)) in reports.iter().enumerate() {
        let rects = rects
            .iter()
            .map(|rect| {
                format!(
                    "{{\"x\":{:.2},\"y\":{:.2},\"width\":{:.2},\"height\":{:.2}}}",
                    rect.x, rect.y, rect.width, rect.height
                )
            })
            .collect::<Vec<_>>()
            .join(",");
        let comma = if index + 1 == reports.len() { "" } else { "," };
        println!(
            "  {{\"name\":\"{name}\",\"rects\":[{rects}],\"callback_calls\":{},\"measured_leaves\":{},\"measure_ns\":{}}}{comma}",
            counters.callback_calls,
            counters.measured_leaves,
            counters.measure_time.as_nanos()
        );
    }
    println!("]");
    Ok(())
}

fn print_stats(stats: layout_taffy_spike::SummaryStats) -> String {
    format!("{:.0}/{:.0}", stats.median, stats.p95)
}

fn print_benchmark(iterations: usize) -> Result<(), SpikeError> {
    println!(
        "benchmark columns: shape nodes depth iterations | creation_ns median/p95 | cold_layout_ns median/p95 | cold_publication_ns median/p95 | cold_total_ns median/p95 | cold_callbacks median/p95 | cold_measure_ns median/p95 | update_mutation_ns median/p95 | update_layout_ns median/p95 | update_publication_ns median/p95 | update_total_ns median/p95 | update_callbacks median/p95 | update_measure_ns median/p95 | unchanged_layout_ns median/p95 | unchanged_publication_ns median/p95 | unchanged_total_ns median/p95 | unchanged_callbacks median/p95 | unchanged_measure_ns median/p95"
    );
    for shape in ["wide", "deep"] {
        for nodes in [100_usize, 1_000, 10_000] {
            let summary = benchmark(shape, nodes, iterations)?;
            println!(
                "benchmark {shape} {nodes} {} {} | {} | {} | {} | {} | {} | {} | {} | {} | {} | {} | {} | {} | {} | {} | {} | {} | {}",
                summary.depth,
                summary.iterations,
                print_stats(summary.tree_creation_ns),
                print_stats(summary.cold_layout_ns),
                print_stats(summary.cold_publication_ns),
                print_stats(summary.cold_total_ns),
                print_stats(summary.cold_callbacks),
                print_stats(summary.cold_measure_ns),
                print_stats(summary.update_mutation_ns),
                print_stats(summary.update_layout_ns),
                print_stats(summary.update_publication_ns),
                print_stats(summary.update_total_ns),
                print_stats(summary.update_callbacks),
                print_stats(summary.update_measure_ns),
                print_stats(summary.unchanged_layout_ns),
                print_stats(summary.unchanged_publication_ns),
                print_stats(summary.unchanged_total_ns),
                print_stats(summary.unchanged_callbacks),
                print_stats(summary.unchanged_measure_ns),
            );
            println!(
                "  checksums cold={} update={} unchanged={}",
                summary.cold_checksum, summary.update_checksum, summary.unchanged_checksum
            );
        }
    }
    Ok(())
}

fn usage() {
    eprintln!("usage: layout-taffy [correctness|correctness-json|benchmark|all] [--iterations N]");
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let mut mode = "all";
    let mut iterations = env::var("TAFFY_BENCH_ITERS")
        .ok()
        .and_then(|value| value.parse().ok())
        .unwrap_or(7);
    let mut args = env::args().skip(1);
    while let Some(arg) = args.next() {
        match arg.as_str() {
            "correctness" | "correctness-json" | "benchmark" | "all" => {
                mode = Box::leak(arg.into_boxed_str())
            }
            "--iterations" => {
                iterations = args.next().ok_or("--iterations needs a number")?.parse()?;
                if iterations == 0 {
                    return Err("--iterations must be greater than zero".into());
                }
            }
            "--help" | "-h" => {
                usage();
                return Ok(());
            }
            _ => {
                usage();
                return Err(format!("unknown argument: {arg}").into());
            }
        }
    }

    match mode {
        "correctness" => print_correctness()?,
        "correctness-json" => print_correctness_json()?,
        "benchmark" => print_benchmark(iterations)?,
        "all" => {
            print_correctness()?;
            print_benchmark(iterations)?;
        }
        _ => unreachable!(),
    }
    Ok(())
}
