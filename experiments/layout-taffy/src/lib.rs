//! A small, reproducible Taffy adapter experiment.
//!
//! The experiment deliberately owns a Taffy tree and keeps the measurement
//! callback outside of Taffy's storage.  It is not part of Moxi's production
//! dependency graph.

#![allow(clippy::type_complexity)]

use std::time::{Duration, Instant};

use taffy::prelude::*;
use taffy::tree::{LayoutInput, LayoutOutput};

const CHAR_WIDTH_FACTOR: f32 = 0.56;
const LINE_HEIGHT_FACTOR: f32 = 1.25;

/// The deterministic text model used by the headless fixtures.
///
/// This intentionally matches the estimator described in Moxi's research
/// document: every Unicode scalar is assigned `font_size * 0.56` advance and
/// each line is `font_size * 1.25` high.  It is a fixture model, not native
/// font shaping.
#[derive(Clone, Debug)]
pub struct TextContext {
    pub text: String,
    pub font_size: f32,
    pub revision: u32,
}

impl TextContext {
    pub fn new(text: impl Into<String>, font_size: f32) -> Self {
        Self {
            text: text.into(),
            font_size,
            revision: 0,
        }
    }

    fn char_width(&self) -> f32 {
        self.font_size * CHAR_WIDTH_FACTOR
    }

    fn line_height(&self) -> f32 {
        self.font_size * LINE_HEIGHT_FACTOR
    }
}

/// User data supplied to Taffy's global measurement callback.
#[derive(Clone, Debug)]
pub enum NodeContext {
    Text(TextContext),
    /// A deterministic non-text leaf used by the larger tree benchmarks.
    Box {
        width: f32,
        height: f32,
        revision: u32,
    },
}

/// Counts and timings collected from one layout pass.
#[derive(Clone, Debug, Default)]
pub struct MeasureCounters {
    /// Calls into the adapter's callback, one for each uncached leaf layout.
    pub callback_calls: u64,
    /// Calls into the text/box measurement body.
    pub measured_leaves: u64,
    /// Time spent inside the deterministic measurement body.
    pub measure_time: Duration,
}

/// A stable, copied result for one node.
#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct Rect {
    pub x: f32,
    pub y: f32,
    pub width: f32,
    pub height: f32,
}

/// Timings and operation counters for one phase of a benchmark.
#[derive(Clone, Debug, Default)]
pub struct PhaseSample {
    pub layout_time: Duration,
    pub publication_time: Duration,
    pub total_time: Duration,
    pub counters: MeasureCounters,
    pub layout_reads: u64,
    pub checksum: u64,
}

/// One benchmark sample. Tree construction is kept as a separate field so it
/// cannot be mistaken for layout computation.
#[derive(Clone, Debug, Default)]
pub struct BenchmarkSample {
    pub depth: usize,
    pub tree_creation: Duration,
    pub cold: PhaseSample,
    pub update_mutation: Duration,
    pub update: PhaseSample,
    pub unchanged: PhaseSample,
}

/// A result row aggregated over repeated benchmark iterations.
#[derive(Clone, Debug)]
pub struct BenchmarkSummary {
    pub shape: &'static str,
    pub nodes: usize,
    pub depth: usize,
    pub iterations: usize,
    pub tree_creation_ns: SummaryStats,
    pub cold_layout_ns: SummaryStats,
    pub cold_publication_ns: SummaryStats,
    pub cold_total_ns: SummaryStats,
    pub cold_callbacks: SummaryStats,
    pub cold_measure_ns: SummaryStats,
    pub update_mutation_ns: SummaryStats,
    pub update_layout_ns: SummaryStats,
    pub update_publication_ns: SummaryStats,
    pub update_total_ns: SummaryStats,
    pub update_callbacks: SummaryStats,
    pub update_measure_ns: SummaryStats,
    pub unchanged_layout_ns: SummaryStats,
    pub unchanged_publication_ns: SummaryStats,
    pub unchanged_total_ns: SummaryStats,
    pub unchanged_callbacks: SummaryStats,
    pub unchanged_measure_ns: SummaryStats,
    pub cold_checksum: u64,
    pub update_checksum: u64,
    pub unchanged_checksum: u64,
}

