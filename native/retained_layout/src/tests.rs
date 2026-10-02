use super::*;
use std::sync::atomic::{AtomicUsize, Ordering};
static LIVE: AtomicUsize = AtomicUsize::new(0);
unsafe extern "C" fn measure(
    text: *const c_char,
    font: f32,
    width: f32,
    _: i32,
    query: i32,
    out: *mut Metrics,
    handle: *mut usize,
) -> i32 {
    let text = CStr::from_ptr(text).to_str().unwrap();
    if text == "FAIL" {
        return 1;
    }
    let natural = text.chars().count() as f32 * font;
    let width = match query {
        1 => font.min(natural),
        2 => natural,
        _ => width,
    };
    let lines = (natural / width.max(font)).ceil().max(1.0);
    *out = Metrics {
        width,
        height: lines * font * 2.0,
        first_baseline: font * 1.5,
        last_baseline: (lines - 1.0) * font * 2.0 + font * 1.5,
    };
    *handle = Box::into_raw(Box::new(123u32)) as usize;
    LIVE.fetch_add(1, Ordering::SeqCst);
    0
}
unsafe extern "C" fn release(handle: usize) {
    drop(Box::from_raw(handle as *mut u32));
    LIVE.fetch_sub(1, Ordering::SeqCst);
}
fn engine() -> Engine {
    Engine::new(measure, release)
}
fn node(e: &mut Engine, key: u64, spec: Spec) {
    e.set_node(key, spec.style(false).unwrap(), None).unwrap();
}
fn text(e: &mut Engine, key: u64, text: &str, font: f32) {
    let spec = Spec {
        kind: 5,
        ..Spec::default()
    };
    e.set_node(key, spec.style(true).unwrap(), Some((text, font, 0)))
        .unwrap();
}
fn rect(s: &Snapshot, key: u64) -> [f32; 4] {
    s.outputs.iter().find(|o| o.key == key).unwrap().rect
}
fn close(a: f32, b: f32) {
    assert!((a - b).abs() < 0.001, "{a} != {b}");
}

