# PnM Self-Serve NL Query Layer — v0 (iteration 2)

Prototype that answers **one catalog metric question at a time** against the same
Snowflake logic as the weekly PnM MBR pipeline — without the weekly run, the staging-table
writes, or the Google Sheet round-trip.

## How it works (three layers)

1. **`metrics_registry.py`** — the menu. Every queryable metric with its definition,
   section, verbatim ⚠ VERIFY flags, quirks, and section readiness
   (`prototype_only | stakeholder_ready | blocked | not_built`). Only the owner
   promotes anything to `stakeholder_ready`, by editing this file deliberately.
2. **`sqlgen.py` + `ask.py`** — the kitchen. One deterministic, read-only SELECT per
   section, staging logic inlined as CTEs (adapted from `queries.py` — see the module
   docstring for the three deliberate adaptations). **Dry-run is the default**: without
   `--execute` the tool prints the exact SQL and stops. The SQL shown is byte-for-byte
   the SQL that runs.
3. **The Claude session** — the waiter. Maps plain English to a metric id using the
   registry (`--list`), calls `ask.py`, narrates the answer with its trust footer.
   The AI never authors SQL; credentials are only exercised inside `ask.py --execute`.

## Fidelity stance

Bug-for-bug replication of the pipeline's semantics — including the staging-window
population quirks and attribution undercount — so answers reconcile with the MBR sheet.
Quirks are disclosed in every answer's footer, never silently fixed. Definition changes
are the owner's call.

## Sections in v0

| Section | Status |
|---|---|
| leads | built — prototype_only |
| orders | built — prototype_only |
| derived (conversion + order mix) | built — prototype_only |
| tpo | built — prototype_only |
| ota | **blocked** — query references columns the staging table never materializes |
| p80_durations | not built (iteration 3) |
| order_edits | not built (iteration 3) |

## Usage

```bash
python ask.py --list
python ask.py --metric tpo_overall --month 2026-05            # dry-run: SQL + footer only
python ask.py --metric tpo_overall --month 2026-05 --execute  # single read-only SELECT
python ask.py --question "tickets per order in may" --month 2026-05
python run_tests.py                                           # dry-run test suite + rendered SQL
```

`--execute` needs `SF_ACCOUNT`, `SF_USER`, `SF_PASSWORD` (and optionally
`SF_WAREHOUSE/SF_DATABASE/SF_SCHEMA/SF_ROLE`) — the same env vars `config.py` uses.
Executed answers are appended to `answers_log/answers.jsonl` (question, SQL, result,
readiness at time of answer).

## Dependencies

None beyond the Python standard library for dry-run. `--execute` lazily imports
`snowflake-connector-python` (already a dependency of the existing pipeline). No pandas.

## What v0 refuses, by design

Anything not on the menu: uncataloged metrics, new dimensions (city, vendor), new grains
(weekly, daily), medians/percentiles not in the registry, future months, blocked or
unbuilt sections. Refusal beats improvisation for MBR-grade numbers.
