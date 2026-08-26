# SOP — how to update this knowledge base

*The Tuesday-morning runbook. You have just built, fixed, verified or ruled on something, and you
need to know where it goes and what else it breaks.*

> **Three docs, three jobs. Don't confuse them.**
> [`WALKTHROUGH.md`](./WALKTHROUGH.md) tells you **why** this KB exists — read it once, on day one.
> [`CONTRIBUTING.md`](./CONTRIBUTING.md) is **the law** — schema, source format, confidence,
> precedence. Where this SOP and CONTRIBUTING disagree, **CONTRIBUTING wins** and this file is the
> thing that needs fixing.
> This file is the **runbook** — what you actually do, in order, on a normal working day.

---

## 1. The one idea, and everything follows from it

**A KB fact is not a sentence. It is a row with three things:**

1. a **stable ID** (`M-003`, `G-161`, `T-020`) that never changes and is never reused,
2. a **source you can open** and check for yourself,
3. a **confidence label** saying how much weight it can carry.

If you cannot supply all three, **you are not writing a fact — you are writing a gap.** Put it in
`GAPS.md` and move on. That is not a lesser outcome; a well-written gap is one of the most useful
things in here.

Think of the KB as a **library catalogue, not a textbook.** Nobody reads it end to end. You arrive
with a question, the front desk sends you to a shelf, and every card on that shelf has a call number
and says which book it came from. That shape is what makes corrections surgical (fix one row, not a
paragraph) and merges clean (two people editing different rows never collide).

---

## 2. The shelves — what each file is and when you open it

| File | What lives there | ID prefix | You open it when |
|---|---|---|---|
| `CONTEXT.md` | The front desk: routing table, load protocol, and the handful of facts that prevent most errors | — | **Always first.** Capped at 175 lines on purpose — a long entry point stops being read |
| `business.md` | What PTL is, jargon, house formulas, dated structural events | `B-###` | "What does CBDF mean?" · "What's the house formula for allocation %?" |
| `metrics.md` | Metric definitions, formulas, and which card computes each one | `M-###` | "How is fulfilment actually calculated?" |
| `data-model.md` | Tables, columns, enums, units | `T-###` | "Which table holds order state?" · "Is fare in rupees or paise?" |
| `dashboards.md` | One row per Metabase card, plus its freshness fingerprint | card number | "Where did this number come from?" · "Has the card changed since we read it?" |
| `GAPS.md` | Open questions, conflicts, uncovered surface | `G-###` | "What don't we know?" — and where **anything you can't source** goes |
| `query-rules.md` | Operational SQL rules, each naming the KB row it collides with | `Q-###` | You are about to write a query |
| `CONTRIBUTING.md` | The law | — | **Before you change anything** |
| `WALKTHROUGH.md` | The 10-minute why | — | Day one, once |

**Three files that are not the KB but govern it:**

- `../DECISION_LOG.md` — **D1–D7**, the metric owner's programme-level rulings. These sit at
  **precedence tier 2**, above the metric catalogue and below observed card SQL.
- `../coordination/DECISIONS.md` — **D-###**, append-only log of workstream decisions. Never edit an
  entry in place; append a new one that supersedes it.
- `../coordination/BOARD.md` — mutable "where we are right now". The only file here you overwrite.

**And one thing that is downstream of all of it:** `../coverage-map/`. The coverage map is a
**projection** of the KB, not a place to record progress. Its statuses carry a `file:line` citation
back into these files. **Never edit the map to say a metric shipped** — that makes its own citation
a lie. Fix the KB, then re-derive the map (§4, Loop A).

---

## 3. "I have a new thing. Where does it go?"

Work down this list. Stop at the first match.

```
Did you read it directly out of SQL, code, or an explicit owner ruling?
├─ NO  → it is a GAPS.md row (G-###). Stop here. This is the correct answer more often than you think.
└─ YES → what kind of thing is it?
         a word, business rule, or dated event ......... business.md      B-###
         a metric formula or its source card ........... metrics.md       M-###
         a table, column, enum, or unit ................ data-model.md    T-###
         a card's identity or freshness ................ dashboards.md    card number
         a rule about how to write queries ............. query-rules.md   Q-###
         a decision a human made ....................... DECISION_LOG (owner-level)
                                                         coordination/DECISIONS.md (workstream)
         a question you could not answer ............... GAPS.md          G-###
```