#[test]
fn nested_flow_and_unchanged_transaction() {
    let mut e = engine();
    node(
        &mut e,
        1,
        Spec {
            padding: 10.0,
            gap: 5.0,
            ..Spec::default()
        },
    );
    node(
        &mut e,
        2,
        Spec {
            kind: 1,
            gap: 7.0,
            height_kind: 1,
            height: 30.0,
            ..Spec::default()
        },
    );
    node(
        &mut e,
        3,
        Spec {
            kind: 5,
            width_kind: 1,
            width: 40.0,
            ..Spec::default()
        },
    );
    node(
        &mut e,
        4,
        Spec {
            kind: 5,
            grow: 1.0,
            ..Spec::default()
        },
    );
    node(
        &mut e,
        5,
        Spec {
            kind: 5,
            grow: 1.0,
            min_height: 20.0,
            ..Spec::default()
        },
    );
    e.set_children(1, &[2, 5]).unwrap();
    e.set_children(2, &[3, 4]).unwrap();
    let s = e.layout(1, 200.0, 100.0).unwrap();
    assert_eq!(rect(&s, 3), [10.0, 10.0, 40.0, 30.0]);
    assert_eq!(rect(&s, 4), [57.0, 10.0, 133.0, 30.0]);
    assert_eq!(rect(&s, 5), [10.0, 45.0, 180.0, 45.0]);
    let before = e.counters();
    let s2 = e.layout(1, 200.0, 100.0).unwrap();
    assert_eq!(s.generation, s2.generation);
    assert_eq!(e.counters().mutations, before.mutations);
    assert_eq!(e.counters().measurements, before.measurements);
    assert_eq!(e.counters().publications, before.publications);
}
#[test]
fn wrap_threshold_and_fractional_geometry() {
    let mut e = engine();
    node(
        &mut e,
        1,
        Spec {
            kind: 2,
            gap: 5.0,
            align: 1,
            ..Spec::default()
        },
    );
    for key in [2, 3, 4] {
        node(
            &mut e,
            key,
            Spec {
                kind: 5,
                width_kind: 1,
                width: 50.25,
                height_kind: 1,
                height: 20.0,
                ..Spec::default()
            },
        );
    }
    e.set_children(1, &[2, 3, 4]).unwrap();
    let a = e.layout(1, 160.75, 100.0).unwrap();
    close(rect(&a, 4)[1], 0.0);
    let b = e.layout(1, 160.74, 100.0).unwrap();
    assert!(rect(&b, 4)[1] > 20.0);
}
#[test]
fn baseline_uses_provider_and_final_width_payload() {
    let mut e = engine();
    node(
        &mut e,
        1,
        Spec {
            kind: 1,
            align: 4,
            ..Spec::default()
        },
    );
    text(&mut e, 2, "small", 10.0);
    text(&mut e, 3, "BIG", 20.0);
    e.set_children(1, &[2, 3]).unwrap();
    let s = e.layout(1, 200.0, 100.0).unwrap();
    let a = s.outputs.iter().find(|o| o.key == 2).unwrap();
    let b = s.outputs.iter().find(|o| o.key == 3).unwrap();
    close(
        a.rect[1] + a.measurement.as_ref().unwrap().metrics.first_baseline,
        b.rect[1] + b.measurement.as_ref().unwrap().metrics.first_baseline,
    );
    close(a.rect[2], a.measurement.as_ref().unwrap().metrics.width);
}
#[test]
fn ownership_rejection_is_atomic() {
    let mut e = engine();
    for key in 1..=4 {
        node(&mut e, key, Spec::default());
    }
    e.set_children(1, &[2, 3]).unwrap();
    e.set_children(2, &[4]).unwrap();
    assert!(e.set_children(3, &[4]).unwrap_err().contains("owner"));
    assert!(e.set_children(4, &[1]).unwrap_err().contains("cycle"));
    assert!(e
        .set_children(1, &[2, 2])
        .unwrap_err()
        .contains("duplicate"));
    assert_eq!(e.nodes[&1].children, vec![2, 3]);
    assert_eq!(e.nodes[&4].parent, Some(2));
    e.layout(1, 100.0, 100.0).unwrap();
}
#[test]
fn removal_then_failure_tombstones_and_remounts() {
    let mut e = engine();
    node(&mut e, 1, Spec::default());
    text(&mut e, 2, "ok", 10.0);
    text(&mut e, 3, "ok", 10.0);
    e.set_children(1, &[2, 3]).unwrap();
    let old = e.layout(1, 100.0, 100.0).unwrap();
    let old_mount = e.nodes[&2].mount;
    e.remove(2).unwrap();
    text(&mut e, 3, "FAIL", 10.0);
    assert!(e.layout(1, 100.0, 100.0).is_err());
    assert!(!e.snapshot.outputs.iter().any(|o| o.key == 2));
    assert!(old.outputs.iter().any(|o| o.key == 2)); // explicit historical snapshot
    text(&mut e, 2, "new", 10.0);
    assert!(e.nodes[&2].mount > old_mount);
}
#[test]
fn native_payload_outlives_context_and_bounded_cache() {
    let detached;
    {
        let mut e = engine();
        node(&mut e, 1, Spec::default());
        text(&mut e, 2, "a long title", 10.0);
        e.set_children(1, &[2]).unwrap();
        detached = e.layout(1, 100.0, 100.0).unwrap();
        for w in 1..100 {
            e.layout(1, w as f32, 100.0).unwrap();
        }
        assert!(
            e.tree
                .get_node_context(e.id(2).unwrap())
                .unwrap()
                .cache
                .len()
                <= 8
        );
        let before = e.counters().measurements;
        e.invalidate_environment().unwrap();
        e.layout(1, 99.0, 100.0).unwrap();
        assert!(e.counters().measurements > before);
    }
    let payload = detached
        .outputs
        .iter()
        .find(|o| o.key == 2)
        .unwrap()
        .measurement
        .as_ref()
        .unwrap()
        .payload
        .handle;
    assert_eq!(unsafe { *(payload as *const u32) }, 123);
}
#[test]
fn hidden_participates_and_nested_clip_keeps_logical_geometry() {
    let mut e = engine();
    node(
        &mut e,
        1,
        Spec {
            overflow: 1,
            ..Spec::default()
        },
    );
    node(
        &mut e,
        2,
        Spec {
            kind: 5,
            height_kind: 1,
            height: 60.0,
            ..Spec::default()
        },
    );
    node(
        &mut e,
        3,
        Spec {
            kind: 5,
            height_kind: 1,
            height: 60.0,
            ..Spec::default()
        },
    );
    e.set_children(1, &[2, 3]).unwrap();
    e.set_hidden(2, true).unwrap();
    let s = e.layout(1, 100.0, 100.0).unwrap();
    let b = s.outputs.iter().find(|o| o.key == 3).unwrap();
    assert_eq!(b.rect, [0.0, 60.0, 100.0, 60.0]);
    assert_eq!(b.clip, [0.0, 60.0, 100.0, 40.0]);
    assert!(s.outputs.iter().find(|o| o.key == 2).unwrap().hidden);
}
#[test]
fn grid_minmax_fraction_span_and_intrinsic_tracks() {
    let mut e = engine();
    let mut root = Spec {
        kind: 3,
        gap: 10.0,
        ..Spec::default()
    }
    .style(false)
    .unwrap();
    root.grid_template_columns = vec![
        GridTemplateComponent::Single(minmax(length(30.0), fr(1.0))),
        GridTemplateComponent::Single(minmax(length(20.0), fr(2.0))),
    ];
    e.set_node(1, root, None).unwrap();
    node(
        &mut e,
        2,
        Spec {
            kind: 5,
            column: 1,
            row: 1,
            height_kind: 1,
            height: 20.0,
            ..Spec::default()
        },
    );
    node(
        &mut e,
        3,
        Spec {
            kind: 5,
            column: 2,
            row: 1,
            height_kind: 1,
            height: 20.0,
            ..Spec::default()
        },
    );
    node(
        &mut e,
        4,
        Spec {
            kind: 5,
            column: 1,
            column_span: 2,
            row: 2,
            height_kind: 1,
            height: 20.0,
            ..Spec::default()
        },
    );
    e.set_children(1, &[2, 3, 4]).unwrap();
    let s = e.layout(1, 310.0, 100.0).unwrap();
    close(rect(&s, 2)[2], 100.0);
    close(rect(&s, 3)[2], 200.0);
    close(rect(&s, 4)[2], 310.0);
    let mut nested = Spec {
        kind: 3,
        ..Spec::default()
    }
    .style(false)
    .unwrap();
    nested.grid_template_columns = vec![GridTemplateComponent::Single(max_content())];
    e.set_node(4, nested, None).unwrap();
    text(&mut e, 5, "intrinsic", 10.0);
    e.set_children(4, &[5]).unwrap();
    let s = e.layout(1, 310.0, 100.0).unwrap();
    close(rect(&s, 5)[2], 90.0);
}
#[test]
fn invalid_styles_and_ffi_faults_are_reported() {
    assert!(Spec {
        min_width: 50.0,
        max_width: 10.0,
        ..Spec::default()
    }
    .style(false)
    .is_err());
    assert!(Spec {
        width: f32::NAN,
        ..Spec::default()
    }
    .style(false)
    .is_err());
    assert!(Spec {
        kind: 5,
        padding: 1.0,
        ..Spec::default()
    }
    .style(true)
    .is_err());
    assert!(Track {
        min_kind: 1,
        max_kind: 1,
        min: 50.0,
        max: 20.0
    }
    .sizing()
    .is_err());
    unsafe {
        assert_eq!(moxi_layout_remove(std::ptr::null_mut(), 1), 1);
        let e = moxi_layout_create(Some(measure), Some(release));
        assert_eq!(
            moxi_layout_set_node(e, 1, std::ptr::null(), std::ptr::null(), 0.0, 0),
            1
        );
        assert!(CStr::from_ptr(moxi_layout_error(e))
            .to_str()
            .unwrap()
            .contains("null"));
        moxi_layout_destroy(e);
    }
}

