"""Expected rejection: a field origin does not match this whole-parent trait.

This is a failure of this signature on Mojo 1.1.0, not proof that no generic
safe lens can be expressed. The field adapter avoids this mismatch.
"""
trait Lens:
    comptime Parent: ImplicitlyCopyable
    comptime Child: ImplicitlyCopyable
    @staticmethod
    def get(ref parent: Self.Parent) -> ref[parent] Self.Child: ...

struct Model(ImplicitlyCopyable):
    var value: Int
    def __init__(out self):
        self.value = 0

struct ValueLens(Lens):
    comptime Parent = Model
    comptime Child = Int
    @staticmethod
    def get(ref parent: Model) -> ref[parent.value] Int:
        return parent.value

def main():
    var model = Model()
    print(ValueLens.get(model))
