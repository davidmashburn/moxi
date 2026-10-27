from layout import sample_graph

@export
def fdg_probe(steps: Int32) abi("C") -> Float64:
    try:
        var graph = sample_graph()
        for _ in range(Int(steps)):
            _ = graph.step()
        var checksum: Float64 = 0
        for i in range(len(graph.nodes)):
            checksum += graph.nodes[i].x * Float64(i + 1) + graph.nodes[i].y
        return checksum
    except:
        return -999999.0

def main():
    print(fdg_probe(0))
    print(fdg_probe(1))
    print(fdg_probe(100))
