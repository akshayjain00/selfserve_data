#!/usr/bin/env python3
"""Pipeline tests (stdlib unittest). Run: python3 test_pipeline.py

Covers the checks the report depends on: like-for-like windows, export
validation (truncation, stale tag, fan-out, missing window), conservation of
sums across every cut, and blank-not-zero behaviour.
"""

from __future__ import annotations

import datetime as _dt
import json
import pathlib
import sys
import tempfile
import unittest

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import hcvlib  # noqa: E402
import install_exports as inst  # noqa: E402
import metrics  # noqa: E402
from hcvlib import Periods, SUM_KEYS  # noqa: E402


def mcp_json(cols: list[str], rows: list[list], num_rows: int | None = None) -> str:
    return json.dumps({"result_set": {
        "data": [[str(x) if x is not None else "" for x in r] for r in rows],
        "resultSetMetaData": {"numRows": len(rows) if num_rows is None else num_rows,
                              "rowType": [{"name": c} for c in cols]}}})


def manifest_for(p: Periods) -> dict:
    qs = hcvlib.queries_for(p)
    a, b = p.date_range()
    return {
        "analysis_end": p.analysis_end.isoformat(),
        "date_range": [a.isoformat(), b.isoformat()],
        "periods": p.period_keys(), "queries": list(qs),
        "tags": {n: hcvlib.tag(n, p) for n in qs},
        "required_cols": {n: hcvlib.required_cols(n) for n in qs},
        "orders_chunks": {n: [x.isoformat(), y.isoformat()]
                          for n, (x, y) in hcvlib.orders_chunks(p).items()},
    }


def order_row(d, city, vm, ot, demand=10, completed=6, cadf=2, cbdf=2, rev=6000.0):
    # D CITY VM OT N_ROWS DEMAND ALLOCATED COMPLETED CADF cust partner porter CBDF SO MO REVENUE
    return [d, city, vm, ot, demand, demand, completed + cadf, completed, cadf,
            1, 1, 0, cbdf, 1, cbdf - 1, rev]


def synth(p: Periods, data: pathlib.Path) -> dict:
    """A complete, valid synthetic run written to ``data``."""
    m = manifest_for(p)
    ocols = hcvlib.required_cols("daily_orders_1")
    for name, (a, b) in hcvlib.orders_chunks(p).items():
        rows = []
        for i in range((b - a).days + 1):
            d = (a + _dt.timedelta(days=i)).isoformat()
            for city in ("1", "2"):
                for vm in ("9ft", "14ft", "17ft"):
                    for ot in ("SCHEDULE", "EXPRESS"):
                        rows.append(order_row(d, city, vm, ot, demand=10 + i % 3))
        (data / f"hcv_{name}.json").write_text(mcp_json(ocols + [m["tags"][name]], rows))
    a, b = p.date_range()
    drows = [[(a + _dt.timedelta(days=i)).isoformat(), c, vm, 5, 5]
             for i in range((b - a).days + 1) for c in ("1", "2") for vm in ("9ft", "14ft")]
    (data / "hcv_daily_dap.json").write_text(
        mcp_json(hcvlib.REQUIRED_COLS["daily_dap"] + [m["tags"]["daily_dap"]], drows))
    arows = []
    for per in p.period_keys():
        arows.append([per, "ALL", "ALL", None, 500, 12, 60])
        for c, nm in (("1", "Mumbai"), ("2", "Delhi NCR")):
            arows.append([per, "CITY", c, nm, 250, 10, 50])
        arows.append([per, "VM", "9ft", None, 5, 9, 40])      # below the sample floor
    (data / "hcv_period_alloc.json").write_text(
        mcp_json(hcvlib.REQUIRED_COLS["period_alloc"] + [m["tags"]["period_alloc"]], arows))
    (data / "manifest.json").write_text(json.dumps(m))
    return m


