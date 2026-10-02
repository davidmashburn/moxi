//! Optional, single-threaded retained layout adapter. Native payloads are shared
//! only because a published snapshot must outlive cache eviction and its tree.
//! The C boundary owns handles; callers must not forge or reuse released handles.
use std::collections::{HashMap, HashSet, VecDeque};
use std::ffi::{c_char, CStr, CString};
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::rc::Rc;
use std::thread::{self, ThreadId};
use taffy::geometry::Point;
use taffy::prelude::*;
use taffy::style::{Direction, Overflow};

pub type Measure =
    unsafe extern "C" fn(*const c_char, f32, f32, i32, i32, *mut Metrics, *mut usize) -> i32;
pub type Release = unsafe extern "C" fn(usize);

#[repr(C)]
#[derive(Clone, Copy, Debug, Default)]
pub struct Metrics {
    pub width: f32,
    pub height: f32,
    pub first_baseline: f32,
    pub last_baseline: f32,
}

struct Payload {
    handle: usize,
    release: Release,
}
impl Drop for Payload {
    fn drop(&mut self) {
        unsafe { (self.release)(self.handle) }
    }
}

struct Measurement {
    metrics: Metrics,
    payload: Rc<Payload>,
}
struct Paragraph {
    text: CString,
    font: f32,
    direction: i32,
    cache: VecDeque<((u32, i32), Rc<Measurement>)>,
}
impl Paragraph {
    fn measure(
        &mut self,
        width: f32,
        query: i32,
        callback: Measure,
        release: Release,
        counters: &mut Counters,
    ) -> Result<Rc<Measurement>, String> {
        let key = (width.to_bits(), query);
        if let Some((_, cached)) = self.cache.iter().find(|(k, _)| *k == key) {
            return Ok(Rc::clone(cached));
        }
        let mut metrics = Metrics::default();
        let mut handle = 0;
        counters.measurements += 1;
        let status = unsafe {
            callback(
                self.text.as_ptr(),
                self.font,
                width,
                self.direction,
                query,
                &mut metrics,
                &mut handle,
            )
        };
        if status != 0 || handle == 0 {
            if handle != 0 {
                unsafe { release(handle) };
            }
            return Err("paragraph provider rejected measurement".into());
        }
        let payload = Rc::new(Payload { handle, release });
        if ![
            metrics.width,
            metrics.height,
            metrics.first_baseline,
            metrics.last_baseline,
        ]
        .iter()
        .all(|v| v.is_finite())
            || metrics.width < 0.0
            || metrics.height < 0.0
        {
            return Err("paragraph provider returned invalid metrics".into());
        }
        let measured = Rc::new(Measurement { metrics, payload });
        if self.cache.len() == 8 {
            self.cache.pop_front();
        }
        self.cache.push_back((key, Rc::clone(&measured)));
        Ok(measured)
    }
}

#[derive(Clone, Copy, Debug, Default)]
pub struct Counters {
    pub measurements: u64,
    pub mutations: u64,
    pub publications: u64,
}
struct Node {
    id: NodeId,
    parent: Option<u64>,
    children: Vec<u64>,
    hidden: bool,
    mount: u64,
    declared: Style,
    placement: Option<[f32; 4]>,
}
#[derive(Clone)]
pub struct Output {
    pub key: u64,
    pub mount: u64,
    pub parent: u64,
    pub rect: [f32; 4],
    pub clip: [f32; 4],
    pub hidden: bool,
    measurement: Option<Rc<Measurement>>,
}
#[derive(Clone, Default)]
pub struct Snapshot {
    pub generation: u64,
    pub outputs: Vec<Output>,
}