/// Median and p95 duration/count statistic, represented as a floating point
/// nanosecond value to keep the output compact and machine-readable.
#[derive(Clone, Copy, Debug, Default)]
pub struct SummaryStats {
    pub median: f64,
    pub p95: f64,
}

#[derive(Debug)]
pub enum SpikeError {
    Taffy(taffy::TaffyError),
    Assertion(String),
    InvalidArgument(String),
}

impl std::fmt::Display for SpikeError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Taffy(error) => write!(f, "Taffy error: {error}"),
            Self::Assertion(message) => write!(f, "fixture assertion failed: {message}"),
            Self::InvalidArgument(message) => write!(f, "invalid argument: {message}"),
        }
    }
}

impl std::error::Error for SpikeError {}

impl From<taffy::TaffyError> for SpikeError {
    fn from(value: taffy::TaffyError) -> Self {
        Self::Taffy(value)
    }
}

fn assert_close(name: &str, got: f32, expected: f32) -> Result<(), SpikeError> {
    if (got - expected).abs() > 0.01 {
        return Err(SpikeError::Assertion(format!(
            "{name}: got {got:.3}, expected {expected:.3}"
        )));
    }
    Ok(())
}

fn assert_rect(name: &str, got: Rect, expected: Rect) -> Result<(), SpikeError> {
    assert_close(&format!("{name}.x"), got.x, expected.x)?;
    assert_close(&format!("{name}.y"), got.y, expected.y)?;
    assert_close(&format!("{name}.width"), got.width, expected.width)?;
    assert_close(&format!("{name}.height"), got.height, expected.height)?;
    Ok(())
}

fn text_measure(
    context: &TextContext,
    known: Size<Option<f32>>,
    available: Size<AvailableSpace>,
) -> Size<f32> {
    let advance = context.char_width();
    let line_height = context.line_height();
    let scalar_count = context.text.chars().count();
    let natural_width = scalar_count as f32 * advance;

    let offered_width = known.width.or_else(|| match available.width {
        AvailableSpace::Definite(width) => Some(width.max(0.0)),
        AvailableSpace::MinContent | AvailableSpace::MaxContent => None,
    });

    let chars_per_line = offered_width
        .filter(|width| *width > 0.0 && advance > 0.0)
        .map(|width| ((width / advance).floor() as usize).max(1));
    let line_count = match chars_per_line {
        Some(per_line) => ((scalar_count + per_line - 1) / per_line).max(1),
        None => 1,
    };
    let measured_width = offered_width
        .unwrap_or(natural_width)
        .min(natural_width.max(0.0));
    let measured_height = line_count as f32 * line_height;

    Size {
        width: known.width.unwrap_or(measured_width),
        height: known.height.unwrap_or(measured_height),
    }
}

fn node_measure(
    inputs: LayoutInput,
    _node_id: NodeId,
    node_context: Option<&mut NodeContext>,
    style: &Style,
    counters: &mut MeasureCounters,
) -> LayoutOutput {
    counters.callback_calls += 1;
    taffy::compute_leaf_layout(
        inputs,
        style,
        |_, _| 0.0,
        |known, available| {
            counters.measured_leaves += 1;
            let started = Instant::now();
            let result = match node_context {
                Some(NodeContext::Text(context)) => text_measure(context, known, available),
                Some(NodeContext::Box { width, height, .. }) => Size {
                    width: known.width.unwrap_or(*width),
                    height: known.height.unwrap_or(*height),
                },
                None => Size::ZERO,
            };
            counters.measure_time += started.elapsed();
            result
        },
    )
}

fn layout_once(
    tree: &mut TaffyTree<NodeContext>,
    root: NodeId,
    nodes: &[NodeId],
    viewport: Size<AvailableSpace>,
) -> Result<PhaseSample, SpikeError> {
    let mut counters = MeasureCounters::default();
    let started = Instant::now();
    tree.compute_layout_with_measure(root, viewport, |inputs, node_id, context, style| {
        node_measure(inputs, node_id, context, style, &mut counters)
    })?;
    let layout_time = started.elapsed();

    let publication_started = Instant::now();
    let mut checksum = 0_u64;
    for (index, node) in nodes.iter().enumerate() {
        let layout = tree.layout(*node)?;
        // Quantise the geometry into a deterministic checksum.  The checksum
        // makes it difficult for an optimizing build to elide publication.
        let values = [
            layout.location.x,
            layout.location.y,
            layout.size.width,
            layout.size.height,
        ];
        for value in values {
            checksum =
                checksum.rotate_left(5) ^ (value.to_bits() as u64).wrapping_add(index as u64);
        }
    }
    std::hint::black_box(checksum);
    let publication_time = publication_started.elapsed();

    Ok(PhaseSample {
        layout_time,
        publication_time,
        total_time: layout_time + publication_time,
        counters,
        layout_reads: nodes.len() as u64,
        checksum,
    })
}

