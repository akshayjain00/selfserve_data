# PnM Leadership Digest — daily run book

Runs every day at 4:00 PM IST as a scheduled task that starts with a fresh session. Owner: Rashmi.
Read `HANDOFF.md` and `rules-and-notes.md` first; they hold every settled decision. **Don't change a settled decision; if something is unclear, stop and ask Rashmi.**

## 0. Setup
- Clone this repo into the working directory. Tools needed: the Snowflake connector (`sql-exec`), the Slack connector, and Python 3.
- `REPORT_DATE` = yesterday in IST (`python3 periods.py` prints every window for it).

## 1. Render and run the SQL
```
python3 render_sql.py $REPORT_DATE      # writes rendered/{all,nn,nano}/01..14e_*.sql
```
**Nano toggle (12 Oct):** every query runs once per segment (`all` = Nano included, `nn` = Nano excluded, `nano` = Nano only), so 18 queries x 3.
Save each result under `$DATA_DIR/<segment>/` with the file name below (e.g. `data1012/nano/alloc.txt`, `data1012/nn/city_weekly/ota.txt`).
Leads and conversion are never Nano-filtered, so those values repeat across the three segments (expected).
**Fastest path (used 12 Oct):** `python3 combine_sql.py` writes `rendered/combined/NN_*.sql`, one query per file that returns all three segments side by side (all, nn, nano).
Run it in Snowflake, then `python3 save_result.py NN_name.sql <query_id> $DATA_DIR` splits the result into the three segment folders and writes the
right file format (tpo/city_orders/AOV-SURGE/TPO-NPS handled automatically). `tools/query_result.py` reads the result from the session transcript, so nothing is retyped.
If a combined query is too slow or times out, run `rendered/<seg>/NN_*.sql` one segment at a time and save with `python3 save_result.py NN_name.sql <query_id> $DATA_DIR --seg <seg>`.
Manual fallback: each returns LISTAGG string(s): paste them **verbatim** into the data file named in the file's header comment.
- `data/tpo.txt` = column A + `;k_tpo|<mtd_this>|<mtd_last>||||||` from column B.
- `data/esc.txt` = the single string.
- `data/city_orders.txt` = two lines, `CITY_LO=<city_lo>;(No city yet)|<nocity>|0` and `ORDERS=<orders_grid>`. The no-city row is **never shown** on the page; it only feeds the note.
- `sql/14a..14e_cw_*.sql` -> `data/city_weekly/*.txt` (City trends section: last 13 full weeks; paste the single string).
- `data/city_aov_surge.txt`: `AOV=` / `SURGE=` lines. `data/city_tpo_nps.txt`: `TPO=` / `NPS=` lines. The rest are the single string.
Record format: `metric|this_month|last_month|this_week|last_week_same_days|6m_avg_same_days|3m_avg_same_days|last_week_full|n_months|6m_avg_full|3m_avg_full`. Empty fields are allowed (a segment with no rows, mostly Nano only) and show as dashes. Sanity check: `n_months` = 6 on every metric in `all` and `nn`. If any query errors or returns empty, stop and tell Rashmi.

## 2. Build
```
DATA_DIR=$DATA_DIR REPORT_DATE=$REPORT_DATE OUT=pnm-leadership-digest.html python3 compose.py
```
`compose.py` builds the page once per segment (via `build_html.py`, `SEG` env), runs `verify.py` on each, and stitches them into one page with the
**Nano filter toggle** at the top (Nano excluded = default view, All orders, Nano only). Leads and Conversion rows carry an "Overall · Nano filter n/a" tag.
(`base.html` is the fixed template the builder patches; never edit it by hand.)
Colour logic is automatic: **Tue–Sun colours WTD-this vs 6mo avg (per the rules)**. **Monday** (single-day WTD) colours MTD-this vs 6mo avg and shows the single-day banner.

## 3. Verify before sending (all must pass)
- Tag balance: open count = close count for div/table/tr/td/th/p/span/details.
- `python3 verify.py pnm-leadership-digest.html` prints OK (tags, 7 cells per row, column order This week → Last week (WTD) → Last week (full) → This month → Last month → 3m avg → 6m avg).
- City Orders column sum = network MTD orders in the `all` segment (`o_all` mt); `nn` + `nano` orders = `all` orders (every period, incl. 3m/6m), and per City×BHK cell.
- Leads and Conversion values are identical in all three segments.
- Independent recompute of Key Metrics (simple per-period and per-month queries) for each view; all must match to rounding.
- Nano only view: no fully empty rows/columns (compose.py hides them); Tier 2 and the 1BHK–4+BHK columns are expected to disappear there.
- Click all three toggle buttons in the headless browser: one view visible at a time, no duplicate ids, no page errors.
- Headless screenshot (`node shot.js`, Chromium at /opt/pw-browsers/chromium) loads with no page errors.
- Re-read every prose note on the page against the numbers (the builder writes most of them from data, but check for anything now false).

## 4. Deliver
- Give Rashmi the HTML as a file in the session (she downloads it and attaches it in Slack herself; the Slack connector can't attach files).
- Post to Slack (for now: Rashmi's own DM, `channel_id U07PWG51H3N`; switch to the leadership channel once she names it):
  > PnM Leadership Digest — data till {D Mon} (intra-city). RAG vs the 6-month baseline; start with Key Metrics at the top. HTML attached.
- Commit `data/*.txt` and `latest/pnm-leadership-digest.html` to this repo with message `refresh {REPORT_DATE}`.

## 5. If something is off
Don't guess. Message Rashmi with what failed or what looks wrong, and hold the Slack post.
