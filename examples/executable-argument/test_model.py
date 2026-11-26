import unittest
from xml.etree import ElementTree

from build import DISPATCH, MAX_RIDERS, evaluate, fit_rate, scenario


class ArgumentTest(unittest.TestCase):
    def test_fit_and_authored_case(self):
        self.assertEqual((fit_rate(1), fit_rate(2)), (6, 2))
        self.assertEqual(evaluate(40, 120), dict(voucher=240, shuttle=200, delta=40))

    def test_entire_published_domain(self):
        for cost in DISPATCH:
            model = scenario(cost)
            chart = ElementTree.fromstring(model["chart"])
            self.assertEqual(len(chart.findall('.//{*}polyline')), 1)
            for n in range(MAX_RIDERS + 1):
                delta = model["rows"][n]["delta"]
                self.assertEqual(delta, 4 * n - cost)
                self.assertEqual(delta > 0, n > model["threshold"])
                self.assertEqual(delta == 0, n == model["threshold"])

    def test_invalid_premises(self):
        for n, cost in [(-1, 80), (61, 120), (1.5, 160), (True, 80), (30, 0)]:
            with self.assertRaises(ValueError):
                evaluate(n, cost)