/// Build the row fixture from the acceptance contract.
pub fn row_weighted_fixture() -> Result<(TaffyTree<NodeContext>, NodeId, Vec<NodeId>), SpikeError> {
    let mut tree: TaffyTree<NodeContext> = TaffyTree::with_capacity(4);
    let root_style = Style {
        display: Display::Flex,
        flex_direction: FlexDirection::Row,
        size: Size {
            width: length(300.0),
            height: length(40.0),
        },
        gap: Size {
            width: length(10.0),
            height: zero(),
        },
        ..Default::default()
    };
    let first_style = Style {
        flex_grow: 1.0,
        flex_shrink: 0.0,
        flex_basis: length(0.0),
        min_size: Size {
            width: length(0.0),
            height: auto(),
        },
        max_size: Size {
            width: length(60.0),
            height: auto(),
        },
        ..Default::default()
    };
    let second_style = Style {
        flex_grow: 2.0,
        flex_shrink: 0.0,
        flex_basis: length(0.0),
        min_size: Size {
            width: length(0.0),
            height: auto(),
        },
        ..Default::default()
    };
    let first = tree.new_leaf_with_context(
        first_style,
        NodeContext::Box {
            width: 0.0,
            height: 40.0,
            revision: 0,
        },
    )?;
    let second = tree.new_leaf_with_context(
        second_style,
        NodeContext::Box {
            width: 0.0,
            height: 40.0,
            revision: 0,
        },
    )?;
    let root = tree.new_with_children(root_style, &[first, second])?;
    Ok((tree, root, vec![root, first, second]))
}

/// Build the column fixture from the acceptance contract.
pub fn column_content_fill_fixture(
) -> Result<(TaffyTree<NodeContext>, NodeId, Vec<NodeId>), SpikeError> {
    let mut tree: TaffyTree<NodeContext> = TaffyTree::with_capacity(4);
    let root_style = Style {
        display: Display::Flex,
        flex_direction: FlexDirection::Column,
        size: Size {
            width: length(300.0),
            height: length(200.0),
        },
        padding: taffy::Rect {
            left: length(10.0),
            right: length(10.0),
            top: length(10.0),
            bottom: length(10.0),
        },
        gap: Size {
            width: zero(),
            height: length(5.0),
        },
        ..Default::default()
    };
    let header_style = Style {
        size: Size {
            width: auto(),
            height: length(20.0),
        },
        ..Default::default()
    };
    let body_style = Style {
        flex_grow: 1.0,
        min_size: Size {
            width: auto(),
            height: length(40.0),
        },
        ..Default::default()
    };
    let header = tree.new_leaf_with_context(
        header_style,
        NodeContext::Text(TextContext::new("Header", 16.0)),
    )?;
    let body = tree.new_leaf_with_context(
        body_style,
        NodeContext::Box {
            width: 0.0,
            height: 0.0,
            revision: 0,
        },
    )?;
    let root = tree.new_with_children(root_style, &[header, body])?;
    Ok((tree, root, vec![root, header, body]))
}

