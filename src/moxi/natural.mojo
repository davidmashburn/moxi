"""Nonnegative decimal counters whose range is independent of machine words."""

from std.collections import List


struct Natural(ImplicitlyCopyable):
    """Little-endian decimal digits; storage grows with the input's spelling."""

    var digits: List[UInt8]

    def __init__(out self, value: Int = 0):
        self.digits = List[UInt8]()
        var remaining = max(value, 0)
        while remaining > 0:
            self.digits.append(UInt8(remaining % 10))
            remaining //= 10

    def __init__(out self, *, copy: Self):
        self.digits = copy.digits.copy()

    def parse(mut self, text: String) -> Bool:
        """Accept ASCII decimal without an overflow or a permissive fallback."""
        var bytes = text.as_bytes()
        if len(bytes) == 0:
            return False
        var parsed = List[UInt8]()
        for index in range(len(bytes) - 1, -1, -1):
            var code = Int(bytes[index])
            if code < 48 or code > 57:
                return False
            parsed.append(UInt8(code - 48))
        while len(parsed) > 0 and parsed[len(parsed) - 1] == 0:
            _ = parsed.pop()
        self.digits = parsed^
        return True

    def is_zero(self) -> Bool:
        return len(self.digits) == 0

    def increment(mut self):
        var index = 0
        while index < len(self.digits) and self.digits[index] == 9:
            self.digits[index] = 0
            index += 1
        if index == len(self.digits):
            self.digits.append(1)
        else:
            self.digits[index] += 1

    def decrement(mut self):
        if self.is_zero():
            return
        var index = 0
        while self.digits[index] == 0:
            self.digits[index] = 9
            index += 1
        self.digits[index] -= 1
        if self.digits[len(self.digits) - 1] == 0:
            _ = self.digits.pop()

    def bounded_value(self, limit: Int) -> Int:
        """Read min(self, limit) without overflowing, including at Int.MAX."""
        var result = 0
        for index in range(len(self.digits) - 1, -1, -1):
            var digit = Int(self.digits[index])
            if result > limit // 10 or (result == limit // 10 and digit > limit % 10):
                return limit
            result = result * 10 + digit
        return result

    def __eq__(self, other: Self) -> Bool:
        if len(self.digits) != len(other.digits):
            return False
        for index in range(len(self.digits)):
            if self.digits[index] != other.digits[index]:
                return False
        return True

    def __eq__(self, other: Int) -> Bool:
        return other >= 0 and self == Natural(other)

    def text(self) -> String:
        if self.is_zero():
            return "0"
        var result = String()
        for index in range(len(self.digits) - 1, -1, -1):
            result += String(Int(self.digits[index]))
        return result