---

## 4. The four loops

Almost every update you will ever make is one of these four.

### Loop A — a metric got built, verified, or promoted

**Trigger:** you traced a metric to its SQL, ran it, reconciled it, or the owner promoted a section.

1. **Write or update the `M-###` row** in `metrics.md`. Edit **in place** — never delete and re-add,
   because the ID is a stable reference other rows point at.
2. Set `source_ref` to what you actually read (see CONTRIBUTING §3). Set `confidence` per §4:
   `verified` only if **you saw the expression**.
3. Record the card's `source_updated_at` fingerprint in `dashboards.md` if it isn't there yet.
4. **Close the gap it answers.** Find the `G-###` row, mark it `CLOSED` with today's date and the
   resolving ID. **Do not delete it** — a deleted gap loses the record that the trap ever existed.
5. Bump `last_verified` **only if you re-checked against the source this session.**
6. Re-derive the coverage map and re-run its validators.

**Done-test:** a stranger can open your `source_ref`, see the same thing you saw, and reach the same
confidence label without asking you anything.

### Loop B — a conflict got ruled

This is the big one. Full mechanics in **§5**.

### Loop C — a new definition arrived from outside

**Trigger:** a spec, playbook or note lands that defines metrics.

1. **Assign a precedence tier per claim, not per document** (CONTRIBUTING §6). One document routinely
   holds tier-3 and tier-5 claims side by side.
2. A claim that names no reconciliation surface is **tier 5**. Naming one is necessary, not sufficient
   — if our own reading of that surface contradicts the claim, **the reconciliation did not happen.**
3. Where a higher-tier claim outranks a KB row, **correct the row's statement** and preserve the
   superseded wording verbatim in its `note`. Annotation alone is indistinguishable from no ruling.
4. Where it merely disagrees, record **both sides** and open a `G-###`.
5. Strip every number. CONTRIBUTING §7 bans values in definition rows; §9 bans derived query results.

**Expect the import to make the KB *less* certain.** Importing a source that disagrees with you
should mark long-standing facts as contested. That is the import working, not failing.

### Loop D — nothing changed, but time passed

**Trigger:** you are about to quote something, or it's the pre-review sweep.

1. For every row sourced from a Metabase card, compare the card's current `updated_at` to the
   `source_updated_at` recorded in `dashboards.md`.
2. Newer means the row is **stale — not wrong.** It was right when checked and its source has moved.
   Mark it `unverified` and re-extract.
3. `stale` is a **freshness** state, not a confidence one. A row can be `verified` **and** stale.

---

## 5. Resolving conflicts — the exact mechanic

### The short answer to "should I call out the number?"

**No. Rule the definition, not the number.**

A number is an *output*. Declare "fulfilment is 56%" and the next person recomputes it on a different
denominator and gets 66%, and you have resolved nothing — worse, both numbers are now quotable and
both claim your authority. Declare **the rule that produces the number** and the number follows,
reproducibly, forever, and anyone can regenerate it.

Concretely, this is the difference between:

> ❌ "CBDF for April is 30%."
> ✅ "CBDF denominates on **all placed orders**, not on terminal orders (`state IN (3,4)`). The
> weekly report's terminal-denominator variant is retired. Applies to PTL only. Re-run anything
> quoting cancel% since June."

The second closes a conflict permanently. The first creates a fourth number.

### First, work out which kind of conflict you have

| | What it is | What actually settles it |
|---|---|---|
| **Definitional fork** — `G-161` denominator, `G-002` sub-60s, `G-154` week convention, `G-004` AOV base | Two defensible definitions. No fact decides between them | **An owner ruling.** More analysis just re-describes the fork in more detail |
| **Factual dispute** — `G-159` `event_ts` vs `event_timestamp`, `G-156` state labels, `G-167` has anyone opened dashboard 4632 | One side is simply wrong | **A cheap check.** A ruling here risks blessing an error into permanence |

Getting this backwards is the most common failure: people investigate forks (which no investigation
can close) and rule on facts (which a two-minute read would settle).

