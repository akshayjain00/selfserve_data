# Research log — AI-consumable KB patterns (Phase 1)

**Date:** 2026-07-29 · **Workstream:** PTL self-serve `kb/` build · **Method:** 2 Sonnet research
workers (W1 entry-point/load-protocol, W2 per-fact provenance/staleness), orchestrator-synthesised.
**Purpose:** decide the structure for `ptl-selfserve/kb/`. Citation-first; every claim carries its
source. Claims the workers could not verify against a primary source are marked `[unverified]` and
were NOT used to justify the recommendation.

---

## Part A — Entry point & load protocol (W1)

### CLAUDE.md
- Source: https://docs.claude.com/en/docs/claude-code/memory · https://www.anthropic.com/engineering/claude-code-best-practices
- **Layout:** 4-tier scope — managed policy > user (`~/.claude/CLAUDE.md`) > project (`./CLAUDE.md`) > local (`./CLAUDE.local.md`, gitignored). Supports topic-split `.claude/rules/*.md`, optionally with `paths` glob frontmatter.
- **Load:** files in the hierarchy above cwd load **in full at launch**; subdirectory files load on-demand when Claude reads files there. `.claude/rules/*.md` without `paths` load unconditionally; with `paths`, only on matching file reads. User rules load before project rules → project wins on conflict.
- **Size discipline:** no numeric limit stated, but it loads every session, so Anthropic explicitly directs "only sometimes relevant" material into Skills. `@path` imports (recursive, max depth 4) keep the root thin.
- **Failure modes (stated by Anthropic):** "If Claude keeps doing something you don't want despite having a rule against it, the file is probably too long and the rule is getting lost." Contradicting rules across nested files → Claude "picks one arbitrarily." Fix: periodic pruning, treat the file "like code."

### AGENTS.md
- Source: https://agents.md/
- **Layout:** single flat Markdown file, no enforced schema. Recommended: project overview, build/test commands, code style, testing, security. Deliberately separate from README ("README is for humans").
- **Load:** nearest-file-wins in the directory tree. OpenAI's monorepo ships 88 AGENTS.md files as a scale example.
- **Size discipline:** `[unverified]` — no limit stated on the page.
- **Note:** the page claims broad tool adoption but does **not** document a CLAUDE.md interop mechanism. Any claim of automatic CLAUDE.md↔AGENTS.md compatibility is `[unverified]`.

### llms.txt
- Source: https://llmstxt.org/
- **Layout (strict order):** optional BOM → **required H1** (only mandatory element) → blockquote summary → zero+ non-heading Markdown sections → zero+ H2 "file list" sections of links with required title + optional description. Convention reserves a final `## Optional` H2 for skippable links.
- **Load:** on-demand at inference time — "mainly useful for inference... as opposed to training." Fetched when an agent wants a library's docs; not crawled like a sitemap.
- **Adoption:** `[contested / unverified at primary-source level]` — secondary SEO/industry blogs report no confirmed adoption by any major LLM vendor ~18 months post-proposal, incl. a reported statement from Google's John Mueller that no AI system currently uses it. **No vendor has officially confirmed parsing it.** These are secondary sources; treated as unverified and NOT relied on.

### Memory-bank / context-bank patterns
- Sources: https://docs.cline.bot/best-practices/memory-bank · https://docs.claude.com/en/docs/agents-and-tools/agent-skills/overview · Cursor rules cross-checked via github.com/sanjeed5/awesome-cursor-rules-mdc `[unverified against primary — cursor.com docs are a JS SPA and did not render]`
- **Cline Memory Bank:** `projectbrief.md → productContext/systemPatterns/techContext → activeContext/progress`. Enforced by a rule stating "I MUST read ALL memory bank files at the start of EVERY task." Hierarchical read order, **all always-on**.
- **Cursor Rules:** `.cursor/rules/*.mdc`, frontmatter `description` / `globs` / `alwaysApply`. Three trigger modes: always, glob-attached, or description-matched.
- **Agent Skills (Anthropic):** 3-level progressive disclosure — L1 frontmatter (`name`, `description`) always in system prompt; L2 SKILL.md body loads on trigger; L3 bundled files load file-by-file on demand. "No practical limit on bundled content" since unused files cost zero tokens. Design goal: "install many Skills without context penalty."

### Convergence (all four)
1. Every one separates a **thin always-on index** from a **heavy on-demand body**.
2. Every one uses **nearest-file-wins precedence** for nested scoping.
3. Every one warns that unbounded growth in the always-loaded layer degrades reliability.

---

## Part B — Per-fact provenance, staleness, versioning (W2)

### dbt Semantic Layer / MetricFlow
- Sources: https://docs.getdbt.com/reference/resource-configs/meta · https://docs.getdbt.com/reference/resource-properties/freshness · https://docs.getdbt.com/reference/semantic-model-properties
- `entities` / `measures` / `dimensions` each carry `description`; free-form `meta:` (→ `config.meta` in dbt ≥1.10) is **overloaded for `owner`** — dbt has no first-class owner field. Lineage is implicit via `ref()`/DAG, not declared.
- **Freshness is a separate mechanism and does NOT cover metric definitions:** `sources` declare `loaded_at_field` + `freshness.warn_after`/`error_after`; `dbt source freshness` runs `MAX(loaded_at_field)` and compares. Computed, but scoped to **raw source data**, not definition drift.
- No metric-level version field or changelog. Versioning = git + PR review of YAML.

