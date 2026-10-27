from std.testing import assert_equal, assert_true
from graph_io import parse_graph, load_graph

def rejects(text: String) raises:
    var rejected = False
    try:
        _ = parse_graph(text)
    except:
        rejected = True
    assert_true(rejected)
    with open("/tmp/moxi-fdg-empty.json", "w") as file:
        file.write('{"nodes":[],"links":[]}')
    var loaded = load_graph("/tmp/moxi-fdg-empty.json")
    assert_equal(len(loaded.nodes), 0)

def main() raises:
    var graph = parse_graph('{"links":[{"source":"a", "target":"b", "value":2.5}], "nodes":[{"id":"a","group":1},{"id":"b", "group":2}]}')
    assert_equal(len(graph.nodes), 2)
    assert_equal(graph.links[0].weight, 2.5)
    var unicode = parse_graph('{"nodes":[{"id":"\\u03b1\\ud83c\\udf10"}],"links":[]}')
    assert_equal(unicode.nodes[0].id, "α🌐")
    var rejected = False
    try:
        _ = parse_graph('{"nodes":[], "links":[{"source":"x","target":"y"}]}')
    except:
        rejected = True
    assert_true(rejected)
    rejects('{"nodes":[{"id":"a","group":1,"group":2}],"links":[]}')
    rejects('{"nodes":[{"id":"a"}],"links":[{"source":"a","target":"a","value":1,"value":2}]}')
    rejects('{"nodes":[{"id":"a"},{"id":"a"}],"links":[]}')
    rejects('{"nodes":[],"links":[],}')
    rejects('{"nodes":[{"id":"\\ud800"}],"links":[]}')
    rejects('{"nodes":[{"id":"a"}],"links":[{"source":"a","target":"a","value":-1}]}')
    rejects('{"nodes":[{"id":"a"}],"links":[{"source":"a","target":"a","value":1e999}]}')
    print("graph JSON: original schema, ordering, values, Unicode, missing endpoints pass")
