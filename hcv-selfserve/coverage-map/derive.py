#!/usr/bin/env python3
"""Derive metric-coverage.json's coverage fields from the knowledge base.

The coverage map is a PROJECTION, never a source (`kb/GAPS.md` G-082, `kb-build/DECISIONS.md`
D-028). Nothing in `coverage-map/` may be edited by hand: fix `kb/`, then re-run this.

What it derives, and from what:

  status / blocker / source / resolves_to / kb_row   <- kb/metrics.md SS1 and SS2
  north_star                                        <- kb/metrics.md SS1, M-001 (D-011)

What it deliberately does NOT touch: every descriptive field already in the JSON
(`name`, `level`, `type`, `domain`, `system`, `classification`, `argus_phase`,
`cross_thread`, `path`). Those transcribe the Argus DD CSV, and re-deriving them would
risk drift for no gain. Their `level`, `classification` and `system` tallies and all 113
distinct names were checked against the CSV and match exactly (G-100).

  !! ONE KNOWN-WRONG DESCRIPTIVE CELL: `cross_thread` on HCV-004 (`L4 Tickets`) should be
  `Core Platforms`, not `None recorded`. The six short rows of G-079 are misaligned by TWO
  columns, so the thread-owner value sits at cell index 23 on those rows and 24 on the
  other 112; reading 24 uniformly drops this one. Fix it at source, not here -- see G-103.

Row identity: `HCV-NNN` is row NNN of
`ProdOps/01_reference_readonly/migrated_context/HCV_Metrics_DD.csv` (header = line 1,
so data row NNN is file line NNN+1). Established by G-100.

Usage:  python3 hcv-selfserve/coverage-map/derive.py [--check]
        --check exits 1 if the committed JSON differs from the derivation.
"""

import json
import pathlib
import re
import sys

HERE = pathlib.Path(__file__).resolve().parent
KB = HERE.parent / "kb"
JSON_PATH = HERE / "metric-coverage.json"
HTML_PATH = HERE / "coverage-map.html"

CSV_REL = "ProdOps/01_reference_readonly/migrated_context/HCV_Metrics_DD.csv"
KB_METRICS = "hcv-selfserve/kb/metrics.md"

NORTH_STAR = "Fulfilment % (M-001)"

NOTE_FULL = (
    "Retired by a full M-### entry in metrics.md SS1 -- formula, verbatim SQL and provenance "
    "recorded. Open definition disputes remain; see the entry's gap rows."
)
NOTE_INDEX = (
    "Indexed in metrics.md SS2 with its source, level, Doshi category and dedup rule. "
    "Awaiting promotion to a full M-### entry: locate its card SQL, fingerprint the card, "
    "establish its store_ref."
)
NOTE_UNREAD = (
    "Present in the Argus DD but never indexed by this KB -- outside the rows 1-90 window the "
    "2026-08-14 build read. Whether it is a new identity or a duplicate of an indexed one is "
    "undetermined. See G-101."
)


def read(name):
    return (KB / name).read_text(encoding="utf-8")


def section(text, start_prefix, end_prefix):
    lines = text.split("\n")
    i1 = next(i for i, l in enumerate(lines) if l.startswith(start_prefix))
    i2 = next(i for i, l in enumerate(lines) if l.startswith(end_prefix))
    return lines[i1:i2]


def parse_full_entries(met):
    """gsheet row number -> (M-###, resolves_to list or None).

    Bounded to SS1. Without the bound the final M-012 block runs to end-of-file and
    swallows SS2's whole index table, whose rows also cite `gsheet:NN` -- which yields
    64 "full entries" instead of 6.
    """
    sec1 = "\n".join(section(met, "## §1 The 12", "## §2 Index"))
    out = {}
    for block in re.split(r"\n(?=### M-\d{3} — )", sec1):
        m = re.match(r"### (M-\d{3}) — ", block)
        if not m:
            continue
        mid = m.group(1)
        rows = [int(x) for x in re.findall(r"gsheet:(\d+)", block)]
        store = re.search(r"store_ref:\*\*\s*`(metric\.porter\.[a-z_]+)`", block)
        resolves = [store.group(1)] if store else None
        for r in rows:
            out[r] = (mid, resolves)
    return out


