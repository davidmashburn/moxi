@export
def moxi_probe(x: Float64, y: Float64) abi("C") -> Float64:
    return x * x + y

def main():
    pass
