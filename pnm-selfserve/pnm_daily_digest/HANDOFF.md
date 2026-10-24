# HANDOFF — PNM Leadership Digest

## 1. Goal
An HTML leadership metrics digest for PnM (Packers & Movers) ops leadership at Porter —
daily/refreshable snapshot of ~65+ validated metrics (funnel, pricing, allocation,
experience, timing, escalations) with RAG status, built for Rashmi (data analytics)
to hand to leadership. Report policy: **report_date = yesterday, always** (today's
CORE-layer data is structurally incomplete — confirmed, ~6% sync lag).

## 2. Key decisions (with reasons)
- **RAG lives IN the driving column, not a separate "RAG" column.** Cell gets a tinted
  background (5-level scale h1–h5; originally muted, **amplified to 'medium' intensity on 09-29 per user** via an override CSS block appended at the end of <style> — original rules left in place) matching the City×BHK heatmap
  style, chosen for one consistent visual language across the whole page. Per-user
  instruction, done late — earlier version had a separate RAG column.
- **Two different bases, by table**: Key Metrics table colors **MTD-this** (vs MTD-last,
  ±10% tolerance — chosen because leadership reads MTD as the primary trend). Every
  other table colors **WTD-this** (vs 6-month trailing avg, no tolerance — WTD is noisier
  so needs a longer baseline, not just last week).
- **Nano policy (updated 30 Sep): excluded everywhere except Leads & Orders** (and City×BHK Orders booked). Previously NOT uniform — (that's the one group
  leadership explicitly wants total volume for); excluded everywhere else. Documented
  per-group in `rules-and-notes.md` because it's easy to get backwards.
- **Two customer-experience date bases, deliberately**: Completion Score on
  `SHIFTING_TS_IST`, NPS/Detractors on `ORDER_COMPLETED_TS_IST` — per direct instruction,
  not a bug.
- **On Time Arrival % / Delay>60min use Card #37409's definition** (30min + 2km GPS,
  BOTH required) — supersedes a simpler flag that existed in PNM_SUPPORT. Authoritative
  source, not self-derived.
- **Cancellation % = CAC+PAC+PoAC combined**, built from existing cancellation_type
  values already in PNM_ALLOCATION — chosen because no bespoke "cancellation" field
  existed; reused what was already validated rather than inventing new logic.
- **Social Media Escalation % gets NO color, ever** — counts are 3-10/month network-wide;
  any color would be noise, not signal. Damage % does get colored (40-70/month supports it).
- **City grouping**: Tier-1 cities shown individually (Bangalore, Delhi NCR, Mumbai,
  Hyderabad, Pune, Chennai, Kolkata, Ahmedabad) via `DIM_GEO_REGIONS.TIER`; everything
  else rolled into "Tier 2 (combined)" — chosen so the grid stays 9 rows, not 30+.
- **City×BHK RAG is against each cell's OWN 6-month baseline**, not the network avg —
  chosen because volume varies 100x between cells; a network-wide baseline would flag
  every small city as "bad" regardless of its own normal pattern.