class TestPeriods(unittest.TestCase):
    def test_like_for_like_every_day_of_a_year(self):
        d = _dt.date(2026, 1, 1)
        for i in range(400):
            p = Periods(d + _dt.timedelta(days=i))
            ae = p.analysis_end
            n = lambda r: (r[1] - r[0]).days + 1  # noqa: E731
            self.assertEqual(n(p.wtd), n(p.lwtd), ae)
            self.assertEqual(p.wtd[0].weekday(), 0)
            self.assertEqual(p.lwtd[0], p.wtd[0] - _dt.timedelta(days=7))
            self.assertLessEqual(n(p.lmtd), n(p.mtd))            # clamped to shorter month
            self.assertEqual(p.lmtd[0].day, 1)
            if ae.day <= 28:
                self.assertEqual(n(p.mtd), n(p.lmtd), ae)
            self.assertEqual(len(p.strip_days), 14)
            self.assertEqual(p.strip_days[-1], ae)
            self.assertTrue(all(x.weekday() == ae.weekday() for x in p.sw_days))
            self.assertNotIn(ae, p.sw_days)

    def test_chunks_cover_the_range_exactly_once(self):
        p = Periods(_dt.date(2026, 11, 26))
        a, b = p.date_range()
        seen = []
        for x, y in hcvlib.orders_chunks(p).values():
            seen += [x + _dt.timedelta(days=i) for i in range((y - x).days + 1)]
        self.assertEqual(seen, [a + _dt.timedelta(days=i) for i in range((b - a).days + 1)])
        self.assertTrue(set(p.all_dates()) <= set(seen))


class TestInstaller(unittest.TestCase):
    def setUp(self):
        self.p = Periods(_dt.date(2026, 11, 26))
        self.tmp = pathlib.Path(tempfile.mkdtemp())
        self.m = synth(self.p, self.tmp)

    def _orders(self, mutate=None, num_rows=None, tag=None):
        name = "daily_orders_1"
        j = json.loads((self.tmp / f"hcv_{name}.json").read_text())["result_set"]
        cols = [c["name"] for c in j["resultSetMetaData"]["rowType"]]
        rows = j["data"]
        if tag:
            cols[-1] = tag
        if mutate:
            mutate(cols, rows)
        return inst.validate(name, mcp_json(cols, rows, num_rows), self.m)[1]

    def test_valid_run_passes(self):
        for name in self.m["queries"]:
            rows, probs = inst.validate(
                name, (self.tmp / f"hcv_{name}.json").read_text(), self.m)
            self.assertEqual(probs, [], name)
            self.assertTrue(rows)

    def test_truncated_response_refused(self):
        self.assertTrue(any("numRows" in x for x in self._orders(num_rows=99999)))

    def test_stale_tag_refused(self):
        probs = self._orders(tag="TAG__daily_orders_1__2026-11-25")
        self.assertTrue(any("stale" in x for x in probs))

    def test_fan_out_refused(self):
        def m(cols, rows):
            rows[0][cols.index("N_ROWS")] = "999"
        self.assertTrue(any("fan-out" in x for x in self._orders(m)))

    def test_missing_day_refused(self):
        def m(cols, rows):
            d0 = rows[0][0]
            rows[:] = [r for r in rows if r[0] != d0]
        self.assertTrue(any("no rows" in x for x in self._orders(m)))

    def test_cbdf_split_must_add_up(self):
        def m(cols, rows):
            rows[0][cols.index("CBDF_SO")] = "0"
        self.assertTrue(any("CBDF_SO" in x for x in self._orders(m)))

    def test_missing_column_refused(self):
        def m(cols, rows):
            i = cols.index("REVENUE")
            cols.pop(i)
            for r in rows:
                r.pop(i)
        self.assertTrue(any("missing columns" in x for x in self._orders(m)))

    def test_missing_window_refused(self):
        j = json.loads((self.tmp / "hcv_period_alloc.json").read_text())["result_set"]
        cols = [c["name"] for c in j["resultSetMetaData"]["rowType"]]
        rows = [r for r in j["data"] if r[0] != "LMTD"]
        probs = inst.validate("period_alloc", mcp_json(cols, rows), self.m)[1]
        self.assertTrue(any("missing windows" in x for x in probs))

    def test_garbage_refused(self):
        self.assertTrue(inst.validate("daily_dap", "not json", self.m)[1])
        self.assertTrue(inst.validate("daily_dap", mcp_json(["D"], []), self.m)[1])


