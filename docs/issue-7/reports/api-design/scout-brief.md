# Issue #7 — Scout Brief (Phase 1)

Mode: **internal-canon scout** (local file reads, not web search) — the
question is "how did a sibling rulebook plugin in this same monorepo
family build its methodology gate," which is answered by reading files,
not searching the web. One angle run: read pricing-rulebook's hook
machine directly. Saturated after one pass — pricing-rulebook is the
only comparable plugin locally checked out (`implementation-rulebook`,
the other exemplar issue #7 names, is not present in this workspace).

## What was read

- `/home/jwjung/tokenmaxxxer/rulebooks/pricing-rulebook/pricing/hooks/hooks.json`
- `/home/jwjung/tokenmaxxxer/rulebooks/pricing-rulebook/pricing/hooks/methodology-gate.sh`
- `/home/jwjung/tokenmaxxxer/core/hooks/lib/role-directive.sh` (shared
  boilerplate api-design's own `directive.sh` already sources)
- `/tmp/claude-1000/core-canon2/docs/handbooks/canon-scripts.md` (the
  canon-scripts norm)
- This repo's `api-design/hooks/directive.sh`, `api-design/hooks.json`
  → `api-design/hooks/hooks.json`, `docs/issue-1/proposals/api-design.md`,
  `docs/issue-1/reports/api-design.md`

## Must-bes extracted (what a rulebook methodology gate must do)

1. **Register on `PreToolUse` with matcher `Write|Edit|MultiEdit`**,
   pointed at a role-owned script — not folded into `SessionStart`
   (which only prints the directive once per session and cannot see or
   block individual writes).
2. **Fail closed on ambiguity or internal error.** pricing's gate wraps
   its Python body in `try/except` with a fail-closed handler, and its
   outer shell sets a `trap __fc EXIT` that turns any non-{0,2} exit
   into a hard deny. A gate that silently passes on a parse error or
   unexpected payload shape is not a gate.
3. **Scope the check to the role's own write surfaces via path regex**,
   and exit 0 immediately for anything outside them — a methodology
   gate must not become a generic file-content linter for the whole
   repo, and must not accidentally gate unrelated roles' records.
4. **Reconstruct resulting content, not just present content.** The
   gate must simulate what `Write`/`Edit`/`MultiEdit` would produce
   (applying `old_string`→`new_string` for Edit/MultiEdit) before
   checking for required elements — checking only the tool's raw diff
   fields would miss content assembled via Edit.
5. **Enumerate required elements as independent boolean checks**, and
   report every missing one together in a single deny message (not
   just the first failure) — pricing's six-element checklist denies
   with a comma-joined list of all missing elements at once.
6. **Deny with the deficiency and pointer to the norm document**, not a
   bare "denied" — every pricing deny message names the missing
   elements and cites `docs/issue-1/proposals/methodology-norms.md`.

## Performance axes (where implementations differ)

1. **Ordering/state dependency.** pricing-rulebook's methodology has no
   cross-write ordering constraint — every required element the gate
   checks lives inside the single file being written, so its gate is
   stateless (pure content check, no external state file). Issue #1's
   ADR proposal norm is similarly single-file (all five ADR sections
   live in one `docs/issue-<n>/proposals/api-design.md` document), and
   the four PRODUCES fields also live in one record file — so api-design's
   methodology, like pricing's, has **no genuine cross-file ordering
   constraint to enforce mechanically**. The repo-level survey →
   proposal → Approve → record sequence (contract v3 s19) is already
   enforced by the PR/Approve-gate mechanism itself, not by anything a
   role-local content gate should re-implement.
2. **Root-detection strategy.** pricing's gate tries
   `CLAUDE_PROJECT_DIR` first (validated via a `_plausible`/`_under`
   sandity check), then falls back to `git rev-parse
   --show-toplevel` from the target's directory, then from cwd — three
   fallbacks before failing closed. A gate with only one detection path
   is more fragile under different invocation contexts (subagent cwd,
   worktree checkouts).
3. **Content-check granularity.** pricing's six checks mix "is a keyword
   present" tests (method-named) with a conditional rule (family-named
   *only if* conjoint-family language appears) and a derived rule
   (labeled-numbers *only if* digits are present at all). A field-presence
   gate for api-design's four PRODUCES headers is a simpler case
   (structural: are the four named sections/labels present) but should
   still borrow the conditional pattern for phase-1 proposals (e.g. only
   require "alternatives considered" content, not just a heading with no
   body).

## Adopt / skip

- **Adopt:** PreToolUse + Write|Edit|MultiEdit registration; fail-closed
  trap + exception wrapper; path-regex scoping to this role's own two
  write surfaces; resulting-content reconstruction for Edit/MultiEdit;
  all-missing-at-once deny messages naming the proposal document.
- **Adopt, adapted:** the three-tier root-detection fallback, unchanged
  in shape (api-design's write surfaces are the same shape as pricing's:
  `docs/issue-<n>/proposals/*api-design*.md` and
  `docs/issue-<n>/reports/api-design.md`).
- **Skip:** any state-tracking/ordering file — api-design's methodology,
  like pricing's, has no cross-file ordering dependency for a role-local
  gate to enforce; inventing one would gate a constraint the PR/Approve
  process already owns.
- **Skip:** vendoring pricing's script itself. Per
  `docs/handbooks/canon-scripts.md`'s canon-scripts norm, only files
  under `core/hooks/` are "canon scripts" referenced-not-copied in the
  strict sense; pricing-rulebook's `methodology-gate.sh` is itself a
  role-local, non-canon script belonging to a sibling plugin, so it is
  not something api-design either vendors or references at runtime —
  it is read here purely as a **design pattern**, and api-design's own
  gate (if approved in phase 2) must be an independently written script
  under `api-design/hooks/`, not a copy or a runtime `source` of
  pricing's file.

## Gap line

Met: none of pricing-rulebook's must-bes are currently present in
api-design (survey.md gaps 1–5) — api-design has zero `PreToolUse`
hooks today. Missing: the gate script itself, its `hooks.json`
registration, and any test coverage. This scout brief and the
survey together are the basis for the proposal's gate design in
`docs/issue-7/proposals/api-design.md`.

## Sources (internal-canon file reads; no web search performed)

- `/home/jwjung/tokenmaxxxer/rulebooks/pricing-rulebook/pricing/hooks/hooks.json`
- `/home/jwjung/tokenmaxxxer/rulebooks/pricing-rulebook/pricing/hooks/methodology-gate.sh`
- `/home/jwjung/tokenmaxxxer/core/hooks/lib/role-directive.sh`
- `/tmp/claude-1000/core-canon2/docs/handbooks/canon-scripts.md`
- `api-design/hooks/directive.sh`, `api-design/hooks/hooks.json` (this repo)
- `docs/issue-1/proposals/api-design.md`, `docs/issue-1/reports/api-design.md` (this repo)
