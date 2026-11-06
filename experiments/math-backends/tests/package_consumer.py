"""Copied outside the checkout by package-check.sh; uses installed modules only."""
import pathlib
import time
import moxi_math_probe
from moxi_math_probe.controller import Controller
from moxi_math_probe.corpus import fixtures, canonical
from moxi_math_probe.model import Backend, Status
assert "site-packages" in moxi_math_probe.__file__
for backend in Backend:
    with Controller(backend) as c:
        fixture = fixtures()[0]
        c.submit(fixture.request, 0)
        until = time.monotonic() + 10
        result = None
        while result is None and time.monotonic() < until:
            result = c.poll()
            time.sleep(.002)
        assert result is not None and result.status == Status.OK, result
        assert canonical(result.result) == canonical(fixture.expected)
        print(backend.value, "installed consumer: exact 1/2; child reaped on close")