/// Build the width-dependent wrapping fixture.
pub fn wrapped_text_fixture() -> Result<(TaffyTree<NodeContext>, NodeId, Vec<NodeId>), SpikeError> {
    let mut tree: TaffyTree<NodeContext> = TaffyTree::with_capacity(4);
    let root_style = Style {
        display: Display::Flex,
        flex_direction: FlexDirection::Row,
        size: Size {
            width: length(200.0),
            height: auto(),
        },
        gap: Size {
            width: length(10.0),
            height: zero(),
        },
        align_items: Some(AlignItems::FLEX_START),
        ..Default::default()
    };
    let text_style = Style {
        flex_grow: 1.0,
        flex_basis: length(0.0),
        min_size: Size {
            width: length(0.0),
            height: length(0.0),
        },
        align_self: Some(AlignSelf::FLEX_START),
        ..Default::default()
    };
    let first = tree.new_leaf_with_context(
        text_style.clone(),
        NodeContext::Text(TextContext::new("abcdefghijklmnopqrst", 16.0)),
    )?;
    let second = tree.new_leaf_with_context(
        text_style,
        NodeContext::Text(TextContext::new("abcdefghijklmnopqrstuvwxyzabcd", 16.0)),
    )?;
    let root = tree.new_with_children(root_style, &[first, second])?;
    Ok((tree, root, vec![root, first, second]))
}

/// Run the correctness fixtures and return copied geometry for the README or
/// the executable's human-readable output.
pub fn run_correctness() -> Result<Vec<(&'static str, Vec<Rect>, MeasureCounters)>, SpikeError> {
    let mut reports = Vec::new();

    let (mut tree, root, nodes) = row_weighted_fixture()?;
    let phase = layout_once(
        &mut tree,
        root,
        &nodes,
        Size {
            width: AvailableSpace::Definite(300.0),
            height: AvailableSpace::Definite(40.0),
        },
    )?;
    let row_rects = copy_rects(&tree, &nodes)?;
    assert_close("row first width", row_rects[1].width, 60.0)?;
    assert_close("row second width", row_rects[2].width, 230.0)?;
    assert_close("row second x", row_rects[2].x, 70.0)?;
    reports.push(("row-weighted-fill-min-max", row_rects, phase.counters));

    let (mut tree, root, nodes) = column_content_fill_fixture()?;
    let phase = layout_once(
        &mut tree,
        root,
        &nodes,
        Size {
            width: AvailableSpace::Definite(300.0),
            height: AvailableSpace::Definite(200.0),
        },
    )?;
    let column_rects = copy_rects(&tree, &nodes)?;
    assert_rect(
        "column root",
        column_rects[0],
        Rect {
            x: 0.0,
            y: 0.0,
            width: 300.0,
            height: 200.0,
        },
    )?;
    assert_rect(
        "column body",
        column_rects[2],
        Rect {
            x: 10.0,
            y: 35.0,
            width: 280.0,
            height: 155.0,
        },
    )?;
    reports.push((
        "column-content-header-fill-body",
        column_rects,
        phase.counters,
    ));

    let (mut tree, root, nodes) = wrapped_text_fixture()?;
    let phase = layout_once(
        &mut tree,
        root,
        &nodes,
        Size {
            width: AvailableSpace::Definite(200.0),
            height: AvailableSpace::MaxContent,
        },
    )?;
    let wrapped_rects = copy_rects(&tree, &nodes)?;
    assert_close("wrapped first offered width", wrapped_rects[1].width, 95.0)?;
    assert_close("wrapped second offered width", wrapped_rects[2].width, 95.0)?;
    assert_close("wrapped first height", wrapped_rects[1].height, 40.0)?;
    assert_close("wrapped second height", wrapped_rects[2].height, 60.0)?;
    reports.push((
        "wrapped-text-at-offered-width",
        wrapped_rects,
        phase.counters,
    ));

    Ok(reports)
}

fn copy_rects(tree: &TaffyTree<NodeContext>, nodes: &[NodeId]) -> Result<Vec<Rect>, SpikeError> {
    nodes
        .iter()
        .map(|node| {
            let layout = tree.layout(*node)?;
            Ok(Rect {
                x: layout.location.x,
                y: layout.location.y,
                width: layout.size.width,
                height: layout.size.height,
            })
        })
        .collect()
}

fn benchmark_leaf_style() -> Style {
    Style {
        flex_grow: 1.0,
        flex_basis: length(0.0),
        min_size: Size {
            width: length(0.0),
            height: length(0.0),
        },
        align_self: Some(AlignSelf::FLEX_START),
        ..Default::default()
    }
}

fn benchmark_container_style() -> Style {
    Style {
        display: Display::Flex,
        flex_direction: FlexDirection::Row,
        flex_grow: 1.0,
        flex_basis: length(0.0),
        min_size: Size {
            width: length(0.0),
            height: length(0.0),
        },
        align_self: Some(AlignSelf::FLEX_START),
        ..Default::default()
    }
}

