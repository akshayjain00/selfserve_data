# DECISIONS — append-only decision log
# Writer: ORCHESTRATOR ONLY. Workers propose (in their return); the orchestrator commits here.
# Append at the END. IDs strictly increasing. Never edit an existing entry in place.
# Format: [D-NNN] YYYY-MM-DD (orchestrator) — decision — rationale
#
# Workstream: close PnM KB gaps and mine the governed dbt layer (2026-08-26 →).
# The completed 2026-07-29 Gem-KB workstream and its own D-001..D-015 live in ./gem-kb-build/.
# Decision ids here are a FRESH space and do not continue that one.

[D-001] 2026-08-27 (orchestrator) — **This is a new workstream, not a continuation of the Gem-KB
build; its record was filed to `coordination/gem-kb-build/` and a fresh `D-001` space opened.** — The
2026-07-29 BOARD reads "COMPLETE — both deliverables written, reviewed, and fixed. Nothing in
flight," and its deliverables (`pnm-gem-knowledge.md`, `pnm-gem-instructions.md`) are different
artifacts from this workstream's (the row-addressed `pnm-selfserve/kb/`). Appending `D-016` under a
board declaring itself complete would have misstated live state. Filing rather than deleting keeps
the "why" trail — `D-010` there is the origin of what is now `PNM-G-070`. The subfolder name mirrors
the existing house convention at `ptl-selfserve/coordination/kb-build/` rather than the skill's
generic `archive/<timestamp>/`, so the two verticals stay legible the same way. Owner chose this over
resuming.

[D-002] 2026-08-27 (orchestrator) — **`coordination/` is version-controlled.** — Settles the question
`D-015` of the previous workstream explicitly left to the owner and which had sat unresolved for a
month (present on disk, untracked, no `.gitignore` entry). Committed because it is the durable
decision trail and the resumable handoff: untracked, it dies with the clone, and this repo has
already been relocated once under DLP pressure (see BOARD learnings). Owner decided.

[D-003] 2026-08-27 (orchestrator) — **Mode is PARALLEL across verticals, SEQUENTIAL within PnM.** —
Step-0: (1) yes, PnM mining and the HCV KB/coverage-map audit need none of each other's live output;
(2) breadth across two verticals, but depth within PnM's dbt mining; (3) yes, the workers touch
disjoint trees (`pnm-selfserve/**` vs `hcv-selfserve/**`) so they cannot collide on a BOARD section or
a file; (4) yes — the owner asked for HCV as a parallel session explicitly. PnM's own mining stays
single-orchestrator because the findings interlock: three OTA definitions had to be compared against
each other before any could be written down, which a fan-out would have fragmented.

[D-004] 2026-08-27 (orchestrator) — **`PNM-G-002` was closed by disproving its premise, not by doing
its `next_action`.** — Both files it called untracked were already tracked — the spec since `83011b2`
(2026-07-19), **38 days before** the KB recording the gap was built at `3d535b6`. Its `next_action`
("copy it across from the Desktop clone") would have overwritten the tracked board-reviewed revision
with an older 2026-07-12 pre-board draft, destroying three `[board-fix]` decisions. Recorded the trap
on `PNM-S-032` so it cannot recur. Shipped as `e7b8f72`.

[D-005] 2026-08-27 (orchestrator) — **Citations were re-pointed `local:` → `repo@<sha>:` but NO
confidence grade was upgraded.** — `CONTRIBUTING §4.1` (no SHA available) and `§5` (a document's
assertion vs something read from SQL/code) are independent caps. Pinning a design document at a SHA
lifts the first and leaves the second, so `PNM-S-032` and `PNM-S-037` stay `unverified` for a newly
stated reason. No readiness tier was set either — only the owner promotes.