class TestCube(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.p = Periods(_dt.date(2026, 11, 26))
        cls.tmp = pathlib.Path(tempfile.mkdtemp())
        synth(cls.p, cls.tmp)
        cls.cube = metrics.Cube(cls.tmp)

    def test_every_cut_conserves_every_sum_in_every_window(self):
        c = self.cube
        for win in ("D1", "SW4", "WTD", "LWTD", "MTD", "LMTD"):
            total = c.sums(c.dates(win))
            self.assertGreater(total["DEMAND"], 0)
            for cut in ("CITY", "VM", "OT"):
                parts = [c.sums(c.dates(win), cut, k) for k in c.members(cut)]
                for key in SUM_KEYS:
                    self.assertAlmostEqual(sum(x[key] for x in parts), total[key],
                                           msg=f"{win} {cut} {key}")

    def test_all_rows_loaded(self):
        raw = sum(len(hcvlib.load_export(f))
                  for f in self.tmp.glob("hcv_daily_orders_*.json"))
        self.assertEqual(len(self.cube.orders), raw)

    def test_definitions(self):
        m = metrics.derive({"DEMAND": 200, "ALLOCATED": 150, "COMPLETED": 120, "CADF": 30,
                            "CADF_CUSTOMER": 20, "CADF_PARTNER": 6, "CADF_PORTER": 4,
                            "CBDF": 50, "CBDF_SO": 10, "CBDF_MO": 40, "REVENUE": 600000})
        self.assertEqual(m["alloc_pct"], 75.0)
        self.assertEqual(m["ff_pct"], 60.0)          # completed / demand
        self.assertEqual(m["cadf_pct"], 15.0)
        self.assertEqual(m["cbdf_pct"], 25.0)
        self.assertEqual(m["cbdf_so_pct"] + m["cbdf_mo_pct"], m["cbdf_pct"])
        self.assertEqual(m["aov"], 5000.0)           # revenue / completed

    def test_blank_is_not_zero(self):
        m = metrics.derive(dict.fromkeys(SUM_KEYS, 0))
        for k in ("demand", "ff_pct", "aov", "revenue", "cbdf_pct"):
            self.assertIsNone(m[k], k)
        self.assertEqual(metrics.delta("ff_pct", None, 50.0), (None, None))

    def test_sw4_is_a_per_day_mean(self):
        c = self.cube
        tot = c.sums(c.dates("SW4"))["DEMAND"]
        self.assertAlmostEqual(c.cell("SW4")["demand"], tot / 4)

    def test_percentile_sample_floor_and_dap_scope(self):
        c = self.cube
        self.assertIsNone(c.cell("MTD", "VM", "9ft")["alloc_p90"])     # n = 5 < 30
        self.assertEqual(c.cell("MTD", "CITY", "1")["alloc_p50"], 10)
        self.assertIsNone(c.cell("MTD", "OT", "SCHEDULE")["dap"])
        self.assertEqual(c.cell("MTD")["dap"], 20)                       # 2 cities x 2 vm x 5

    def test_deltas(self):
        self.assertEqual(metrics.delta("ff_pct", 60.0, 57.5), (2.5, "pp"))
        self.assertEqual(metrics.delta("demand", 110, 100), (10.0, "%"))
        self.assertEqual(metrics.delta("alloc_p90", 50, 60), (-10, "s"))


class TestFormat(unittest.TestCase):
    def test_formatters(self):
        import build_report as br
        self.assertEqual(br.f_int(1234567), "12,34,567")
        self.assertEqual(br.f_int(999), "999")
        self.assertEqual(br.f_money(123456789), "₹12.35 Cr")
        self.assertEqual(br.f_money(250000), "₹2.50 L")
        self.assertEqual(br.f_time(59.4), "59s")
        self.assertEqual(br.f_time(125), "2m 05s")
        self.assertEqual(br.f_pct(57.25), "57.3%")           # half rounds up
        self.assertEqual(br.fmt("ff_pct", None), "")
        self.assertEqual(br.f_delta(-0.25, "pp"), "−0.3pp")
        self.assertEqual(br.f_delta(0.0, "%"), "0.0%")


if __name__ == "__main__":
    unittest.main(verbosity=1)