struct BenchTree {
    tree: TaffyTree<NodeContext>,
    root: NodeId,
    nodes: Vec<NodeId>,
    update_node: NodeId,
    depth: usize,
}

fn new_bench_leaf(
    tree: &mut TaffyTree<NodeContext>,
    nodes: &mut Vec<NodeId>,
    index: usize,
) -> Result<NodeId, SpikeError> {
    let node = tree.new_leaf_with_context(
        benchmark_leaf_style(),
        NodeContext::Text(TextContext::new(format!("node-{index}"), 12.0)),
    )?;
    nodes.push(node);
    Ok(node)
}

fn build_deep_subtree(
    tree: &mut TaffyTree<NodeContext>,
    nodes: &mut Vec<NodeId>,
    next_index: &mut usize,
    count: usize,
    depth: usize,
    max_depth: usize,
    deepest: &mut usize,
) -> Result<NodeId, SpikeError> {
    *deepest = (*deepest).max(depth);
    if count == 1 || depth >= max_depth {
        let index = *next_index;
        *next_index += 1;
        return new_bench_leaf(tree, nodes, index);
    }

    // Four-way fanout keeps the tree genuinely deep while bounding the depth
    // for the benchmark sizes.  Remainders are distributed to the first
    // children so the requested total node count is exact.
    let child_count = 4.min(count - 1);
    let remaining = count - 1;
    let base = remaining / child_count;
    let remainder = remaining % child_count;
    let mut children = Vec::with_capacity(child_count);
    for child_index in 0..child_count {
        let child_size = base + usize::from(child_index < remainder);
        children.push(build_deep_subtree(
            tree,
            nodes,
            next_index,
            child_size,
            depth + 1,
            max_depth,
            deepest,
        )?);
    }
    let node = tree.new_with_children(benchmark_container_style(), &children)?;
    nodes.push(node);
    Ok(node)
}

fn build_bench_tree(shape: &'static str, node_count: usize) -> Result<BenchTree, SpikeError> {
    if node_count < 2 {
        return Err(SpikeError::InvalidArgument(
            "benchmark node count must be at least 2".into(),
        ));
    }

    let mut tree: TaffyTree<NodeContext> = TaffyTree::with_capacity(node_count);
    let mut nodes = Vec::with_capacity(node_count);
    let (root, depth) = if shape == "wide" {
        let mut children = Vec::with_capacity(node_count - 1);
        for index in 0..(node_count - 1) {
            children.push(new_bench_leaf(&mut tree, &mut nodes, index)?);
        }
        let root = tree.new_with_children(
            Style {
                display: Display::Flex,
                flex_direction: FlexDirection::Row,
                size: Size {
                    width: length(800.0),
                    height: length(600.0),
                },
                align_items: Some(AlignItems::FLEX_START),
                ..Default::default()
            },
            &children,
        )?;
        nodes.push(root);
        (root, 2)
    } else {
        let mut next_index = 0;
        let mut deepest = 0;
        let root = build_deep_subtree(
            &mut tree,
            &mut nodes,
            &mut next_index,
            node_count,
            0,
            8,
            &mut deepest,
        )?;
        (root, deepest + 1)
    };

    if tree.total_node_count() != node_count || nodes.len() != node_count {
        return Err(SpikeError::Assertion(format!(
            "{shape} tree requested {node_count} nodes but built {}",
            tree.total_node_count()
        )));
    }
    let update_node = nodes
        .iter()
        .copied()
        .find(|node| tree.get_node_context(*node).is_some())
        .ok_or_else(|| SpikeError::Assertion("benchmark tree has no measured leaf".into()))?;
    Ok(BenchTree {
        tree,
        root,
        nodes,
        update_node,
        depth,
    })
}

