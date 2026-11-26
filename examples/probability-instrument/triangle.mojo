"""Export the probability triangle's affine basis and inverse in SVG order."""
from moxi.geometry import Transform


def coefficients(t: Transform) -> String:
    return String("[", t.m11, ",", t.m12, ",", t.m21, ",", t.m22, ",", t.tx, ",", t.ty, "]")


def main() raises:
    # World coordinates are (P(1), P(2)). P(0) is the residual.
    var basis = Transform(340, 0, 170, -160, 130, 185)
    print('{"forward":', coefficients(basis), ',"inverse":', coefficients(basis.inverse()), '}')