pub struct Candidate {
    snapshot: Snapshot,
    owner: Rc<()>,
    request: (u64, u32, u32, u64),
    base_generation: u64,
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct Placement {
    pub key: u64,
    pub x: f32,
    pub y: f32,
    pub width: f32,
    pub height: f32,
}

pub struct Engine {
    tree: TaffyTree<Paragraph>,
    nodes: HashMap<u64, Node>,
    measure: Measure,
    release: Release,
    snapshot: Snapshot,
    counters: Counters,
    next_mount: u64,
    last_request: Option<(u64, u32, u32, u64)>,
    revision: u64,
    thread: ThreadId,
    error: CString,
    owner: Rc<()>,
}

fn extent(value: f32) -> Result<f32, String> {
    if value.is_finite() && value >= 0.0 {
        Ok(value)
    } else {
        Err("extent must be finite and nonnegative".into())
    }
}
fn intersect(a: [f32; 4], b: [f32; 4]) -> [f32; 4] {
    let x = a[0].max(b[0]);
    let y = a[1].max(b[1]);
    [
        x,
        y,
        (a[0] + a[2]).min(b[0] + b[2]).max(x) - x,
        (a[1] + a[3]).min(b[1] + b[3]).max(y) - y,
    ]
}
impl Engine {
    pub fn new(measure: Measure, release: Release) -> Self {
        let mut tree = TaffyTree::new();
        tree.disable_rounding();
        Self {
            tree,
            nodes: HashMap::new(),
            measure,
            release,
            snapshot: Snapshot::default(),
            counters: Counters::default(),
            next_mount: 1,
            revision: 0,
            last_request: None,
            thread: thread::current().id(),
            error: CString::default(),
            owner: Rc::new(()),
        }
    }
    fn id(&self, key: u64) -> Result<NodeId, String> {
        self.nodes
            .get(&key)
            .map(|n| n.id)
            .ok_or_else(|| format!("unknown layout key {key}"))
    }
    fn changed(&mut self) {
        self.revision += 1;
        self.counters.mutations += 1;
    }
    pub fn set_node(
        &mut self,
        key: u64,
        mut style: Style,
        text: Option<(&str, f32, i32)>,
    ) -> Result<(), String> {
        if key == 0 {
            return Err("key zero is reserved for the presentation root".into());
        }
        let context = if let Some((text, font, direction)) = text {
            if !font.is_finite() || font <= 0.0 || !(0..=2).contains(&direction) {
                return Err("invalid paragraph font or direction".into());
            }
            Some(Paragraph {
                text: CString::new(text).map_err(|_| "embedded NUL in paragraph")?,
                font,
                direction,
                cache: VecDeque::new(),
            })
        } else {
            None
        };
        if let Some(node) = self.nodes.get(&key) {
            if style.display == Display::Grid && node.declared.display == Display::Grid {
                if style.grid_template_columns.is_empty() {
                    style.grid_template_columns = node.declared.grid_template_columns.clone();
                }
                if style.grid_template_rows.is_empty() {
                    style.grid_template_rows = node.declared.grid_template_rows.clone();
                }
                if style.grid_template_column_names.is_empty() {
                    style.grid_template_column_names =
                        node.declared.grid_template_column_names.clone();
                }
                if style.grid_template_row_names.is_empty() {
                    style.grid_template_row_names = node.declared.grid_template_row_names.clone();
                }
            }
            if context.is_some() && !node.children.is_empty() {
                return Err("paragraph cannot own children".into());
            }
            let old_context = self.tree.get_node_context(node.id);
            let same_content = match (&context, old_context) {
                (None, None) => true,
                (Some(a), Some(b)) => {
                    a.text == b.text && a.font == b.font && a.direction == b.direction
                }
                _ => false,
            };
            let id = node.id;
            if node.declared == style && same_content {
                return Ok(());
            }
            self.nodes.get_mut(&key).unwrap().declared = style.clone();
            let effective = self.effective_style(key, &style);
            self.tree
                .set_style(id, effective)
                .map_err(|e| e.to_string())?;
            if !same_content {
                self.tree
                    .set_node_context(id, context)
                    .map_err(|e| e.to_string())?;
            }
        } else {
            let effective = self.effective_style(key, &style);
            let id = if let Some(context) = context {
                self.tree.new_leaf_with_context(effective, context)
            } else {
                self.tree.new_leaf(effective)
            }
            .map_err(|e| e.to_string())?;
            self.nodes.insert(
                key,
                Node {
                    id,
                    parent: None,
                    children: Vec::new(),
                    hidden: false,
                    mount: self.next_mount,
                    declared: style,
                    placement: None,
                },
            );
            self.next_mount += 1;
        }
        self.refresh_child_styles(key)?;
        self.changed();
        Ok(())
    }
    fn effective_style(&self, key: u64, style: &Style) -> Style {
        let mut result = style.clone();
        if result.display == Display::Block {
            result.display = Display::Grid;
            result.grid_template_columns = vec![GridTemplateComponent::Single(fr(1.0))];
            result.grid_template_rows = vec![GridTemplateComponent::Single(auto())];
        }
        if self
            .nodes
            .get(&key)
            .and_then(|n| n.parent)
            .is_some_and(|p| self.nodes[&p].declared.display == Display::Block)
        {
            result.grid_column = Line {
                start: line(1),
                end: line(2),
            };
            result.grid_row = Line {
                start: line(1),
                end: line(2),
            };
        }
        if let Some(rect) = self.nodes.get(&key).and_then(|n| n.placement) {
            result.position = Position::Absolute;
            result.inset.left = length(rect[0]);
            result.inset.top = length(rect[1]);
            result.size = Size {
                width: length(rect[2]),
                height: length(rect[3]),
            };
        }
        result
    }

    pub fn place(&mut self, placements: &[Placement]) -> Result<(), String> {
        let mut keys = HashSet::new();
        for p in placements {
            self.id(p.key)?;
            if !keys.insert(p.key) || self.nodes[&p.key].parent.is_none() {
                return Err("custom placement requires unique owned children".into());
            }
            if !p.x.is_finite() || !p.y.is_finite() {
                return Err("custom placement origin must be finite".into());
            }
            extent(p.width)?;
            extent(p.height)?;
        }
        for p in placements {
            let rect = [p.x, p.y, p.width, p.height];
            let node = self.nodes.get_mut(&p.key).unwrap();
            if node.placement == Some(rect) {
                continue;
            }
            node.placement = Some(rect);
            let id = node.id;
            let style = self.effective_style(p.key, &self.nodes[&p.key].declared);
            self.tree.set_style(id, style).map_err(|e| e.to_string())?;
            self.changed();
        }
        Ok(())
    }

