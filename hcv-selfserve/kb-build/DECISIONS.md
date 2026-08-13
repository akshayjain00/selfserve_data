# HCV KB build — decision trail

**Append-only.** Newest at the bottom. Never edit or delete a prior entry; supersede it with a new
one that names what it replaces. Full rationale for the initial set: [DESIGN.md](./DESIGN.md).

> **Note on ids.** DESIGN.md v1 carried a parallel `H1`–`H5` series for the same decisions. Those
> labels are **retired and must not be cited** — `D-###` here is the single series. Mapping, for
> anyone reading a v1 quote: `H1→D-001`, `H2→D-002`, `H3→D-003`, `H4→D-004`, `H5→D-007`.

---

### D-001 · 2026-08-14 · KB only, no query layer
**Decision:** Build `hcv-selfserve/kb/` only. No `selfserve_nlq/` for HCV — no metric registry, no
`sqlgen`, no `ask.py`.
**Why:** Owner call. PnM and PTL each have a dry-run query layer; HCV's value is concentrated in
base context, because HCV already has a reconciled query pack and two rich dashboard inventories.
**Consequence:** `core.py`'s stated third consumer ("PnM and PTL — and later HCV") does not
materialise in this engagement. The shared-core promotion question stays open.

### D-002 · 2026-08-14 · Location and branch
**Decision:** New branch `claude/hcv-metric-catalog-map`, cut from `claude/ptl-metric-catalog-map`
@ `28703aa`, in the clone at `dev/selfserve/pnm/selfserve_data`. Directory `hcv-selfserve` (hyphen).
**Why:** Puts `ptl-selfserve/kb/` beside it as the live template and PnM reference material one
directory over. Hyphen matches `ptl-selfserve`.
**Note:** An untracked `hcv_selfserve/` (underscore, containing only a `.DS_Store`) already existed
in this clone. Left in place rather than deleted — it is not tracked and not mine to remove.

### D-003 · 2026-08-14 · Coverage — pack full, everything else indexed
**Decision:** The ~10 query-pack metrics get full `M-###` write-ups. Every other HCV metric across
`dashboard/1882`, `dashboard/4146`, and the Sheet gets an index-only row plus one `G-###`.
**Why:** Mirrors PTL's shape (23 full / 62 index-only of 85) and makes the uncovered surface
visible rather than invisible.

### D-004 · 2026-08-14 · Anchor on the governed metric store
**Decision:** Every full `M-###` entry carries a `store_ref` naming its `metric.porter.*`
counterpart or the literal `none`, plus an explicit statement of how the definitions differ.
**Why:** The Deep Dive shows the governed store already carries HCV metrics that the dashboards
re-derive in raw SQL — and disagrees with both the dashboards and the query pack (MAP is the
sharpest case: login-based vs order-based). Anchoring turns "we hand-rolled a fifth definition"
into a documented, closeable gap instead of an invisible one.
**Rejected alternative:** putting the store at the top of the precedence ladder. That would mark
the owner's own reconciled MBR numbers as non-canonical, and the evidence does not support that yet.

### D-005 · 2026-08-14 · Namespaced inventory references
**Decision:** KB metric ids stay `M-###` (hyphenated). References to the Notion inventories are
**never bare** — always `nb1882:M016` or `nb4146:M016`.
**Why:** The two inventories have colliding id spaces (`M016` is Revenue on 1882, DAP on 4146), and
a bare `M016` would also collide with PTL's `M-###` series.

### D-006 · 2026-08-14 · Three confidence tiers, not four
**Decision:** Keep PTL's `verified` / `unverified` / `assumption`. Record reconciliation-against-
numbers in `note`, not as a fourth tier.
**Why:** "Same architecture across verticals" is a design constraint; forking the confidence schema
for one vertical breaks it. The distinction still gets stated, just in prose that names what was
reconciled, against what, on what date.

### D-007 · 2026-08-14 · Ship WALKTHROUGH.md and a published artifact
**Decision:** Both, built after the seven KB files are stable.
**Why:** PTL's pair landed with people who do not open repos. Building last stops the two drifting
at birth — PTL's drifted once and was caught by audit rather than by process.
**Consequence:** A manual-sync burden with no automation. Stated in `CONTRIBUTING.md`, not left to
memory.

