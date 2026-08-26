# Message to card owners — PTL dashboard defects (2026-07-30)

*Drafted for the owner to send. Covers KB gaps `G-137` (inert filters) and `G-018` (pruning
anti-pattern), combined into one note because the affected cards almost certainly share owners.
Both gaps remain OPEN and marked ESCALATED in `kb/GAPS.md` — the KB warnings stand until a fix
lands. See `DECISIONS.md` D-031.*

---

**Subject: PTL dashboards — 3 cards where filters silently don't work (+ 2 full-scan queries)**

Hi — while mapping PTL metric definitions against the underlying SQL, I found three cards whose
filter widgets don't actually affect the query. These return plausible-looking numbers for the
wrong period, with no error, so anyone using them is likely reading the wrong answer without
knowing it.

## 1. Date filters that do nothing

| Card | Problem |
|---|---|
| **47540** (PTL Batching Opportunity) | Exposes Start/End Date, but the SQL hardcodes `pickup_date >= '2026-02-01'`. The `{{start_date}}` / `{{end_date}}` references exist only inside a commented-out block. |
| **48449** (…City Wise) | Same hardcoded `pickup_date >= '2026-02-01'`. **Also** hardcodes `pickup_city IN ('Bangalore','Mumbai')` in the SQL despite being titled "City Wise" and exposing no city parameter — so it silently only ever covers two cities. |
| **49365** | Outer date filters do work, but the `completed_orders` CTE hardcodes `>= '2026-03-01'`. Any start date before March 2026 returns **empty results rather than an error**. |

**Impact:** set a date range on 47540/48449 and you get Feb-2026→today regardless. On 49365 you get
a blank chart that looks like "no data" rather than "your filter was ignored."

## 2. Two queries doing full table scans

- **33706** (AOV/revenue) uses `date(updated_at + interval '330 mins')` as its **primary** date predicate.
- **33519** (Ops - Orders Details) has the same pattern in one optional filter:
  `DATE(pickup_slot_start + INTERVAL '330 minutes') = {{pickup_date}}`.

Wrapping a timestamp column in an expression inside `WHERE` prevents Snowflake micro-partition
pruning, forcing a full scan. The fix is to keep the column bare and shift the *bound* instead:

```sql
-- instead of:  DATE(ts + INTERVAL '330 minutes') = {{d}}
-- use:         ts >= DATEADD('minute', -330, {{d}}::timestamp_ntz)
--              AND ts <  DATEADD('minute', -330, DATEADD('day', 1, {{d}})::timestamp_ntz)
```

Worth noting 33519 already carries a `-- KEY FIX: UTC range enables micro-partition pruning`
comment on its main predicate — so the correct pattern is right there in the same card.

Happy to walk through any of these. No rush on the full-scan ones; the filter bugs feel more urgent
since they produce wrong answers rather than slow ones.

---

## Follow-up tracking

| Card | Gap | Fixed? | Date | Notes |
|---|---|---|---|---|
| 47540 | `G-137` | ☐ | | |
| 48449 | `G-137` | ☐ | | date + hardcoded city |
| 49365 | `G-137` | ☐ | | |
| 33706 | `G-018` | ☐ | | primary predicate |
| 33519 | `G-018` | ☐ | | optional filter only |

**When a card is fixed:** close its `G-###` row in `kb/GAPS.md` with the date and the fixing card
version — **do not delete the row.** A deleted gap loses the record that the trap ever existed,
which is precisely what a future session needs when a number looks wrong.
