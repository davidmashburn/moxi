import unittest
from instrument import INITIAL, mean, redistribute


class DistributionTests(unittest.TestCase):
    def test_grid(self):
        # Independent feasibility oracle: remaining mass placed entirely at
        # either endpoint gives the two attainable mean bounds.
        for a in range(11):
            for b in range(11 - a):
                mass = (a / 10, b / 10, (10 - a - b) / 10)
                for outcome in range(3):
                    other = sorted({0, 1, 2} - {outcome})
                    for step in range(11):
                        target = step / 10
                        bounds = [outcome * target + x * (1-target) for x in other]
                        for pinned in (False, True):
                            if pinned and not bounds[0]-1e-12 <= mean(mass) <= bounds[1]+1e-12:
                                with self.assertRaisesRegex(ValueError, 'possible mean'):
                                    redistribute(mass, outcome, target, True)
                                continue
                            result = redistribute(mass, outcome, target, pinned)
                            self.assertAlmostEqual(sum(result), 1)
                            self.assertEqual(result[outcome], target)
                            self.assertGreaterEqual(min(result), 0)
                            if pinned:
                                self.assertAlmostEqual(mean(result), mean(mass))
                            else:
                                i, j = other
                                self.assertAlmostEqual(result[i]*mass[j], result[j]*mass[i])

    def test_empty_remainder(self):
        self.assertEqual(redistribute([0, 1, 0], 1, .5, False), [.25, .5, .25])

    def test_invalid_probability(self):
        for value in (-.1, 1.01, float('nan'), float('inf')):
            with self.assertRaises(ValueError):
                redistribute(INITIAL, 0, value, False)
