import unittest
from dataclasses import replace
from urllib.parse import parse_qs, urlsplit
from xml.etree import ElementTree as ET

from app import plot, snapshot, SVG
from model import COLLECTIONS, Domain, View, Visibility


class CoordinationTests(unittest.TestCase):
    def test_each_projection_keeps_exact_source_set(self):
        for domain, collection in COLLECTIONS.items():
            rows = collection.sources
            for filtered in (False, True):
                for grouped in (False, True):
                    # Exercise every deletion subset, including empty projections.
                    for mask in range(1 << len(rows)):
                        deleted = tuple(r.key for i, r in enumerate(rows) if mask & (1 << i))
                        view = View(domain, (), deleted, filtered, grouped)
                        projected = [r for r in rows if r.key not in deleted and
                                     (not filtered or r.y >= collection.threshold)]
                        members = [[r.key for r in projected if r.group == group]
                                   for group in dict.fromkeys(r.group for r in projected)
                                   ] if grouped else [[r.key] for r in projected]
                        self.assertEqual([list(m.members) for m in view.marks()], members)
                        links = ET.fromstring(plot(view)).iter(SVG + "a")
                        self.assertEqual([parse_qs(urlsplit(a.get("href")).query)["selected"]
                                          for a in links], members)

    def test_hidden_deleted_and_ambiguous(self):
        first, second, *_ = COLLECTIONS[Domain.SPECIMEN].sources
        view = View(selected=(first.key,))
        hidden = replace(view, filtered=True)
        self.assertEqual(hidden.visibility(first), Visibility.FILTERED)
        for invalid in (hidden, view.delete(), replace(view, selected=(first.key, second.key))):
            with self.assertRaisesRegex(ValueError, "one visible"):
                invalid.delete()
        self.assertEqual(view.delete().visibility(first), Visibility.DELETED)
        self.assertEqual(view.delete().selected, view.selected)
        self.assertEqual(view.delete().visible()[0], second)

    def test_malformed_snapshot_cannot_delete_a_hidden_row(self):
        query = "selected=S-14&filtered=1&delete=1"
        status, page = snapshot(query)
        self.assertEqual(status, 200)
        self.assertIn("Choose one visible source to delete.", page)
        for field in ("filtered=1", "grouped=2", "selected=", "deleted=",
                      "domain=specimen&domain=specimen", "delete=1", "grouped="):
            with self.subTest(field=field), self.assertRaises(ValueError):
                snapshot(query + "&" + field)

    def test_fixture_aggregation_and_domain_boundary(self):
        transit = View(Domain.TRANSIT, grouped=True)
        mean_stop = transit.marks()[0]
        self.assertEqual((mean_stop.members, mean_stop.x, mean_stop.y),
                         (("T-02", "T-19"), 3, 32))
        with self.assertRaises(ValueError):
            snapshot("domain=transit&selected=S-14")
        with self.assertRaises(ValueError):
            snapshot("selected=S-38&selected=S-38")


if __name__ == "__main__":
    unittest.main()
