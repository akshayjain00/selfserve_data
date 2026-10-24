# PNM Leadership Digest — Rules & Notes Reference

## Report policy
- **report_date = yesterday, always.** Never live/today (CORE-layer sync lag means "today" is
  structurally incomplete — confirmed early in this project: ~6% of same-day raw orders show
  up in CORE at query time).
- Current state: report_date = **2026-09-28** (a Monday). WTD-this = Mon 28 only; WTD-last = Mon 21 only
  (same weekday, like-for-like — user's choice). **WTD-this is not colour-coded anywhere** for this single-day
  refresh (user instruction); a banner at the top of the page says so.
  **Instead, for this refresh only, every non-Key table colours MTD-this vs 6mo avg** (same directions, ±5%/±20%
  bands, CX vendor buckets included; CX RAG pills = MTD vs 6mo, Amber if worse). Leads/Orders volume rows keep
  MTD vs MTD-last, any drop = Amber (±10% band removed 12 Oct). na rows stay grey; Trip Duration + fare-increase stay neutral h3 with delta.
- MTD-this = 1st of month through report_date. MTD-last = same day-range, prior month.
- **3m avg / 6m avg (user decision 30 Sep, replaces the 26-week median):** simple mean of the previous 3 / 6 months,
  each month taken over the SAME days as the current MTD (day 1..report day, clipped to month length). Rates = mean of
  the monthly rates; counts = mean of the monthly same-days counts. Applies to the whole page incl. RAG and City×BHK
  own-cell baselines.
- **Update 6 Oct (user): displayed 3m/6m avg columns = mean of FULL calendar months** (3m = last 3 complete months,
  6m = last 6; e.g. for report 5 Oct: Jul–Sep and Apr–Sep). **Colouring still uses the same-days averages above**
  (MTD/WTD vs same-days 6m avg, and City×BHK grids vs same-days 6m avg). SQL emits both: b6/b3 (same days) and fb6/fb3
  (full months) as fields 5/6 and 9/10 of each record. Hover on coloured cells shows the same-days colour basis.
- **Nano filter toggle (user decision 12 Oct):** the page has a 3-way toggle at the top: Nano excluded (default view) / All orders (Nano included) / Nano only.
  Every metric follows it EXCEPT Leads and Conversion, which are always overall (leads are created before a package exists) and carry an
  "Overall · Nano filter n/a" tag (Key Metrics, Leads & Orders, Leads-by-city, City trends). Booked Orders and % Orders by channel follow the toggle.
  The old "Booked Orders (Nano excluded)" row is gone (the toggle replaces it). Test users stay excluded in every view.
  Each source keeps its own Nano flag (is_nano_order or package_name ILIKE 'Nano%' / '%Nano%'); SQL templates mark it as {{NANO:<expr>}}.
- **Nano only view (user 12 Oct):** rows and columns with no data at all are hidden (compose.py prune_empty): City×BHK shows only the Nano/Micro column, Tier 2 (no Nano orders) drops out of grids and City trends, and vendor buckets empty in every column drop. Partly-empty rows keep a dash in the empty cells.
- **Volume colour (user 12 Oct, everywhere):** ANY drop vs last month is Amber for Leads and Orders: Key Metrics, Leads & Orders table and the City×BHK Orders grid. The old ±10% band is removed (up = green, h5 from +20%; down = amber, h1 from -20%). Rate rows too (user 12 Oct): the ±5% neutral band is removed everywhere (tables, CX buckets, City×BHK, City trends) — any worsening = Amber (h2, h1 beyond -20%), at-or-better = Green (h4, h5 beyond +20%). Unchanged: no-direction rows stay grey; Trip Duration and fare-increase rows stay neutral with a delta.
- **Column dates (user 12 Oct):** every table with the 7 period columns shows that column's date range on a second line of the header (e.g. This week (WTD) / 5–8 Oct, 3m avg / Jul–Sep), computed from periods.py each run.
- **Column order everywhere (user, 30 Sep):** This week (WTD) | Last week (WTD, same weekdays) | Last week (full Mon–Sun) | This month (MTD) | Last month (same days) | 3m avg | 6m avg
  — both last-week columns on every table (user, 30 Sep).
- Key Metrics now has all six columns (colour still This month vs Last month) and includes **Social Media Escalation %**
  (grey, no RAG) — it also stays in Escalations & Damage.

## Format on the page (current convention)
- **No separate "RAG" column anywhere.** The color lives directly in whichever column drives
  that table's comparison:
  - **Key Metrics table**: color in **MTD-this** (MTD-this vs MTD-last, ±10% tolerance band,
    5-level heat scale using ±10%/±20% thresholds instead of the usual ±5%/±20%).
  - **Every other table**: color in **WTD-this** (WTD-this vs 6-month avg, no tolerance,
    ±5%/±20% thresholds).
  - Cell shows the value, a small delta% underneath (for volume/delta-style rows), and the
    full 6-month-avg or MTD-last figure on hover (`title` attribute).
  - Row gets a colored left-edge stripe (CSS `:has()` selector keys off the cell's heat class —
    no per-row class needed to be added by hand).
- **5-level heat scale**, amplified to medium intensity on 09-29 (override block at end of <style>: h1 #E3A9A0, h2 #F6D3A8, h3 #EEF0EE, h4 #BFE0CF, h5 #7FC4A4). Originally muted/tinted:
  h1 (deep bad, dusty red-brown) / h2 (mild bad, amber tint) / h3 (neutral, grey) /
  h4 (mild good, green tint) / h5 (deep good, dusty green) — see CSS `.hcell.h1`–`.h5` in the HTML.
- **Neutral/no-direction metrics** get `hna` (grey, no color claim) — never forced into a
  green/amber reading. Applies to: % orders with surge (mixes +ve/-ve), Social Media
  Escalation % (counts too thin), % Orders by channel (mix share, no inherent direction),
  Trip Duration stages and fare-increase metrics (explicitly told: no color, plain delta only).
- City×BHK heatmap: same 5-level scale, but compared against **that cell's own** 6-month
  trailing average, not the network-wide figure. Thin cells (<30 orders MTD in that
  city×BHK combo) get reduced opacity + a trailing marker — visual de-emphasis, not exclusion.

## Scope & Nano policy (per group — NOT uniform across the page)
| Group | Nano policy |
|---|---|
| Leads & Orders | **Included** — only exception to the exclude-by-default rule |
| Pricing | Excluded (fare-increase metrics fixed to exclude Nano on 09-28 — earlier page wrongly included it) |
| Allocation & Completion | Excluded on **all** metrics (is_nano_order=0 AND is_test_user=0) — user decision 30 Sep |
| Trip Duration | Excluded |
| Edits & Add-ons | Excluded (Add-on Adoption % specifically has no Nano filter in its query — uses whole intra_city population) |
| Customer Experience | Excluded |
| Fulfillment Timing | Excluded |
| Escalations & Damage | Excluded — escalation/damage tickets counted only when the CRN is a non-Nano order (30 Sep) |
| City×BHK | Varies by metric — Orders booked is Nano-inclusive (matches Leads&Orders); everything else Nano-excluded |

All groups: **Intra-city only.** Rule since 30 Sep: **Nano excluded everywhere except Leads & Orders** (Leads, Orders, Conversion, channel mix) and City×BHK Orders booked.

## Metric direction reference (higher/lower-is-better, or no direction)
- **Higher-better**: Leads (all), Conversion % (all), Booked Orders (both variants), AOV,
  % orders +ve surge (contributes to revenue), Allocation % (Overall/SPOT/Scheduled), Completion %
  (all variants), Overall Add-on Adoption %, Overall Completion Score, Overall NPS,
  On Time Arrival %.
- **Lower-better**: % orders -ve surge, Deallocation % (all variants), Dry Run P75, CAC/PAC/PoAC
  (SPOT/Scheduled), Allocation Time P80, % no vendor before slot, Reschedule %, % orders >2
  deallocations, % supervisor changed, Pickup/Drop Deviation P80, % orders edited (wide
  tolerance — soft signal, no hard threshold defined), % support-edited, % edits after
  shifting started, % orders where location modified (widest tolerance in its group),
  Overall Detractors %, TPO — Overall, Cancellation % (=CAC+PAC+PoAC combined), Damage %.
- **No direction (na)**: % orders with surge (mixes both), % Orders by channel (App/Website/LMS
  — mix share), Social Media Escalation % (counts too thin for any color), Trip Duration
  (all 6 stages — plain delta only, no color), fare-increase metrics (plain delta only).

## Known findings & caveats (don't re-litigate these — they're settled)
1. **-ve surge's 6-month baseline is artificially low.** Confirmed via raw distribution:
   early August had zero negative-surge orders (every booking_surge_multiplier ≥ 1.0).
   Discounting is a relatively new behavior; any metric tied to something recently launched
   will show this same distortion — check "did this exist 6 months ago" before trusting a
   6mo-avg comparison for a new behavior.
2. **Vendor Accepted → Supervisor Assigned (Trip Duration S1) is genuinely bimodal, not
   broken.** ~32% get a supervisor within an hour, ~30% take a day+. Consistent with
   Scheduled/advance-booked orders where vendors accept days before the actual shift.
3. **Add-on Adoption % (~87-98%) is real, not a defaulting bug.** Only ~17% of orders have
   a genuinely empty ADD_ONS field; basic packing is near-default for this service, not a
   rare upsell.
4. **On Time Arrival % / Delay >60min definitions use Card #37409** — the authoritative
   source, provided directly rather than self-built. Supersedes an earlier, simpler
   `PNM_SUPPORT.ON_TIME_ARRIVAL_FLAG`-based version. "On time" requires BOTH arriving within
   30 min of scheduled shift time AND within 2km GPS proximity of the pickup location.
5. **Delay >60min has NO pre-built source** — earlier claim that it existed in
   `PNM_ALLOCATION` was checked and found wrong. Only buildable via the Card #37409
   GPS+timing join.
6. **DIM_PNM_VENDOR.BUCKET_TYPE requires a point-in-time join** (BUCKET_START_DATE/
   BUCKET_END_DATE, up to 27 historical rows per vendor) and is fan-out-prone if joined
   naively. `PNM_EXPERIENCE.VENDOR_BUCKET_TYPE` avoids this entirely — already point-in-time
   correct, no join needed. Use that column, not a join to DIM_PNM_VENDOR.
7. **NPS declines / Detractors % rises monotonically with BHK size**, across nearly every
   city — a real, consistent pattern the network-wide "Overall NPS" aggregate hides
   entirely. Confirmed stable across two separate refreshes (not a one-period fluke).
8. **City×BHK thin cells produce genuine small-sample artifacts** — e.g. a 4+BHK cell in a
   smaller city can show NPS = -100.00 off literally 1-2 rated orders. Always check the
   underlying order count (Orders grid) before trusting an extreme cell value anywhere in
   this section.
9. **Escalations & Damage is new, not yet independently cross-validated** the way earlier
   metrics were. Social Media Escalation % carries no RAG on principle (counts too thin —
   3-10/month, 3-4/week network-wide); Damage % does get RAG (MTD volume 40-70 supports it)
   but WTD volume (5-22) is still modest.
10. **Cross-validation signals found along the way** (worth citing if anyone questions the
    pipeline): Vendor TPO (Group 7) and Vendor-raised TPO (Group 8) — two independently
    written queries — landed within 0.02 of each other. City-level Leads/Orders sums exactly
    match the network-wide MTD totals, every refresh.

## Reference wireframe inspiration (from manager's HCV VP digest mock)
- **Own-baseline deviation banding** — cells compared against their OWN historical baseline
  (not one global cutoff), using MAD over a shorter regime-stable window rather than a
  blunt average. City×BHK uses a simpler version of this (own-cell 6mo avg) but NOT the
  full MAD/regime-window sophistication — **explicitly deferred, "will do later."**
- **Footnotes generated from a single source-of-truth rules object, dynamically** — DONE.
  See `RAG_RULES` JS array in the HTML `<script>` block: it drives the Rules Register table,
  the fold-button's "N metrics" count, the two-basis intro sentence, AND several inline
  callouts (Pricing's -ve surge note, Edits & Add-ons' tolerance note) via JS lookup —
  not duplicated prose. If a rule changes, change it once in `RAG_RULES`.
- Cheap wins also done: horizontal scroll wrappers on every wide table, an orientation box
  under the header (What this is / Who it's for / What to do / Status), and the
  Orders = Leads × Conversion identity block (no longer a separate visual block — now 3
  plain rows in the Key Metrics table, per later instruction).
- NOT adopted: the wireframe's visual styling (hazard bands, inline ID-annotation tags) —
  that's explicitly review-tooling for a different process, not appropriate for this
  production digest.

## Key Metrics colouring as the page actually runs it
- Volume rows (Orders, Leads): Green if at/above MTD-last, Amber on any drop (12 Oct; was: Amber only beyond -10%). % rows: Green if at/better than MTD-last,
  Amber if worse. Only h4/h2 used (the ±10%/±20% 5-level scale described above is not what this table does).

## Still open / not yet built
- **Vendor Ops** and **Acquisition** groups — never started.
- **~13 metrics with no source anywhere in the pipeline** (checked, genuinely absent):
  L4 Tickets, P90 L4 Resolution Time, Users landing to PnM page, Activation, Frequency,
  Weekend contribution by bucket, Face match success rate, % orders with no images uploaded.
- **Out of scope per direct instruction**: Conversion % — Overall (1hr window), Completed
  orders by bucket.
- **Considered covered, not separately built**: Vendors distribution by bucket (via the
  Customer Experience bucket breakdowns).
- Own-baseline MAD/regime-window banding (see wireframe inspiration above) — deferred.
- Edit-metric tolerance ("wide"/"widest") has no actual numeric threshold defined — applied
  qualitatively only. Worth a real number before this ships as-is.

## Structural gotchas hit during this build (avoid repeating)
- Regex-based table-swap patches on collapsible `<details>` blocks are fragile when two
  sections share identical header text (e.g. "Overall NPS" exists in both Customer
  Experience and City×BHK) — a `.search()` can silently patch the WRONG occurrence. Always
  verify tag-count balance (`div`, `table`, `details`, `span`, `p`, `tr`, `td`, `th` — open
  count must equal close count) after ANY regex-based HTML surgery, and spot-check the
  actual rendered section, not just that the script reported success.
- A blanket "remove dead CSS" pass once accidentally swept up CSS that other sections
  actually depended on (`.scroll`, `.metric-table`, `.rules-table`, `.exp-metric-header`,
  `.bucket-detail`, `.heatlegend`, `.hcell` all got deleted in one bad edit). Verify by
  grepping for the specific class definitions before/after any bulk CSS removal, not just
  by checking the page "looks fine" at a glance.
- `CASE ... source_details ... source ...` channel-grouping logic and the city/BHK CASE
  expressions are copy-pasted across many queries — if the grouping rule ever changes, it
  needs to change in every copy (no single source of truth for these SQL-side groupings,
  unlike the JS-side `RAG_RULES`).


## 1 Oct changes
- Page is now **metrics-only**: orientation boxes, all notes/status/scope lines and the footer are stripped at build time (build_html.py, 'Minimal-text layout'). Kept: titles, headers, legends, a one-line definitions strip under the header, the collapsed RAG rules register.
- New **City trends — weekly** section right below Key Metrics: 11 Key Metrics (all except Social Media Escalation %) × Network + 9 cities × last 13 full weeks, cells tinted vs that row's own 13-week mean (±5%/±20%, same directions), sparkline per row. Source: sql/14*_cw_*.sql, builder city_trend.py.