#[test]
fn stack_participation_and_rtl() {
    let mut e = engine();
    node(
        &mut e,
        1,
        Spec {
            kind: 4,
            ..Spec::default()
        },
    );
    text(&mut e, 2, "small", 10.0);
    text(&mut e, 3, "taller", 20.0);
    e.set_children(1, &[2, 3]).unwrap();
    let s = e.layout(1, 120.0, 100.0).unwrap();
    close(rect(&s, 2)[0], rect(&s, 3)[0]);
    close(rect(&s, 2)[1], rect(&s, 3)[1]);
    node(
        &mut e,
        1,
        Spec {
            kind: 1,
            rtl: 1,
            ..Spec::default()
        },
    );
    let s = e.layout(1, 200.0, 100.0).unwrap();
    assert!(rect(&s, 2)[0] > rect(&s, 3)[0]);
}
#[test]
fn clamp_redistributes_and_shrink_is_opt_in() {
    let mut e = engine();
    node(
        &mut e,
        1,
        Spec {
            kind: 1,
            ..Spec::default()
        },
    );
    node(
        &mut e,
        2,
        Spec {
            kind: 5,
            grow: 1.0,
            max_width: 30.0,
            ..Spec::default()
        },
    );
    node(
        &mut e,
        3,
        Spec {
            kind: 5,
            grow: 1.0,
            ..Spec::default()
        },
    );
    e.set_children(1, &[2, 3]).unwrap();
    let s = e.layout(1, 100.0, 20.0).unwrap();
    close(rect(&s, 2)[2], 30.0);
    close(rect(&s, 3)[2], 70.0);
    for key in [2, 3] {
        node(
            &mut e,
            key,
            Spec {
                kind: 5,
                width_kind: 1,
                width: 80.0,
                ..Spec::default()
            },
        );
    }
    let s = e.layout(1, 100.0, 20.0).unwrap();
    close(rect(&s, 2)[2], 80.0);
    close(rect(&s, 3)[2], 80.0);
    for key in [2, 3] {
        node(
            &mut e,
            key,
            Spec {
                kind: 5,
                width_kind: 1,
                width: 80.0,
                shrink: 1.0,
                ..Spec::default()
            },
        );
    }
    let s = e.layout(1, 100.0, 20.0).unwrap();
    close(rect(&s, 2)[2], 50.0);
    close(rect(&s, 3)[2], 50.0);
}
#[test]
fn exact_parent_and_orphan_errors_do_not_publish() {
    let mut e = engine();
    node(
        &mut e,
        1,
        Spec {
            min_height: 50.0,
            ..Spec::default()
        },
    );
    assert!(e
        .layout(1, 100.0, 20.0)
        .err()
        .unwrap()
        .contains("allocation"));
    assert_eq!(e.snapshot.generation, 0);
    node(&mut e, 2, Spec::default());
    assert!(e.layout(1, 100.0, 100.0).err().unwrap().contains("unowned"));
    e.set_children(1, &[2]).unwrap();
    let s = e.layout(1, 100.0, 100.0).unwrap();
    assert!(e.layout(1, f32::NAN, 100.0).is_err());
    assert_eq!(e.snapshot.generation, s.generation);
}
#[test]
fn churn_releases_payloads_and_bounds_retention() {
    let mut e = engine();
    node(&mut e, 1, Spec::default());
    text(&mut e, 2, "old", 10.0);
    e.set_children(1, &[2]).unwrap();
    let snapshot = e.layout(1, 100.0, 100.0).unwrap();
    let weak = Rc::downgrade(&snapshot.outputs[1].measurement.as_ref().unwrap().payload);
    e.remove(2).unwrap();
    assert!(weak.upgrade().is_some());
    drop(snapshot);
    assert!(weak.upgrade().is_none());
    for key in 2..1002 {
        text(&mut e, key, "replacement", 10.0);
        e.set_children(1, &[key]).unwrap();
        e.layout(1, 100.0, 100.0).unwrap();
        e.remove(key).unwrap();
    }
    assert_eq!(e.nodes.len(), 1);
    assert_eq!(e.snapshot.outputs.len(), 1);
}

