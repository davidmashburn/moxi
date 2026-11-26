"""Deterministic model, projection and loopback boundary regressions."""
import json
import threading
import unittest
from urllib.error import HTTPError
from urllib.request import Request, urlopen
from xml.etree import ElementTree as ET

from matrix import Matrix, RankState
from serve import Handler, ThreadingHTTPServer


class MatrixTest(unittest.TestCase):
    def test_exact_determinant_and_rank(self):
        cases = [((2000, 0, 0, 2000), 4_000_000, RankState.REGULAR),
                 ((0, 1000, 1000, 0), -1_000_000, RankState.REGULAR),
                 ((2000, 1000, 2000, 1000), 0, RankState.SINGULAR),
                 ((0, 0, 0, 0), 0, RankState.SINGULAR),
                 ((1000, 1000, 1000, 1001), 1000, RankState.NEAR_SINGULAR),
                 ((125, 0, 0, 125), 15625, RankState.REGULAR)]
        for ticks, determinant, state in cases:
            with self.subTest(ticks=ticks):
                matrix = Matrix(ticks)
                self.assertEqual(matrix.determinant, determinant)
                self.assertIs(matrix.rank_state, state)
        self.assertEqual(Matrix((125, 0, 0, 125)).render()["determinant"], "0.015625")

    def test_projection_shares_fixed_equal_unit_scales(self):
        def points(result, layer):
            root = ET.fromstring(result["svg"])
            self.assertIsNotNone(root.find(".//{*}g[@data-moxi='plot']"))
            path = root.find(f".//{{*}}polyline[@data-layer='{layer}']")
            return [tuple(map(float, p.split(","))) for p in path.get("points").split()]

        initial = Matrix((2000, 0, 0, 2000)).render()
        u, v, square = [points(initial, layer) for layer in ("u", "v", "square")]
        self.assertEqual(len(u), 2)  # Domain anchors and padding are never drawn.
        self.assertEqual(u[0], v[0])
        self.assertAlmostEqual(u[1][0] - u[0][0], v[0][1] - v[1][1])
        self.assertEqual(square, [u[0], u[1], (u[1][0], v[1][1]), v[1], u[0]])
        moved = Matrix((3000, -3000, 0, 1000)).render()
        moved_u = points(moved, "u")
        self.assertEqual(moved_u[0], u[0])
        self.assertAlmostEqual(moved_u[1][0] - u[0][0], 1.5 * (u[1][0] - u[0][0]), delta=.002)
        # Singular and zero frames remain finite, renderable and in the same view.
        for ticks in ((0, 0, 0, 0), (3000, -3000, 3000, -3000)):
            result = Matrix(ticks).render()
            self.assertEqual(result["rank"], "singular")  # Independent wire contract.
            self.assertNotIn("nan", result["svg"].lower())
            self.assertEqual(points(result, "u")[0], u[0])

    def test_invalid_matrix_rejected(self):
        for ticks in ((), (1, 2, 3), (1, 2, 3, 4, 5), (True, 0, 0, 1),
                      (1.1, 0, 0, 1), (3001, 0, 0, 1), ("1", 0, 0, 1)):
            with self.subTest(ticks=ticks), self.assertRaises(ValueError):
                Matrix(ticks)


class QuietHandler(Handler):
    def log_message(self, *args):
        pass


class ServiceTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = ThreadingHTTPServer(("127.0.0.1", 0), QuietHandler)
        cls.worker = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.worker.start()
        cls.url = f"http://127.0.0.1:{cls.server.server_port}"

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        cls.worker.join()

    def post(self, body):
        return urlopen(Request(self.url + "/render", data=body,
                               headers={"Content-Type": "application/json"}), timeout=5)

    def test_render_contract(self):
        with self.post(b'{"matrix":[0,1000,1000,0]}') as response:
            result = json.load(response)
            self.assertEqual(result["matrix"], [0, 1000, 1000, 0])
            self.assertEqual(result["determinant"], "−1")
            self.assertEqual(result["rank"], "regular")
            self.assertIn('data-moxi="plot"', result["svg"])
            self.assertEqual(response.headers["Cache-Control"], "no-store")

    def test_bad_requests_leave_service_usable(self):
        for body in (b"", b"{", b"null", b"[]", b'{}', b'{"matrix":1}',
                     b'{"matrix":[NaN,0,0,1]}', b'{"matrix":[true,0,0,1]}',
                     b'{"matrix":[3001,0,0,1]}', b" " * 1025):
            with self.subTest(body=body[:45]), self.assertRaises(HTTPError) as failure:
                self.post(body)
            self.assertEqual(failure.exception.code, 400)
            failure.exception.close()
        with self.post(b'{"matrix":[0,0,0,0]}') as response:
            self.assertEqual(json.load(response)["rank"], "singular")


if __name__ == "__main__":
    unittest.main()
