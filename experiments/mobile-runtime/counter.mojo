"""The mobile host supplies the current count and receives the Mojo transition."""
from moxi_demo.authoring_examples.counter import Counter


@export
def moxi_mobile_increment(value: Int32) abi("C") -> Int32:
    var model = Counter()
    model.count = Int(value)
    model.increment()
    return Int32(model.count)