def parse_index(met):
    """gsheet row number -> index row number; and cov id -> index row number."""
    gs2idx, cov2idx = {}, {}
    for l in section(met, "## §2 Index", "### §2a"):
        m = re.match(r"^\|\s*(\d+)\s*\|", l)
        if not m:
            continue
        n = int(m.group(1))
        cells = [c.strip() for c in l.strip("|").split("|")]
        inv = cells[3]
        for grp in re.finditer(r"gsheet:([\d,\s]+)", inv):
            for x in re.findall(r"\d+", grp.group(1)):
                gs2idx.setdefault(int(x), n)
        for grp in re.finditer(r"cov:HCV-(\d{3})", inv):
            cov2idx.setdefault(int(grp.group(1)), n)
    return gs2idx, cov2idx


def derive():
    met = read("metrics.md")
    full = parse_full_entries(met)
    gs2idx, cov2idx = parse_index(met)
    rows = json.loads(JSON_PATH.read_text(encoding="utf-8"))

    tally = {"partial": 0, "pending": 0}
    for i, row in enumerate(rows):
        n = int(row["id"].split("-")[1])
        row["north_star"] = NORTH_STAR

        if n in full:
            mid, resolves = full[n]
            row.update(
                status="partial",
                blocker="reconciliation",
                blocker_note=NOTE_FULL,
                source=KB_METRICS,
                resolves_to=resolves,
                kb_row=mid,
            )
        elif n in gs2idx or n in cov2idx:
            idx = gs2idx.get(n, cov2idx.get(n))
            row.update(
                status="pending",
                blocker="promotion",
                blocker_note=NOTE_INDEX,
                source=KB_METRICS,
                resolves_to=None,
                kb_row="G-%d" % (200 + idx),
            )
        else:
            row.update(
                status="pending",
                blocker="source-unread",
                blocker_note=NOTE_UNREAD,
                source="%s:%d" % (CSV_REL, n + 1),
                resolves_to=None,
                kb_row="G-101",
            )
        tally[row["status"]] += 1

        # keep key order stable and identical across rows
        order = [
            "id", "vertical", "north_star", "path", "name", "level", "type", "domain",
            "system", "classification", "argus_phase", "cross_thread", "status", "blocker",
            "blocker_note", "provenance", "source", "resolves_to", "kb_row",
        ]
        for k in order:
            row.setdefault(k, None)
        for k in list(row):
            if k not in order:
                raise SystemExit("unexpected field %r on %s" % (k, row["id"]))
        rows[i] = {k: row[k] for k in order}

    return rows, tally, full, gs2idx, cov2idx


def main():
    rows, tally, full, gs2idx, cov2idx = derive()
    text = json.dumps(rows, indent=2, ensure_ascii=False) + "\n"

    check = "--check" in sys.argv
    if check:
        current = JSON_PATH.read_text(encoding="utf-8")
        if current != text:
            print("DRIFT: committed metric-coverage.json != derivation from kb/", file=sys.stderr)
            return 1
        print("in sync")
        return 0

    JSON_PATH.write_text(text, encoding="utf-8")

    # the HTML embeds the same array after a /*__COVERAGE_DATA__*/ marker
    html = HTML_PATH.read_text(encoding="utf-8")
    compact = json.dumps(rows, ensure_ascii=False, separators=(",", ":"))
    new_html, n = re.subn(
        r"(/\*__COVERAGE_DATA__\*/)\[.*?\](;\s*\n)",
        lambda m: m.group(1) + compact + m.group(2),
        html,
        count=1,
        flags=re.S,
    )
    if n != 1:
        raise SystemExit("could not locate the /*__COVERAGE_DATA__*/ array in coverage-map.html")
    HTML_PATH.write_text(new_html, encoding="utf-8")

    print("rows            : %d" % len(rows))
    print("status mix      : %s" % ", ".join("%d %s" % (v, k) for k, v in sorted(tally.items())))
    print("full entries    : %d gsheet rows -> %s" % (len(full), sorted(full)))
    print("index-linked    : %d" % (len(gs2idx) + len(cov2idx)))
    print("never indexed   : %d" % sum(1 for r in rows if r["blocker"] == "source-unread"))
    print("wrote %s and %s" % (JSON_PATH.name, HTML_PATH.name))
    return 0


if __name__ == "__main__":
    sys.exit(main())
