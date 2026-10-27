from std.testing import assert_true, assert_equal, assert_almost_equal
from std.math import isfinite
from layout import Layout, sample_graph

def main() raises:
    var empty = Layout()
    assert_true(not empty.step())
    var singleton = Layout()
    singleton.add_node("only")
    for _ in range(400):
        _ = singleton.step()
    assert_true(not singleton.active())
    assert_true(isfinite(singleton.nodes[0].x) and isfinite(singleton.nodes[0].y))
    var graph = sample_graph()
    var replay = sample_graph()
    for _ in range(400):
        _ = graph.step()
        _ = replay.step()
    assert_true(not graph.active())
    for i in range(len(graph.nodes)):
        assert_true(isfinite(graph.nodes[i].x) and isfinite(graph.nodes[i].y))
        assert_equal(graph.nodes[i].x, replay.nodes[i].x)
        assert_equal(graph.nodes[i].y, replay.nodes[i].y)
    graph.pin(0, 10, -20)
    for _ in range(30):
        _ = graph.step()
    assert_equal(graph.nodes[0].x, 10.0)
    assert_equal(graph.nodes[0].y, -20.0)
    graph.release(0)
    assert_true(not graph.nodes[0].pinned and graph.active())
    graph.paused = True
    var x = graph.nodes[1].x
    assert_true(not graph.step())
    assert_equal(graph.nodes[1].x, x)
    var pair = Layout()
    pair.add_node("a")
    pair.add_node("b")
    pair.nodes[0].x = 0
    pair.nodes[0].y = 0
    pair.nodes[1].x = 0
    pair.nodes[1].y = 0
    _ = pair.step()
    assert_true(isfinite(pair.nodes[0].x))
    assert_true(pair.nodes[0].x != pair.nodes[1].x)
    pair.charge = 0
    pair.add_link("a", "b")
    pair.nodes[0].x = -100
    pair.nodes[1].x = 100
    pair.nodes[0].vx = 0
    pair.nodes[1].vx = 0
    _ = pair.step()
    assert_true(pair.nodes[0].x > -100 and pair.nodes[1].x < 100)
    var rejected = False
    try:
        pair.add_link("a", "missing")
    except:
        rejected = True
    assert_true(rejected)
    rejected = False
    try:
        pair.add_node("a")
    except:
        rejected = True
    assert_true(rejected)
    print("layout: deterministic replay, cooling, pins, pause, coincidence, attraction, validation pass")
