# Scheduled daily run — PnM Leadership Digest

Runs every day at 2 pm IST from a Claude scheduled task. Each run starts in a fresh session, so everything it needs is in this folder.
REPORT_DATE is always **yesterday (IST)**. No step needs a date typed by hand.

**Delivery:** the run saves the HTML to Rashmi's Mac at `~/Downloads/pnm-leadership-digest-<REPORT_DATE>.html`.
A separate Slack step (owned by Rashmi) picks the file up and posts it to #hsc-metric-digest. **This run never posts to that channel.**
If QC fails, the file is **not** saved to Downloads; the run DMs Rashmi on Slack with the failure instead.

## 0. Get the code
Repo `akshayjain00/selfserve_data`, folder `pnm-selfserve/pnm_daily_digest` (branch `main`; before the PR is merged use branch `pnm-daily-digest`).
Clone with git if the session can reach the repo; otherwise download the folder with the GitHub connector (`get_file_contents`).
Work from the folder root (`cd .../pnm_daily_digest`). Needs Python 3 (stdlib only) and, for step 6, Node + Playwright.

## 1. Prepare
```
python3 tools/daily_prep.py
```
Prints `REPORT_DATE=YYYY-MM-DD  DATA_DIR=dataMMDD` and the period windows. Check they are sensible:
- MTD = 1st of month..R vs same days of the previous month; WTD = Monday..R vs the same weekdays last week.
- Last week = previous full Mon–Sun week. City trends = last 13 full weeks (includes the current week only when R is a Sunday).

## 2. Run the 18 queries
For each file in `rendered/combined/` (sorted: 01_alloc … 14e_cw_tpo_nps), paste its **exact** text into the Snowflake connector (`sql-exec`), then **immediately**:
```
python3 save_result.py <file name> <query_id> <DATA_DIR>
```
Save each result straight away; `tools/query_result.py` reads the result back from this session's transcript, so nothing is retyped.
If a query fails or times out, rerun that one file. If a save prints `NOTFOUND`, rerun the query and save again.

## 3. Confirm the SQL that ran
```
python3 tools/sql_match.py        # expect 18/18 matched
```

## 4. Build and verify
```
DATA_DIR=<DATA_DIR> REPORT_DATE=<REPORT_DATE> OUT=out/pnm-leadership-digest-<REPORT_DATE>.html python3 compose.py
for v in nn all nano; do python3 verify.py build_tmp/$v.html; done      # expect OK x3
```

## 5. Independent QC
Run `rendered/qc_daily_sums.sql` in Snowflake, then:
```
python3 tools/qc_check.py <DATA_DIR> <REPORT_DATE> <qc_query_id>   # expect 49 checks, 0 mismatches for all / nn / nano
python3 tools/struct_check.py <DATA_DIR>                            # expect BAD 0 (cells 45, city-weeks 130 today)
```

## 6. Toggle test
```
NODE_PATH=$(npm root -g) node tools/toggle_test.js out/pnm-leadership-digest-<REPORT_DATE>.html   # expect errors []
```

## 7. Deliver (only if steps 3–6 all pass)
1. `python3 tools/key_numbers.py <DATA_DIR> <REPORT_DATE>` for the summary.
2. Send the HTML into the run's chat (`SendUserFile`), then write it to the Mac with `device_commit_files` at
   `/Users/rashmi.dutta/Downloads/pnm-leadership-digest-<REPORT_DATE>.html`. If the Mac is unreachable, retry once, then say so in the summary.
3. Final message: file name, QC result, key numbers (MTD vs same days last month, WTD in brackets; Nano excluded), and any data notes
   (struct_check prints Kolkata's last two weeks — flag it if conversion is far below its usual ~15–19%).

## If anything fails
Do not save to Downloads. DM Rashmi on Slack (user ID `U07PWG51H3N`) with: report date, which step failed, the error or the mismatching
metrics. Do not post in #hsc-metric-digest.

## Notes
- Data folders are `dataMMDD/{all,nn,nano}`. `data1022/` is kept as a reference run (report date 2026-10-22).
- Metric definitions and design decisions: `HANDOFF.md`, `rules-and-notes.md`, `RUNBOOK.md`.
