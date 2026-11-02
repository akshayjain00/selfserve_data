# PTL Daily Digest: runbook

Goal: rebuild the digest HTML with fresh Snowflake numbers and save it to Downloads.
Latest day D = today (IST) minus 2 days. Everything below uses absolute paths.

Folder: `ptl-daily-digest (repo root: selfserve_data)`

| File | Purpose |
|---|---|
| `make_sql.py` | writes `work/*.sql` for the run (also clears `work/`) |
| `build_digest.py` | merges `work/*.txt` into `data/daily.json`, builds the HTML, saves it |
| `template.html` | page shell (CSS, chart code). Do not edit |
| `data/daily.json` | daily history since 1 Apr 2026. Refreshed on every run |

## Steps

1. `cd <repo>/ptl-daily-digest && python3 make_sql.py`
   Prints D and the SQL files (daily_orders, daily_created, daily_util, daily_opt, daily_return, route_a, route_b, route_c, route_d, route_weekly, freshness).
2. Freshness: run `work/freshness.sql`. The value is the latest order created time (IST). If it is earlier than D 23:00, the orders feed is lagging: stop, do not build, and report it.
3. For each of the other ten files: read the file, run its contents with the Snowflake MCP tool `mcp__snowflake-domestic-mcp__run_snowflake_query`, or in the cloud `mcp__Snowflake__sql-exec` (argument `statement`/`sql` = the file text, unchanged), and save the single returned column `S` as plain text to `work/<name>.txt` (same name as the .sql, no quotes, no JSON, one line) using the Write tool. Copy the string exactly. Decimal tails such as `.0000000000000000` may be dropped, nothing else may be altered. Independent queries can be run in parallel.
4. `python3 build_digest.py`
   - Fails loudly if the latest day is missing a field (rerun the daily queries) or a route file is missing.
   - Writes the HTML to `out/PTL-Daily-Digest-<D>.html` and `out/PTL-Daily-Digest-LATEST.html` (plus `~/Downloads` when that folder exists, i.e. locally). In the cloud, copy `out/PTL-Daily-Digest-LATEST.html` to `latest/`, then commit `data/daily.json` and `latest/PTL-Daily-Digest-LATEST.html` and push, so history keeps growing and the owner can download the file from GitHub.
5. Publish (best effort): use the Artifact tool, action publish, file_path = `out/PTL-Daily-Digest-LATEST.html`, url = `https://claude.ai/artifact/GckMruvaYBfjKNidFf4to7`, title "PTL Daily Digest", icon "chart", label "Refresh <D>". If it says the latest version must be read first, read that URL with the Artifact tool (action read) and publish again. If it still fails, skip it and say so.
6. Post to Slack (only after step 2 freshness passed and step 4 built): `mcp__Slack__slack_send_message` to channel `C0C0QUSQLDB`, heading `# PTL Daily Digest`, the latest day D, a table of the KEY NUMBERS printed by build_digest.py (day, MTD, WTD, † on the settling metrics) and, below the table, two links: `Open in browser: https://claude.ai/artifact/GckMruvaYBfjKNidFf4to7` (only if the step 5 publish succeeded; if it failed, omit this line and say so in the final reply) and `Download the HTML: https://github.com/akshayjain00/selfserve_data/blob/claude/loving-thompson-2b7ozh/ptl-daily-digest/latest/PTL-Daily-Digest-LATEST.html` followed by the instruction `(open the link, click the download icon at the top right of the file view, then open the saved .html file in your browser)`. Post the GitHub link only after the push in step 4 succeeded. Never use a /raw/ link, it only shows source text. If freshness failed or the build failed, do not post.
7. Send a PushNotification (status proactive) reminding the owner to send the HTML to the channel: say latest day D and that the file is at ptl-daily-digest/latest/PTL-Daily-Digest-LATEST.html on branch claude/loving-thompson-2b7ozh (download it from GitHub or from ~/Downloads after a local run).
8. Final reply, short: latest day D, files written, and the key numbers printed by build_digest.py, plus anything that failed.

## Rules

- Slack: only the step 6 post to C0C0QUSQLDB; no other messages. Do not edit other files in the project.
- Internal test users are excluded through `ptl_internal_users.customer_uuid` (plus two legacy ids), already inside the SQL. Do not use mobile numbers (masked since 5 Oct).
- The "latest day" at 2 days old is still settling for Fulfilment, Order Value, Orders per Trip and Utilization. The page already marks this; do not "fix" it.
- Return Trip Share comes from `daily_return` (adapted from Metabase card 44691: a batch is a return trip when the same vehicle's previous batch started in this batch's drop city). It is a normal metric like the others; the latest day is provisional (†).
- If Snowflake is unavailable, stop and report. Never invent or reuse numbers.
