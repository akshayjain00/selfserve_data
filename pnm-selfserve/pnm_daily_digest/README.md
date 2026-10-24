# pnm-leadership-digest
PnM (Packers & Movers) leadership metrics digest: ~60 metrics, RAG vs month-ago and the 6-month baseline, refreshed daily from Snowflake.
One HTML page with a **Nano filter** at the top (Nano excluded = default / All orders / Nano only); Leads and Conversion are always overall.

Start with `RUNBOOK.md`. Decisions: `HANDOFF.md`, `rules-and-notes.md`.
- SQL templates: `sql/` (Nano condition marked `{{NANO:...}}`); `render_sql.py` -> `rendered/{all,nn,nano}/`; `combine_sql.py` -> `rendered/combined/`.
- Saving results: `save_result.py` (+ `tools/query_result.py`). Data: `dataYYYYMMDD/{all,nn,nano}/`.
- Build: `compose.py` (runs `build_html.py` per segment, stitches the toggle page). Checks: `verify.py`, `shot.js`.
- Earlier single-view code is kept in `archive/pre_nano_toggle/`.
