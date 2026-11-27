---
name: hcv-intracity-ops-report
description: Daily HCV intracity ops report for Porter (9ft and above, Tier 1). One self-contained HTML page answering how yesterday went and how the week and month are going. Use to re-run the report, or to change a metric, cut or window in it.
---

```text
What this is:      How to re-run and maintain the HCV intracity ops report pipeline.
Who it's for:      An agent or analyst re-running the report; assumes Snowflake access, not knowledge of this code.
What to do with it: Follow "Run it" top to bottom; read "Rules" before changing anything.
Status:            reviewed
```

# HCV intracity ops report

**Start here:** this file. Decisions and their reasons are in
[coordination/DECISIONS.md](coordination/DECISIONS.md); current state is in
[coordination/BOARD.md](coordination/BOARD.md).

Output: `docs/YYYY-MM-DD-hcv-intracity-ops-report.html` (the date is the run date; data ends the
day before).

## Run it

```bash
cd ~/dev/selfserve/hcv-selfserve/ops-report
python3 gen_sql.py                    # writes sql/*.sql + sql/manifest.json
#   run every sql/*.sql through the Snowflake MCP, ONE AT A TIME
python3 capture_exports.py            # tool output -> inbox/hcv_<name>.json
python3 install_exports.py            # validate against the manifest -> data/
python3 build_report.py               # -> docs/<run-date>-hcv-intracity-ops-report.html
python3 test_pipeline.py              # 21 tests; run after any code change
```

`gen_sql.py --target-date YYYY-MM-DD` re-creates a past run (the target date is the run date).

### Running the queries

A normal run is **5 queries**: `daily_orders_1..3`, `daily_dap`, `period_alloc`. Paste each
file's text into `mcp__claude_ai_Snowflake__sql-exec` exactly as written. Run them one at a time.
If neither the Snowflake nor the Metabase connector is live, stop and tell the owner.

Each query stamps a run tag into a column **name** (`TAG__<query>__<analysis_end>`). That tag is
how a result is found and how a stale one is refused, so never edit it out.

### Getting results onto disk (`capture_exports.py`)

The Snowflake MCP returns results into the agent's tool output, and no local Snowflake client is
installed. Claude Code then stores a result by size:

| Result size | Where it lands |
|---|---|
| over roughly 100 KB | a file under `~/.claude/projects/<project>/<session>/tool-results/` |
| 4 KB up to that | the context-mode capture store, `~/.context-mode/projects/<id>/context.db` |
| under 4 KB | inline in the conversation only |

`capture_exports.py` searches the first two for each tag and writes the newest complete result to
`inbox/`. All five exports are larger than 4 KB. In a harness without these stores, save each
query's JSON response as `inbox/hcv_<name>.json` by any means; `install_exports.py` validates it
the same way.

**The MCP truncates a result at about 468 KB** and says so only in an `execution_status` field.
Measured 2026-11-27: the un-chunked order facts returned 4,079 of 4,274 rows. `daily_orders` is
therefore split into 20-day chunks (`ORDERS_CHUNK_DAYS` in `hcvlib.py`), and every loader refuses
a result whose row count differs from Snowflake's `numRows`. If a chunk is refused for that
reason, lower `ORDERS_CHUNK_DAYS`.

### What `install_exports.py` checks

Nothing reaches `data/` unless every export passes. It refuses an export that is missing, empty,
truncated, carrying another run's tag, missing a required column, or failing a conservation rule:
`N_ROWS == DEMAND` per cell (no join fan-out), `CBDF_SO + CBDF_MO == CBDF`, CADF splits ≤ CADF,
every date of the range present, every window present, one row per key. A missing newest DAP day
is a warning, not a refusal, because that mart can land late.

## What the report contains

| Section | Content |
|---|---|
| Headline | Demand, Fulfilment %, Revenue for yesterday, week to date, month to date |
| Scorecard | all 15 metric rows × 3 windows, each beside its comparison and the change |
| By vehicle / order type / city | one table per cut, tabs for the three windows, Tier 1 total row |
| Last 14 days | Tier 1 total by day |
| Definitions | every metric as computed, including where the KB disagrees |

