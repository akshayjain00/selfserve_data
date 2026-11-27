#!/usr/bin/env python3
"""Lift this run's Snowflake MCP results into inbox/ — the one harness-specific step.

The Snowflake MCP returns results into the agent's tool output, not to disk.
Claude Code then puts a result in one of two places depending on its size:

  * large (roughly > 100 KB): a file under
    ~/.claude/projects/<project>/<session>/tool-results/
  * mid-size (4 KB up to that): the context-mode capture store,
    ~/.context-mode/projects/<id>/context.db, as ordered 4 KB chunks

Every query stamps its run tag into a column name, so a result identifies
itself: this script finds the newest COMPLETE result carrying each tag and
writes it to inbox/hcv_<name>.json. A result that is not valid JSON, or whose
row count differs from Snowflake's numRows, is never written.

Outside this harness, skip this script and save each query's JSON response as
inbox/hcv_<name>.json yourself; install_exports.py validates it the same way.

Usage:
    python3 capture_exports.py [--hours 24]
"""

from __future__ import annotations

import argparse
import json
import pathlib
import sqlite3
import sys
import time

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from hcvlib import ExportError, parse_export  # noqa: E402

HOME = pathlib.Path.home()


def _file_candidates(since: float):
    for f in (HOME / ".claude" / "projects").glob("*/*/tool-results/*sql-exec*.txt"):
        try:
            if f.stat().st_mtime >= since:
                yield f.stat().st_mtime, f"file:{f}", f.read_text()
        except OSError:
            continue


def _ctx_candidates(since: float):
    for db in (HOME / ".context-mode" / "projects").glob("*/context.db"):
        try:
            if db.stat().st_mtime < since:
                continue
            con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
            srcs = con.execute(
                "SELECT id, bytes_total, created_ts FROM sources "
                "WHERE label LIKE '%sql-exec%'").fetchall()
            for sid, nbytes, ts in srcs:
                ts = ts / 1000 if ts > 1e11 else ts
                if ts < since:
                    continue
                body = "".join(b for (b,) in con.execute(
                    "SELECT body FROM chunks WHERE source_id = ? "
                    "ORDER BY CAST(ord AS INTEGER)", (sid,)))
                if len(body.encode()) != nbytes:      # chunks must rebuild exactly
                    continue
                yield ts, f"context-mode:{db.parent.name}#{sid}", body
            con.close()
        except sqlite3.Error:
            continue


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--sql", default=str(HERE / "sql"))
    ap.add_argument("--inbox", default=str(HERE / "inbox"))
    ap.add_argument("--hours", type=float, default=24.0,
                    help="only consider results captured this recently")
    args = ap.parse_args()

    manifest = json.loads((pathlib.Path(args.sql) / "manifest.json").read_text())
    inbox = pathlib.Path(args.inbox)
    inbox.mkdir(parents=True, exist_ok=True)
    since = time.time() - args.hours * 3600

    cands = sorted(list(_file_candidates(since)) + list(_ctx_candidates(since)),
                   key=lambda c: -c[0])
    captured, missing = {}, []
    for name, tag in manifest["tags"].items():
        needle = f'"{tag}"'
        hit = None
        rejected = []
        for ts, where, text in cands:
            if needle not in text:
                continue
            try:
                rows, got = parse_export(text)
            except ExportError as e:
                rejected.append(f"{where}: {e}")
                continue
            if got == tag:
                hit = (where, text, len(rows))
                break
        if hit is None:
            missing.append({"query": name, "rejected": rejected})
            continue
        (inbox / f"hcv_{name}.json").write_text(hit[1])
        captured[name] = {"rows": hit[2], "from": hit[0]}

    print(json.dumps({"captured": captured, "missing": missing}, indent=2))
    if missing:
        sys.exit(1)


if __name__ == "__main__":
    main()