### D-008 · 2026-08-14 · Themed decade-block ID allocation
**Decision:** Allocate `B-`/`T-`/`M-`/`G-` ids in themed decade blocks (DESIGN.md §7). Insertions
and splits use letter suffixes (`T-001a`, `B-053b`) — never a renumber.
**Why:** Flat sequential allocation is **irreversible** once renumbering is forbidden. PTL allocates
in blocks (`B-030–034` conventions, `B-060–061` formulas, `T-030/031` time basis); v1 of this spec
said only "next unused number", which would have yielded `B-001…B-140` sequential across ~140 rows
with no way to recover the structure or file a future fact near its kin.
**Found by:** blind coverage check, ranked its highest-rework-cost omission.

### D-009 · 2026-08-14 · Owner rulings citable as `OWNER:<yyyy-mm-dd>`
**Decision:** Add `OWNER:<yyyy-mm-dd>` to the `source_ref` forms.
**Why:** `D-006` admits "an explicit owner ruling" as grounds for `verified`, but `D-001` removes
the `DECISION_LOG` that PTL cited as `DECISION_LOG:D<n>`. Without a replacement form,
`verified`-by-ruling had no expressible provenance — a live contradiction between two locked
decisions.
**Found by:** blind coverage check.

### D-010 · 2026-08-14 · Resolve the coverage ambiguity: one `G-###` per index-only metric
**Decision:** Each index-only metric gets its own `G-###` row, in `GAPS.md` class G, sharing a
**class-level `next_action`**.
**Why:** v1 said "each gets one `G-###`" in one place and "the uncovered surface" in another — a
fork of two orders of magnitude in output size (~130 rows vs 1). Per-row matches PTL, which is the
architecture being replicated; the class-level action stops ~130 rows each needing bespoke intent.
**Supersedes:** nothing — it resolves an ambiguity `D-003` left open rather than changing it.

### D-011 · 2026-08-14 · North star = Fulfilment % — `OWNER:2026-08-14`
**Decision:** **Fulfilment %** is HCV's north star (L0). Demand, Completed Orders and Allocation %
are demoted to L1 supporting. This is an explicit owner ruling and is citable as
`OWNER:2026-08-14`, which under `D-009` makes the *designation* `verified`.
**Why:** `metabase:dashboard/4146` recommends it; `dashboard/1882` recommends Completed Orders;
neither dashboard had a single primary metric. Owner settled it in favour of 4146.

> ⚠️ **The designation is `verified`; the metric's own definition is not.** Fulfilment %'s
> denominator is unresolved — total demand vs unique demand vs business-hours placed orders are all
> in production under the name "fulfilment" (`4146` contested-definition list). That gap stays
> **BLOCKED — owner** and must not be treated as closed by this ruling. An L0 with a contested
> denominator is a known, recorded tension, not an oversight.
>
> The pack's `ff_pct` = `completed / total_placed` (§2/§2a/§6) is therefore *one* of the three live
> denominators, not automatically the canonical one.

### D-012 · 2026-08-14 · Fingerprint the cited cards now; commit to a full sweep as a tracked gap
**Decision:** `dashboards.md`'s staleness register covers the cards the KB actually cites — those
feeding a covered metric or a recorded conflict. Every other card on `1882`/`4146` is listed in the
surfaces-covered table as **not opened**, a stated boundary. A single `G-###` commits to the full
sweep.
**Why:** ~100+ cards across the two dashboards; most will never be cited. Cited-first unblocks
step 4 without pretending the boundary is permanent.
**Guard against rot:** PTL's equivalent (`G-152`, nine unfingerprinted cards) is still open. This
gap's `next_action` therefore names **a specific card list and a named owner**, not "sweep the
dashboards" — a `next_action` that cannot be executed without further thought is the failure mode
`CONTRIBUTING.md` §8 exists to prevent.

