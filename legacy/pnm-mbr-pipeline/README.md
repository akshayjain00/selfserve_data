# Legacy PnM MBR pipeline — `PNM-S-038`

**This is NOT the current validated automation. Do not cite it as such.**

Recovered on 2026-08-28 from an untracked stray folder at `~/dev/selfserve/pnm/`, where it was the only
copy on this laptop and existed nowhere in git history. It is committed here so it can be cited and so
the ⚠ VERIFY flags that trace back to it stop being uncitable.

## What it is

The five-file MBR pipeline plus its `requirements.txt`. `queries.py` (387 lines) defines the **legacy**
query set:

    CREATE_STG_LEADS   CREATE_STG_ORDERS   QUERY_LEADS   QUERY_ORDERS
    QUERY_OTA          QUERY_TPO           QUERY_ORDER_EDITS

Ruling **D3** established that this set could never execute.

## What it is not

It contains **zero** occurrences of the four query names used by the current validated automation —
`LEADS_CONVERSION_QUERY`, `TPO_TREND_QUERY`, `TRIP_DURATION_PERCENTILE_QUERY`, `EDIT_ADOPTION_QUERY`.
Verified by `grep -c`, all four return 0.

**Finding this file does NOT close `PNM-G-003` or `PNM-G-006`.** Those gaps concern the *current*
automation, which is not present anywhere on this machine. A blind check across 56,121 candidate files
found 21 files that *mention* the four current names — all in comments and prose in
`pnm-selfserve/selfserve_nlq/`, which mirrors the automation rather than containing it — and **zero**
files that define one.

If you re-run that search, use `find -print0 | xargs -0`. The naive `grep $(cat filelist)` form exceeds
the argument limit and exits with no output, which reads as "nothing found" when it means "nothing
searched".

## Contents

| path | note |
|---|---|
| `queries.py` `config.py` `runner.py` `validator.py` `gsheet_client.py` `requirements.txt` | the pipeline itself |
| `diagrams/` | `pnm-self-serve-nlq-architecture` as `.mmd`, `.svg`, `.png` |
| `sketches/` | `v-a/b/c.png` render variants and the `.planning/sketches/` answer-surface prototype |