### Cube / LookML
- Sources: https://cube.dev/docs/schema/reference/measures/ · https://docs.cube.dev/reference/data-modeling/dimensions
- Cube: `name`, `sql`, `type`, `title`, `description`, plus arbitrary `meta:`, exposed live via a `/meta` API endpoint. No owner/verification/freshness fields found `[unverified further]`.
- LookML: `description` on every dimension/measure/view/Explore. No native owner/lineage/freshness field; review via Looker's git integration. Deprecation by convention (`hidden: yes` + manual changelog), not a schema field.

### Data catalogs — the only conventions with explicit trust fields
- **DataHub** (richest template): https://docs.datahub.com/docs/generated/metamodel/entities/metric · https://docs.datahub.com/docs/api/tutorials/deprecation
  - First-class `Metric` entity with `ownership`, `deprecation`, `documentation`, `globalTags`, `glossaryTerms`, `structuredProperties`, plus `metricUpstreams` (dataset/column lineage) and `metricRelationships` (`parentMetric`).
  - **Deprecation aspect** — directly reusable: `deprecated` (bool), `decommissionTime` (epoch), `note` (reason/link), `actor` (URN — who flagged it).
  - `AuditStamp` / `lastModified` gives who + when for any field change.
  - **Staleness here is declared (manual flag + note), not computed.**
- **OpenMetadata:** https://openmetadatastandards.org/governance/metric/ · https://github.com/open-metadata/OpenMetadata/issues/18639 — `Tier` (asset importance), a certification/"Certified" badge distinct from Tier, `owners`, `stewards`, glossary/classification tags, first-class Metric entity.
- Amundsen: `[unverified]` — not covered in this pass.

### Open Semantic Interchange (OSI)
- Sources: https://www.snowflake.com/en/news/press-releases/snowflake-salesforce-dbt-labs-and-more-revolutionize-data-readiness-for-ai-with-open-semantic-interchange-initiative/ · https://github.com/open-semantic-interchange/OSI/blob/main/core-spec/spec.yaml
- Announced Sept 2025 (Snowflake / Salesforce / dbt Labs / BlackRock / RelationalAI); v1.0 published 2026-01-27, donated to Apache as "Ossie".
- Declares `datasets`, `fields`, `metrics`, `relationships`, and an **`aiContext` block** (synonyms, NL instructions, few-shot examples for LLM consumers).
- Ownership/approval field keys not confirmed `[unverified]`. GitHub discussion #82 flags that **lineage for derived-metric calculations is an acknowledged gap in v1.0** — cross-vendor metric provenance is explicitly unsolved as of this spec version.

### The load-bearing finding
> **No reviewed system automatically computes drift between a metric *definition* and its source.**
> dbt's freshness check covers raw source *data* timestamps only, not SQL-definition drift.

Practical mechanism (W2, borrowing DataHub's audit-stamp pattern): store `source_ref` **plus a
content hash or last-fetched timestamp of the source artifact** (e.g. the Metabase card's
`updated_at` via API) alongside `last_verified`. An agent then makes **one cheap call** to compare
before deciding whether to re-read the full source. Declared + diffed, not deep-computed.

---

## Orchestrator synthesis

**Independent convergence worth recording:** the maker-checker agent (finding BS-5) and research
worker W2 arrived at the *same* staleness mechanism — store the source artifact's `updated_at`
next to `last_verified`, compare the two — with no visibility of each other's output. Two
independent derivations of one mechanism is materially stronger evidence than either alone.

**Adopted:** Agent-Skills-style progressive disclosure for structure (thin always-on index → topic
files on demand); DataHub's audit-stamp + deprecation field shapes for per-fact rows; W2's minimal
schema, extended with `source_updated_at`.

**Rejected, with reasons:**
- *llms.txt format* — designed for public websites and crawler/inference fetch over HTTP. This KB is
  read by a local agent with filesystem access, so the format's core benefit doesn't apply; and its
  adoption evidence is `[contested]`. Its one good idea (an `## Optional` skippable tier) is
  absorbed into the load protocol instead.
- *Cline Memory-Bank "read ALL files at start of EVERY task"* — works for Cline because it is the
  agent's only state. Here it would compete directly with session context budget and reproduce the
  documented CLAUDE.md failure mode ("the file is too long and the rule is getting lost").
- *Full lineage graphs, Tier/certification badges* (DataHub `metricUpstreams`, OpenMetadata Tier) —
  built for many-consumer, many-tool ecosystems. Over-engineering for a ~15-metric internal KB.

**Rejected W2's advice on one point (orchestrator override):** W2 recommends dropping OSI-style
`aiContext` synonym blocks as over-engineering. That calibration assumes a generic markdown KB.
This KB's primary consumer is an AI agent translating natural-language questions into PTL metrics,
against dense jargon (`ff`, `co`, `cadf`, `cbdf`, `so`, `mo`, `cac`, `aov`, qualified demand).
Synonyms/aliases are load-bearing for that job, so a lightweight `aliases` field is retained —
a single list per row, not OSI's full few-shot block.