### The one case where you must NOT resolve

**When observed card SQL contradicts an owner ruling — tiers 1 vs 2 — do not pick a side.** Record
both, set `confidence: unverified`, and open a `G-###` naming the exact action that would settle it.
CONTRIBUTING §6 calls this exception absolute, and it is: silently choosing converts a *known* unknown
into an *invisible* error, and an invisible error in a KB is worse than no KB, because it looks right.

### What a ruling must contain

Append to `../DECISION_LOG.md` as a new `D#`. Never edit an old one — supersede it.

```
### D8 — <the rule, stated as a rule>
- Date: YYYY-MM-DD · Status: ACTIVE · Confidence: NN%
- Rule:        <the predicate or formula that wins, precisely enough to implement>
- Loser:       <retired, or kept as a named alternate — say which>
- Scope:       <this vertical only | all verticals>  ← never leave this implicit
- Consequence: <which M-###/T-###/B-### rows change; what must be re-run or backfilled>
- Closes:      G-###, G-###
```

Five fields, and every one of them is load-bearing:

- **Rule, not value** — for the reason above.
- **Loser** — an unretired losing definition stays live in production and the conflict reopens in six
  weeks. Say explicitly whether it dies or becomes a named alternate.
- **Scope** — `allocation %`, `CBDF` and `CAC` mean **different things in PTL, PnM and HCV**
  (`G-039`). A ruling that doesn't say which vertical it binds will silently break the other two.
- **Consequence** — the blast radius, so nobody has to guess what your ruling touched.
- **Confidence %** — the standing house rule. It tells the next reader how hard to push back.

### "Should I have it compare old vs new versions?"

**No — and you don't need to.** That instinct is solving a real problem (*what changed, and what did
it break?*), but a model eyeballing two document versions is lossy and unfalsifiable. You have two
exact tools already:

1. **`git diff`** answers *what changed* precisely, for free, with no interpretation. That is what
   version control is for.
2. **The `→ G-###` backlinks answer *what it breaks*.** The KB is already cross-linked: `G-161` names
   `M-003`, `M-005`, `M-006` and `B-060` as the rows it touches. Follow the backlinks and you have
   your blast radius deterministically, not by inference.

**And the KB is designed to carry its own history**, so "old vs new" is preserved in place by
construction:

- corrected rows keep the **superseded wording verbatim in `note`**,
- closed gaps are **marked `CLOSED` with a date, never deleted**,
- IDs are **never reused or renumbered**, so a citation written a year ago still resolves.

If you ever find yourself needing to diff two versions to understand the current state, that is a
signal someone skipped one of those three rules — fix that, don't build a diffing habit around it.

---

## 6. Operating principles

Eight rules. If you remember nothing else, remember these.

1. **No source, no fact.** An unattributable statement is a `GAPS.md` row, not a KB row.
2. **Downgrading confidence is always allowed. Upgrading needs new evidence, cited.** Time does not
   promote a fact.
3. **A card title is never evidence.** A card called "Fulfilment %" tells you what someone *intended*.
   Only its SQL tells you what it *computes* — and on this project those diverged more than once.
4. **Two unverified sources agreeing is still unverified.** Agreement is not verification.
5. **Annotate the row, not the pointer.** Marking a summary that *points at* a fact, while leaving the
   fact itself unmarked, is a defect this project has committed twice. Go to the row.
6. **Never delete a gap.** Close it with the date and the resolving ID. The record that a trap existed
   is exactly what the next person needs when a number looks wrong.
7. **When the top two rungs collide, record both sides.** See §5.
8. **Bump `last_verified` only when you actually re-checked this session.** Bumping it because the row
   looks fine destroys the field's only purpose.

---

## 7. Worked example — closing a real conflict end to end

**The situation.** `G-161` is `BLOCKED`. The weekly report denominates fulfilment, cancel%, CBDF% and
CADF% on **terminal orders** (`state IN (3,4)`), because open orders inflate the denominator. The
canonical dashboard 4793 uses an **unconditional count** — all placed orders. Both are currently
defensible. Numbers computed on one base are not comparable to the other.

**Step 1 — classify it.** Definitional fork. No amount of reading settles which denominator PTL
*should* use. It needs a ruling. *(If you had instead found that one side simply miscounted, that
would be a factual dispute and you would go read the SQL, not rule.)*