    pub fn clear_placement(&mut self, key: u64) -> Result<(), String> {
        let id = self.id(key)?;
        if self.nodes.get_mut(&key).unwrap().placement.take().is_some() {
            self.tree
                .set_style(id, self.effective_style(key, &self.nodes[&key].declared))
                .map_err(|e| e.to_string())?;
            self.changed();
        }
        Ok(())
    }
    fn refresh_child_styles(&mut self, key: u64) -> Result<(), String> {
        for child in self.nodes[&key].children.clone() {
            let node = &self.nodes[&child];
            let id = node.id;
            let style = self.effective_style(child, &node.declared);
            self.tree.set_style(id, style).map_err(|e| e.to_string())?;
        }
        Ok(())
    }
    pub fn set_children(&mut self, key: u64, children: &[u64]) -> Result<(), String> {
        let id = self.id(key)?;
        if self.tree.get_node_context(id).is_some() {
            return Err("paragraph cannot own children".into());
        }
        let mut unique = HashSet::new();
        let mut ids = Vec::with_capacity(children.len());
        for &child in children {
            if !unique.insert(child) {
                return Err(format!("duplicate child key {child}"));
            }
            ids.push(self.id(child)?);
            if self.nodes[&child].parent.is_some_and(|p| p != key) {
                return Err(format!("child {child} already has an owner"));
            }
            let mut ancestor = Some(key);
            while let Some(a) = ancestor {
                if a == child {
                    return Err(format!("layout ownership cycle at key {child}"));
                }
                ancestor = self.nodes[&a].parent;
            }
        }
        if self.nodes[&key].children == children {
            return Ok(());
        }
        self.tree
            .set_children(id, &ids)
            .map_err(|e| e.to_string())?;
        let old = std::mem::take(&mut self.nodes.get_mut(&key).unwrap().children);
        for child in old {
            self.nodes.get_mut(&child).unwrap().parent = None;
            let node = &self.nodes[&child];
            self.tree
                .set_style(node.id, self.effective_style(child, &node.declared))
                .map_err(|e| e.to_string())?;
        }
        for &child in children {
            self.nodes.get_mut(&child).unwrap().parent = Some(key);
        }
        self.nodes.get_mut(&key).unwrap().children = children.to_vec();
        self.refresh_child_styles(key)?;
        self.changed();
        Ok(())
    }
    pub fn set_hidden(&mut self, key: u64, hidden: bool) -> Result<(), String> {
        self.id(key)?;
        let node = self.nodes.get_mut(&key).unwrap();
        if node.hidden != hidden {
            node.hidden = hidden;
            self.changed();
        }
        Ok(())
    }
    pub fn remove(&mut self, key: u64) -> Result<(), String> {
        self.id(key)?;
        let mut pending = vec![key];
        let mut retired = Vec::new();
        while let Some(key) = pending.pop() {
            pending.extend_from_slice(&self.nodes[&key].children);
            retired.push(key);
        }
        let retired_set: HashSet<_> = retired.iter().copied().collect();
        for key in retired.into_iter().rev() {
            let node = self.nodes.remove(&key).unwrap();
            if let Some(parent) = node.parent {
                if let Some(parent) = self.nodes.get_mut(&parent) {
                    parent.children.retain(|&c| c != key);
                }
            }
            // Taffy 0.14 remove() leaves its context SecondaryMap entry alive.
            // Retire our provider cache explicitly before retiring the node slot.
            self.tree
                .set_node_context(node.id, None)
                .map_err(|e| e.to_string())?;
            self.tree.remove(node.id).map_err(|e| e.to_string())?;
        }
        // Recovery publication tombstones retired identities even on failure.
        self.snapshot
            .outputs
            .retain(|o| !retired_set.contains(&o.key));
        self.snapshot.generation += 1;
        self.changed();
        Ok(())
    }
    pub fn invalidate_environment(&mut self) -> Result<(), String> {
        for node in self.nodes.values() {
            if let Some(context) = self.tree.get_node_context_mut(node.id) {
                context.cache.clear();
            }
            self.tree.mark_dirty(node.id).map_err(|e| e.to_string())?;
        }
        self.changed();
        Ok(())
    }
    pub fn layout(&mut self, root: u64, width: f32, height: f32) -> Result<Snapshot, String> {
        let candidate = self.stage(root, width, height)?;
        self.commit(&candidate)
    }
    pub fn stage(&mut self, root: u64, width: f32, height: f32) -> Result<Candidate, String> {
        extent(width)?;
        extent(height)?;
        let root_id = self.id(root)?;
        if self.nodes[&root].parent.is_some() {
            return Err("layout root is owned by another region".into());
        }
        let mut reached = HashSet::new();
        self.walk_keys(root, &mut reached)?;
        if reached.len() != self.nodes.len() {
            return Err("unowned nodes in layout transaction".into());
        }
        let request = (root, width.to_bits(), height.to_bits(), self.revision);
        if self.last_request == Some(request) {
            return Ok(Candidate {
                snapshot: self.snapshot.clone(),
                owner: Rc::clone(&self.owner),
                request,
                base_generation: self.snapshot.generation,
            });
        }
        let mut style = self.effective_style(root, &self.nodes[&root].declared);
        for (allocated, minimum, maximum) in [
            (width, style.min_size.width, style.max_size.width),
            (height, style.min_size.height, style.max_size.height),
        ] {
            let minimum = minimum
                .resolve_to_option(allocated, |_, _| 0.0)
                .unwrap_or(0.0);
            let maximum = maximum
                .resolve_to_option(allocated, |_, _| 0.0)
                .unwrap_or(f32::MAX);
            if allocated < minimum || allocated > maximum {
                return Err("exact parent allocation conflicts with root bounds".into());
            }
        }
        style.size = Size {
            width: length(width),
            height: length(height),
        };
        if self.tree.style(root_id).map_err(|e| e.to_string())? != &style {
            self.tree
                .set_style(root_id, style)
                .map_err(|e| e.to_string())?;
        }
        let callback = self.measure;
        let release = self.release;
        let counters = &mut self.counters;
        let mut failure = None;
        self.tree
            .compute_layout_with_measure(
                root_id,
                Size {
                    width: AvailableSpace::Definite(width),
                    height: AvailableSpace::Definite(height),
                },
                |inputs, _, context, style| {
                    let Some(context) = context else {
                        return taffy::compute_leaf_layout(
                            inputs,
                            style,
                            |_, _| 0.0,
                            |_, _| Size::ZERO,
                        );
                    };
                    let mut baseline = None;
                    let mut last = None;
                    let mut result = taffy::compute_leaf_layout(
                        inputs,
                        style,
                        |_, _| 0.0,
                        |known, available| {
                            let (width, query) = match known.width {
                                Some(width) => (width.max(0.0), 0),
                                None => match available.width {
                                    AvailableSpace::Definite(width) => (width.max(0.0), 0),
                                    AvailableSpace::MinContent => (0.0, 1),
                                    AvailableSpace::MaxContent => (0.0, 2),
                                },
                            };
                            match context.measure(width, query, callback, release, counters) {
                                Ok(measured) => {
                                    baseline = Some(measured.metrics.first_baseline);
                                    last = Some(measured.metrics.last_baseline);
                                    Size {
                                        width: measured.metrics.width,
                                        height: measured.metrics.height,
                                    }
                                }
                                Err(error) => {
                                    failure = Some(error);
                                    Size::ZERO
                                }
                            }
                        },
                    );
                    // Leaf helpers don't propagate provider baselines. Text padding
                    // is intentionally prohibited at the bridge boundary; wrap it in
                    // a region so baseline and payload coordinates stay identical.
                    if inputs.run_mode == taffy::tree::RunMode::PerformLayout || baseline.is_none()
                    {
                        match context.measure(result.size.width, 0, callback, release, counters) {
                            Ok(measured) => {
                                baseline = Some(measured.metrics.first_baseline);
                                last = Some(measured.metrics.last_baseline);
                            }
                            Err(error) => failure = Some(error),
                        }
                    }
                    result.baselines.first = baseline;
                    result.baselines.last = last;
                    result
                },
            )
            .map_err(|e| e.to_string())?;
        if let Some(error) = failure {
            for node in self.nodes.values() {
                self.tree.mark_dirty(node.id).map_err(|e| e.to_string())?;
            }
            return Err(error);
        }
        let mut outputs = Vec::with_capacity(self.nodes.len());
        self.collect(
            root,
            [0.0, 0.0],
            [0.0, 0.0, width, height],
            false,
            &mut outputs,
        )?;
        if outputs
            .iter()
            .any(|o| !o.rect.iter().chain(&o.clip).all(|v| v.is_finite()))
        {
            return Err("nonfinite computed geometry".into());
        }
        for output in &outputs {
            if let Some(rect) = self.nodes[&output.key].placement {
                if (output.rect[2] - rect[2]).abs() > 0.001
                    || (output.rect[3] - rect[3]).abs() > 0.001
                {
                    return Err(format!(
                        "exact custom allocation conflicts with bounds at key {}",
                        output.key
                    ));
                }
            }
        }
        let snapshot = Snapshot {
            generation: self.snapshot.generation + 1,
            outputs,
        };
        Ok(Candidate {
            snapshot,
            owner: Rc::clone(&self.owner),
            request,
            base_generation: self.snapshot.generation,
        })
    }
    pub fn commit(&mut self, candidate: &Candidate) -> Result<Snapshot, String> {
        if !Rc::ptr_eq(&candidate.owner, &self.owner)
            || candidate.request.3 != self.revision
            || candidate.base_generation != self.snapshot.generation
        {
            return Err("stale or foreign layout candidate".into());
        }
        if self.last_request == Some(candidate.request) {
            return Ok(self.snapshot.clone());
        }
        self.snapshot = candidate.snapshot.clone();
        self.counters.publications += 1;
        self.last_request = Some(candidate.request);
        Ok(self.snapshot.clone())
    }
    fn walk_keys(&self, key: u64, out: &mut HashSet<u64>) -> Result<(), String> {
        let mut pending = vec![(key, 0)];
        while let Some((key, depth)) = pending.pop() {
            if depth > 256 {
                return Err(format!("layout depth limit exceeded at key {key}"));
            }
            out.insert(key);
            pending.extend(self.nodes[&key].children.iter().map(|&c| (c, depth + 1)));
        }
        Ok(())
    }
    fn collect(
        &mut self,
        key: u64,
        origin: [f32; 2],
        clip: [f32; 4],
        hidden: bool,
        out: &mut Vec<Output>,
    ) -> Result<(), String> {
        let node = &self.nodes[&key];
        let id = node.id;
        let layout = *self.tree.layout(id).map_err(|e| e.to_string())?;
        let style = self.tree.style(id).map_err(|e| e.to_string())?;
        let hidden = hidden || node.hidden || style.display == Display::None;
        let rect = [
            origin[0] + layout.location.x,
            origin[1] + layout.location.y,
            layout.size.width,
            layout.size.height,
        ];
        let mut child_clip = clip;
        if style.overflow.x != Overflow::Visible {
            child_clip[0] = rect[0].max(clip[0]);
            child_clip[2] = (rect[0] + rect[2])
                .min(clip[0] + clip[2])
                .max(child_clip[0])
                - child_clip[0];
        }
        if style.overflow.y != Overflow::Visible {
            child_clip[1] = rect[1].max(clip[1]);
            child_clip[3] = (rect[1] + rect[3])
                .min(clip[1] + clip[3])
                .max(child_clip[1])
                - child_clip[1];
        }
        let mount = node.mount;
        let parent = node.parent.unwrap_or(0);
        let children = node.children.clone();
        let measurement = if hidden {
            None
        } else if let Some(context) = self.tree.get_node_context_mut(id) {
            Some(context.measure(rect[2], 0, self.measure, self.release, &mut self.counters)?)
        } else {
            None
        };
        out.push(Output {
            key,
            mount,
            parent,
            rect,
            clip: intersect(rect, clip),
            hidden,
            measurement,
        });
        for child in children {
            self.collect(child, [rect[0], rect[1]], child_clip, hidden, out)?;
        }
        Ok(())
    }
    pub fn counters(&self) -> Counters {
        self.counters
    }
}

// Compact C style contract. All scalar and enum validation occurs before mutation.
// kind: 0=column,1=row,2=wrap,3=grid,4=stack,5=leaf,6=collapsed.
// dimension: 0=content,1=fixed,2=fill,3=fraction,4=min-content,5=max-content,6=fit-content.
#[repr(C)]
#[derive(Clone, Copy)]
pub struct Spec {
    pub kind: i32,
    pub width_kind: i32,
    pub height_kind: i32,
    pub width: f32,
    pub height: f32,
    pub min_width: f32,
    pub min_height: f32,
    pub max_width: f32,
    pub max_height: f32,
    pub gap: f32,
    pub padding: f32,
    pub grow: f32,
    pub shrink: f32,
    pub align: i32,
    pub rtl: i32,
    pub overflow: i32,
    pub column: i32,
    pub column_span: i32,
    pub row: i32,
    pub row_span: i32,
}
impl Default for Spec {
    fn default() -> Self {
        Self {
            kind: 0,
            width_kind: 0,
            height_kind: 0,
            width: 0.0,
            height: 0.0,
            min_width: 0.0,
            min_height: 0.0,
            max_width: f32::MAX,
            max_height: f32::MAX,
            gap: 0.0,
            padding: 0.0,
            grow: 0.0,
            shrink: 0.0,
            align: 0,
            rtl: 0,
            overflow: 0,
            column: 0,
            column_span: 1,
            row: 0,
            row_span: 1,
        }
    }
}
fn dimension(kind: i32, value: f32) -> Result<Dimension, String> {
    extent(value)?;
    Ok(match kind {
        0 => auto(),
        1 => length(value),
        2 => percent(1.0),
        3 => percent(value),
        4 => Dimension::min_content(),
        5 => Dimension::max_content(),
        6 => Dimension::fit_content_px(value),
        _ => return Err("unknown sizing policy".into()),
    })
}
impl Spec {
    pub fn style(self, paragraph: bool) -> Result<Style, String> {
        if !(0..=6).contains(&self.kind)
            || !(0..=4).contains(&self.align)
            || !(0..=1).contains(&self.rtl)
            || !(0..=2).contains(&self.overflow)
            || self.column < 0
            || self.row < 0
            || self.column > i16::MAX as i32
            || self.row > i16::MAX as i32
            || !(1..=u16::MAX as i32).contains(&self.column_span)
            || !(1..=u16::MAX as i32).contains(&self.row_span)
        {
            return Err("invalid layout style enum or grid placement".into());
        }
        for v in [
            self.min_width,
            self.min_height,
            self.max_width,
            self.max_height,
            self.gap,
            self.padding,
            self.grow,
            self.shrink,
        ] {
            extent(v)?;
        }
        if self.min_width > self.max_width || self.min_height > self.max_height {
            return Err("contradictory size bounds".into());
        }
        if paragraph && (self.padding != 0.0 || self.kind != 5) {
            return Err("paragraph requires an unpadded leaf style".into());
        }
        let align = match self.align {
            0 => AlignItems::STRETCH,
            1 => AlignItems::START,
            2 => AlignItems::END,
            3 => AlignItems::CENTER,
            4 => AlignItems::BASELINE,
            _ => AlignItems::BASELINE,
        };
        Ok(Style {
            display: match self.kind {
                3 => Display::Grid,
                4 => Display::Block,
                6 => Display::None,
                _ => Display::Flex,
            },
            size: Size {
                width: dimension(self.width_kind, self.width)?,
                height: dimension(self.height_kind, self.height)?,
            },
            min_size: Size {
                width: length(self.min_width),
                height: length(self.min_height),
            },
            max_size: Size {
                width: length(self.max_width),
                height: length(self.max_height),
            },
            padding: Rect {
                left: length(self.padding),
                right: length(self.padding),
                top: length(self.padding),
                bottom: length(self.padding),
            },
            gap: Size {
                width: length(self.gap),
                height: length(self.gap),
            },
            flex_direction: if self.kind == 0 {
                FlexDirection::Column
            } else {
                FlexDirection::Row
            },
            flex_wrap: if self.kind == 2 {
                FlexWrap::Wrap
            } else {
                FlexWrap::NoWrap
            },
            flex_grow: self.grow,
            flex_shrink: self.shrink,
            align_items: Some(align),
            direction: if self.rtl == 0 {
                Direction::Ltr
            } else {
                Direction::Rtl
            },
            overflow: Point {
                x: if self.overflow == 0 {
                    Overflow::Visible
                } else {
                    Overflow::Hidden
                },
                y: if self.overflow == 0 {
                    Overflow::Visible
                } else {
                    Overflow::Hidden
                },
            },
            grid_column: Line {
                start: if self.column == 0 {
                    GridPlacement::Auto
                } else {
                    line(self.column as i16)
                },
                end: span(self.column_span as u16),
            },
            grid_row: Line {
                start: if self.row == 0 {
                    GridPlacement::Auto
                } else {
                    line(self.row as i16)
                },
                end: span(self.row_span as u16),
            },
            ..Style::default()
        })
    }
}

/// Track limits: 0=auto,1=points,2=min-content,3=max-content,4=fr(max only).
#[repr(C)]
#[derive(Clone, Copy)]
pub struct Track {
    pub min_kind: i32,
    pub max_kind: i32,
    pub min: f32,
    pub max: f32,
}
impl Track {
    fn sizing(self) -> Result<TrackSizingFunction, String> {
        extent(self.min)?;
        extent(self.max)?;
        let min = match self.min_kind {
            0 => auto(),
            1 => length(self.min),
            2 => min_content(),
            3 => max_content(),
            _ => return Err("invalid grid track minimum".into()),
        };
        let max = match self.max_kind {
            0 => auto(),
            1 => length(self.max),
            2 => min_content(),
            3 => max_content(),
            4 => fr(self.max),
            _ => return Err("invalid grid track maximum".into()),
        };
        if self.min_kind == 1 && self.max_kind == 1 && self.min > self.max {
            return Err("contradictory grid track bounds".into());
        }
        Ok(minmax(min, max))
    }
}

// C ABI errors never unwind into Mojo. A null/invalid pointer is a caller error;
// nulls are checked, while arbitrary forged pointers cannot be validated by C.
fn call(handle: *mut Engine, operation: impl FnOnce(&mut Engine) -> Result<(), String>) -> i32 {
    if handle.is_null() {
        return 1;
    }
    let engine = unsafe { &mut *handle };
    if engine.thread != thread::current().id() {
        return 1;
    }
    let result = catch_unwind(AssertUnwindSafe(|| operation(engine)));
    match result {
        Ok(Ok(())) => {
            engine.error = CString::default();
            0
        }
        Ok(Err(error)) => {
            engine.error = CString::new(error.replace('\0', "?")).unwrap();
            1
        }
        Err(_) => {
            engine.error = CString::new("internal layout panic; discard context").unwrap();
            2
        }
    }
}
#[no_mangle]
pub extern "C" fn moxi_layout_create(
    measure: Option<Measure>,
    release: Option<Release>,
) -> *mut Engine {
    match (measure, release) {
        (Some(m), Some(r)) => Box::into_raw(Box::new(Engine::new(m, r))),
        _ => std::ptr::null_mut(),
    }
}
/// # Safety
/// Handles must be null or live handles of the declared type, used on their
/// creating thread without concurrent access. Input pointers must cover their
/// declared lengths; output pointers must be writable. Release consumes a handle.
#[no_mangle]
pub unsafe extern "C" fn moxi_layout_destroy(handle: *mut Engine) {
    if !handle.is_null() {
        drop(Box::from_raw(handle));
    }
}
/// # Safety
/// Handles must be null or live handles of the declared type, used on their
/// creating thread without concurrent access. Input pointers must cover their
/// declared lengths; output pointers must be writable. Release consumes a handle.
#[no_mangle]
pub unsafe extern "C" fn moxi_layout_error(handle: *const Engine) -> *const c_char {
    if handle.is_null() {
        c"null layout handle".as_ptr()
    } else {
        (*handle).error.as_ptr()
    }
}
/// # Safety
/// Handles must be null or live handles of the declared type, used on their
/// creating thread without concurrent access. Input pointers must cover their
/// declared lengths; output pointers must be writable. Release consumes a handle.
#[no_mangle]
pub unsafe extern "C" fn moxi_layout_set_node(
    handle: *mut Engine,
    key: u64,
    spec: *const Spec,
    text: *const c_char,
    font: f32,
    direction: i32,
) -> i32 {
    call(handle, |engine| {
        let spec = spec.as_ref().ok_or("null layout style")?;
        let paragraph = !text.is_null();
        let text = if paragraph {
            Some((
                CStr::from_ptr(text).to_str().map_err(|_| "invalid UTF-8")?,
                font,
                direction,
            ))
        } else {
            None
        };
        engine.set_node(key, spec.style(paragraph)?, text)
    })
}
/// # Safety
/// Handles must be null or live handles of the declared type, used on their
/// creating thread without concurrent access. Input pointers must cover their
/// declared lengths; output pointers must be writable. Release consumes a handle.
#[no_mangle]
pub unsafe extern "C" fn moxi_layout_children(
    handle: *mut Engine,
    key: u64,
    children: *const u64,
    count: usize,
) -> i32 {
    call(handle, |engine| {
        if count > 0 && children.is_null() {
            return Err("null child list".into());
        }
        engine.set_children(
            key,
            if count == 0 {
                &[]
            } else {
                std::slice::from_raw_parts(children, count)
            },
        )
    })
}
/// # Safety
/// Handles must be null or live handles of the declared type, used on their
/// creating thread without concurrent access. Input pointers must cover their
/// declared lengths; output pointers must be writable. Release consumes a handle.
#[no_mangle]
pub unsafe extern "C" fn moxi_layout_tracks(
    handle: *mut Engine,
    key: u64,
    axis: i32,
    tracks: *const Track,
    count: usize,
) -> i32 {
    call(handle, |engine| {
        if !(0..=1).contains(&axis) || count > 1024 || (count > 0 && tracks.is_null()) {
            return Err("invalid grid track list".into());
        }
        let id = engine.id(key)?;
        let tracks = if count == 0 {
            &[]
        } else {
            std::slice::from_raw_parts(tracks, count)
        };
        let tracks: Vec<GridTemplateComponent<String>> = tracks
            .iter()
            .map(|t| t.sizing().map(GridTemplateComponent::Single))
            .collect::<Result<_, _>>()?;
        let mut style = engine.tree.style(id).map_err(|e| e.to_string())?.clone();
        if style.display != Display::Grid {
            return Err("tracks require a grid owner".into());
        }
        if axis == 0 {
            style.grid_template_columns = tracks;
        } else {
            style.grid_template_rows = tracks;
        }
        engine.nodes.get_mut(&key).unwrap().declared = style.clone();
        if engine.tree.style(id).map_err(|e| e.to_string())? != &style {
            engine
                .tree
                .set_style(id, style)
                .map_err(|e| e.to_string())?;
            engine.changed();
        }
        Ok(())
    })
}
/// # Safety
/// Handles must be null or live handles of the declared type, used on their
/// creating thread without concurrent access. Input pointers must cover their
/// declared lengths; output pointers must be writable. Release consumes a handle.
#[no_mangle]
pub unsafe extern "C" fn moxi_layout_hidden(handle: *mut Engine, key: u64, hidden: i32) -> i32 {
    call(handle, |e| e.set_hidden(key, hidden != 0))
}
/// # Safety
/// Handles must be null or live handles of the declared type, used on their
/// creating thread without concurrent access. Input pointers must cover their
/// declared lengths; output pointers must be writable. Release consumes a handle.
#[no_mangle]
pub unsafe extern "C" fn moxi_layout_remove(handle: *mut Engine, key: u64) -> i32 {
    call(handle, |e| e.remove(key))
}
/// # Safety
/// Handles must be null or live handles of the declared type, used on their
/// creating thread without concurrent access. Input pointers must cover their
/// declared lengths; output pointers must be writable. Release consumes a handle.
#[no_mangle]
pub unsafe extern "C" fn moxi_layout_invalidate(handle: *mut Engine) -> i32 {
    call(handle, Engine::invalidate_environment)
}
/// # Safety
/// Handles must be null or live handles of the declared type, used on their
/// creating thread without concurrent access. Input pointers must cover their
/// declared lengths; output pointers must be writable. Release consumes a handle.
#[no_mangle]
pub unsafe extern "C" fn moxi_layout_compute(
    handle: *mut Engine,
    root: u64,
    width: f32,
    height: f32,
    out: *mut *mut Snapshot,
) -> i32 {
    call(handle, |e| {
        if out.is_null() {
            return Err("null snapshot output".into());
        }
        *out = Box::into_raw(Box::new(e.layout(root, width, height)?));
        Ok(())
    })
}
/// # Safety
/// The owner and candidate must be live handles on their creating thread.
/// The output must be writable. Candidates must be released exactly once.
#[no_mangle]
pub unsafe extern "C" fn moxi_layout_stage(
    handle: *mut Engine,
    root: u64,
    width: f32,
    height: f32,
    out: *mut *mut Candidate,
) -> i32 {
    call(handle, |e| {
        if out.is_null() {
            return Err("null candidate output".into());
        }
        *out = Box::into_raw(Box::new(e.stage(root, width, height)?));
        Ok(())
    })
}
/// # Safety
/// The owner and candidate must be live handles on their creating thread.
/// The output must be writable. This operation borrows the candidate.
#[no_mangle]
pub unsafe extern "C" fn moxi_layout_commit(
    handle: *mut Engine,
    candidate: *const Candidate,
    out: *mut *mut Snapshot,
) -> i32 {
    call(handle, |e| {
        if out.is_null() {
            return Err("null snapshot output".into());
        }
        let candidate = candidate.as_ref().ok_or("null layout candidate")?;
        *out = Box::into_raw(Box::new(e.commit(candidate)?));
        Ok(())
    })
}
/// # Safety
/// Candidate must be a live handle on its creating thread. Result is owned.
#[no_mangle]
pub unsafe extern "C" fn moxi_layout_candidate_snapshot(
    candidate: *const Candidate,
) -> *mut Snapshot {
    candidate.as_ref().map_or(std::ptr::null_mut(), |c| {
        Box::into_raw(Box::new(c.snapshot.clone()))
    })
}
/// # Safety
/// Candidate must be null or a live handle on its creating thread. Consumes it.
#[no_mangle]
pub unsafe extern "C" fn moxi_layout_candidate_release(candidate: *mut Candidate) {
    if !candidate.is_null() {
        drop(Box::from_raw(candidate));
    }
}
/// # Safety
/// The owner must be live on its creating thread and the placements must cover
/// the declared count. Input is borrowed and validated before mutation.
#[no_mangle]
pub unsafe extern "C" fn moxi_layout_place(
    handle: *mut Engine,
    placements: *const Placement,
    count: usize,
) -> i32 {
    call(handle, |e| {
        if count > 0 && placements.is_null() {
            return Err("null placement list".into());
        }
        let placements = if count == 0 {
            &[]
        } else {
            std::slice::from_raw_parts(placements, count)
        };
        e.place(placements)
    })
}
/// # Safety
/// The owner must be live on its creating thread.
#[no_mangle]
pub unsafe extern "C" fn moxi_layout_clear_placement(handle: *mut Engine, key: u64) -> i32 {
    call(handle, |e| e.clear_placement(key))
}
/// # Safety
/// Handles must be null or live handles of the declared type, used on their
/// creating thread without concurrent access. Input pointers must cover their
/// declared lengths; output pointers must be writable. Release consumes a handle.
#[no_mangle]
pub unsafe extern "C" fn moxi_layout_snapshot(handle: *const Engine) -> *mut Snapshot {
    if handle.is_null() {
        std::ptr::null_mut()
    } else {
        Box::into_raw(Box::new((*handle).snapshot.clone()))
    }
}
/// # Safety
/// Handles must be null or live handles of the declared type, used on their
/// creating thread without concurrent access. Input pointers must cover their
/// declared lengths; output pointers must be writable. Release consumes a handle.
#[no_mangle]
pub unsafe extern "C" fn moxi_layout_snapshot_release(handle: *mut Snapshot) {
    if !handle.is_null() {
        drop(Box::from_raw(handle));
    }
}
/// # Safety
/// Handles must be null or live handles of the declared type, used on their
/// creating thread without concurrent access. Input pointers must cover their
/// declared lengths; output pointers must be writable. Release consumes a handle.
#[no_mangle]
pub unsafe extern "C" fn moxi_layout_snapshot_count(handle: *const Snapshot) -> usize {
    handle.as_ref().map_or(0, |s| s.outputs.len())
}
/// # Safety
/// Handles must be null or live handles of the declared type, used on their
/// creating thread without concurrent access. Input pointers must cover their
/// declared lengths; output pointers must be writable. Release consumes a handle.
#[no_mangle]
pub unsafe extern "C" fn moxi_layout_snapshot_generation(handle: *const Snapshot) -> u64 {
    handle.as_ref().map_or(0, |s| s.generation)
}
/// # Safety
/// Handles must be null or live handles of the declared type, used on their
/// creating thread without concurrent access. Input pointers must cover their
/// declared lengths; output pointers must be writable. Release consumes a handle.
#[no_mangle]
pub unsafe extern "C" fn moxi_layout_snapshot_integer(
    handle: *const Snapshot,
    index: usize,
    field: i32,
) -> u64 {
    let Some(output) = handle.as_ref().and_then(|s| s.outputs.get(index)) else {
        return 0;
    };
    match field {
        0 => output.key,
        1 => output.mount,
        2 => output.parent,
        3 => u64::from(output.hidden),
        4 => output
            .measurement
            .as_ref()
            .map_or(0, |m| m.payload.handle as u64),
        _ => 0,
    }
}
/// # Safety
/// Handles must be null or live handles of the declared type, used on their
/// creating thread without concurrent access. Input pointers must cover their
/// declared lengths; output pointers must be writable. Release consumes a handle.
#[no_mangle]
pub unsafe extern "C" fn moxi_layout_snapshot_float(
    handle: *const Snapshot,
    index: usize,
    field: usize,
) -> f32 {
    let Some(output) = handle.as_ref().and_then(|s| s.outputs.get(index)) else {
        return 0.0;
    };
    match field {
        0..=3 => output.rect[field],
        4..=7 => output.clip[field - 4],
        8 => output
            .measurement
            .as_ref()
            .map_or(-1.0, |m| m.metrics.first_baseline),
        9 => output
            .measurement
            .as_ref()
            .map_or(-1.0, |m| m.metrics.last_baseline),
        _ => 0.0,
    }
}
/// # Safety
/// Handles must be null or live handles of the declared type, used on their
/// creating thread without concurrent access. Input pointers must cover their
/// declared lengths; output pointers must be writable. Release consumes a handle.
#[no_mangle]
pub unsafe extern "C" fn moxi_layout_counter(handle: *const Engine, field: i32) -> u64 {
    let Some(engine) = handle.as_ref() else {
        return 0;
    };
    match field {
        0 => engine.counters.measurements,
        1 => engine.counters.mutations,
        2 => engine.counters.publications,
        _ => 0,
    }
}

#[cfg(test)]
mod tests;

/// # Safety
/// Handle must be live and thread-confined; spec must point to a readable Spec.
#[no_mangle]
pub unsafe extern "C" fn moxi_layout_set_region(
    handle: *mut Engine,
    key: u64,
    spec: *const Spec,
) -> i32 {
    moxi_layout_set_node(handle, key, spec, std::ptr::null(), 0.0, 0)
}
/// # Safety
/// Handle must be null or live and thread-confined.
#[no_mangle]
pub unsafe extern "C" fn moxi_layout_has_key(handle: *const Engine, key: u64) -> i32 {
    handle
        .as_ref()
        .map_or(0, |e| i32::from(e.nodes.contains_key(&key)))
}