[D-006] 2026-08-27 (orchestrator) — **A pre-existing four-figure miscount in `GAPS.md` was corrected
rather than republished.** — The per-group column had always summed to 57 while `Total rows` read 58
and the prose read "58 rows exist / 56 live / 48 `OPEN`" (correct at the time: 57 / 55 / 47). One root
cause, four wrong published numbers, surviving because each edit adjusted the stated total instead of
recounting. My own edit would have carried it forward, which made it mine to fix. Rule recorded in the
file: recount from the rows, never carry a total.

[D-007] 2026-08-27 (orchestrator) — **§3.1 mining took the documentation-debt ordering (low trust
first), against the evidentiary-yield ordering.** — The new trust-score ranking (`PNM-S-058`) inverts
the handoff's stated priority: three of its five named targets are gates-failing `C` grades. Owner
chose gap-first, so the debt ordering was used deliberately — it targets the owner-blocked gaps
(`PNM-G-024`, `-070`, `-073`) at the cost of yielding mostly `unverified`-grade prose, since `§5` only
lets a merged *test* clear `verified`. Both orderings are now recorded on `PNM-G-091` with the
instruction to state which one a future pass is using.

[D-008] 2026-08-27 (orchestrator) — **`PNM-G-024`'s "event fork" is disproved and the gap restated
around the distance term.** — `pnm_ota_capacity.sql:53` filters `a.action = 'ShiftingStarted'` on
`supervisor_actions` — a **supervisor** action of that type, not a vendor arrival — so it anchors on
the same event as `PNM_EXPERIENCE.OTA_FLAG`. A **third** governed definition was then found
(`pnm_support.on_time_arrival_flag`) reading the same rows with the same filter and rank and applying
**no distance test at all**, and it is the only one of the three carrying a written description. So
the two models the KB called independent corroboration are not independent. The 30-minute clock is
corroborated three ways; the 500 m only two of three. The owner's question narrows from "which event"
to "does OTA require GPS proximity to pickup, or is it purely 30-minute punctuality".

[D-009] 2026-08-27 (orchestrator) — **Six new gap rows opened rather than folding the findings into
existing rows.** — `PNM-G-094` (two models publish absent data as a bad outcome via `ELSE 0` /
`ELSE 'No'`), `-095` (a model's `exclude_daily` tag contradicts its docs' `refresh_frequency: daily`),
`-096` (`RANK()` where `ROW_NUMBER()` was meant — logged as a **latent risk, not a demonstrated
defect**, because ties have not been shown to occur), `-097` (the validation layer cannot be counted
naively — 11 byte-identical duplicates and one off-schema file), `-098` (what
`PNM_EXPERIENCE.distance_km` measures is unestablished, and OTA definition (1) turns on it), `-099`
(the governed `is_test_user` is not the complement of the catalog's user filter). Each is a distinct
owner or action, so merging them into their parent gaps would have buried the `next_action`.

[D-010] 2026-08-27 (orchestrator) — **`PNM-G-070` was re-priced upward, not marked cheaper.** — The
prior note said a city cut is now "materially cheaper" because `pnm_ota_capacity` publishes
`ota_percentage` by city. Reading it: the city cut is a hardcoded `CASE` over
`geo_region_id IN (1,2,3,4,5,8)`, written twice, with no reference to `dim_geo_regions` — the
dimension `dim_pnm_opportunity` does FK-test against. Plus a denominator limited to orders having a
`ShiftingStarted` action, and `ELSE 0` publishing absent data as 0%. Adopting it buys six cities on a
private mapping. Cheaper than new work, not free, and the KB now says so.

[D-011] 2026-08-27 (orchestrator) — **Seven pre-existing malformed table rows in `GAPS.md` were left
unfixed; the one row this workstream edited was fixed.** — Groups D and H declare 5-column headers
while `PNM-G-025`/`-026`/`-027` and all of group H supply 4 cells, so their `status` renders inside
`next_action`. Identical at `HEAD`, so not this work's doing, and fixing all seven is scope the owner
did not ask for. `PNM-G-091` was repaired because this workstream rewrote its `next_action`, making
its well-formedness mine. All 30 rows added here match their header width.