**Step 2 — check the forbidden case.** Is this observed SQL contradicting an owner ruling? No — it is
observed SQL versus an operational practice. So it *can* be ruled. If it had been tiers 1 vs 2, you
would stop here and record both sides.

**Step 3 — the owner writes the ruling** in `DECISION_LOG.md`:

```
### D8 — PTL ratio denominators are DEMAND (all placed orders), not terminal
- Date: 2026-08-18 · Status: ACTIVE · Confidence: 80%
- Rule:        ff, cancel%, CBDF% and CADF% denominate on all placed orders in the period.
               Open orders (state 1, 2) stay in the denominator.
- Loser:       The terminal (state IN (3,4)) base is RETIRED for PTL reporting. Not a named alternate.
- Scope:       PTL only. PnM and HCV are unaffected and keep their own conventions.
- Consequence: M-003, M-005, M-006 confirmed as-written; B-060 annotation removed.
               The weekly report must be re-pointed; figures published on the terminal base
               since June are not comparable and must be restated.
- Closes:      G-161. Partially informs G-002 (which side of the ratio <60s sits on) — still open.
```

**Step 4 — walk the backlinks.** `G-161` names `M-003`, `M-005`, `M-006`, `B-060`. Open each. Three
were already correct and now lose their "contradicted by production" annotation; `B-060` gets its
contested marker removed. Each edited row: bump `last_verified`, add a `note` saying what changed and
why, keep the superseded wording.

**Step 5 — close the gap.** `G-161` → `CLOSED 2026-08-18 → D8`. Row stays where it is.

**Step 6 — re-derive the coverage map.** Those metrics move from `partial` to whatever the new
evidence supports, and their citations now point at `D8`. Re-run the validators.

**What you did *not* do:** publish a fulfilment number, delete the gap, edit the coverage map by hand,
or rule on the two other conflicts that happen to touch the same metrics.

---

## 8. Five things that will get your change sent back

1. **A fact with no `source_ref`** — or one pointing at a document that merely repeats the claim.
2. **`confidence: verified` when you did not see the expression.** Reading a summary of SQL is not
   reading SQL.
3. **A number in a definition row.** CONTRIBUTING §7 and §9. Definitions live here; values do not.
4. **A deleted gap**, or a gap closed with no date and no resolving ID.
5. **A ruling that declares a value instead of a rule**, or that omits its scope.

---

## 9. Who does what, and when

| Trigger | Who | Doing what |
|---|---|---|
| A metric gets traced to SQL | Analyst | Loop A |
| A source doc lands | Analyst | Loop C |
| A definitional fork surfaces | Analyst raises `G-###`; **owner rules** | §5 |
| A factual dispute surfaces | Analyst | Go check it. Do not escalate |
| Before quoting anything externally | Whoever is quoting | Loop D |
| Before a leadership review | Owner | Loop D across every row the review touches |

**Cadence is event-driven, not calendar-driven** — the KB updates when evidence changes. The one
exception is the staleness sweep (Loop D), which must run before anything is quoted outside the team,
because a card can change under you without anyone touching this repo.

**The honest caveat:** none of this is enforced by tooling. There is no linter and no CI gate on these
files, and the drift this KB exists to fix was itself a discipline failure. The coverage-map validators
are the only automated check in the loop, and they only check citations resolve — not that they say
what you claim.

---

## 10. If PnM or HCV want a KB

Neither has one today. What they'd each need, in order:

1. **A metric universe** — PnM and HCV both have one already, the Argus data dictionary (167 and 118
   metrics respectively). That is the equivalent of PTL's 85-row catalogue.
2. **An addressable-row format** — the `B-`/`M-`/`T-`/`G-` split, namespaced per vertical so
   `M-001` never means two things.
3. **A precedence ladder of their own.** PTL's ladder is specific to PTL's sources; PnM's top rung is
   the validated MBR automation, not Metabase card SQL.
4. **A gaps file from day one.** It is the highest-value file and the cheapest to start.

Start with 3 and 4. A KB with ten sourced rows and an honest gaps list beats one with two hundred
unsourced ones.