fn update_context(tree: &mut TaffyTree<NodeContext>, node: NodeId) -> Result<Duration, SpikeError> {
    let started = Instant::now();
    let context = tree
        .get_node_context(node)
        .cloned()
        .ok_or_else(|| SpikeError::Assertion("update target has no context".into()))?;
    let updated = match context {
        NodeContext::Text(mut context) => {
            context.text.push('x');
            context.revision += 1;
            NodeContext::Text(context)
        }
        NodeContext::Box {
            width,
            height,
            revision,
        } => NodeContext::Box {
            width,
            height,
            revision: revision + 1,
        },
    };
    tree.set_node_context(node, Some(updated))?;
    Ok(started.elapsed())
}

/// Run one cold/update/unchanged sequence on a freshly created tree.
pub fn benchmark_one(
    shape: &'static str,
    node_count: usize,
) -> Result<BenchmarkSample, SpikeError> {
    let creation_started = Instant::now();
    let mut bench = build_bench_tree(shape, node_count)?;
    let tree_creation = creation_started.elapsed();
    let viewport = Size {
        width: AvailableSpace::Definite(800.0),
        height: AvailableSpace::Definite(600.0),
    };
    let cold = layout_once(&mut bench.tree, bench.root, &bench.nodes, viewport)?;
    let update_mutation = update_context(&mut bench.tree, bench.update_node)?;
    let update = layout_once(&mut bench.tree, bench.root, &bench.nodes, viewport)?;
    let unchanged = layout_once(&mut bench.tree, bench.root, &bench.nodes, viewport)?;
    Ok(BenchmarkSample {
        depth: bench.depth,
        tree_creation,
        cold,
        update_mutation,
        update,
        unchanged,
    })
}

fn percentile(mut values: Vec<f64>, percentile: f64) -> f64 {
    values.sort_by(|a, b| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal));
    if values.is_empty() {
        return 0.0;
    }
    let index = ((values.len() - 1) as f64 * percentile).round() as usize;
    values[index.min(values.len() - 1)]
}

fn stats(values: impl IntoIterator<Item = f64>) -> SummaryStats {
    let values: Vec<f64> = values.into_iter().collect();
    SummaryStats {
        median: percentile(values.clone(), 0.50),
        p95: percentile(values, 0.95),
    }
}

/// Run repeated benchmark sequences and aggregate median/p95 values.
pub fn benchmark(
    shape: &'static str,
    node_count: usize,
    iterations: usize,
) -> Result<BenchmarkSummary, SpikeError> {
    if iterations == 0 {
        return Err(SpikeError::InvalidArgument(
            "iterations must be greater than zero".into(),
        ));
    }
    let mut samples = Vec::with_capacity(iterations);
    for _ in 0..iterations {
        samples.push(benchmark_one(shape, node_count)?);
    }

    let depth = samples[0].depth;
    let summary = BenchmarkSummary {
        shape,
        nodes: node_count,
        depth,
        iterations,
        tree_creation_ns: stats(samples.iter().map(|s| s.tree_creation.as_secs_f64() * 1e9)),
        cold_layout_ns: stats(
            samples
                .iter()
                .map(|s| s.cold.layout_time.as_secs_f64() * 1e9),
        ),
        cold_publication_ns: stats(
            samples
                .iter()
                .map(|s| s.cold.publication_time.as_secs_f64() * 1e9),
        ),
        cold_total_ns: stats(
            samples
                .iter()
                .map(|s| s.cold.total_time.as_secs_f64() * 1e9),
        ),
        cold_callbacks: stats(
            samples
                .iter()
                .map(|s| s.cold.counters.callback_calls as f64),
        ),
        cold_measure_ns: stats(
            samples
                .iter()
                .map(|s| s.cold.counters.measure_time.as_secs_f64() * 1e9),
        ),
        update_mutation_ns: stats(
            samples
                .iter()
                .map(|s| s.update_mutation.as_secs_f64() * 1e9),
        ),
        update_layout_ns: stats(
            samples
                .iter()
                .map(|s| s.update.layout_time.as_secs_f64() * 1e9),
        ),
        update_publication_ns: stats(
            samples
                .iter()
                .map(|s| s.update.publication_time.as_secs_f64() * 1e9),
        ),
        update_total_ns: stats(
            samples
                .iter()
                .map(|s| s.update.total_time.as_secs_f64() * 1e9),
        ),
        update_callbacks: stats(
            samples
                .iter()
                .map(|s| s.update.counters.callback_calls as f64),
        ),
        update_measure_ns: stats(
            samples
                .iter()
                .map(|s| s.update.counters.measure_time.as_secs_f64() * 1e9),
        ),
        unchanged_layout_ns: stats(
            samples
                .iter()
                .map(|s| s.unchanged.layout_time.as_secs_f64() * 1e9),
        ),
        unchanged_publication_ns: stats(
            samples
                .iter()
                .map(|s| s.unchanged.publication_time.as_secs_f64() * 1e9),
        ),
        unchanged_total_ns: stats(
            samples
                .iter()
                .map(|s| s.unchanged.total_time.as_secs_f64() * 1e9),
        ),
        unchanged_callbacks: stats(
            samples
                .iter()
                .map(|s| s.unchanged.counters.callback_calls as f64),
        ),
        unchanged_measure_ns: stats(
            samples
                .iter()
                .map(|s| s.unchanged.counters.measure_time.as_secs_f64() * 1e9),
        ),
        cold_checksum: samples[0].cold.checksum,
        update_checksum: samples[0].update.checksum,
        unchanged_checksum: samples[0].unchanged.checksum,
    };
    if summary.cold_checksum != summary.update_checksum {
        // The one-leaf edit changes the measured content, but a geometry checksum
        // may remain unchanged when the leaf still fits on one line.  The
        // operation counters remain the source of truth for invalidation.
        std::hint::black_box(summary.update_checksum);
    }
    Ok(summary)
}

