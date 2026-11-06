"""Independent public-API consumer: no private geometry, Python or CAS."""
from moxi_math import run_math_editor

def main() raises:
    run_math_editor("Moxi Math · Formula card", 'frac(root(?, row(a, +, b)), scripts(c, i, 2, ?, ?))', "assets/math/STIXTwoMath-Regular.otf")