## 3. Current state
**Refreshed 2026-10-23 (scheduled 2 pm IST run) for report_date = 2026-10-22 (Thursday)** — data in `data1022/{all,nn,nano}`. WTD = 19–22 Oct vs 12–15 Oct. City trends window unchanged: 20 Jul – 12 Oct (14e ticket window to 22 Oct).
- QC (all three views): 147 Key Metric values recomputed independently: 0 mismatches. Structural: all = nn + nano in 45 City×BHK cells and 130 city-weeks; Leads/Conversion identical across views; city weekly orders sum to network; verify.py OK x3; toggle test OK. Executed SQL identical to rendered/combined/*.sql (18/18, transcript check).
- `tools/qc_daily_sums_template.sql` now holds the 22 Oct dates.
- Data note (still open): Kolkata week of 12 Oct still 80 orders / 5.0% conversion vs ~290 / ~16% before.
- Delivery: HTML to Rashmi's ~/Downloads (device unreachable 20–22 Oct runs; files delivered in chat); she posts to #hsc-metric-digest herself. Next run self-scheduled for 24 Oct 2 pm IST.

**Refreshed 2026-10-22 (scheduled 2 pm IST run) for report_date = 2026-10-21 (Wednesday)** — data in `data1021/{all,nn,nano}`. WTD = 19–21 Oct vs 12–14 Oct. City trends window unchanged: 20 Jul – 12 Oct (14e ticket window to 21 Oct).
- QC (all three views): 147 Key Metric values recomputed independently: 0 mismatches. Structural: all = nn + nano in 45 City×BHK cells and 130 city-weeks; Leads/Conversion identical across views; city weekly orders sum to network; verify.py OK x3; toggle test OK. Executed SQL identical to rendered/combined/*.sql (18/18, transcript check).
- `tools/qc_daily_sums_template.sql` now holds the 21 Oct dates.
- Data note (still open): Kolkata week of 12 Oct still 80 orders / 5.0% conversion vs ~290 / ~16% before.
- Delivery: HTML to Rashmi's ~/Downloads; she posts to #hsc-metric-digest herself. Next run self-scheduled for 23 Oct 2 pm IST.

**Refreshed 2026-10-21 (scheduled 2 pm IST run) for report_date = 2026-10-20 (Tuesday)** — data in `data1020/{all,nn,nano}`. WTD = 19–20 Oct vs 12–13 Oct. City trends window unchanged: 20 Jul – 12 Oct (14e ticket window to 20 Oct).
- QC (all three views): 147 Key Metric values recomputed independently: 0 mismatches. Structural: all = nn + nano in 45 City×BHK cells and 130 city-weeks; Leads/Conversion identical across views; city weekly orders sum to network; verify.py OK x3; toggle test OK. Executed SQL identical to rendered/combined/*.sql (18/18, transcript check).
- `tools/qc_daily_sums_template.sql` now holds the 20 Oct dates.
- Data note (still open): Kolkata week of 12 Oct still 80 orders / 5.0% conversion vs ~290 / ~16% before.
- Delivery: HTML to Rashmi's ~/Downloads; she posts to #hsc-metric-digest herself. Next run self-scheduled for 22 Oct 2 pm IST.

**Refreshed 2026-10-20 (scheduled 2 pm IST run) for report_date = 2026-10-19 (Monday)** — data in `data1019/{all,nn,nano}`. WTD = Mon 19 Oct only (vs Mon 12 Oct). City trends window unchanged: 20 Jul – 12 Oct (13 full weeks; 14e ticket window to 19 Oct).
- QC (all three views): 147 Key Metric values recomputed independently: 0 mismatches. Structural: all = nn + nano in 45 City×BHK cells and 130 city-weeks; Leads/Conversion identical across views; city weekly orders sum to network; verify.py OK x3; toggle test OK. Executed SQL identical to rendered/combined/*.sql (18/18, transcript check).
- `tools/qc_daily_sums_template.sql` now holds the 19 Oct dates.
- Data note (still open): Kolkata week of 12 Oct shows only 80 orders / 5.0% conversion vs ~290 / ~16% before.
- Delivery: HTML to Rashmi's ~/Downloads; she posts to #hsc-metric-digest herself. Next run self-scheduled for 21 Oct 2 pm IST.

**Refreshed 2026-10-19 (scheduled 2 pm IST run) for report_date = 2026-10-18 (Sunday)** — data in `data1018/{all,nn,nano}`. Colour basis = WTD-this (12–18 Oct, full week) vs same-days 6m avg. City trends window now 20 Jul – 12 Oct (13 full weeks).
- QC (all three views): 147 Key Metric values recomputed independently: 0 mismatches. Structural: all = nn + nano in 45 City×BHK cells and 130 city-weeks; Leads/Conversion identical across views; city weekly orders sum to network; verify.py OK x3; toggle test OK. Executed SQL identical to rendered/combined/*.sql (18/18, checked by hash against Snowflake QUERY_HISTORY because the transcript was compacted mid-run).
- QC daily-sum SQL now kept at `tools/qc_daily_sums_template.sql` (dates for 18 Oct; swap dates each run).
- Data note: Kolkata week of 12 Oct shows only 80 orders / 5.0% conversion (vs ~290 / ~16% prior weeks) — looks like a pickup-geo mapping or data issue; worth checking before reading it as a real drop.
- Delivery: HTML to Rashmi's ~/Downloads; she posts to #hsc-metric-digest herself. Next run self-scheduled for 20 Oct 2 pm IST.

**Refreshed 2026-10-18 (scheduled 2 pm IST run) for report_date = 2026-10-17 (Saturday)** — data in `data1017/{all,nn,nano}`. Colour basis = WTD-this (12–17 Oct) vs same-days 6m avg.
- QC (all three views): 147 Key Metric values recomputed independently: 0 mismatches. Structural: all = nn + nano in 45 City×BHK cells and 130 city-weeks; Leads/Conversion identical across views; city weekly orders sum to network; verify.py OK x3; toggle test OK. Executed SQL identical to rendered/combined/*.sql (18/18).
- Delivery: HTML to Rashmi's ~/Downloads (if computer reachable); she posts to #hsc-metric-digest herself. Next run self-scheduled for 19 Oct 2 pm IST.

**Refreshed 2026-10-17 (scheduled 2 pm IST run) for report_date = 2026-10-16 (Friday)** — data in `data1016/{all,nn,nano}`. Colour basis = WTD-this (12–16 Oct) vs same-days 6m avg.
- QC (all three views): 147 Key Metric values recomputed independently: 0 mismatches. Structural: all = nn + nano in 45 City×BHK cells and 130 city-weeks; Leads/Conversion identical across views; city weekly orders sum to network; verify.py OK x3; toggle test OK. Executed SQL checked identical to rendered/combined/*.sql (18/18).
- Delivery: HTML saved to Rashmi's ~/Downloads; she posts to #hsc-metric-digest herself. Next run self-scheduled for 18 Oct 2 pm IST.

**Refreshed 2026-10-16 (scheduled 2 pm IST run) for report_date = 2026-10-15 (Thursday)** — data in `data1015/{all,nn,nano}`. Colour basis = WTD-this (12–15 Oct) vs same-days 6m avg.
- QC (all three views): 147 Key Metric values recomputed independently: 0 mismatches. Structural: all = nn + nano in 45 City×BHK cells and 130 city-weeks; Leads/Conversion identical across views; city weekly orders sum to network; verify.py OK x3; toggle test OK.
- Delivery: HTML saved to Rashmi's ~/Downloads; she posts to #hsc-metric-digest herself. Next run self-scheduled for 17 Oct 2 pm IST.

**Refreshed 2026-10-15 (scheduled 2 pm IST run) for report_date = 2026-10-14 (Wednesday)** — data in `data1014/{all,nn,nano}`. Colour basis = WTD-this (12–14 Oct) vs same-days 6m avg.
- QC (all three views): 147 Key Metric values recomputed independently: 0 mismatches. Structural: all = nn + nano in 45 City×BHK cells and 130 city-weeks; Leads/Conversion identical across views; city weekly orders sum to network; verify.py OK x3; toggle test OK.
- Delivery: HTML saved to Rashmi's ~/Downloads; she posts to #hsc-metric-digest herself. Next run self-scheduled for 16 Oct 2 pm IST.

**Refreshed 2026-10-14 (scheduled 2 pm IST run) for report_date = 2026-10-13 (Tuesday)** — data in `data1013/{all,nn,nano}`. Colour basis = WTD-this (12–13 Oct) vs same-days 6m avg.
- QC (all three views): 147 Key Metric values recomputed independently: 0 mismatches. Structural: all = nn + nano in 45 City×BHK cells and 130 city-weeks; Leads/Conversion identical across views; city weekly orders sum to network; verify.py OK x3; toggle test OK.
- Delivery: HTML saved to Rashmi's ~/Downloads; she posts it to #hsc-metric-digest herself. Next run self-scheduled for 15 Oct 2 pm IST.

**Refreshed 2026-10-13 for report_date = 2026-10-12 (Monday)** — data in `data1012/{all,nn,nano}`. Single-day WTD columns, so colour basis = MTD-this vs same-days 6m avg.
- City trends window unchanged from 11 Oct (13 full weeks 13 Jul–5 Oct), but re-pulled: late-arriving data had shifted a few values.
- QC (all three views): 147 Key Metric values (5 period columns + 3m/6m full-month averages for 7 metrics) recomputed with a separate daily-sum query: 0 mismatches.
  Structural: all = nn + nano orders in every City×BHK cell (45) and every city-week (130); Leads/Conversion identical across views; city weekly orders sum to network; verify.py OK; toggle test OK, no page errors.
- Note: transcripts rotate when context is compacted, so tools/query_result.py only finds results from the current transcript — save each result right after it runs.

**Refreshed 2026-10-12 for report_date = 2026-10-11 (Sunday)** — first run with the 3-way Nano toggle (data in `data1011/{all,nn,nano}`).
- Queries ran as one call per file returning all 3 segments (combine_sql.py for small ones; hand-compacted 'segs' versions for heavy ones), split with save_result.py.
- City trends now include the current week on Sundays (periods.py CW window = last 13 FULL weeks: 13 Jul - 5 Oct weeks).
- QC (full, all three views): 108 Key Metric values (this week / last week / this month / last month) + 24 monthly 3m/6m averages recomputed with separate simple queries: 0 mismatches.
  Structural: all = nn + nano orders in every period and every City×BHK cell; Leads/Conversion identical across views; city leads/orders sum to network; page cells match data; verify.py OK; toggle test OK.
- Fixes after first build: City trends week list now follows periods.py CW window (was showing empty 6 Jul column, missing 5 Oct); Nano only view hides fully empty rows/columns.
- New helpers: combine_sql.py, save_result.py, tools/query_result.py (see RUNBOOK step 1).

**12 Oct — code updated, not yet run:** 3-way Nano toggle (compose.py + {{NANO:..}} SQL placeholders; leads/conversion overall with a tag),
Key Metrics any-drop-is-Amber for volume rows. Next: run all 18 queries x 3 segments for the next report date, then compose + QC.

**Refreshed 2026-10-09 for report_date = 2026-10-08 (Thursday)** from Snowflake (data in `data1008/`). Colour basis = WTD-this vs same-days 6m avg.
- Independent QC: 77 Key Metrics values (5 period columns + 3m/6m) recomputed with separate queries: all match. TPO ticket windows left as is (user, 9 Oct).

**Refreshed 2026-10-06 for report_date = 2026-10-05 (Monday)** from Snowflake (data in `data1005/`).
- 3m/6m avg columns now show **full calendar-month averages** (Jul–Sep / Apr–Sep); colouring stays on same-days averages (days 1–N).
- Validated by an independent per-month query (Apr–Sep, GROUP BY month) for 11 Key Metrics: all match the page to rounding.
- Watch: Allocation Time P80 same-days 6m avg = 148 min (early-month outlier) -> colours look very green; full-month 6m = 26.

**Refreshed 2026-09-29 for report_date = 2026-09-28 (Monday), everything incl. City×BHK, from Snowflake.**
- **30 Sep:** baselines are now **3m avg + 6m avg = mean of previous months over the same days** (not a weekly median), whole page.
  Column order everywhere: This week (WTD) | Last week (WTD) | Last week (full) | This month | Last month | 3m avg | 6m avg.
  Key Metrics has all seven and now includes Social Media Escalation % (also kept in Escalations).
- WTD-this = Mon 28 only, WTD-last = Mon 21 only. **WTD-this uncoloured everywhere** (user instruction) + top banner.
  RAG in all non-Key tables (incl. CX buckets) moved to **MTD-this vs 6mo avg** for this refresh (user choice).
  MTD colouring unchanged (Key Metrics, Leads/Orders volume rows, City×BHK grids).
- Fixes this refresh: fare-increase metrics now Nano-excluded (user-approved); Add-on 6mo baseline now uses same
  filters as MTD; Leads-by-city excludes 14,827 leads with no pickup city (row removed per user; note states the gap).
- All tags balanced, CSS block untouched, all tables swapped by position with identity asserts (see build_html.py pattern).
- Daily scheduled task (4:00 PM IST) follows RUNBOOK.md: sql/ templates -> data/*.txt -> build_html.py (REPORT_DATE env) -> Slack.
  Colour basis: WTD-this vs 6mo avg Tue–Sun (rules); MTD-this vs 6mo avg on Mondays (single-day WTD).

## 4. Source-of-truth files (GitHub RASHDUTT/pnm-leadership-digest; daily procedure in RUNBOOK.md)
- **pnm-leadership-digest.html** — THE live page. Always the latest edit wins.
- **queries.sql** — every metric's SQL, by group, parameterized by report_date literal.
- **scripts.py** — heat-classification/row-generation Python + the regex patch patterns
  used for HTML surgery, plus the tag-balance check to run after any of it.
- **rules-and-notes.md** — the single most important file: full direction reference,
  Nano policy per group, 10 settled findings (don't re-litigate), open items.
This HANDOFF.md is a compressed pointer to those three — read them, not just this.

## 5. What failed — don't repeat
- **A "remove dead CSS" pass once deleted CSS other sections depended on** (`.scroll`,
  `.metric-table`, `.heatlegend`, etc.) — global counts still balanced (deletions were
  paired) but sections rendered broken. Always grep for specific class definitions
  before/after bulk CSS removal, not just eyeball the page.
- **Regex table-swaps on `<details>` blocks silently patched the WRONG section** when two
  sections share identical header text (e.g. "Overall NPS" exists in both Customer
  Experience and City×BHK) — `.search()` grabs the first match. Always verify against
  the actual rendered section, not just "script reported success."
- **Assumed a table structure without checking → wasted an ask-cycle.** When in doubt on
  scope/format ambiguity, ask once, narrowly, before touching ~150 rows.

## 6. Open questions / next 3 steps
1. Next refresh (a non-Monday): move colour back to WTD-this vs 6mo avg (per rules) and drop the single-day banner.
2. Vendor Ops and Acquisition groups were never started — ask if leadership still wants them.
3. "Wide/widest tolerance" on edit metrics has no actual numeric threshold — only
   qualitative. Worth defining a real number before this ships as authoritative.

## 7. Gotchas
- **report_date landing on a Monday collapses WTD-this to a single day** — happened
  twice now. Flag it explicitly in-page when it occurs; don't silently color a
  single-day snapshot like a normal week.
- **DIM_PNM_VENDOR.BUCKET_TYPE needs a point-in-time join** (fan-out risk) —
  `PNM_EXPERIENCE.VENDOR_BUCKET_TYPE` avoids this, always use that column instead.
- **-ve surge's 6mo baseline is artificially low** (discounting didn't exist 6mo ago) —
  keep the caveat note, don't "fix" the color.
- **User preference: never assume — ask when in doubt**, even mid-build. Confirmed
  repeatedly to hold even for scope/format calls that seem minor.
- **User preference: point out real inconsistencies/mistakes plainly**, don't just
  reassure — e.g. corrected a stale "genuine 6-day week" claim without being asked to
  double-check first.


## 1 Oct changes
- Page is now **metrics-only**: orientation boxes, all notes/status/scope lines and the footer are stripped at build time (build_html.py, 'Minimal-text layout'). Kept: titles, headers, legends, a one-line definitions strip under the header, the collapsed RAG rules register.
- New **City trends — weekly** section right below Key Metrics: 11 Key Metrics (all except Social Media Escalation %) × Network + 9 cities × last 13 full weeks, cells tinted vs that row's own 13-week mean (±5%/±20%, same directions), sparkline per row. Source: sql/14*_cw_*.sql, builder city_trend.py.