/// Small C-compatible rectangle used by the optional static library bridge.
#[repr(C)]
#[derive(Clone, Copy, Debug, Default)]
pub struct CRect {
    pub x: f32,
    pub y: f32,
    pub width: f32,
    pub height: f32,
}

struct CTree {
    tree: TaffyTree<NodeContext>,
    root: NodeId,
    nodes: Vec<NodeId>,
}

fn ffi_result<T>(operation: impl FnOnce() -> Result<T, SpikeError>) -> Result<T, ()> {
    std::panic::catch_unwind(std::panic::AssertUnwindSafe(operation))
        .ok()
        .and_then(Result::ok)
        .ok_or(())
}

/// Create an empty flex-row tree.  External node handles are indexes into this
/// adapter, so Taffy's generational `NodeId` never crosses the ABI.
#[no_mangle]
pub extern "C" fn layout_taffy_create(width: f32, height: f32) -> *mut std::ffi::c_void {
    let result = ffi_result(|| {
        let mut tree: TaffyTree<NodeContext> = TaffyTree::with_capacity(8);
        let root = tree.new_with_children(
            Style {
                display: Display::Flex,
                flex_direction: FlexDirection::Row,
                size: Size {
                    width: length(width.max(0.0)),
                    height: length(height.max(0.0)),
                },
                ..Default::default()
            },
            &[],
        )?;
        Ok(Box::into_raw(Box::new(CTree {
            tree,
            root,
            nodes: Vec::new(),
        })) as *mut std::ffi::c_void)
    });
    result.unwrap_or(std::ptr::null_mut())
}

/// Add a measured leaf to the C bridge and return its external index, or -1.
///
/// # Safety
///
/// `handle` must be a live pointer returned by `layout_taffy_create`, and
/// `text` must point to a readable NUL-terminated string for the duration of
/// this call. The handle must not be used concurrently with this operation.
#[no_mangle]
pub unsafe extern "C" fn layout_taffy_add_text(
    handle: *mut std::ffi::c_void,
    text: *const std::ffi::c_char,
    font_size: f32,
    flex_grow: f32,
) -> i32 {
    if handle.is_null() || text.is_null() {
        return -1;
    }
    let result = ffi_result(|| {
        // SAFETY: the caller promises a valid NUL-terminated string for the
        // duration of this call; all resulting data is copied into Rust.
        let text = unsafe { std::ffi::CStr::from_ptr(text) }
            .to_string_lossy()
            .into_owned();
        // SAFETY: null was checked above and ownership remains with the caller.
        let state = unsafe { &mut *(handle as *mut CTree) };
        let node = state.tree.new_leaf_with_context(
            Style {
                flex_grow: flex_grow.max(0.0),
                flex_basis: length(0.0),
                min_size: Size {
                    width: length(0.0),
                    height: length(0.0),
                },
                align_self: Some(AlignSelf::FLEX_START),
                ..Default::default()
            },
            NodeContext::Text(TextContext::new(text, font_size.max(1.0))),
        )?;
        let index = state.nodes.len();
        state.nodes.push(node);
        state.tree.add_child(state.root, node)?;
        Ok(i32::try_from(index).unwrap_or(-1))
    });
    result.unwrap_or(-1)
}

