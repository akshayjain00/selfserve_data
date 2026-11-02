"""Shared helpers for the PTL daily digest pipeline."""
import json
import os
from datetime import date, datetime, timedelta, timezone

ROOT = os.path.dirname(os.path.abspath(__file__))
WORK = os.path.join(ROOT, "work")
DATA = os.path.join(ROOT, "data")
OUT = os.path.join(ROOT, "out")
HIST = os.path.join(DATA, "daily.json")
IST = timezone(timedelta(hours=5, minutes=30))
HISTORY_FLOOR = date(2026, 4, 1)  # earliest day needed for the 6-month windows


def today_ist():
    return datetime.now(IST).date()


def default_end():
    """The digest's 'latest day' is the day before yesterday (T-2)."""
    return today_ist() - timedelta(days=2)


def d8(d):
    return d.strftime("%Y%m%d")


def parse8(s):
    return date(int(s[:4]), int(s[4:6]), int(s[6:8]))


def load_hist():
    if not os.path.exists(HIST):
        return {}
    return json.load(open(HIST))


def save_hist(h):
    os.makedirs(DATA, exist_ok=True)
    json.dump(h, open(HIST, "w"), separators=(",", ":"), sort_keys=True)


def windows(D, hist):
    """All date windows the queries need, derived from the latest day D."""
    have = sorted(date.fromisoformat(k) for k in hist) if hist else []
    start = HISTORY_FLOOR if not have else max(HISTORY_FLOOR, min(have[-1] - timedelta(days=6), D - timedelta(days=6)))
    route0 = D - timedelta(days=6)                                    # last 7 days ending D
    last_sun = D - timedelta(days=(D.weekday() + 1) % 7)              # most recent Sunday <= D
    last_mon = last_sun - timedelta(days=6)
    weekly0 = last_mon - timedelta(weeks=12)                          # 13 full weeks
    return dict(start=start, end=D, route0=route0, weekly0=weekly0, weekly1=last_sun, last_mon=last_mon)


def read_s(name):
    """Return the saved query string for work/<name>.txt, or None."""
    p = os.path.join(WORK, name + ".txt")
    if not os.path.exists(p):
        return None
    s = open(p).read().strip()
    return s or None
