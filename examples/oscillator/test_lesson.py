import math
import unittest
from xml.etree import ElementTree

from lesson import BASE, TRANSFER, Spring, comparison


class SpringTest(unittest.TestCase):
    def test_period_scaling_and_transfer(self):
        self.assertAlmostEqual(BASE.period, math.pi / 2)
        self.assertAlmostEqual(Spring(4, 16, .5).period, 2 * BASE.period)
        self.assertAlmostEqual(TRANSFER.period, BASE.period)

    def test_quarter_cycle_and_singular_basis(self):
        position, velocity = BASE.sample(BASE.period / 4)
        self.assertAlmostEqual(position, 0)
        self.assertAlmostEqual(velocity, -2)
        self.assertEqual(Spring(1, 16, 0).sample(1), (0, 0))

    def test_rejection(self):
        for params in [(0, 16, .5), (1, -1, .5), (1, 16, float("nan"))]:
            with self.subTest(params=params), self.assertRaises(ValueError):
                Spring(*params)
        with self.assertRaises(ValueError):
            comparison(BASE, 9)

    def test_repeatable_plot_and_linked_sample(self):
        result = comparison(BASE, 0)
        self.assertEqual(result, comparison(BASE, 0))
        self.assertEqual(result["position"], .5)
        curves = ElementTree.fromstring(result["svg"]).findall(".//{*}polyline")
        self.assertEqual(len(curves), 3)
        self.assertEqual(curves[0].attrib["points"], curves[1].attrib["points"])

    def test_common_axes(self):
        result = comparison(Spring(1, 16, 1), 2)
        root = ElementTree.fromstring(result["svg"])
        def points(line):
            return [tuple(map(float, pair.split(","))) for pair in line.get("points").split()]
        reference, trial, cursor = map(points, root.findall(".//{*}polyline"))
        left, right = reference[0][0], reference[-1][0]
        self.assertAlmostEqual(cursor[0][0], left + (right - left) / 4, delta=.001)
        middle = (cursor[0][1] + cursor[-1][1]) / 2
        self.assertAlmostEqual(middle - trial[0][1], 2 * (middle - reference[0][1]), delta=.001)