/// Compute the C bridge tree.  A non-zero return means the handle or layout
/// operation was invalid; no Rust panic is allowed to cross the ABI.
///
/// # Safety
///
/// `handle` must be a live pointer returned by `layout_taffy_create` and must
/// not be used concurrently with this operation.
#[no_mangle]
pub unsafe extern "C" fn layout_taffy_compute(
    handle: *mut std::ffi::c_void,
    width: f32,
    height: f32,
) -> i32 {
    if handle.is_null() {
        return -1;
    }
    let result = ffi_result(|| {
        // SAFETY: null was checked above and the handle is only freed by the
        // paired destroy function after the caller stops using it.
        let state = unsafe { &mut *(handle as *mut CTree) };
        let mut root_style = state.tree.style(state.root)?.clone();
        root_style.size = Size {
            width: length(width.max(0.0)),
            height: length(height.max(0.0)),
        };
        state.tree.set_style(state.root, root_style)?;
        let mut counters = MeasureCounters::default();
        state.tree.compute_layout_with_measure(
            state.root,
            Size {
                width: AvailableSpace::Definite(width.max(0.0)),
                height: AvailableSpace::Definite(height.max(0.0)),
            },
            |inputs, node_id, context, style| {
                node_measure(inputs, node_id, context, style, &mut counters)
            },
        )?;
        Ok(())
    });
    if result.is_ok() {
        0
    } else {
        -1
    }
}

/// Copy one result into a caller-provided rectangle.  Return zero on success.
///
/// # Safety
///
/// `handle` must be a live pointer returned by `layout_taffy_create`, `out`
/// must point to writable space for one `CRect`, and the handle must not be
/// used concurrently with this operation.
#[no_mangle]
pub unsafe extern "C" fn layout_taffy_get_rect(
    handle: *mut std::ffi::c_void,
    node_index: u32,
    out: *mut CRect,
) -> i32 {
    if handle.is_null() || out.is_null() {
        return -1;
    }
    let result = ffi_result(|| {
        // SAFETY: null was checked above; ownership remains with the caller.
        let state = unsafe { &mut *(handle as *mut CTree) };
        let node = *state
            .nodes
            .get(node_index as usize)
            .ok_or_else(|| SpikeError::InvalidArgument("node index out of bounds".into()))?;
        let layout = state.tree.layout(node)?;
        // SAFETY: null was checked above and the caller supplied space for one
        // CRect; the write is a plain copied value.
        unsafe {
            *out = CRect {
                x: layout.location.x,
                y: layout.location.y,
                width: layout.size.width,
                height: layout.size.height,
            };
        }
        Ok(())
    });
    if result.is_ok() {
        0
    } else {
        -1
    }
}

/// Release a handle returned by [`layout_taffy_create`].
///
/// # Safety
///
/// `handle` must be null or a live pointer returned by
/// `layout_taffy_create`, and it must not be used again after this call.
#[no_mangle]
pub unsafe extern "C" fn layout_taffy_destroy(handle: *mut std::ffi::c_void) {
    if !handle.is_null() {
        // SAFETY: the pointer came from Box::into_raw in layout_taffy_create,
        // and the C contract requires destroy to be called at most once.
        unsafe { drop(Box::from_raw(handle as *mut CTree)) };
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn acceptance_fixtures_hold() {
        run_correctness().expect("Taffy acceptance fixtures should pass");
    }

    #[test]
    fn unchanged_layout_uses_taffy_cache() {
        let sample = benchmark_one("wide", 100).expect("benchmark should run");
        assert!(sample.cold.counters.callback_calls > 0);
        assert_eq!(sample.unchanged.counters.callback_calls, 0);
    }

    #[test]
    fn deep_builder_hits_exact_node_count() {
        let sample = benchmark_one("deep", 100).expect("deep benchmark should run");
        assert_eq!(sample.cold.layout_reads, 100);
    }
}
