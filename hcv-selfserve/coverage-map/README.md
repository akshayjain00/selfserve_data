# coverage-map — a derived projection, **not** a source of truth

`metric-coverage.json` (118 rows) + `coverage-map.html` + `derive.py`. Merged here 2026-08-18 from
the `hcv_selfserve` (underscore) directory in a third clone — see `../kb-build/DECISIONS.md` `D-028`.
**Re-derived from the KB 2026-08-27.**

## Never edit this directory by hand

It is a projection of `../kb/`. To change what it says, **fix the KB and re-run the generator**:

```
python3 hcv-selfserve/coverage-map/derive.py            # rewrite json + html
python3 hcv-selfserve/coverage-map/derive.py --check     # exit 1 on drift
```

`derive.py` sets `status`, `blocker`, `blocker_note`, `source`, `resolves_to`, `kb_row` and
`north_star` from `../kb/metrics.md` §1+§2. It deliberately does **not** touch the descriptive
fields (`name`, `level`, `type`, `domain`, `system`, `classification`, `argus_phase`,
`cross_thread`, `path`) — those are a faithful transcription of the Argus DD and re-deriving them
would risk drift for no gain.

## What its coverage fields say now

| status | n | means |
|---|---|---|
| `partial` | **6** | a full `M-###` entry retires this identity — formula, verbatim SQL, provenance. Open disputes remain |
| `pending` · `blocker: promotion` | **92** | indexed in `metrics.md` §2; awaiting promotion to a full entry |
| `pending` · `blocker: source-unread` | **20** | in the Argus DD, never indexed by this KB → `../kb/GAPS.md` `G-101` |

`north_star` is `Fulfilment % (M-001)`, by owner ruling (`D-011`, `OWNER:2026-08-14`). The page
treats `north_star` as a vertical-level attribute — it reads the first row's value — so it is set
uniformly on all 118 rows.

This replaces the uniform `status: pending` / `blocker: not-started` / `north_star: null` stamp that
`~~G-082~~` recorded as factually wrong.

## Row identity and the source it actually came from

**`HCV-NNN` is row *NNN* of `ProdOps/01_reference_readonly/migrated_context/HCV_Metrics_DD.csv`**
(header = line 1, so data row *NNN* is file line *NNN*+1).

⚠️ **All 118 rows used to cite `ProdOps/02_specs_plans_logs/specs/2026-08-07-hcv-metric-mapping-design.md:17`.**
That line is three sentences *about* the CSV and contains none of the 118 rows. → `G-083`

⚠️ **This file is the same artifact as `gsheet:HCV_Metrics_DD`, not a fourth source.** The KB counted
that sheet at 90 rows; it has 118. → **`G-100`**, which is an open owner decision, and `G-101`.

## What was harvested into the KB

1. **8 new customer/demand-side identities** — `HCV-103`, `104`, `105`, `106`, `107`, `110`, `113`,
   `115` → `metrics.md` §2 rows 100–107. These are CSV rows 103–115, i.e. beyond the row-90 window
   the 2026-08-14 build read — which is why they looked like a new surface.
2. **Thread ownership for 31 metrics** — LFC 20 · Core Platforms 7 · Marketplace 3 · Finance 1 →
   `metrics.md` §2d. Carried by the Argus DD's own `Rightful Thread owning the metric` column, which
   no Notion inventory has; the `Finance` value is reachable only from rows 91–118.

   ⚠️ **This JSON says 30 / Core Platforms 6.** Its `cross_thread` cell for `HCV-004` (`L4 Tickets`)
   is wrong — the six short rows of `G-079` are misaligned by two columns, so the owner sits at cell
   index 23 there and 24 elsewhere, and reading 24 uniformly drops it. `derive.py` does not touch
   descriptive fields, so this must be fixed at source. → **`G-103`**

Coverage itself lives in [`../kb/metrics.md`](../kb/metrics.md) — §1 (12 full entries) and §2 (107
index rows). Read it there, not here.
