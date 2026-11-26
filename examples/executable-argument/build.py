"""Build a portable, offline V05 consumer with the checkout's Moxi renderer."""
import argparse
import json
from pathlib import Path

import moxi

# Riders, pooled voucher spend, shuttle variable spend (USD per run).
OBSERVATIONS = ((5, 30, 10), (10, 60, 20), (20, 120, 40))
DISPATCH = (80, 120, 160)
MAX_RIDERS = 60


def fit_rate(column):
    """Least-squares unit cost with the variable-cost intercept fixed at zero."""
    return sum(row[0] * row[column] for row in OBSERVATIONS) / sum(
        row[0] ** 2 for row in OBSERVATIONS
    )


def evaluate(riders, dispatch):
    if type(riders) is not int or not 0 <= riders <= MAX_RIDERS or dispatch not in DISPATCH:
        raise ValueError("Choose 0–60 whole riders and a listed dispatch cost.")
    voucher = fit_rate(1) * riders
    shuttle = dispatch + fit_rate(2) * riders
    return dict(voucher=voucher, shuttle=shuttle, delta=voucher-shuttle)


def scenario(dispatch):
    rows = [evaluate(n, dispatch) for n in range(MAX_RIDERS + 1)]
    spec = moxi.PlotSpec("Shuttle savings per run")
    spec.add_line("Savings", "riders", "delta", (0.08, 0.43, 0.45, 1))
    chart = moxi.plot([dict(riders=n, **row) for n, row in enumerate(rows)],
                      spec, width=420, height=128)
    return dict(rows=rows, chart=chart.to_svg().decode(),
                threshold=dispatch / (fit_rate(1) - fit_rate(2)))


def build(path):
    folder = Path(__file__).parent
    fixture = dict(observations=OBSERVATIONS, rates=[fit_rate(1), fit_rate(2)],
                   cases={cost: scenario(cost) for cost in DISPATCH})
    page = (folder / "page.html").read_text().replace("/*FIXTURE*/", json.dumps(fixture))
    page = page.replace("/*APP*/", (folder / "argument.js").read_text())
    path.write_text(page, encoding="utf-8")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    build(parser.parse_args().output)