Windows (period math copied from the reference pipeline's `Periods`):

| Window | Compared against |
|---|---|
| Yesterday (D-1) | mean of the last 4 same weekdays |
| Week to date, Monday start | last week, cut to the same number of days |
| Month to date | last month, cut to the same day of the month |

## Architecture

- **Composable sums** (`daily_orders_*`, `daily_dap`): pulled once at date × city ×
  vehicle_mapping × order_type (DAP: date × city × vehicle_mapping) and summed into every window
  and cut in Python (`metrics.Cube`). A new window costs no query.
- **Non-composable** (`period_alloc`): allocation-time P50/P90 are computed in SQL for every
  window × one-way cut. Each order is fanned into every window it belongs to through an inlined
  `(period, start, n_days)` spine; cuts come from `GROUPING SETS`.
- **Rendering**: `build_report.py` formats every figure from `data/`. The page has no JavaScript;
  tabs are CSS radios, and printing expands every pane.

| File | Role |
|---|---|
| `hcvlib.py` | windows, SQL builders, export parsing |
| `gen_sql.py` | writes `sql/` and the manifest |
| `capture_exports.py` | tool output → `inbox/` (harness-specific) |
| `install_exports.py` | validation → `data/` |
| `metrics.py` | metric cube, definitions, deltas |
| `build_report.py` | HTML |
| `reconcile.py` | report vs dashboard 6406 card SQL for one week |
| `test_pipeline.py` | tests |

`sql/`, `inbox/` and `data/` are git-ignored; they are regenerated every run.

## Rules (do not regress)

| Rule | Why |
|---|---|
| Definitions come from the `hcv-data` skill, not the HCV KB | Owner instruction. Fulfilment % = Completed ÷ Demand; the KB's G-030/G-031 objection is printed in Definitions, not applied. Ask before changing any definition. |
| Intracity = `lower(dim_vehicles.serviceability_segment) = 'vanilla'` | Owner's Gate-0 pick (D-002). Same field as dashboard 6406's Serviceability Segment filter. |
| Every % is over Demand | Card 55586 uses `div0(x, Demand)` for Allocation, FF, CADF and CBDF. |
| Never build a total by adding vehicle categories | KB T-024: HCV category dimensions can overlap. Here each order has exactly one `vehicle_mapping`, the export is a partition, and the installer proves it with `N_ROWS == DEMAND`. |
| Dedup `dim_cancel_reasons_attribution` before joining | It is keyed on `ID`, not `CANCEL_REASON_ID`; a raw join can fan out. |
| Stockout / Missed order uses the two PROD matchmaking marts only | hcv-data's definition. Card 55612 also reads a DEV sandbox table (D-005). |
| A percentile on fewer than 30 accepted orders is blank | `P_MIN_N` in `metrics.py`; a P90 from a handful of orders looks like a normal number. |
| DAP is averaged over days that have DAP rows | A window missing its newest day would otherwise read low. |
| Blank is not zero | A cell with no denominator renders empty. `build_report.py` refuses to write a page containing `None` or `nan`. |
| Order-type and city keys carry no spaces in the exports | The mid-size capture path rebuilds a result from 4 KB chunks; codes keep that exact. |

Out of scope by owner decision: the 3-year trend cache, QTD and LQER windows, AOP vs plan, Rapido
pricing, festive targets, rain, EFF drivers, the board report, and any LFC category. Ask before
adding a metric, cut or window, installing a dependency, pushing to `main`, opening a PR, or
sharing the report.

## Reconciling against dashboard 6406

`reconcile.py <start> <end>` compares the report with the dashboard's own card SQL for one week.
The card side is produced by executing each card's **stored** SQL with the template tags
substituted, so no card logic is copied by hand:

```sql
EXECUTE IMMEDIATE $$
DECLARE q STRING; rs RESULTSET;
BEGIN
  SELECT MAX(TRY_PARSE_JSON(dataset_query):stages[0]:native::string) INTO :q
  FROM PROD_ELDORIA.CORE.FACT_MB_CARDS WHERE card_id = 55586;          -- 55587 for revenue
  q := REPLACE(REPLACE(REPLACE(q, '{{start_date}}', '''2026-11-16'''),
               '{{end_date}}', '''2026-11-22'''), '{{period}}', '''week''');
  q := REGEXP_REPLACE(q, '\\[\\[\\s*and\\s*\\{\\{(vehicle_id|vehicle_mapping|city_name)\\}\\}\\s*\\]\\]', '', 1, 0, 'i');
  q := REGEXP_REPLACE(q, '\\[\\[\\s*and\\s*\\{\\{serviceability_segment\\}\\}\\s*\\]\\]',
                      'and vv.serviceability_segment = ''Vanilla''', 1, 0, 'i');
  q := REGEXP_REPLACE(q, '\\[\\[\\s*and\\s*\\{\\{Tier\\}\\}\\s*\\]\\]', 'and gg.tier = ''Tier 1''', 1, 0, 'i');
  q := REGEXP_REPLACE(q, ';\\s*$', '');
  rs := (EXECUTE IMMEDIATE :q);
  RETURN TABLE(rs);
END;
$$
```

Card 55586 aliases the dimensions `vv` / `gg`. Card 55587 does not alias them, so substitute
`prod_eldoria.core.dim_vehicles.serviceability_segment` and
`prod_eldoria.core.dim_geo_regions.tier` there. Save each response verbatim as
`docs/reconciliation/card_<id>_<start>_<end>.json`, then run `reconcile.py`.

Result for 2026-11-16 to 2026-11-22 is in
[docs/2026-11-27-reconciliation-dashboard-6406.md](docs/2026-11-27-reconciliation-dashboard-6406.md).
Demand and Fulfilment % tie exactly to card 55586. Revenue differs from card 55587 because that
card uses a different source and fare field (D-006).

## Reference

Modelled on `~/dev/ops_report_dailydigest` (read-only; never edit or commit there). Reused: the
period math, the composable / non-composable split, the spine fan-out, and install-time
validation. Added here: the run tag, which closes that pipeline's documented blind spot for a
day-stale export with identical period keys.
