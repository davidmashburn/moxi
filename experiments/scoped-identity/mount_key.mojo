"""Sibling slot and mount generation are different identity coordinates."""

struct MountKey(ImplicitlyCopyable):
    var slot: Int
    var generation: Int

    def __init__(out self, slot: Int, generation: Int):
        self.slot = slot
        self.generation = generation

    def __eq__(self, other: Self) -> Bool:
        return self.slot == other.slot and self.generation == other.generation

    def __ne__(self, other: Self) -> Bool:
        return not self == other


def key_path[K: ImplicitlyCopyable](key: K) -> String:
    comptime if K == Int:
        return String(rebind[Int](key))
    elif K == MountKey:
        var mount = rebind[MountKey](key)
        # Typed mount keys cannot alias legacy integer keys.
        return "m:" + String(mount.slot) + ":" + String(mount.generation)
    else:
        comptime assert False, "child key must be Int or MountKey"