#[test]
fn staged_custom_allocation_is_atomic_and_rejects_stale_candidates() {
    let mut e = engine();
    node(&mut e, 1, Spec::default());
    node(
        &mut e,
        2,
        Spec {
            kind: 5,
            min_width: 30.0,
            ..Spec::default()
        },
    );
    e.set_children(1, &[2]).unwrap();
    let old = e.layout(1, 200.0, 100.0).unwrap();
    let tentative = e.stage(1, 300.0, 100.0).unwrap();
    assert_eq!(e.snapshot.generation, old.generation);
    assert_eq!(e.counters.publications, 1);
    e.place(&[Placement {
        key: 2,
        x: 10.5,
        y: 12.0,
        width: 70.0,
        height: 20.0,
    }])
    .unwrap();
    assert!(e.commit(&tentative).is_err());
    let ready = e.stage(1, 300.0, 100.0).unwrap();
    assert_eq!(rect(&ready.snapshot, 2), [10.5, 12.0, 70.0, 20.0]);
    let published = e.commit(&ready).unwrap();
    assert_eq!(published.generation, old.generation + 1);
    assert!(e.commit(&ready).is_err());
    let mut other = engine();
    assert!(other.commit(&ready).is_err());
    let mutations = e.counters.mutations;
    assert!(e
        .place(&[
            Placement {
                key: 2,
                x: 0.0,
                y: 0.0,
                width: 80.0,
                height: 20.0
            },
            Placement {
                key: 999,
                x: 0.0,
                y: 0.0,
                width: 80.0,
                height: 20.0
            },
        ])
        .is_err());
    assert_eq!(e.counters.mutations, mutations);
    e.place(&[Placement {
        key: 2,
        x: 0.0,
        y: 0.0,
        width: 10.0,
        height: 20.0,
    }])
    .unwrap();
    assert!(e.stage(1, 300.0, 100.0).is_err());
    assert_eq!(e.snapshot.generation, published.generation);
    e.clear_placement(2).unwrap();
    assert_eq!(rect(&e.layout(1, 300.0, 100.0).unwrap(), 2)[2], 300.0);
}

#[test]
fn parent_local_clip_changes_publication_without_remeasuring_geometry() {
    let mut e = engine();
    node(
        &mut e,
        1,
        Spec {
            padding: 10.0,
            ..Spec::default()
        },
    );
    node(&mut e, 2, Spec::default());
    text(&mut e, 3, "retained", 10.0);
    e.set_children(1, &[2]).unwrap();
    e.set_children(2, &[3]).unwrap();
    let initial = e.layout(1, 100.0, 100.0).unwrap();
    let count = e.counters().measurements;
    e.set_clip(3, [5.0, 3.0, 20.0, 4.0]).unwrap();
    let staged = e.stage(1, 100.0, 100.0).unwrap();
    assert_eq!(e.snapshot.generation, initial.generation);
    let output = staged.snapshot.outputs.iter().find(|o| o.key == 3).unwrap();
    assert_eq!(output.clip, [15.0, 13.0, 20.0, 4.0]);
    assert_eq!(output.rect, rect(&initial, 3));
    assert_eq!(e.counters().measurements, count);
    assert!(e.set_clip(3, [0.0, 0.0, -1.0, 4.0]).is_err());
    e.commit(&staged).unwrap();
    assert_eq!(e.snapshot.generation, initial.generation + 1);
}