### D-013 · 2026-08-14 · Argus posture — the KB is a migration map · `OWNER:2026-08-14`
**Decision:** This KB reads as a **migration map toward the governed metric store**, not a parallel
definition set. The goal state is **one source of truth and one definition per metric**, and that
source is `metric.porter.*`.
**Why:** Owner ruling. Settles the `G-###` seeded as "Argus posture" and resolves PTL's `G-132`
question in the opposite direction for HCV — where PTL's architecture had been *rejected* by Argus,
HCV's store already exists and is the target.

**What changes:**
- Every full `M-###` entry's `store_ref` carries a **`migration:` line** — the delta to close, and
  **what closing it would change about the reported number**. A delta with no stated consequence is
  not a migration plan.
- Where no store counterpart exists, `store_ref: none` becomes a **gap with a `next_action`**
  ("propose `metric.porter.<name>`"), not a dead end.
- `GAPS.md` class F is reframed: rows record *distance from the target*, not *posture undecided*.

**What does NOT change — read this before "simplifying" the ladder:**
> ⚠️ The precedence ladder (`CONTRIBUTING.md` §6) is an **evidentiary** ordering — what is
> demonstrably true *today*. `D-013` sets the **target**. These are different axes and the ladder
> does not move. The pack stays rung 1 because it is reconciled SQL; the store stays rung 3 for
> formulas because its definitions have not been reconciled against anything here.
>
> The absolute exception still holds. `D-013` tells you **which direction convergence runs**; it
> does **not** decide which formula is correct, and it is not licence to overwrite a pack definition
> with a store definition.

### D-014 · 2026-08-14 · `dashboard/6406` is the go-forward demand source · `OWNER:2026-08-14`
**Decision:** `metabase:dashboard/6406` ("HCV Demand Dashboard", created 2026-08-12) is the
canonical HCV **demand** surface going forward. `dashboard/1882`'s Traffic & Demand tab becomes
legacy. The owner states Experience and Supply will migrate into `6406` over time.
**Why:** Owner ruling. `6406` consolidates OMS and SO demand in one place with data from Jan-2025;
`1882` splits the same measures across incompatible lineages.

**What it resolves:** the three-objects-answer-"completed orders" problem (`T-050`/`T-051`/`T-059`,
`G-012`) now has a stated target — one consolidated demand object rather than three.

**What it does not resolve, and must be recorded before anyone treats `6406` as settled:**
- **`T-029`** — the Demand card's status filter is **commented out**, so `6406`'s "Demand" counts
  every status while the pack's base is `(4,5)`. Two different populations under one word.
- **`T-021`** — the dashboard's `vehicle_mapping` default is `["14ft","10ft","9ft"]`, which
  **excludes 17ft and 19ft**. The default view under-reports HCV against the pack's scope.
- **Stale defaults** — dashboard defaults to `2025-04-01 → 2025-09-30`; card 55561 defaults to
  `2025-12-10 → 2025-12-10`, a single day. The two disagree, and neither is current.
- **No distance dimension**, which is the pack's primary economic cut (6 of 8 sections use it), and
  **no 10ft NCR/non-NCR split** (`T-023`, `T-024`). Both confirmed absent; the owner has flagged
  distance and Business/Retail as planned.
- **Matchmaking data exists only from Jan-2026**, so those cards are empty for the pack's own
  reporting history.
- The four dimension filters (`vehicle_id`, `vehicle_mapping`, `city_name`, `Tier`) are wired in
  card SQL as optional `[[and {{…}}]]` blocks with real dimension aliases. Whether the
  **dashboard-level** parameters are mapped through to them is not determinable from the API
  response and needs a UI check → `G-014`.

> ⚠️ **Convergence is not free, and one case is already known.** `metric.porter.map` is
> **order-based** (≥1 completed order/month); the pack's MAP is **login-based**
> (`business_login_hours > 0.5`/day). Migrating MAP to the store **changes the number reported in
> the MBR** — it is a business decision with a visible consequence, not a mechanical repoint. Each
> such case ships as a gap stating the delta *and its cost*, for the owner to accept or reject
> per metric.
