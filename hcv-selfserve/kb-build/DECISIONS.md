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
